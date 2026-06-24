# 05 — Practice Mode (the 94KB beast)

Everything in [`PracticeMode.cs`](../PracticeMode.cs) (~1840 lines) plus helpers
[`GrenadeProjectiles.cs`](../GrenadeProjectiles.cs), [`GrenadeThrownData.cs`](../GrenadeThrownData.cs),
[`PlayerLocationData.cs`](../PlayerLocationData.cs), [`PlayerPracticeTimer.cs`](../PlayerPracticeTimer.cs). The
command catalog is in [04](04-commands-and-convars.md); this doc is the **mechanics + gotchas**.

> Every practice command exists on **both** dispatch paths (chat `.cmd` via `commandActions`/`StartsWith`, and
> `css_cmd` console). Both call the same `On*`/`Handle*` method. See [01](01-architecture.md#6-command-dispatch--two-distinct-systems).

---

## 1. Key fields (the practice state)

| Field | Type | Purpose |
|---|---|---|
| `lastGrenadesData` | `Dictionary<int, List<GrenadeThrownData>>` | **Per-userid** ordered throw history (1-based in commands, 0-based internally). |
| `nadeSpecificLastGrenadeData` | `Dictionary<int, Dictionary<string,GrenadeThrownData>>` | Per-userid, per-type (`smoke/flash/hegrenade/decoy/molotov`) last nade → `.rethrowsmoke` etc. |
| `lastGrenadeThrownTime` | `Dictionary<int, DateTime>` | **Keyed by projectile entity index** (NOT userid) → "landed in N.NNs" messages. |
| `spawnsData` | `Dictionary<byte, List<Position>>` | Competitive spawns per team (keys `2`=T, `3`=CT). |
| `pracUsedBots` | `Dictionary<int, Dictionary<string,object>>` | Bots spawned via `.bot`, keyed by bot userid; inner dict (`controller`/`position`/`owner`/`crouchstate`) is **untyped `object`** — every read casts. |
| `noFlashList` | `List<int>` | Userids with flash suppression. |
| `playerTimers` | `Dictionary<int, PlayerPracticeTimer>` | `.timer` instances. |
| `savedPlayerLocationData` | `Dictionary<int, PlayerLocationData>` | `.savepos`/`.loadpos` (single slot/player). |
| `maxLastGrenadesSavedLimit` | int (512) | History cap (`querator_max_saved_last_grenades`; 0 disables). |
| `isDryRun` | bool | Dryrun sub-state (see §7). |
| `collisionGroupTimer` | Timer? | **Single shared** bot-collision restore timer. |
| `practiceCfgPath` / `dryrunCfgPath` | const | `Querator/prac.cfg` / `Querator/dryrun.cfg`. |

---

## 2. Enter / exit

- **`StartPracticeMode()`**: refuses if `matchStarted`; sets `isPractice=true; isDryRun=false; isWarmup=false;
  readyAvailable=false`; execs `prac.cfg` (or a hardcoded cheats/infinite-ammo/full-nades/`buddha 1` default);
  `GetSpawns()`; prints help. Does **not** clear history/bots/noflash on entry.
- **`.prac`/`.tactics`** → `OnPracCommand` (admin `@css/map` or `@custom/prac`). There is **no** "`.prac` again to exit"
  toggle.
- **Exit:** `.exitprac` and `.match` both route to **`OnMatchCommand` → `StartMatchMode()`** (note: *not*
  `OnExitPracCommand`, though that console command also exists). `StartMatchMode` → `ExecUnpracCommands()` (revert
  cheats/loadout) → `ResetMatch()` (this is where `isPractice` and `pracUsedBots`/`noFlashList`/history are cleared)
  → `RemoveSpawnBeams()`. ⚠️ `StartMatchMode` does **not** explicitly `bot_kick` — leftover practice bots rely on
  `ResetMatch`.

---

## 3. Spawns

- **`GetSpawns()`**: finds `info_player_*` entities, computes the **minimum `Priority`** among CT spawns, and keeps only
  spawns at that priority (filters out warmup/extra spawns). ⚠️ **T spawns are filtered by the CT-derived
  `minPriority`** — maps with per-team priority differences can yield wrong/empty T spawns.
- `.spawn <n>` (own team) / `.ctspawn <n>` / `.tspawn <n>` → `HandleSpawnCommand` (1-based; lazily re-runs
  `GetSpawns()` if any list is empty). Teleports pawn to the stored pos+ang.
- `.bestspawn`/`.worstspawn` (+ ct/t variants): nearest/furthest spawn by **3D Euclidean distance**. ⚠️ These do
  **not** lazily call `GetSpawns()`, so an empty list → index `-1` → exception.
- `.showspawns`/`.hidespawns`: spawn pillars are `CBeam` entities named `"beam"` (CT blue, T orange).
  ⚠️ `RemoveSpawnBeams()` removes **all** entities named `beam` server-wide.

---

## 4. Bots (described in-code as "a lot of workarounds")

CSSharp can't spawn fake clients directly, so:
- **`.bot`/`.cbot`(`.crouchbot`)** → `AddBot(player, crouch)`: auto-detects if the player is crouching; adds a bot on
  the **opposite** team via `bot_add_*`; schedules `SpawnBot` at +0.1s; immediately `bot_stop 1; bot_freeze 1;
  bot_zombie 1`.
- **`SpawnBot`**: scans `cs_player_controller` for bots, **kicks extras** that `bot_add` spawned, claims one into
  `pracUsedBots` snapshotting the owner's position, applies crouch, teleports the bot to the owner, and disables
  collision temporarily.
- **`.boost`/`.crouchboost`**: `AddBot` then `ElevatePlayer` teleports the **player up +80 units** (stands them on the
  frozen bot's head — pure teleport, no physics stacking).
- **`.nobots`**: `bot_kick` + clear `pracUsedBots`.
- **`OnPlayerSpawn`** re-teleports tracked bots to their stored position on respawn, and **kicks "erroneous" bots**
  (stray `bot_quota_mode fill` bots) after 2.5s when `!isSpawningBot`.
- ⚠️ **`collisionGroupTimer` is a single shared field** — rapid `.bot`/`.boost` calls orphan the prior pair's
  collision-restore (can leave players stuck in `COLLISION_GROUP_DEBRIS`). `AddBot`/`SpawnBot` also `catch
  (JsonException)` — the wrong exception type, so real failures propagate.

---

## 5. Grenade history & rethrow (the clever/brittle part)

### Recording
`OnEntitySpawnedHandler` ([`EventHandlers.cs:208`](../EventHandlers.cs)) fires on grenade projectile spawn (practice
only), defers one frame, and records a `GrenadeThrownData` into `lastGrenadesData[userid]` +
`nadeSpecificLastGrenadeData[userid][type]`. **It skips projectiles with `Globalname == "custom"`** — that tag is set
by `Throw()` on re-thrown nades so they don't re-enter history.

> ⚠️ **`Globalname == "custom"` is load-bearing.** It prevents rethrows from re-entering history AND from recursing.
> Remove it and you get runaway history growth + recursive rethrows.

### `GrenadeThrownData` (struct)
Stores projectile `Position/Angle/Velocity`, thrower `PlayerPosition/PlayerAngle`, `Type`, `ThrownTime`, mutable
`Delay`, and `ItemIndex`.
- `LoadPosition(player)` → teleport the *player* back (for `.last`/`.back`).
- **`Throw(player)`** = the actual rethrow. **Not** "give nade + simulate" — it **directly spawns a projectile with
  the stored velocity**:
  - smoke/he/molotov/decoy → native signature-scanned `C*Projectile_CreateFunc` (in
    [`GrenadeProjectiles.cs`](../GrenadeProjectiles.cs)).
  - **flash** is special-cased (no create-func): `CreateEntityByName<CFlashbangProjectile>` + `DispatchSpawn`. This is
    why flash rethrow can behave differently.
  - tags the new projectile `Globalname="custom"` and reparents `Thrower`/`OwnerEntity` to the player.

> ⚠️ **`GrenadeProjectiles.cs` holds Windows+Linux byte-pattern signature scans** for the create-funcs. **A CS2 update
> that shifts these breaks all non-flash rethrow** until the patterns are re-scanned. This is the single most
> update-fragile part of the plugin.

### Commands
`.last` (teleport to last throw pos), `.back <n>` (to history index n), `.rethrow`/`.rt`/`.throw` (re-throw last after
its `Delay`), `.throwindex <i...>` (throw a **space-separated list** of indices — replays multi-nade setups),
`.lastindex`, `.delay <s>` (set `Delay` on the most recent nade only), and per-type
`.rethrowsmoke/flash/nade(=he)/molotov/decoy`. Detonate handlers print "landed in N.NNs" (suppressed in dryrun;
molotov handler leaks its `lastGrenadeThrownTime` key — minor).

---

## 6. Saved nades (lineups)

- **`savednades.json`** (`csgo/cfg/Querator/savednades.json`):
  `Dictionary<steamid|"default", Dictionary<lineupName, Dictionary<string,string>>>`. Per-lineup fields: `LineupPos`
  (`"X Y Z"`, Z lifted +4), `LineupAng` (`"pitch yaw roll"`), `Desc`, `Map`, `Type` (`Flash/Smoke/HE/Decoy/Molly`;
  both molotov & incendiary → `Molly`).
- **Keying / global flag** (`querator_save_nades_as_global_enabled` / `.globalnades`):
  - save & delete: key = player steamid, or `"default"` when global is on.
  - ⚠️ **import & load ignore the global flag** — import always keys by steamid; load searches the player's steamid
    **and** `"default"`.
- Commands: `.savenade/.sn <name> [desc]` (rejects same name **on the same map**), `.loadnade/.ln <name>` (**fuzzy
  match** via Dice-coefficient bigram similarity; switches to the right grenade slot; prints `Desc` center-screen),
  `.listnades/.lin [filter]`, `.importnade/.in <code>`, `.deletenade/.delnade/.dn <name>`.
- **Import code format = `name X Y Z pitch yaw roll`** (7 space-separated tokens). ⚠️ Imported lineups get **no `Type`
  field**, which breaks `.listnades` (`kvp.Value["Type"]` throws) and makes `.loadnade` default them to the smoke
  slot. There is **no explicit export command** — the shareable "code" is the string printed on save.

---

## 7. Misc toggles

| Command | Effect / gotcha |
|---|---|
| `.noflash`/`.noblind` | Toggle userid in `noFlashList`; `KillFlashEffect` sets `FlashMaxAlpha = 0.5` (dims, not zero). Applied per-flash in `EventPlayerBlind`. |
| `.god` | HP-derived toggle: `Health>100` → 100; else `int.MaxValue`. (Also `buddha 1` from prac.cfg.) |
| `.clear` | Removes smoke/molotov/inferno entities (mollys/inferno are cast to the wrong type but `.Remove()` works on base). |
| `.solid` | Toggles `mp_solid_teammates` 2↔1 (never 0). |
| `.impacts` | Toggles `sv_showimpacts`. |
| `.traj`/`.pip` | Toggles `sv_grenade_trajectory_prac_pipreview`. |
| `.ff`/`.fastforward` | Freezes all players (`MOVETYPE_NONE`), `host_timescale 10` for ~20s scaled (~2s wall), then restores. |
| `.timer` | Toggle a center-screen practice timer (`PlayerPracticeTimer`). A movement-triggered `timer2` is commented out (needs `OnPlayerRunCmd`). |
| `.savepos`/`.loadpos` | Single-slot save/restore of player pos+ang. |
| `.break` | Sends `Break` input to `prop_dynamic`/`func_breakable`. |
| `.fas`/`.watchme` | Moves **all other** players to spectator (`SideSwitchCommand(None)` sentinel). |
| `.spec` | Move self to spectator. |
| `.t`/`.ct` | In practice → `SideSwitchCommand`; ⚠️ refuses to switch **out of** Spectator (known-broken). Overloaded: also used by veto/side-selection. |
| noclip | Global `noclip` hook (`OnConsoleNoClip`), gated on `sv_cheats` + alive/non-spec; toggles `MOVETYPE_NOCLIP`. Force-disabled on every spawn. |

---

## 8. Dryrun (`.dry`/`.dryrun`)

A **sub-state of practice** (admin-gated; requires `!matchStarted && isPractice`). It `bot_kick`s, clears
bots/noflash, runs `ExecUnpracCommands()` (strip cheats), then `ExecDryRunCFG()` (`dryrun.cfg` or a hardcoded
competitive-ish ruleset ending in `mp_restartgame; mp_warmup_end`), and sets `isDryRun=true` while **`isPractice`
stays true**. Net effect: a live-*like* round to test nades against, with no knife/veto and **no DB recording**
(`matchStarted` stays false). To go truly live you still `.exitprac`/`.match`. The `EventRoundEnd` (Post) handler in
[`Querator.cs`](../Querator.cs) detects `isDryRun` and re-enters practice after the dry round.

---

## 9. Maintainer gotchas (consolidated)
1. Two different key spaces: history dicts use **userid**; `lastGrenadeThrownTime` uses **projectile index**.
2. **`Globalname=="custom"`** is load-bearing (see §5).
3. **Signature-scanned create-funcs** break on CS2 updates; **flash** uses a different path (usual outlier).
4. `pracUsedBots` inner dict is `Dictionary<string,object>` — string-key typos fail silently.
5. `collisionGroupTimer` is shared → concurrent bot spawns can orphan collision-restore.
6. Empty-spawn crashes in best/worst-spawn; `RemoveSpawnBeams` is server-wide.
7. Imported lineups lack `Type` → break `.listnades`, default to smoke slot.
8. Global-nade flag is honored in save/delete but ignored in import/load.
9. `.exitprac` and `.match` both route to `OnMatchCommand` (not `OnExitPracCommand`).
