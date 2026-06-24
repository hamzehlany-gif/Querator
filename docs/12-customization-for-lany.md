# 12 — Customizing Querator for Lany

The actionable "what we're changing and why" doc. Built from the codebase reality (docs 01–11) + Lany's direction.
Everything else is *how it works*; this is *how we make it ours*.

## 0. Fork goals (in your words)

- **Replace workarounds with solid core functions.** Things currently hacked around outside the plugin should become
  first-class plugin features. Canonical example: **a warmup ready-timer that penalizes players who don't ready up** —
  MatchZy has no such thing (it runs an effectively infinite warmup, `mp_warmuptime 9999`, with only repeating
  "unready players" chat reminders).
- **Tighter Lany integration** — own the event/demo/backup seam with `lanyBot` (`/webhooks/matchzy`) and `lany-clipper`.
- **Own & rebrand the core** — MatchZy → **Querator** (priority #1).
- **Match formats & stats** — BO3/BO5 pugs, side-type parsing, richer stats for Glicko + the frontend.
- **Fix gaps & dead code.**

**Lany-only.** This plugin will never be shared outside Lany — that frees us from upstream-compat constraints where
they cost us (but see the Get5 note in §7 — "Lany-only" doesn't automatically mean "rip Get5 out").

> Where Querator sits: it's the on-VM match engine, deployed/version-managed by **lany-node-agent**, configured via
> `querator_loadmatch[_url]`, posting events to **lanyBot** and demos/backups to upload URLs. See the
> [Lany-wide notes](../../LANY.md). **Any rename or cvar change is coupled to lany-node-agent (config sync + plugin
> update/rollback) and lanyBot (commands/webhooks) — coordinate, don't surprise them.**

---

## 1. Priority #1 — Rebrand MatchZy → Querator (do it in tiers)

The identity is "MatchZy" in ~8 distinct places, each with a **different blast radius**. Do the safe tier first; treat
the coupled tier as a coordinated change with `lany-node-agent`/`lanyBot`.

### Tier A — cosmetic / internal (safe, do first)
| What | Where | Notes |
|---|---|---|
| `ModuleName`, `ModuleAuthor`, `ModuleDescription` | [`Querator.cs`](../Querator.cs) | `ModuleName "MatchZy"` → `"Querator"`. Changes the load banner + `css_plugins` name. |
| Chat prefix default | `Querator.cs` `chatPrefix` + `config.cfg` `querator_chat_prefix` | `[{Green}MatchZy{Default}]` → `[{Green}Querator{Default}]` (or Lany branding). |
| Namespace + class name | every `.cs` (`namespace MatchZy`, `class MatchZy`) | Mechanical rename (`MatchZy` → `Querator`). The class is `partial`, so rename consistently across all files. |
| Assembly / DLL name | rename `Querator.csproj` → `Querator.csproj` | Produces `Querator.dll`; deploy folder becomes `plugins/Querator/`. **Update lany-node-agent's plugin path/manifest.** |
| `get5_status` `plugin_version` string, credits message | `G5API.cs`, `Utility.cs` | Optional vanity. |

### Tier B — coupled to external systems (coordinate before changing)
| What | Where | Coupling / risk |
|---|---|---|
| **ConVar prefix** `querator_*` | `ConfigConvars.cs`, `ConsoleCommands.cs`, all `config.cfg`/cfgs | **lany-node-agent config sync + lanyBot RCON likely send `querator_*`.** Safest: add `querator_*` **aliases** (like the existing `get5_*`) and keep `querator_*` working, then migrate callers. Don't hard-rename in one shot. |
| **cfg folder** `MatchZy/` | `Utility.cs` path consts (`warmupCfgPath`…), `SleepMode.cs`, `PracticeMode.cs`, deploy layout | Renaming `cfg/Querator/` → `cfg/Querator/` breaks deployed configs + lany-node-agent's config templates. Coordinate the move. |
| **lang keys** `matchzy.*` | all `lang/*.json` + every `Localizer["matchzy…"]` call | Mechanical but large; purely internal (no external consumer) → safe-ish, just big. Can defer. |
| **DB table names** `querator_stats_*` | `DatabaseStats.cs` (both dialects) | ⚠️ **Renaming breaks existing data and any direct SQL readers.** lanyBot stores match data in **MongoDB** (via events), so it likely doesn't read these tables — *verify*. If nothing reads them directly, a rename is low-risk but pointless; recommend **leaving table names** for data continuity. |
| **get5_\*** aliases | `*.cs` | Keep/drop per §7. |
| Release workflow zip names / `ModuleVersion` grep | `.github/workflows/build.yml` | Only matters if you keep upstream-style releases. Lany deploys via lany-node-agent, so the workflow may be irrelevant — consider replacing it with a Lany build/publish step. |

**Recommended rebrand order:** Tier A (one PR, ship, smoke-test) → lang keys (mechanical, internal) → `querator_*`
cvar aliases (additive, non-breaking) → coordinate cfg-folder + lany-node-agent path move → leave DB tables alone.

---

## 2. Flagship feature — warmup ready-timer + not-ready penalty

**Today:** `StartWarmup()` ([`Utility.cs:230`](../Utility.cs)) sets `mp_warmuptime 9999` and starts a repeating
"unready players" reminder (`SendUnreadyPlayersMessage`, every `chatTimerDelay`). There is **no countdown and no
penalty** — readiness is gated purely by `CheckLiveRequired()` and players can stall forever.

**Design (core function, Lany-integrated penalty):**
1. **New cvars** (add to `ConfigConvars.cs` + `config.cfg`): `querator_ready_timer_seconds` (0 = off),
   `querator_ready_timeout_action` (`none|kick|spec|forfeit|report`), maybe `querator_ready_warn_intervals`.
2. **Arm a countdown** when warmup with `readyAvailable` begins (in `StartWarmup`/`HandleMatchStart` path): a CSSharp
   `AddTimer` that ticks down and broadcasts "N seconds to ready" (reuse the localization + `chatTimerDelay` cadence).
   Cancel it when `CheckLiveRequired()` passes (everyone readied).
3. **On expiry**, compute the not-ready set from `playerReadyStatus` (you already have this), and apply
   `querator_ready_timeout_action`:
   - `kick` / `spec` → use `KickPlayer` / `SwitchPlayerTeam(player, Spectator)` (helpers exist in `Utility.cs`).
   - `report` (recommended for Lany) → **emit a new event** (`ready_timeout` / `player_not_ready` with the steamids)
     to `querator_remote_log_url`, and let **lanyBot apply the real penalty** (rating hit, queue cooldown, ban) — it
     already owns moderation/penalties. This keeps the *policy* in lanyBot and the *detection* in the plugin (clean
     separation; no duplicate penalty logic).
4. Localize all new messages (`lang/en.json`, `querator.ready.*`).

This is the template for "workaround → core function": **detect in-plugin, emit an event, let lanyBot enforce.**

---

## 3. Harden the Lany integration seam (events / demos / backups)

This is the contract with lanyBot/clipper — make it complete and reliable. Concrete fixes (all documented in
[10](10-demos-backups-events-damage.md)):

- **Fire `demo_upload_ended`.** The `QueratorDemoUploadedEvent` class exists but `UploadFileAsync` never sends it.
  lany-clipper needs to know when a demo is uploaded/ready — wire this event (with `success` + filename) so the clip
  pipeline can trigger. **High value, low effort.**
- **Decide on demo zipping.** `System.IO.Compression` is imported but unused; demos upload raw. If R2/bandwidth or
  lany-clipper expects `.zip`, add it; otherwise drop the import. (Raw `.dem` is fine for `demoparser2`/`csdm`.)
- **Event delivery reliability.** `SendEventAsync` is fire-and-forget with **no retry/dedup** and a new `HttpClient`
  per call. For a webhook system of record, add: a shared `HttpClient`, a small retry/backoff, and an idempotency key
  (matchid+mapnumber+round+event) so lanyBot can dedup. Consider a tiny in-memory queue so a webhook blip doesn't drop
  `series_end`/`map_result`.
- **Add Lany-specific events freely.** Since lanyBot is the only consumer, you are not bound to Get5's event schema
  for *new* events (e.g. `ready_timeout`, `player_penalized`, `coach_changed`, richer per-round player stats). Keep the
  existing event *names/fields* stable (lanyBot parses them), but extend at will.
- **Align field names with `/webhooks/matchzy`.** Confirm lanyBot's webhook handler expects the exact `event`/field
  names in [`Events.cs`](../Events.cs); treat that as the integration test.

---

## 4. Match formats & stats

- **`match_side_type` is never parsed** ([07](07-match-management-and-get5.md#2-the-matchconfig-model-matchconfigcs)) —
  add it to `GetOptionalMatchValues` to unlock `random` / `never_knife` / `always_knife` sides without code changes.
  Cheap, isolated win.
- **BO3/BO5 pugs** — `HandleMatchEnd` explicitly TODOs multi-map pugs (only match-mode series are handled). If Lany
  runs pug series, generalize the pug path to reuse the series logic.
- **Stat parity for Glicko/frontend** — the **DB schema has no `kast`/`mvp` columns**, but the event `PlayerStats`
  shape does ([09](09-persistence-database.md) vs [07](07-match-management-and-get5.md#7-stats-wire-shapes-matchdatacs)).
  Since lanyBot computes Glicko from events (Mongo), make sure `GetPlayerStatsDict` populates everything lanyBot's
  rating needs; the SQLite/CSV side is secondary (arguably disposable for Lany — see §6).

---

## 5. Known gaps & dead code to clean (from the deep dive)

| Item | Where | Doc |
|---|---|---|
| `TechPause` is WIP dead code; tech-pause cvars only gate normal pausing | `Pausing.cs` | [08](08-readiness-knife-pausing-coaching.md#3-pausing) |
| `demo_upload_ended` never fired; demos not zipped | `DemoManagement.cs` | [10](10-demos-backups-events-damage.md#1-demos-demomanagementcs) |
| `lastBackupFileName` unused; `lastQueratorBackupFileName` assigned off-file | `BackupManagement.cs` | [10](10-demos-backups-events-damage.md#2-backups--restore) |
| Imported nade lineups lack `Type` → break `.listnades`, default to smoke | `PracticeMode.cs` | [05](05-practice-mode.md#6-saved-nades-lineups) |
| Global-nade flag honored in save/delete, ignored in import/load | `PracticeMode.cs` | [05](05-practice-mode.md) |
| `collisionGroupTimer` shared field → orphaned bot-collision restore | `PracticeMode.cs` | [05](05-practice-mode.md#4-bots-described-in-code-as-a-lot-of-workarounds) |
| best/worst spawn crash on empty spawn list; `RemoveSpawnBeams` is server-wide | `PracticeMode.cs` | [05](05-practice-mode.md#3-spawns) |
| No DB migrations; schema in ~4 places | `DatabaseStats.cs` | [09](09-persistence-database.md#5-maintainer-gotchas) |
| Single un-disposed DB connection, no transactions/concurrency guard | `DatabaseStats.cs` | [09](09-persistence-database.md) |
| `HandleClanTags` is a no-op | `Utility.cs` | [11](11-utility-localization-configs.md) |
| Get5 status TODOs (connected_clients=-1, ready is global, round_time null) | `G5API.cs` | [07](07-match-management-and-get5.md#6-get5-status-surface-g5apics) |

**Most fragile thing to respect, not "fix":** the **signature-scanned grenade create-funcs** in
[`GrenadeProjectiles.cs`](../GrenadeProjectiles.cs) — they break on CS2 updates. Keep a re-scan procedure handy; this
is the #1 thing that will break practice mode after a game patch.

---

## 6. Architectural cautions for the fork

- **One giant `partial class` + global mutable flags.** No tests, no encapsulation. Every change risks flag
  desync. Keep transitioning through the lifecycle functions ([03](03-match-lifecycle.md#7-cheat-sheet-who-sets-the-big-flags));
  consider adding lightweight invariant logging when you touch flow.
- **No automated tests** — your only safety net is loading on a server. The fast Lany loop is: build →
  `lany-node-agent` deploys to a CS2 VM (it's literally built for SM-plugin update + rollback) → test/observe →
  rollback if bad. Lean on that.
- **The on-server SQLite/MySQL DB may be redundant for Lany** — lanyBot is the system of record (MongoDB via events).
  Options: keep SQLite as a local black-box backup, or stop relying on it and treat events as canonical. Don't invest
  in the DB layer unless you actually query it.
- **Hardcoded cfg fallbacks** duplicate the `.cfg` files — if you change competitive defaults, change both or the
  fallback drifts.

---

## 7. Get5 compatibility — keep or drop? (you asked for the trade-off)

**What "Get5 compat" actually is here:** (a) `get5_*` **aliases** for ~18 commands (one-line dupes), (b) the
`get5_status`/`get5_web_available` JSON probes, (c) the remote-log **event JSON shape** loosely modeled on Get5, (d)
`plugin_version "0.15.0"` advertised to panels.

| | Keep | Drop |
|---|---|---|
| **Pros** | Near-zero maintenance (aliases are trivial). `get5_status` is a genuinely useful **health/status probe** lany-node-agent could poll. Lets you drop in a G5V/G5API panel later as a free admin UI. Easier to cherry-pick upstream MatchZy fixes. | Less surface to read/understand. Frees event JSON from any implicit Get5 contract. Cleaner "this is ours" codebase. |
| **Cons** | Extra commands/JSON to keep in your head; implies a Get5 contract you only partially meet (the status TODOs). | You lose the panel escape-hatch and the status probe; reintroducing later is annoying; bigger initial diff during the rebrand. |

**Recommendation (Lany-only):** **Keep the cheap parts, drop the constraint.**
- **Keep** `get5_status` + `get5_web_available` (rename their advertised version if you like) — they're a useful
  status surface for lany-node-agent and cost nothing.
- **Keep** the `get5_*` command aliases for now (they're one-liners) — removing them is busywork that adds risk during
  the rebrand. Drop them in a later cleanup if you confirm nothing calls them.
- **Stop treating the event JSON as a frozen Get5 schema.** lanyBot is the only consumer — own the event shapes,
  extend freely (§3). This is where "Lany-only" actually pays off, not in deleting a few aliases.

Net: you don't *need* Get5, but the maintenance cost of keeping the useful 80% is ~zero, and `get5_status` is worth
keeping. Spend the effort on owning the **events**, not on excising Get5.

---

## 8. Suggested roadmap (given "rebrand first")

1. **Rebrand Tier A** (identity/namespace/DLL) → ship → smoke-test on a VM via lany-node-agent. Update node-agent's
   plugin path/manifest.
2. **Quick wins** while you're in there: fire `demo_upload_ended`, parse `match_side_type`, fix the imported-nade
   `Type` bug.
3. **Ready-timer + not-ready penalty** (§2) — the flagship "workaround → core function," with the penalty delegated to
   lanyBot via a new event.
4. **Event-seam hardening** (§3) — retry/idempotency/shared client; confirm field alignment with `/webhooks/matchzy`.
5. **Rebrand Tier B** as a coordinated change (querator_* cvar aliases → cfg-folder move with node-agent).
6. **Formats/stats** (§4) and **dead-code cleanup** (§5) as ongoing.

> Keep these notes (`docs/`) updated as you change behavior — they're the map for everyone (including future-you and
> AI assistants) working on Querator.
