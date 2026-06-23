# Querator Rebrand Log — MatchZy → Querator

Append-only ledger of the multi-sub-phase rebrand (see the approved plan). Purpose: traceability, justification, and
reversibility of every change "in case we need it some day." Records changes across **all** Lany repos, even though it
lives in Querator. Companion to [`LANY.md`](../../LANY.md) and the engineering docs in [`docs/`](00-index.md).

> Scope rule: we erase "matchzy" **branding**; the upstream MIT attribution is retained on purpose (see `CREDITS`).

## Master old → new mapping (canonical dictionary)

| Old | New | Sub-phase | Status |
|---|---|---|---|
| MatchZy (project identity / branding, docs, comments) | Querator | SP1 / SP3 | in progress |
| `namespace MatchZy` / `class MatchZy` | `namespace Querator` / `class Querator` | SP2 | done |
| `MatchZy*Event` / `MatchZyStats*` (DTO type names) | `Querator*Event` / `QueratorStats*` | SP2 | done |
| `ModuleName "MatchZy"` | `"Querator"` | SP-B1 (coupled) | planned |
| `ModuleVersion 0.8.15` | `1.0.0` | SP3 | done |
| `ModuleAuthor "WD-…"` | `Lany (https://lany.gg)` | SP3 | done |
| `MatchZy.dll` / `plugins/MatchZy` | `Querator.dll` / `plugins/Querator` | SP-B2 (coupled) | planned |
| `cfg/MatchZy/` | `cfg/Querator/` | SP-B2/B3 (coupled, node-agent env) | planned |
| `matchzy_*` cvars | `querator_*` | SP-B3 (coupled) | planned |
| `/api/matchzy/*` | `/api/querator/*` | SP-B4 (coupled) | planned |
| `x-matchzy-secret` | `x-querator-secret` | SP-B5 (coupled) | planned |
| config-root `'matchzy'` | `'querator'` | SP-B6 (coupled + Mongo migration) | planned |
| `MatchZy_Stats` / `MatchZyDataBackup` / `matchzy.db` / demo `MatchZy/` | `Querator_Stats` / `QueratorDataBackup` / `querator.db` / `Querator/` | SP-B7 (data migration) | planned |
| `MATCHZY_*` / `ORCHESTRATOR_MATCHZY_*` env | `QUERATOR_*` | SP-B8 (coupled) | planned |
| release `MatchZy-*.zip` + upstream release source | `Querator-*.zip` + fork source | Phase C | planned |
| lany-docs MatchZy references (37 refs/10 files) | Querator | Phase C | planned |
| `get5_*` surface | (decision: keep; optional removal later) | post-rebrand | deferred (D7) |
| `lastMatchZyBackupFileName` (variable) | `lastQueratorBackupFileName` | SP2 | done |

> Consumers that break on a coupled rename (must change in lockstep) — see the plan's impact map: node-agent
> `rconDetector.js:60`, `detector.js:265`, `plugin.js:254`, `MATCHZY_*` env, config templates; lanyBot
> `matchzy.service.ts`, `cs2.service.ts:340`, `matchzy.controller/routes`, `updateResolver.service.ts:209`,
> `config/index.ts`; lany `orchestratorApi.ts` + admin UI.

## Sub-phase entries

### SP1 — prose & comments (Phase A) — 2026-06-21 — ✅ done
- **Branch:** `rebrand-a-sp1-prose` (off `rebrand-a` off `dev`). Repo: **Querator only**.
- **Changes (identity prose/comments only):**
  - `README.md` — rebranded to Querator with prominent "a Lany fork of MatchZy" header + attribution.
  - `documentation/mkdocs.yml` — `site_name`/`site_url`/`repo_url`/`repo_name`/social → Querator/fork.
  - `documentation/docs/index.md` — identity prose → Querator (+ fork note).
  - `CLAUDE.md` (root) — identity prose → Querator + rebrand-in-progress note (technical refs kept accurate).
  - Code comments: `G5API.cs:180`, `Utility.cs:134`, `ConsoleCommands.cs:621/640` → Querator.
  - Added `CREDITS`; `LICENSE` untouched.
  - `docs/*` — "rebrand is a future decision" → "in progress (see this log)".
- **Kept per SP1 guardrail (still live in code/integration):** `MatchZy.cs`, `MatchZy.dll`, `plugins/MatchZy`,
  `cfg/MatchZy`, `matchzy_*`, `/api/matchzy`, `x-matchzy-secret`, config-root `'matchzy'`, data dirs, and the
  `lastMatchZyBackupFileName` variable (+ its comment at `BackupManagement.cs:103`).
- **Verification:** ✅ `dotnet publish` succeeded (exit 0); `MatchZy.dll` produced; DLL behavior-identical (only
  comments/docs changed — comments aren't compiled). `ModuleName` still "MatchZy" so node-agent/lanyBot detection
  unaffected.
- **Deploy:** none (prose only).
- **Rollback:** delete/revert `rebrand-a-sp1-prose`.

### SP2 — code identifiers (Phase A) — 2026-06-21 — ✅ build green; ✅ VM load smoke passed (2026-06-22)
- **Branch:** `rebrand-a-sp2-identifiers` (off `rebrand-a`). Repo: **Querator only**.
- **Changes (internal identifiers; case-sensitive allow-list, never a blanket replace):** `namespace MatchZy`→`Querator`
  (all files); `partial class MatchZy`→`Querator`; the `MatchZy*Event` / `MatchZyStatsTeam` / `MatchZyTeamWrapper` DTO
  type names → `Querator*`; `lastMatchZyBackupFileName`→`lastQueratorBackupFileName`. Engineering-doc references
  updated to match (docs 00,01,03,06,07,10,11 + CLAUDE.md prose notes).
- **Kept (string literals / coupled — verified counts):** `ModuleName "MatchZy"` (1), `"MatchZy/"` cfg paths (15),
  `MatchZy_Stats`/`MatchZyDataBackup` (5), `matchzy_*` cvars (94), `matchzy.*` lang keys, `MatchZy.cs` filenames,
  `MapResultEvent`/`GoingLiveEvent` (no MatchZy prefix). **Source files NOT renamed** (deferred to the DLL/csproj
  rename, SP-B2).
- **Deferred (internal camelCase, later identifier sweep):** `matchzyTeam1`/`matchzyTeam2` and other lowercase-`matchzy`
  fields.
- **Verification:** ✅ `dotnet publish` exit 0 (compiles). DLL still `MatchZy.dll`, `ModuleName` still "MatchZy" →
  node-agent/lanyBot detection unaffected. ✅ **VM load smoke (2026-06-22, `82.212.83.229`):** deployed flat to
  `plugins/MatchZy/`, `cs2` restarted → CSSharp `Finished loading plugin MatchZy` at 19:56:31 (74 ms), **zero
  errors/exceptions/warns**. Deployed DLL verified to carry **31 `Querator`** namespace/class markers + all
  `Querator*Event` DTOs, and 5 retained `MatchZy` string literals (= the "Kept (5)" count). The renamed
  `partial class Querator` instantiates fine — CSSharp locates the `BasePlugin` subclass by type-scan, not by name.
- **Ops notes (not rebrand changes, logged for traceability):**
  - Discovered the VM's node-agent plugin-install is **nested one level too deep** (real DLL was at
    `plugins/MatchZy/addons/counterstrikesharp/plugins/MatchZy/MatchZy.dll`, with a duplicate `cfg/MatchZy/` inside the
    plugin folder). Moved the cruft to `/tmp/matchzy-botched-bak/` and deployed flat to the correct path. Filed as a
    **TODO for SP-B2/SP-C1** — see the plan's §8a (likely affects the whole fleet).
  - Fixed `scripts/deploy-to-vm.ps1`: `Compress-Archive`+`unzip` emitted a backslash-separator warning → `unzip` exit 1
    → that broke the `&& systemctl restart` chain (files updated but server never restarted). Switched to `tar.gz`
    (forward slashes, exit 0) + base64-piped remote script + a post-restart load-poll that confirms a clean reload.
- **Merge:** ✅ merged `rebrand-a-sp2-identifiers` → `rebrand-a` (local, no push) after the gate passed.
- **Rollback:** revert the merge on `rebrand-a`, or reset `rebrand-a` to its pre-SP2 tip; the `rebrand-a-sp2-identifiers`
  branch is retained.

### SP3 — cosmetics: module metadata, banner, chat prefix, credits (Phase A) — 2026-06-23 — ✅ build green; ✅ VM load smoke passed (2026-06-23)
- **Branch:** `rebrand-a-sp3-cosmetics` (off `rebrand-a`). Repo: **Querator only**.
- **Changes (runtime-visible branding + module metadata; surgical, no blanket replace):**
  - `MatchZy.cs:17` — `ModuleVersion` `0.8.15` → `1.0.0`.
  - `MatchZy.cs:19` — `ModuleAuthor` `"WD- (…shobhit-pathak…)"` → `"Lany (https://lany.gg)"`.
  - `MatchZy.cs:23` — `chatPrefix` field default `[Green]MatchZy[Default]` → `[Green]Querator[Default]`.
  - `MatchZy.cs:545` — `[LOADED]` console banner trailing prose `MatchZy by WD- (…)` → `Querator by Lany (https://lany.gg)`.
    The `[{ModuleName} {ModuleVersion} LOADED]` prefix is unchanged — `{ModuleName}` still resolves to "MatchZy"
    (coupled, SP-B1), so the banner currently prints `[MatchZy 1.0.0 LOADED] Querator by Lany …` by design; it
    auto-flips to `[Querator …]` once SP-B1 renames `ModuleName`.
  - `ConfigConvars.cs:188` — `matchzy_chat_prefix` reset-to-default path → `[Green]Querator[Default]` (kept in sync with
    the field default above; the chat-prefix default lives in **two** places).
  - `Utility.cs:790` — credits-on-match-start chat message `MatchZy Plugin by WD-` → `Querator Plugin by Lany`.
- **Kept (coupled / deferred — NOT touched in SP3):** `ModuleName "MatchZy"` (SP-B1); all `matchzy_*` cvar **names** +
  their help-text descriptions — incl. the `matchzy_show_credits_on_match_start` description that still quotes
  `'MatchZy Plugin by WD-'` (`ConfigConvars.cs:23`) and the `matchzy_chat_prefix`/`_admin_chat_prefix` descriptions
  (`ConfigConvars.cs:179/199`); `cfg/MatchZy/` files incl. the `config.cfg:110` credits comment;
  `matchzy_hostname_format` default `"MatchZy | {TEAM1} vs {TEAM2}"` (`ConfigConvars.cs:25`) — discovered branding
  string, **deferred** (decide: late-SP3 vs SP-B3). These ride with SP-B3 (cvar rename) / SP-B2 (cfg path) / docs sweep.
- **Verification:** ✅ `dotnet publish -c Release` exit 0 (only pre-existing upstream warnings). DLL still `MatchZy.dll`.
  UTF-16 user-string scan of the built DLL: new branding present (`Querator by Lany` ×1, `Lany (https://lany.gg)` ×1,
  `Querator`/`Lany`/` Plugin by ` fragments — the credits line is interpolated so it isn't one contiguous literal);
  old runtime banner `MatchZy by WD-` gone (×0); the single remaining `MatchZy Plugin by WD-` user-string is the
  intentionally-deferred cvar help text. `ModuleName "MatchZy"` retained in metadata → node-agent/lanyBot load
  detection ("Finished loading plugin MatchZy") unaffected.
- **⚠️ Cross-repo flag (ModuleVersion 0.8.15→1.0.0):** lanyBot `updateResolver.service.ts:209` keys on the installed
  version. `1.0.0` > upstream `0.8.x`, so it won't try to revert us to an upstream MatchZy release (protective), but
  **confirm lanyBot's update logic before this DLL is deployed to a live server or merged to `main`** (a `main` push
  cuts a GitHub release tagged from `ModuleVersion`). Pushing `rebrand-a` to origin is inert — CI/release trigger on
  `main` only.
- **Deploy:** ✅ **VM load smoke passed (2026-06-23, `82.212.83.229` / host `carlos`)** via `scripts/deploy-to-vm.ps1`.
  `cs2` restarted 09:05:46 UTC; deployed `MatchZy.dll` (mtime 09:05:34) verified to carry `ModuleVersion 1.0.0` + the
  `LOADED] Querator by Lany (https://lany.gg)` banner string; CSSharp log shows clean
  `unloading… → Loading plugin MatchZy → Finished loading plugin MatchZy` (09:05:48, ~146 ms), **zero
  errors/exceptions**. (lanyBot/node-agent detection still keys on ModuleName "MatchZy" — unaffected.)
- **Ops notes (not rebrand changes, logged for traceability):**
  - `scripts/deploy-to-vm.ps1` carried 8 em-dashes (U+2014). Windows PowerShell 5.1 reads BOM-less files as ANSI, and
    the em-dash inside a double-quoted string terminated it early → parse error (script never executed; VM untouched on
    the first attempt). Replaced all `—`→`--` (ASCII-clean) and re-ran successfully.
  - The script's reload-poll returned a **false negative** (exit 2 "no fresh load confirmed") although the load
    succeeded: `tail -20 | grep "Finished loading plugin"` is too narrow — CS2 startup log spam pushes the load line
    past the last 20 lines before the 2 s poll samples it. **TODO:** scan lines-added-since-snapshot instead of a fixed
    `tail -20`.
- **Merge:** merged `rebrand-a-sp3-cosmetics` → `rebrand-a` (local) after the build gate.
- **Rollback:** revert the merge on `rebrand-a`, or reset `rebrand-a` to its pre-SP3 tip; the `rebrand-a-sp3-cosmetics`
  branch is retained.
