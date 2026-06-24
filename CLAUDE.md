# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Querator is a [CounterStrikeSharp](https://github.com/roflmuffin/CounterStrikeSharp) plugin for CS2 (Counter-Strike 2) that runs and manages practice/pugs/scrims/matches. It is a C# class library targeting **.NET 8.0** that compiles to a DLL loaded by the CounterStrikeSharp runtime inside a CS2 dedicated server. There is no standalone executable — the plugin runs in-process with the game server.

> **Querator is a Lany fork of [MatchZy](https://github.com/shobhit-pathak/MatchZy)** (MIT; see `CREDITS` / `LICENSE`). A rebrand from MatchZy → Querator is **in progress** — see [`docs/00-REBRAND-LOG.md`](docs/00-REBRAND-LOG.md). The *project* is "Querator". Done (on `rebrand-b` branches, not yet deployed): **C# namespace + class** (`Querator`, SP2), **`ModuleName`** → `"Querator"` (SP-B1), **cosmetics** (version `1.0.0`, author, banner, chat-prefix, credits; SP3), the **DLL + entry source file** → `Querator.dll` / `Querator.cs` (SP-B2), the **`matchzy_*` cvars** → `querator_*` (SP-B3), the **`/api/matchzy/*` routes** → `/api/querator/*` (SP-B4), and the **`x-matchzy-secret`** header → `x-querator-secret` (SP-B5), and the **data identifiers** (`matchzy_stats_*` tables, `matchzy.db`, `MatchZy_Stats`/`MatchZyDataBackup`/demo dirs) → `querator_*` (SP-B7 — code done; data migration runs at cutover). Still using the MatchZy name (renamed in later, mostly cross-repo coupled sub-phases): the on-fleet `cfg/MatchZy/` + `plugins/MatchZy/` paths, `matchzy.*` lang keys, `MATCHZY_*` env names, string-literal paths. **The MatchZy-named code references in this document are current and accurate** until those sub-phases land.

## Build & develop

```bash
dotnet restore                  # restore NuGet dependencies
dotnet build                    # compile (Debug)
dotnet publish                  # produce the loadable plugin in bin/Release/net8.0/publish/
```

There are **no unit tests** in this repo — verification is done by loading the plugin into a live CS2 server. To test changes: `dotnet publish`, then copy the contents of `bin/Release/net8.0/publish/` into `csgo/addons/counterstrikesharp/plugins/MatchZy/` on the server (skip `CounterStrikeSharp.API.dll`/`.pdb`). CounterStrikeSharp supports hot-reload, but **never hot-reload while a match is live** — the match state flags get out of sync. Restart the server instead.

The `lang/` and `spawns/` folders are copied to the plugin output dir (see `.csproj`), and the GitHub release workflow also bundles `cfg/` into `csgo/cfg/`.

The version string lives in **one place**: `ModuleVersion` in `Querator.cs`. The release pipeline greps it from there to tag releases, and bumping it is the conventional first line of a release commit (see `CHANGELOG.md`).

## CI / release

- `.github/workflows/build.yml` — on push to `main`, builds three release zips (plugin-only, plus with-CSSharp for Linux and Windows), creates a GitHub Release tagged with `ModuleVersion`, and posts to Discord.
- `.github/workflows/ci.yml` — on push to `main`, deploys the `documentation/` (MkDocs Material site) to GitHub Pages.
- Note: the working branch here is `dev`; releases happen from `main`.

## Architecture

The entire plugin is **one class — `partial class Querator : BasePlugin`** — split across ~19 `.cs` files at the repo root by feature area (e.g. `PracticeMode.cs`, `MapVeto.cs`, `MatchManagement.cs`, `Coach.cs`, `Pausing.cs`, `BackupManagement.cs`, `DamageInfo.cs`). All these files share the same fields and methods; there is no per-file encapsulation. When adding a feature, add a new partial-class file rather than a new class, following the existing split.

`Load()` in `Querator.cs` is the single entry point: it loads admins, initializes the database, executes `cfg/MatchZy/config.cfg`, builds the `commandActions` dictionary, and registers all event handlers. Read it first to understand wiring.

### Command dispatch (two distinct systems)

1. **Chat commands** (`.ready`, `.pause`, `.spawn`, etc.) — handled inside the `EventPlayerChat` handler in `Querator.cs`:
   - Exact-match, no-argument commands are routed through the `commandActions` dictionary (`Dictionary<string, Action<CCSPlayerController?, CommandInfo?>>`). To add one, add an entry mapping the chat string to a handler method.
   - Commands that take arguments (`.map`, `.savenade`, `.ban`, `.coach`, …) are matched with `message.StartsWith(...)` and dispatched to a `Handle*Command` method. Note these take chat strings starting with `.`; players also commonly type `!` which CS2 maps to the same.

2. **Console commands / ConVars** — methods decorated with `[ConsoleCommand("querator_...")]`, mostly in `ConfigConvars.cs` and `ConsoleCommands.cs`. Many also expose a `get5_*` alias for Get5 config compatibility. Server-side ConVar values use `FakeConVar<T>` (CounterStrikeSharp). Pattern across config commands: `if (player != null) return;` (reject if invoked by a player rather than server console), then parse `command.ArgString`.

### State machine via boolean flags

There is no formal state machine — match phase is tracked by a set of public bool flags on the class: `isPractice`, `isWarmup`, `isKnifeRound`, `isSideSelectionPhase`, `isMatchLive`, `matchStarted`, `isPaused`, `isSleep`, `readyAvailable`, `isMatchSetup`, `isVeto`, etc. Game phases are driven by executing `.cfg` files via `Server.ExecuteCommand` — the canonical configs are referenced by the path constants in `Utility.cs` (`warmupCfgPath`, `knifeCfgPath`, `liveCfgPath`, `liveWingmanCfgPath`). When changing match flow, keep these flags mutually consistent — many event handlers early-return based on them.

### Get5 compatibility layer

`G5API.cs`, `MatchConfig.cs`, and `MatchData.cs` implement compatibility with the [Get5](https://github.com/splewis/get5) panel/API ecosystem (G5V/G5API web panels): match-config JSON loading, `get5_status`-style payloads, and per-player stats shapes (referred from Get5/PugSharp). JSON contracts use `[JsonPropertyName]` and must stay stable for panel interop — treat the wire field names as an external API.

### Persistence

`DatabaseStats.cs` contains the `Database` class (the one non-partial-MatchZy class of note). It supports **SQLite (default) and MySQL**, selected via `cfg/MatchZy/database.json` (`DatabaseType` field). Queries use Dapper; table DDL is duplicated as `CreateRequiredTablesSQLite()` / `CreateRequiredTablesSQL()` (SQLite vs MySQL dialect) — **add schema changes to both**. Tables: `querator_stats_matches`, `querator_stats_players`, `querator_stats_maps`. Per-match detailed stats are also written to CSV (CsvHelper). Demos/backups can be uploaded over HTTP (see `DemoManagement.cs`, `BackupManagement.cs`, `RemoteLogConfig.cs`).

### Localization

All player-facing strings go through `Localizer["matchzy.<key>", args...]` backed by `lang/*.json` (12 locales). When adding a user-facing message, add the key to `lang/en.json` rather than hardcoding the string.

### Runtime config files (`cfg/MatchZy/`)

Distributed alongside the plugin and executed/read at runtime: `config.cfg` (default ConVars), `warmup.cfg`/`knife.cfg`/`live.cfg`/`live_wingman.cfg` (phase configs, with `*_override.cfg` for user overrides), `admins.json` (steamid → role), `database.json`, `whitelist.cfg`, `savednades.json`. The `*_override.cfg` files are the intended place for users to customize game settings without editing the plugin's base configs.

## Conventions

- Logging: use the plugin's `Log(...)` helper, not `Console.WriteLine`. Fatal-path catches conventionally log with a `[<Context> FATAL]` prefix and continue rather than throw — handlers run inside game frames and an unhandled exception can destabilize the server.
- Player validity: always guard `CCSPlayerController` access with `IsPlayerValid(player)` and account for `IsBot`/`IsHLTV` before acting on a player.
- Chat output: `PrintToAllChat` / `PrintToPlayerChat` / `ReplyToUserCommand` prepend `chatPrefix`; don't call `Server.PrintToChatAll` directly for normal messages.
- Documentation for users (commands, configuration, events/forwards, Get5) lives in `documentation/docs/*.md` and is the source of truth for externally-documented behavior — update it when changing commands, ConVars, or event/forward payloads.
