# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Querator is a [CounterStrikeSharp](https://github.com/roflmuffin/CounterStrikeSharp) plugin for CS2 (Counter-Strike 2) that runs and manages practice/pugs/scrims/matches. It is a C# class library targeting **.NET 8.0** that compiles to a DLL loaded by the CounterStrikeSharp runtime inside a CS2 dedicated server. There is no standalone executable — the plugin runs in-process with the game server.

> **Querator is a Lany fork of [MatchZy](https://github.com/shobhit-pathak/MatchZy)** (MIT; see `CREDITS` / `LICENSE`). The MatchZy → Querator rebrand is **complete and live in production as of 2026-06-25** (Querator **1.0.0**) — merged to `main`, deployed across all repos, Mongo migrations run, and **all 3 fleet CS2 VMs cut over** (carlos/botez/alan). See [`docs/00-REBRAND-LOG.md`](docs/00-REBRAND-LOG.md) (the "Cutover EXECUTION" entry) and [`docs/CUTOVER-RUNBOOK.md`](docs/CUTOVER-RUNBOOK.md). The code is **Querator-named throughout**: namespace/class, `ModuleName`, `Querator.dll`/`Querator.cs`, `querator_*` cvars, `/api/querator/*`, `x-querator-secret`, `querator_stats_*` tables + `querator.db`, `QUERATOR_*` env, `cfg/Querator/`, `querator.*` lang keys, the `Querator-*` demo-upload headers, and all internal identifiers. **The only remaining MatchZy references are intentional upstream attribution** (`CREDITS` / `LICENSE` / `README` / `ModuleAuthor` lineage) — keep these forever.

## Build & develop

```bash
dotnet restore                  # restore NuGet dependencies
dotnet build                    # compile (Debug)
dotnet publish                  # produce the loadable plugin in bin/Release/net8.0/publish/
```

There are **no unit tests** in this repo — verification is done by loading the plugin into a live CS2 server. To test changes: `dotnet publish`, then copy the contents of `bin/Release/net8.0/publish/` into `csgo/addons/counterstrikesharp/plugins/Querator/` on the server (skip `CounterStrikeSharp.API.dll`/`.pdb`). CounterStrikeSharp supports hot-reload, but **never hot-reload while a match is live** — the match state flags get out of sync. Restart the server instead.

The `lang/` and `spawns/` folders are copied to the plugin output dir (see `.csproj`), and the GitHub release workflow also bundles `cfg/` into `csgo/cfg/`.

The version string lives in **one place**: `ModuleVersion` in `Querator.cs`. The release pipeline greps it from there to tag releases, and bumping it is the conventional first line of a release commit (see `CHANGELOG.md`).

## CI / release

- `.github/workflows/build.yml` — on push to `main` (doc/script/markdown-only pushes are ignored), builds three release zips (plugin-only, plus with-CSSharp for Linux and Windows) and creates a GitHub Release tagged with `ModuleVersion`.
- `.github/workflows/ci.yml` — on push to `main`, deploys the `documentation/` (MkDocs Material site) to GitHub Pages.
- Note: the working branch here is `dev`; releases happen from `main`.

## Architecture

The entire plugin is **one class — `partial class Querator : BasePlugin`** — split across ~19 `.cs` files at the repo root by feature area (e.g. `PracticeMode.cs`, `MapVeto.cs`, `MatchManagement.cs`, `Coach.cs`, `Pausing.cs`, `BackupManagement.cs`, `DamageInfo.cs`). All these files share the same fields and methods; there is no per-file encapsulation. When adding a feature, add a new partial-class file rather than a new class, following the existing split.

`Load()` in `Querator.cs` is the single entry point: it loads admins, initializes the database, executes `cfg/Querator/config.cfg`, builds the `commandActions` dictionary, and registers all event handlers. Read it first to understand wiring.

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

`DatabaseStats.cs` contains the `Database` class (the one non-partial-Querator class of note). It supports **SQLite (default) and MySQL**, selected via `cfg/Querator/database.json` (`DatabaseType` field). Queries use Dapper; table DDL is duplicated as `CreateRequiredTablesSQLite()` / `CreateRequiredTablesSQL()` (SQLite vs MySQL dialect) — **add schema changes to both**. Tables: `querator_stats_matches`, `querator_stats_players`, `querator_stats_maps`. Per-match detailed stats are also written to CSV (CsvHelper). Demos/backups can be uploaded over HTTP (see `DemoManagement.cs`, `BackupManagement.cs`, `RemoteLogConfig.cs`).

### Localization

All player-facing strings go through `Localizer["querator.<key>", args...]` backed by `lang/*.json` (12 locales). When adding a user-facing message, add the key to `lang/en.json` rather than hardcoding the string.

### Runtime config files (`cfg/Querator/`)

Distributed alongside the plugin and executed/read at runtime: `config.cfg` (default ConVars), `warmup.cfg`/`knife.cfg`/`live.cfg`/`live_wingman.cfg` (phase configs, with `*_override.cfg` for user overrides), `admins.json` (steamid → role), `database.json`, `whitelist.cfg`, `savednades.json`. The `*_override.cfg` files are the intended place for users to customize game settings without editing the plugin's base configs.

## Conventions

- Logging: use the plugin's `Log(...)` helper, not `Console.WriteLine`. Fatal-path catches conventionally log with a `[<Context> FATAL]` prefix and continue rather than throw — handlers run inside game frames and an unhandled exception can destabilize the server.
- Player validity: always guard `CCSPlayerController` access with `IsPlayerValid(player)` and account for `IsBot`/`IsHLTV` before acting on a player.
- Chat output: `PrintToAllChat` / `PrintToPlayerChat` / `ReplyToUserCommand` prepend `chatPrefix`; don't call `Server.PrintToChatAll` directly for normal messages.
- Documentation for users (commands, configuration, events/forwards, Get5) lives in `documentation/docs/*.md` and is the source of truth for externally-documented behavior — update it when changing commands, ConVars, or event/forward payloads.
