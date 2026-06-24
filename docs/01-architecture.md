# 01 — Architecture & Core Mental Model

This is the single most important doc. It explains *how the plugin is shaped* and *how control flows*, so every
other doc can assume this context.

---

## 1. What Querator is, physically

- A **C# class library** targeting **.NET 8.0** that compiles to **`Querator.dll`**.
- That DLL is loaded **in-process** by **CounterStrikeSharp (CSSharp)**, which is itself a Metamod plugin running
  inside a **CS2 dedicated server**. There is **no standalone executable** — Querator only "runs" as a guest inside a
  live game server.
- It declares `[MinimumApiVersion(227)]` — CSSharp must expose API ≥ 227 or the plugin won't load.
- Identity lives in [`Querator.cs`](../Querator.cs):
  - `ModuleName => "MatchZy"`, `ModuleVersion => "0.8.15"`, `ModuleAuthor`, `ModuleDescription`.
  - ⚠️ The version string lives in **exactly one place** (`ModuleVersion`); the release pipeline greps it from there.
- The class is annotated `[MinimumApiVersion(227)]` and extends `BasePlugin` (the CSSharp base type that provides
  `Load()`, event registration, timers, `Localizer`, `ModuleDirectory`, etc.).

> **Naming note:** the fork is *Querator*. Done (on `rebrand-b` branches, not yet deployed): **C# namespace + class**
> (`Querator`, SP2), **module name** → `"Querator"` (SP-B1), **cosmetics** (version/author/banner/chat-prefix, SP3),
> the **DLL + entry file** → `Querator.dll` / `Querator.cs` (SP-B2); the **ConVar prefix** `matchzy_` → `querator_`
> (SP-B3); the **`/api/matchzy`** routes → `/api/querator` (SP-B4). The rest still uses the MatchZy name (lang keys
> `matchzy.*`, the on-fleet `plugins/MatchZy`/`cfg/MatchZy` paths, `matchzy_stats_*` tables, `MATCHZY_*` env names,
> string-literal paths) — renamed in later,
> mostly cross-repo coupled sub-phases. See [00-REBRAND-LOG.md](00-REBRAND-LOG.md) and [12-customization-for-lany.md](12-customization-for-lany.md).

---

## 2. The single-partial-class design

**The entire plugin is one class: `public partial class Querator : BasePlugin`.** It is split across ~29 `.cs` files
at the repo root *by feature area*, but they all compile into the same class and **share every field and method**.
There is **no per-file encapsulation, no sub-modules, no DI**. A field declared in `Querator.cs` is directly readable
and writable from `PracticeMode.cs`, `MapVeto.cs`, etc.

Implications you must internalize:
- **Global mutable state.** All the `bool` flags, dictionaries, and timers are instance fields on the one class. Any
  handler can flip any flag. Correctness depends on keeping flags mutually consistent (see §5).
- **Add features as new partial-class files**, following the existing split — *not* as new classes. The few genuine
  separate classes are data/helpers: `Database` (in [`DatabaseStats.cs`](../DatabaseStats.cs)), `Constants`,
  the event DTOs in [`Events.cs`](../Events.cs), and small structs like `GrenadeThrownData`, `Position`.
- **`Load()` is the wiring hub.** Read it first; it is the only place that registers everything.

---

## 3. File map (repo-root `.cs` files)

Grouped by concern. Sizes are approximate (bytes) to signal where the weight is.

### Core / lifecycle
| File | ~Size | Responsibility |
|---|---:|---|
| [`Querator.cs`](../Querator.cs) | 24K | Plugin identity, **all core state fields**, `Load()` entry point, the `commandActions` dictionary, the giant `EventPlayerChat` dispatcher, and inline event/listener registrations. |
| [`Utility.cs`](../Utility.cs) | 93K | **Grab-bag of shared helpers** — match start/end orchestration, warmup/live transitions, player maps, chat/print helpers, cfg-path constants, team-side bookkeeping, hostname/cvar handling. The other half of the "core" with Querator.cs. |
| [`Constants.cs`](../Constants.cs) | <1K | Static projectile-name ↔ nade-type maps. |
| [`SynchronizationContextManagement.cs`](../SynchronizationContextManagement.cs) | <1K | Helpers for marshalling async work back onto the game thread. |

### Match flow
| File | ~Size | Responsibility |
|---|---:|---|
| [`MatchManagement.cs`](../MatchManagement.cs) | 27K | Match setup, `loadmatch`/`loadmatch_url`, series state, `isMatchSetup`/`matchModeOnly` flags, team config application. |
| [`MapVeto.cs`](../MapVeto.cs) | 30K | Veto / side-pick state machine, `.ban`/`.pick`/`.back`, BO1/BO3/BO5, knife-vs-`map_sides`, `.skipveto`. |
| [`ReadySystem.cs`](../ReadySystem.cs) | 4K | Ready/unready/forceready, minimum-ready gating. |
| [`Pausing.cs`](../Pausing.cs) | 2K | Pause/unpause/tech/tactical/admin-pause command handlers. |
| [`Teams.cs`](../Teams.cs) | 8K | Team objects, name changes, side bookkeeping, player↔team assignment. |
| [`Coach.cs`](../Coach.cs) | 13K | Coaching slots, coach teleport/spectate, coach bomb transfer. |
| [`SleepMode.cs`](../SleepMode.cs) | 2K | Idle/"sleep" state when no match is active. |

### Practice
| File | ~Size | Responsibility |
|---|---:|---|
| [`PracticeMode.cs`](../PracticeMode.cs) | **94K** | The biggest file. Practice spawns, bots, grenade save/load/import/list, rethrow/last/timer/back/delay, noflash, dryrun, spawn analysis. |
| [`GrenadeProjectiles.cs`](../GrenadeProjectiles.cs) | 2K | Helpers for grenade projectile entities. |
| [`GrenadeThrownData.cs`](../GrenadeThrownData.cs) | 4K | `GrenadeThrownData` DTO (position/angle/velocity/type/time of a thrown nade). |
| [`PlayerLocationData.cs`](../PlayerLocationData.cs) | <1K | `Position` struct (player position + angle). |
| [`PlayerPracticeTimer.cs`](../PlayerPracticeTimer.cs) | <1K | Per-player practice timer state. |

### Commands / config
| File | ~Size | Responsibility |
|---|---:|---|
| [`ConsoleCommands.cs`](../ConsoleCommands.cs) | 33K | `[ConsoleCommand("querator_*")]` server commands + `get5_*` aliases (admin/match management). |
| [`ConfigConvars.cs`](../ConfigConvars.cs) | 17K | `FakeConVar<T>` server cvars + config ConsoleCommands; default values. |

### Persistence / IO
| File | ~Size | Responsibility |
|---|---:|---|
| [`DatabaseStats.cs`](../DatabaseStats.cs) | 30K | The `Database` class — SQLite/MySQL, schema DDL (both dialects), match/map/player stats, CSV export. |
| [`DemoManagement.cs`](../DemoManagement.cs) | 5K | GOTV demo recording start/stop + HTTP upload. |
| [`BackupManagement.cs`](../BackupManagement.cs) | 28K | Round backup/restore (Valve backups) + remote backup upload/download, `.stop`/`.restore`. |
| [`DamageInfo.cs`](../DamageInfo.cs) | 6K | Per-round damage report (utility damage + hits). |
| [`RemoteLogConfig.cs`](../RemoteLogConfig.cs) | 2K | ConVars for remote event log endpoint. |

### Events / Get5 interop
| File | ~Size | Responsibility |
|---|---:|---|
| [`EventHandlers.cs`](../EventHandlers.cs) | 15K | Named game-event handler methods (connect, disconnect, round start/freeze-end, win panels, nade detonations, etc.). |
| [`Events.cs`](../Events.cs) | 6K | `QueratorEvent` DTO class hierarchy (the JSON shapes sent to the remote log). |
| [`PublishEvents.cs`](../PublishEvents.cs) | 2K | Fires/serializes those events to the remote log endpoint. |
| [`G5API.cs`](../G5API.cs) | 10K | `get5_status`-style payloads and Get5 panel compatibility surface. |
| [`MatchConfig.cs`](../MatchConfig.cs) | 3K | `MatchConfig` model (maplist, teams, num_maps, sides, cvars…). |
| [`MatchData.cs`](../MatchData.cs) | 4K | Per-player/team stats shapes (Get5/PugSharp-compatible). |

> **Two files dominate** — `PracticeMode.cs` (94K) and `Utility.cs` (93K). Together they're ~half the codebase.

---

## 4. The `Load()` lifecycle (single entry point)

[`Querator.cs`](../Querator.cs) `Load(bool hotReload)` runs once when CSSharp loads the plugin. In order:

1. **`LoadAdmins()`** — read `cfg/MatchZy/admins.json` into `loadedAdmins` (steamid → permission string).
2. **`database.InitializeDatabase(ModuleDirectory)`** — read `database.json`, pick SQLite/MySQL, create tables if
   missing.
3. **`Server.ExecuteCommand("execifexists MatchZy/config.cfg")`** — apply default ConVars from
   `cfg/MatchZy/config.cfg`.
4. **Seed team-side maps**: `teamSides[team1]="CT"`, `teamSides[team2]="TERRORIST"`, and the reverse map.
5. **`AutoStart()`** (always; on hot-reload it first calls `UpdatePlayersMap()`). AutoStart picks the initial phase
   based on `autoStartMode`.
6. **Build `commandActions`** — the big `Dictionary<string, Action<CCSPlayerController?, CommandInfo?>>` mapping exact
   chat strings (`.ready`, `.pause`, `.spawn`, …) to handler methods. This is dispatch system #1 (see §5).
7. **Register event handlers & listeners** — both named methods and inline lambdas (see §6).
8. Log `"[MatchZy 0.8.15 LOADED] …"`.

**Hot-reload behavior:** CSSharp supports hot-reload, and `Load()` handles `hotReload == true` by refreshing player
maps. **But never hot-reload during a live match** — the state flags set mid-match get out of sync with a fresh
`Load()`. Restart the server instead. (See [02-build-test-deploy.md](02-build-test-deploy.md).)

---

## 5. State flags — the informal "state machine" {#state-flags}

There is **no formal FSM**. Match phase is the conjunction of a set of public fields. Event handlers early-return
based on them, so **keeping them mutually consistent is the #1 correctness concern** when editing flow code.

Complete catalog (file = where declared):

| Flag | Type | Default | File | Meaning |
|---|---|---|---|---|
| `isPractice` | bool | false | Querator.cs | Practice mode is active. |
| `isWarmup` | bool | false | Querator.cs | Warmup phase active. |
| `isKnifeRound` | bool | false | Querator.cs | Knife round in progress. |
| `isSideSelectionPhase` | bool | false | Querator.cs | Post-knife: waiting for `.stay`/`.switch`. |
| `isMatchLive` | bool | false | Querator.cs | The live match is in progress (post going-live). |
| `matchStarted` | bool | false | Querator.cs | Match has advanced past the ready/warmup gate (used widely as "a real game is underway", e.g. damage tracking). |
| `readyAvailable` | bool | false | Querator.cs | Ready-up system is active; players may `.ready`. |
| `isSleep` | bool | false | Querator.cs | Idle "sleep" state (no match active). |
| `isPaused` | bool | false | Querator.cs | Match currently paused. |
| `isPauseCommandForTactical` | bool | false | Querator.cs | `.pause` is treated as a tactical timeout (per ConVar). |
| `isKnifeRequired` | bool | true | Querator.cs | Whether a knife round happens before live. |
| `isWhitelistRequired` | bool | false | Querator.cs | Enforce player whitelist. |
| `isSaveNadesAsGlobalEnabled` | bool | false | Querator.cs | Save nades to the global pool vs per-player. |
| `isPlayOutEnabled` | bool | false | Querator.cs | Play out all rounds (scrim). |
| `playerHasTakenDamage` | bool | false | Querator.cs | A cross-team damage occurred (gates `.stop`). |
| `mapReloadRequired` | bool | false | Querator.cs | A map reload is queued. |
| `liveMatchId` | long | -1 | Querator.cs | DB id of the current live match (-1 = none). |
| `autoStartMode` | int | 1 | Querator.cs | 0=none, 1=match, 2=practice (from `querator_autostart_mode`). |
| `isMatchSetup` | bool | false | MatchManagement.cs | A match config has been loaded (match mode). |
| `matchModeOnly` | bool | false | MatchManagement.cs | Server restricted to match mode (kick non-roster players). |
| `resetCvarsOnSeriesEnd` | bool | true | MatchManagement.cs | Reset cvars when a series ends. |
| `isPreVeto` | bool | false | MapVeto.cs | Pre-veto phase. |
| `isVeto` | bool | false | MapVeto.cs | Veto in progress. |
| `mapChangePending` | bool | false | MapVeto.cs | A map change is queued from veto. |
| `isDryRun` | bool | false | PracticeMode.cs | Dry-run (test match settings without competitive economy). |
| `isStopCommandAvailable` | bool | true | BackupManagement.cs | `.stop` (round restore) is enabled. |
| `pauseAfterRoundRestore` | bool | true | BackupManagement.cs | Auto-pause after a restore. |
| `isRoundRestoring` | bool | false | BackupManagement.cs | A restore is in progress. |
| `isRoundRestorePending` | bool | false | BackupManagement.cs | A restore is queued. |
| `isDemoRecording` | bool | false | DemoManagement.cs | GOTV demo currently recording. |
| `isDemoRecordingEnabled` | bool | true | DemoManagement.cs | Demo auto-recording enabled. |
| `allowForceReady` | bool | true | ReadySystem.cs | `.forceready` permitted. |

Typical phase progression for a match (see [03-match-lifecycle.md](03-match-lifecycle.md) for detail):
`sleep/auto` → **warmup** (`isWarmup`, `readyAvailable`) → both teams `.ready` → **knife** (`isKnifeRound`) →
**side selection** (`isSideSelectionPhase`) → **live** (`isMatchLive`, `matchStarted`).

Phase transitions are driven by **executing `.cfg` files** via `Server.ExecuteCommand`. The canonical config paths
are constants in `Utility.cs` (`warmupCfgPath`, `knifeCfgPath`, `liveCfgPath`, `liveWingmanCfgPath`, etc.).

---

## 6. Command dispatch — **two distinct systems**

### System #1 — Chat commands (`.`/`!`)
Handled inside the `EventPlayerChat` handler registered in [`Querator.cs`](../Querator.cs) (~line 368). Players type
`.ready` etc. in chat (CS2 maps a leading `!` to the same string the plugin lowercases and trims).

Two sub-mechanisms:
- **Exact-match, no-argument** commands → routed through the **`commandActions` dictionary**. To add one, add an
  entry mapping the chat string to a handler `Action<CCSPlayerController?, CommandInfo?>`.
  Full list (alias → handler) as of 0.8.15 — see [04-commands-and-convars.md](04-commands-and-convars.md); examples:
  `.ready/.r → OnPlayerReady`, `.pause/.p → OnPauseCommand`, `.bot → OnBotCommand`, `.spec → OnSpecCommand`, …
- **Argument-bearing** commands → matched with `message.StartsWith("...")` and dispatched to a `Handle*Command`
  method. These read the raw arg string. Examples: `.map`, `.savenade/.sn`, `.loadnade/.ln`, `.coach`, `.ban`,
  `.pick`, `.team1`/`.team2`, `.rcon`, `.asay`, `.restore`, `.spawn`, `.delay`, `.throwindex`.

The chat handler resolves the `CCSPlayerController` from `playerData` (rebuilding the map via `UpdatePlayersMap()` if
the player isn't found), then runs the matching dispatch.

### System #2 — Console commands / ConVars (`querator_*`)
Methods decorated with `[ConsoleCommand("querator_...")]`, mostly in [`ConfigConvars.cs`](../ConfigConvars.cs) and
[`ConsoleCommands.cs`](../ConsoleCommands.cs). Many also register a **`get5_*` alias** for Get5 config compatibility.

- **Server-side ConVar values** use **`FakeConVar<T>`** (CSSharp). There are exactly **11** of them, all in
  `ConfigConvars.cs` (e.g. `querator_smoke_color_enabled`, `querator_enable_tech_pause`, `querator_tech_pause_duration`,
  `querator_max_tech_pauses_allowed`, `querator_everyone_is_admin`, `querator_show_credits_on_match_start`,
  `querator_hostname_format`, `querator_enable_damage_report`, `querator_stop_command_no_damage`,
  `querator_match_start_message`, `querator_tech_pause_flag`). Their `.Value` is read directly in code.
- **Everything else** is a `[ConsoleCommand]` method that parses `command.ArgString` and sets a plain field. The
  conventional guard at the top is `if (player != null) return;` — i.e. **reject if a player (not the server console)
  invoked it**. This makes `querator_*` commands server/RCON-only.

> The full ConVar + console-command catalog (with defaults, `get5_*` aliases, and which field each writes) is in
> [04-commands-and-convars.md](04-commands-and-convars.md).

---

## 7. Event & listener wiring (registered in `Load()`)

CSSharp game events are hooked via `RegisterEventHandler<T>` (optionally `HookMode.Pre`/`Post`),
`RegisterListener<T>`, and `AddCommandListener`. Complete wiring as of 0.8.15:

### Named handler methods (in [`EventHandlers.cs`](../EventHandlers.cs))
| Event | Hook | Handler | Purpose |
|---|---|---|---|
| `EventPlayerConnectFull` | default | `EventPlayerConnectFullHandler` | Whitelist kick, roster kick (match mode), register player, auto-start warmup on first connect. |
| `EventPlayerDisconnect` | default | `EventPlayerDisconnectHandler` | Cleanup player/ready/coach/nade state. |
| `EventCsWinPanelRound` | Pre | `EventCsWinPanelRoundHandler` | **No-op** now (stopped firing after Arms Race update; knife handled in `EventRoundEnd`). |
| `EventCsWinPanelMatch` | default | `EventCsWinPanelMatchHandler` | `HandleMatchEnd()`. |
| `EventRoundStart` | default | `EventRoundStartHandler` | `HandlePostRoundStartEvent()`. |
| `EventRoundFreezeEnd` | default | `EventRoundFreezeEndHandler` | Force coaches back to spectate after freezetime. |
| `EventPlayerGivenC4` | default | `EventPlayerGivenC4` | Transfer bomb off a coach. |
| `EventPlayerDeath` | Pre | `EventPlayerDeathPreHandler` | Suppress coach suicide broadcast. |
| `EventSmokegrenadeDetonate` | default | `EventSmokegrenadeDetonateHandler` | Practice: report smoke flight time. |
| `EventFlashbangDetonate` | default | `EventFlashbangDetonateHandler` | Practice: report flash flight time. |
| `EventHegrenadeDetonate` | default | `EventHegrenadeDetonateHandler` | Practice: report HE flight time. |
| `EventMolotovDetonate` | default | `EventMolotovDetonateHandler` | Practice: report molotov flight time. |
| `EventDecoyStarted` | default | `EventDecoyDetonateHandler` | Practice: report decoy flight time. |

### Inline lambdas (in `Querator.cs` `Load()`)
| Event/listener | Hook | Purpose |
|---|---|---|
| `EventPlayerTeam` | Pre | If player is a coach, mark the team event silent. |
| `EventPlayerTeam` | default | During setup/veto, snap players back to their assigned team (`SwitchPlayerTeam`). |
| `EventRoundEnd` | Pre | If knife round: determine winner, set `@event.Winner/Reason`, enter side-selection, start after-knife warmup. |
| `EventRoundEnd` | Post | If dry-run → start practice; else if live → `HandlePostRoundEndEvent`. |
| `EventPlayerDeath` | default | During warmup, reset dead player's money to 16000. |
| `EventPlayerHurt` | default | Practice bot-damage report; match cross-team damage tracking (`UpdatePlayerDamageInfo`, `playerHasTakenDamage`). |
| `EventPlayerChat` | default | **The chat-command dispatcher** (System #1). |
| `EventPlayerBlind` | default | Practice flash-duration report; kill flash for players in `noFlashList`. |
| `Listeners.OnClientDisconnectPost` | — | Currently a no-op (commented body). |
| `Listeners.OnEntitySpawned` | — | `OnEntitySpawnedHandler` — track thrown grenades in practice (for `.last`/`.rethrow`/smoke color). |
| `Listeners.OnMapStart` | — | After 1s: `AutoStart()` if no match setup, else re-enter warmup/practice. |
| `AddCommandListener("jointeam")` | — | Block manual team change during setup/veto. |
| `AddCommandListener("noclip")` | — | `OnConsoleNoClip` — override noclip behavior. |

Commented-out (intentionally disabled): `EventMapShutdown` reset, `Listeners.OnMapEnd` reset.

---

## 8. NuGet dependencies (from [`Querator.csproj`](../Querator.csproj))

| Package | Version | Why |
|---|---|---|
| `CounterStrikeSharp.API` | 1.0.342 | The plugin framework/API. **Compile-only** (`ExcludeAssets=runtime`) — the runtime DLL is provided by the server's CSSharp install, which is why deploy skips copying `CounterStrikeSharp.API.dll/.pdb`. |
| `CsvHelper` | 30.0.1 | CSV stats export. |
| `Dapper` | 2.1.15 | Micro-ORM for DB queries. |
| `Microsoft.Data.Sqlite` | 7.0.13 | SQLite provider. |
| `MySqlConnector` | 2.3.0 | MySQL provider. |
| `Newtonsoft.Json` | 13.0.3 | JSON (match config, savednades, admins, etc.). |
| `SQLitePCLRaw.bundle_e_sqlite3` | 2.1.6 | Native SQLite engine bundle. |

Project settings: `TargetFramework=net8.0`, `ImplicitUsings=enable`, `Nullable=enable`.
The csproj also copies `lang/**` and `spawns/**` to the output dir (`CopyToOutputDirectory=PreserveNewest`). **`cfg/`
is NOT copied by the csproj** — it is bundled into the release zip separately by the build workflow (`cp -r cfg`).

> Both **Newtonsoft.Json** and **System.Text.Json** are used in the codebase (e.g. `Events.cs` uses
> `System.Text.Json.Serialization`). Don't assume one serializer.

---

## 9. Cross-cutting conventions (must follow when editing)

- **Logging:** use the plugin's `Log(...)` helper (in `Utility.cs`), not `Console.WriteLine`. Fatal-path catches use
  a `[<Context> FATAL]` prefix and **continue rather than throw** — handlers run inside game frames, and an unhandled
  exception can destabilize the server. You'll see this `try { … } catch (Exception e) { Log("[X FATAL] …"); }`
  pattern everywhere.
- **Player validity:** always guard `CCSPlayerController` access with `IsPlayerValid(player)` and account for
  `IsBot` / `IsHLTV` before acting on a player.
- **Chat output:** use `PrintToAllChat` / `PrintToPlayerChat` / `ReplyToUserCommand` (they prepend `chatPrefix`).
  Don't call `Server.PrintToChatAll` directly for normal messages.
- **Localization:** user-facing strings go through `Localizer["matchzy.<key>", args...]` backed by `lang/*.json`
  (12 locales, 126 keys). Add new keys to `lang/en.json`. (See
  [11-utility-localization-configs.md](11-utility-localization-configs.md).)
- **Async/threading:** game API calls must happen on the game thread. Background work (HTTP, DB) is marshalled back
  via `Server.NextFrame(...)` / the synchronization-context helpers in
  [`SynchronizationContextManagement.cs`](../SynchronizationContextManagement.cs).
- **Get5 wire compatibility:** JSON field names in `Events.cs`, `MatchConfig.cs`, `MatchData.cs`, `G5API.cs` use
  `[JsonPropertyName]` and are an **external API** (G5V/G5API panels). Don't rename them casually.

---

## 10. Where to go next

- Phase flow & transitions → [03-match-lifecycle.md](03-match-lifecycle.md)
- Every command/cvar → [04-commands-and-convars.md](04-commands-and-convars.md)
- Build & deploy → [02-build-test-deploy.md](02-build-test-deploy.md)
