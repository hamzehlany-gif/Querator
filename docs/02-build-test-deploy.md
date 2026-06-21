# 02 — Build, Test & Deploy

How Querator goes from source → `MatchZy.dll` → running on a CS2 server. This doc is the *engineering* reference;
the concrete copy-paste runbook for **your** server is [13-build-and-test-on-server.md](13-build-and-test-on-server.md).

---

## 1. Prerequisites

### To build (dev machine)
- **.NET 8.0 SDK.** ⚠️ As of this writing the SDK is **not installed on the current dev machine** (`dotnet` is not on
  PATH). Install from <https://dotnet.microsoft.com/download/dotnet/8.0> before building.
- NuGet restore pulls the deps listed in [`MatchZy.csproj`](../MatchZy.csproj) — needs internet on first restore.
- No IDE required (CLI is enough), but VS / Rider / VS Code work.

### To run (game server)
- A **CS2 dedicated server** (the `csgo/` install).
- **Metamod:Source** installed.
- **CounterStrikeSharp** installed, exposing **API ≥ 227** (Querator declares `[MinimumApiVersion(227)]`). The repo
  pins `CounterStrikeSharp.API` **1.0.342**; use a matching/compatible CSSharp runtime build.
- `tv_enable 1` for demo recording to work.

---

## 2. Build commands

```bash
dotnet restore     # restore NuGet deps (first time / after csproj changes)
dotnet build       # compile Debug → bin/Debug/net8.0/MatchZy.dll
dotnet publish     # compile + gather deps → bin/Release/net8.0/publish/
```

- `dotnet publish` (default config = Release in .NET 8) is what produces the **loadable plugin set**:
  `bin/Release/net8.0/publish/` containing `MatchZy.dll`, the dependency DLLs (Dapper, CsvHelper,
  Microsoft.Data.Sqlite, MySqlConnector, Newtonsoft.Json, SQLitePCLRaw + native `e_sqlite3`), and the copied
  `lang/` and `spawns/` folders.
- **`CounterStrikeSharp.API.dll` is intentionally NOT emitted** for runtime use — the csproj sets
  `ExcludeAssets=runtime` because the server's CSSharp install provides it. (If it *does* appear, you skip copying it.)
- **`cfg/` is NOT in the publish output** — the csproj doesn't copy it. Only the release workflow bundles it. For a
  manual deploy you must copy `cfg/` yourself (see §4).

There are **no unit tests** in this repo. "Testing" = loading the DLL into a live CS2 server and exercising commands.

---

## 3. What the release pipeline does (for reference)

`.github/workflows/build.yml` runs **on push to `main`** (ignoring `documentation/**` changes) — note the working
branch here is **`dev`**, so releases only happen after merging `dev → main`:

1. Sets up .NET 8, greps `MATCHZY_VERSION` from `ModuleVersion` in `MatchZy.cs`, and `CSSHARP_VERSION` from the
   `CounterStrikeSharp.API` package version in the csproj.
2. `dotnet publish -o package/addons/counterstrikesharp/plugins/MatchZy` and `cp -r cfg package` → zips
   **`MatchZy-<ver>.zip`** (plugin-only; extract into `csgo/`).
3. Downloads `counterstrikesharp-with-runtime-linux-<CSSHARP_VERSION>` into the package, re-publishes, zips
   **`MatchZy-<ver>-with-cssharp-linux.zip`**.
4. Same for Windows → **`MatchZy-<ver>-with-cssharp-windows.zip`**.
5. Creates a GitHub Release tagged `<ver>` with those 3 zips, and posts to Discord.

`.github/workflows/ci.yml` runs on push to `main` and deploys the `documentation/` MkDocs site to GitHub Pages
(`mkdocs gh-deploy`).

> **Takeaway for the fork:** if you want Querator releases, you either reproduce this workflow under your repo (and it
> will still name artifacts `MatchZy-*` and grep the same `ModuleVersion`) or just build locally and copy. The "with
> CSSharp" zips are the easiest first-time install because they bundle the matching CSSharp runtime.

---

## 4. Manual deploy to a server (what actually has to land where)

The server's game dir is `.../game/csgo/`. After `dotnet publish`:

1. Copy the **contents of** `bin/Release/net8.0/publish/` into
   `csgo/addons/counterstrikesharp/plugins/MatchZy/`
   (so you get `.../plugins/MatchZy/MatchZy.dll`, the dep DLLs, `lang/`, `spawns/`).
   - Skip `CounterStrikeSharp.API.dll` / `.pdb` if present (the server provides its own).
2. Copy the repo's **`cfg/`** into `csgo/cfg/` (so `cfg/MatchZy/*.cfg` + `*.json` land at `csgo/cfg/MatchZy/`).
   The plugin executes `MatchZy/config.cfg`, the phase configs, and reads `admins.json`/`database.json`/
   `savednades.json` from there.
3. (First time) make sure Metamod + CSSharp are installed and loading — verify with `meta list` and
   `css_plugins list` in the server console.
4. Load: restart the server, or `css_plugins load MatchZy` (hot path), then check the console for
   `[MatchZy 0.8.15 LOADED] …`.

### Hot-reload caveat (important)
CSSharp supports hot-reload (`css_plugins reload MatchZy`), and `Load()` handles `hotReload=true`. **But never
hot-reload while a match is live** — mid-match state flags (`isMatchLive`, `matchStarted`, scores, restore state…)
will desync from a fresh `Load()`. Restart the server instead. Hot-reload is only for iterating on non-match logic.

---

## 5. Versioning & release hygiene

- **Single source of truth:** `ModuleVersion` in [`MatchZy.cs`](../MatchZy.cs). The pipeline tags releases from it.
- Convention (from upstream): the **first line of a release commit bumps the version** and the change is logged in
  [`CHANGELOG.md`](../CHANGELOG.md). The current branch tip is `0.8.15: noclip command fix`.
- The release tag/name is just the bare version string (e.g. `0.8.15`).

---

## 6. Fork-specific gotchas to remember

- The fork is "Querator" but **every build artifact, ConVar, and identity string still says MatchZy**. If/when you
  rename, you touch: `ModuleName`/`ModuleVersion`/`ModuleAuthor`, namespace `MatchZy`, ConVar prefix `matchzy_`,
  lang keys `matchzy.*`, chat prefix, the `get5_*` aliases (keep for panel compat), the workflow's grep patterns and
  zip names, and the deploy folder name `plugins/MatchZy`. This is a deliberate, wide-reaching change — plan it.
- Because there are no tests, **every change must be smoke-tested on a server**. Keep a scratch server handy.
- `database.json`, `admins.json`, and the `*_override.cfg` files are *user data* — when deploying an update, don't
  clobber a server operator's customized copies. (The override cfgs exist precisely so base configs can change
  without stomping user settings.)

See [13-build-and-test-on-server.md](13-build-and-test-on-server.md) for the exact, ordered runbook for your setup.
