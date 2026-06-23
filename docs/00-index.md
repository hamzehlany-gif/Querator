# Querator — Engineering Reference (Internal Notes)

> **What this folder is.** Deep internal engineering notes for **Querator**, the Lany community's fork of
> [MatchZy](https://github.com/shobhit-pathak/MatchZy) — a CounterStrikeSharp (CSSharp) plugin for CS2 that runs
> practice / pugs / scrims / matches. These notes exist so anyone (human or AI) can work on Querator without
> re-deriving how it works. They are written for *maintainers/forkers*, not end users.
>
> The **user-facing** docs (commands, configuration, Get5) live in [`documentation/`](../documentation/) (a MkDocs
> Material site). This `docs/` folder is the *engineering* counterpart — how the code actually works under the hood.

---

## Key facts at a glance

| Thing | Value |
|---|---|
| Project | Querator (fork of MatchZy) |
| Upstream | `shobhit-pathak/MatchZy` (MIT) |
| Plugin identity | `ModuleName = "MatchZy"`, `ModuleVersion = "0.8.15"` (see [`Querator.cs`](../Querator.cs)) |
| Runtime | CounterStrikeSharp plugin, loaded in-process by a CS2 dedicated server |
| Language / TF | C# / **.NET 8.0** class library → `Querator.dll` |
| Min CSSharp API | `[MinimumApiVersion(227)]` |
| CSSharp API pkg | `CounterStrikeSharp.API` **1.0.342** (compile-only; runtime provided by server) |
| Code shape | **One** `partial class Querator : BasePlugin` split across 29 `.cs` files at repo root |
| Entry point | `Load(bool hotReload)` in [`Querator.cs`](../Querator.cs) |
| State model | No formal FSM — a set of `bool`/`int` flags (see [01-architecture](01-architecture.md#state-flags)) |
| DB | SQLite (default) or MySQL, via Dapper; chosen in `cfg/MatchZy/database.json` |
| Tests | **None.** Verified only by loading into a live CS2 server |
| Working branch | `dev` (releases cut from `main`) |
| Build toolchain on this dev machine | ⚠️ **.NET SDK NOT installed** — must be installed before building locally |

---

## How to read these notes

Suggested order for a newcomer:

1. **[01-architecture.md](01-architecture.md)** — the mental model: single-partial-class design, file map, `Load()`
   lifecycle, the state-flag "machine", the two command-dispatch systems, and all event/listener wiring. **Start here.**
2. **[02-build-test-deploy.md](02-build-test-deploy.md)** — how to compile, what `dotnet publish` emits, how to deploy
   to a server, hot-reload caveats, dependencies, and the CI/release pipeline.
3. **[03-match-lifecycle.md](03-match-lifecycle.md)** — the phase flow (warmup → knife → side selection → live),
   autostart modes, scrim/playout, sleep mode, reset.
4. Then dive into feature docs as needed (below).

## Document set

| Doc | Covers | Status |
|---|---|---|
| [00-index.md](00-index.md) | This index | living |
| [01-architecture.md](01-architecture.md) | Design, file map, `Load()`, state flags, dispatch, events | ✅ |
| [02-build-test-deploy.md](02-build-test-deploy.md) | Build, publish, deploy, hot-reload, deps, CI | ✅ |
| 03-match-lifecycle.md | Phase state machine, autostart, scrim, sleep, reset | ✅ |
| 04-commands-and-convars.md | Every chat command + every ConVar/console command + admin flags | ✅ |
| 05-practice-mode.md | `PracticeMode.cs` (spawns, bots, nades, savednades, timers) | ✅ |
| 06-map-veto.md | Veto / side-pick state machine, BO1/3/5 | ✅ |
| 07-match-management-and-get5.md | loadmatch, series, teams, Get5 JSON contracts | ✅ |
| 08-readiness-knife-pausing-coaching.md | Ready system, knife logic, pauses, coaching | ✅ |
| 09-persistence-database.md | `DatabaseStats.cs`, schema, Dapper, CSV | ✅ |
| 10-demos-backups-events-damage.md | Demos, backups/restore, event forwarding, damage report | ✅ |
| 11-utility-localization-configs.md | `Utility.cs` helpers, localization, runtime cfg files | ✅ |
| 12-customization-for-lany.md | MatchZy limitations, extension points, fork strategy, rebrand plan | ✅ |
| 13-build-and-test-on-server.md | The concrete "build & test on your server" runbook | ✅ |

> **Cross-project context:** workspace-wide shared notes (the Lany.gg ecosystem and where Querator fits) live in
> [`../../LANY.md`](../../LANY.md), one level above this repo.

> Legend: ✅ written · ⏳ planned/in-progress. This table is updated as notes are authored.

## Conventions used in these notes

- File references link to the real source (e.g. [`Querator.cs`](../Querator.cs)); line numbers may drift as code
  changes — treat them as hints, search the symbol to confirm.
- "Chat command" = a `.`/`!` command players type in game chat. "Console command / ConVar" = a `matchzy_*`
  server-console command (often with a `get5_*` alias).
- Where a fact is derived from a config file or external panel contract, that's called out, because those are
  effectively *external APIs* and must stay stable for interop.
