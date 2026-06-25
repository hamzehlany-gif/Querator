# 13 — Build & Test Querator on a Server (Runbook)

The concrete, ordered steps to get Querator from this repo onto a running CS2 server. This is the practical companion
to [02-build-test-deploy.md](02-build-test-deploy.md).

> **Current blocker on this dev machine:** the **.NET 8 SDK is not installed** (`dotnet` is not on PATH). Step 1 fixes
> that. Nothing can be compiled until it's installed.

---

## Step 1 — Install the .NET 8 SDK (dev machine)

- Download the **.NET 8.0 SDK** (Windows x64): <https://dotnet.microsoft.com/download/dotnet/8.0>.
- After install, open a new terminal and verify:
  ```bash
  dotnet --version          # expect 8.0.xxx
  dotnet --list-sdks        # expect an 8.0.x entry
  ```
- (Winget alternative: `winget install Microsoft.DotNet.SDK.8`.)

## Step 2 — Build the plugin

From the repo root (`G:\nodeprojects-lany\Querator`):
```bash
dotnet restore
dotnet publish
```
Output lands in **`bin/Release/net8.0/publish/`**: `Querator.dll` + dependency DLLs (Dapper, CsvHelper,
Microsoft.Data.Sqlite, MySqlConnector, Newtonsoft.Json, SQLitePCLRaw + native `e_sqlite3`) + the `lang/` and
`spawns/` folders. (`CounterStrikeSharp.API.dll` is intentionally **not** emitted for runtime.)

A successful publish is the build "test" — there are no unit tests in this repo.

## Step 3 — Have a CS2 dedicated server to deploy to

Pick one:
- **Rented (fastest):** A host with a CS2 server. DatHost even has a 1-click MatchZy installer — handy as a known-good
  baseline to compare against, then replace its `MatchZy/` plugin folder with your Querator build.
- **Local (full control):** Install a CS2 dedicated server via SteamCMD (app `730`) on Windows or Linux. Heavier
  setup but ideal for fast iteration.
- **Existing Lany server:** if one already runs CS2 + Metamod + CSSharp, you only need to drop in the plugin.

The server must have:
- **Metamod:Source** installed and loading (`meta list`).
- **CounterStrikeSharp** providing **API ≥ 227** (this repo targets `CounterStrikeSharp.API` 1.0.342). Verify with
  `css_plugins list`.
- `tv_enable 1` if you want demos.

> **Shortcut for a fresh server:** the upstream release ships `MatchZy-<ver>-with-cssharp-linux.zip` /
> `-windows.zip` that bundle a matching CSSharp runtime — install Metamod, extract that zip into `csgo/`, then
> overlay your freshly built `Querator.dll`. This avoids version-matching CSSharp by hand.

## Step 4 — Deploy the build

Into the server's game dir (`.../game/csgo/`):
1. Copy the **contents of** `bin/Release/net8.0/publish/` → `csgo/addons/counterstrikesharp/plugins/Querator/`
   (skip `CounterStrikeSharp.API.dll`/`.pdb` if present).
2. Copy the repo's **`cfg/`** → `csgo/cfg/` (so `cfg/Querator/*` lands at `csgo/cfg/Querator/`). Don't overwrite a
   server operator's customized `admins.json`/`database.json`/`*_override.cfg`.

## Step 5 — Load & confirm

- Fresh load: **restart the server**, or `css_plugins load Querator` in console.
- Confirm in the console log: `[Querator 1.0.0 LOADED] …`.
- ⚠️ **Never hot-reload during a live match** — restart instead (see [02](02-build-test-deploy.md#hot-reload-caveat-important)).

## Step 6 — Smoke test in-game

Minimal sanity pass (one client is enough for several):
- `.help` → command list prints (confirms chat dispatch + localization).
- `.prac` → practice mode loads; `.bot`, `.spawn 1`, `.rethrow` → confirms practice/bot/grenade systems.
- `.exitprac` → back to warmup.
- Pug flow (needs 2 clients or `querator_minimum_ready_required 1`): both `.ready` → knife → `.stay`/`.switch` → LIVE.
- Match flow: write a small match JSON (see [07](07-match-management-and-get5.md#3-match-json-contract-input)),
  `querator_loadmatch <file>` from console, ready up, play, confirm a row appears in `querator.db` (SQLite) and a CSV in
  `csgo/Querator_Stats/`.
- Demo check: with `tv_enable 1`, confirm a `.dem` appears under `csgo/Querator/` after a map ends.

---

## What I (Claude) can vs cannot do here

| Task | Who |
|---|---|
| Edit/extend the C# source, configs, docs | **Me** |
| Run `dotnet restore/publish` to build | **Me, once the .NET 8 SDK is installed** on this machine |
| Install the .NET 8 SDK | **You** (or approve me running the installer) |
| Provide/stand up a CS2 dedicated server | **You** (I can't run a game server or reach a remote host) |
| Copy files to the server / load the plugin | **You** (unless the server's `csgo/` is a path on this machine I can write to) |
| In-game smoke testing (connect, ready, play) | **You** (I can't drive a CS2 client) |

**What I need from you to go further:**
1. Install the .NET 8 SDK here (then I can build and hand you `bin/Release/net8.0/publish/`).
2. Tell me where the target CS2 server is — local path on this machine, a rented host, or none yet — and whether
   Metamod + CounterStrikeSharp are already on it. If its `csgo/` is a local/mounted path, I can stage the deploy
   files directly.
