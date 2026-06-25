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
| `ModuleName "MatchZy"` | `"Querator"` | SP-B1 (coupled) | done (branches; deploy deferred) |
| `ModuleVersion 0.8.15` | `1.0.0` | SP3 | done |
| `ModuleAuthor "WD-…"` | `Lany (https://lany.gg)` | SP3 | done |
| `MatchZy.dll`/`MatchZy.cs`/`MatchZy.csproj` / `plugins/MatchZy` | `Querator.dll`/`.cs`/`.csproj` / `plugins/Querator` | SP-B2 (coupled) | **Querator + node-agent + lany done (branches)**; deploy + release pipeline (SP-C1) pending |
| `cfg/MatchZy/` | `cfg/Querator/` | SP-B9 (cfg-dir, coupled) | **code done (Querator + node-agent, branches)**; live-dir move at cutover |
| `matchzy_*` cvars | `querator_*` | SP-B3 (coupled) | **done across all 4 repos (branches)**; deploy/re-seed at cutover |
| `/api/matchzy/*` | `/api/querator/*` | SP-B4 (coupled) | **done (lanyBot + node-agent + Querator notes, branches)**; deploy at cutover |
| `x-matchzy-secret` | `x-querator-secret` | SP-B5 (coupled) | **done (lanyBot + node-agent + Querator notes, branches)**; deploy at cutover |
| config-root `'matchzy'` + version component-key `matchzy` | `'querator'` | SP-B6 (coupled + Mongo migration) | **code done across node-agent + lanyBot + lany (branches), gates green**; Mongo migration script written, run at cutover |
| `matchzy_stats_*` tables / `MatchZy_Stats` / `MatchZyDataBackup` / `matchzy.db` / demo `MatchZy/` | `querator_stats_*` / `Querator_Stats` / `QueratorDataBackup` / `querator.db` / `Querator/` | SP-B7 (data migration) | **code done (Querator + node-agent seed, branch)**; per-server data migration at cutover |
| `MATCHZY_*` / `ORCHESTRATOR_MATCHZY_*` env | `QUERATOR_*` | SP-B8 (coupled) | **code done (node-agent + lanyBot + lany, branches)**; server `.env` rename at cutover |
| release `MatchZy-*.zip` + upstream release source | `Querator-*.zip` + fork source | SP-C1 (Phase C) | **code done (build.yml + fleet source, branches)**; release + switch at cutover |
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

## Phase B — coupled contract renames (lockstep, multi-repo)

> **Phase A (SP1–SP3) merged into `dev`** (merge `016246b`, 2026-06-23); `main` untouched (no release cut). Phase B
> changes land on **same-named `rebrand-b*` branches in every affected repo** and are **NOT deployed to the fleet**
> until the cutover window — the deployed prod node-agent/lanyBot keep matching the upstream "MatchZy" the fleet still
> runs (plan §1/§2). Validate on the test VM (which runs the fork).

### SP-B1 — `ModuleName "MatchZy"` → `"Querator"` (Phase B) — 2026-06-23 — ✅ build/lint/test green (3 repos); ⏳ deploy deferred to cutover
- **Branches (same name in each repo):** `rebrand-b-b1-modulename` off `rebrand-b` — **Querator + lanyBot + lany-node-agent**.
- **Why coupled:** the plugin's `ModuleName` is the literal string the consumers parse out of `css_plugins list` to
  (a) confirm the plugin is `[#N:LOADED]` and (b) read its version. Renaming it alone breaks detection, so the plugin
  and both detectors must flip together.
- **Changes:**
  - **Querator** `MatchZy.cs:15` — `ModuleName "MatchZy"` → `"Querator"`. (The `[{ModuleName} {ModuleVersion} LOADED]`
    banner now prints `[Querator 1.0.0 LOADED] Querator by Lany …` — the SP3 auto-flip via the `{ModuleName}` token.)
  - **lanyBot** `src/services/cs2.service.ts` — `matchzyLoadedInCssList` regex `/"MatchZy"/i` → `/"Querator"/i`;
    detail strings + doc comments "MatchZy" → "Querator". Test `cs2.service.test.ts` fixtures + `it()` titles updated.
  - **lany-node-agent** `src/services/versions/rconDetector.js:60` — `parseMatchzyVersion` regex
    `/"MatchZy"\s+\(([^)]+)\)/i` → `/"Querator"\s+…/i`; doc comments updated. Test `rconVersions.test.js` fixture +
    version assertion (`'0.8.15'` → `'1.0.0'`) updated.
- **Kept (deferred — internal lowercase `matchzy`, later camelCase sweep):** lanyBot `matchzy:` bool field +
  `matchzyLoadedInCssList` method; node-agent `parseMatchzyVersion` fn name. These carry no user-facing "MatchZy" and
  don't trip a branding grep that matters yet; renamed when the wider identifier sweep lands.
- **Out of scope (other sub-phases, NOT touched):** DLL name `MatchZy.dll` + `plugins/MatchZy` (SP-B2 — note
  node-agent `versions.test.js` still asserts `MatchZy.dll`, correct until SP-B2); `matchzy_*` cvars (SP-B3);
  release-URL parsing `…shobhit-pathak/MatchZy…` (SP-C1).
- **Verification (per-repo gates, §10):** ✅ Querator `dotnet publish` exit 0; ✅ lanyBot `npm run build` + `lint`
  (0 errors, pre-existing warnings only) + `test` (49 suites / 455 tests passed); ✅ node-agent `npm test`
  (37 suites / 267 tests passed) + `lint` (clean). No VM e2e yet.
- **⚠️ Deploy / sequencing:** **NOT deployed.** Fleet still runs upstream MatchZy (ModuleName "MatchZy"); the detector
  changes must deploy in lockstep with the fork cutover (Phase B-end / Phase C) or fleet detection breaks. Deployed
  prod node-agent/lanyBot stay on `main` (matching "MatchZy") until then.
- **Artifacts updated:** this log + `LANY.md` (contract + status) + each affected repo's `CLAUDE.md` + agent memory.
- **Merge:** sub-phase branch → `rebrand-b` in each repo (local; not pushed/deployed).
- **Rollback:** revert/delete the `rebrand-b-b1-modulename` branches across the 3 repos as a unit (then redeploy is a
  no-op since nothing was deployed).

### SP-B2 — DLL/source rename `MatchZy.dll`/`MatchZy.cs` → `Querator.dll`/`Querator.cs` (Phase B) — 2026-06-23 — ✅ Querator side done (branch); ✅ consumers done 2026-06-24 (branches, gates green — see follow-up entry below); ⏳ deploy at cutover
- **Branch:** `rebrand-b-b2-dll` off `rebrand-b`. **Querator only this round** (per request: do only the in-repo work,
  leave the coupled cross-repo work as a TODO note in each relevant repo).
- **Querator-side changes (done, build-verified):**
  - `git mv MatchZy.cs → Querator.cs`; `git mv MatchZy.csproj → Querator.csproj` ⇒ `dotnet publish` now outputs
    **`Querator.dll`** (no `<AssemblyName>` override needed — defaults to the project filename). Clean build verified
    (wiped `bin`/`obj`, published; output = `Querator.dll`/`.pdb`, **no `MatchZy.dll`**, exit 0).
  - `.github/workflows/build.yml` — version-grep file refs `MatchZy.cs`→`Querator.cs`, `MatchZy.csproj`→`Querator.csproj`
    (L31/L35). **Left** the release publish path `plugins/MatchZy` + asset names `MatchZy-*.zip` — those are the
    fleet-consumed artifacts, renamed in **SP-C1 / Phase C** in lockstep with the fleet asset regex.
  - `scripts/deploy-to-vm.ps1` — `PluginDir "MatchZy"`→`"Querator"` + caveat comment: the first `Querator.dll` deploy
    must remove the old `plugins/MatchZy` folder or CSSharp double-loads the plugin.
  - Engineering docs + `CLAUDE.md` — `MatchZy.cs`/`.csproj`/`.dll` file refs → `Querator.*` across 11 files; fixed the
    two "still-MatchZy" naming notes (`CLAUDE.md` §What-this-is, `docs/01-architecture.md` §Naming note) that were
    stale after SP1/SP3/SP-B1.
- **NOT renamed (still MatchZy — later sub-phases):** `cfg/MatchZy/` dir (SP-B2/B3, coupled to `MATCHZY_CONFIG_PATH`);
  `matchzy_*` cvars (SP-B3); `MatchZy-*` HTTP headers in `Utility.cs` (header sweep); demo/data dirs + `matchzy.db`
  (SP-B7); release asset `MatchZy-*.zip` (SP-C1).
- **🔴 CRITICAL PENDING TODO — coupled cross-repo work (NOT done; user will do later). Until done the renamed DLL
  CANNOT be deployed (detection + install break).** A `REBRAND-TODO.md` was added to each relevant repo. Work needed:
  1. **lany-node-agent** — `src/services/versions/detector.js` (~L265) + `plugin.js` (~L254): the `/^matchzy$/i`
     plugin/DLL-name match → accept `querator`; `MATCHZY_PLUGIN_PATH` default `…/plugins/MatchZy` → `…/plugins/Querator`
     (`src/config/index.js` + `.env.example`). (SP-B1 ModuleName detector is already on node-agent `rebrand-b`.)
  2. **lany (frontend)** — `MATCHZY_TEMPLATE_URL` / any template/asset/UI string naming `MatchZy.dll` / `plugins/MatchZy`.
  3. **node-agent §8a nested-install bug** — fix in the SAME change (plan §8a option (c): ship a flat `Querator-*.zip`
     with the DLL at archive root + extract into `plugins/Querator`). SP-B2 and §8a touch the same install path.
  4. **Deploy migration** — on first `Querator.dll` deploy, remove the old `plugins/MatchZy` (+ §8a nested cruft).
  5. **Release pipeline (SP-C1/Phase C)** — `build.yml` publish path + `MatchZy-*.zip` asset → `Querator`; fleet asset
     regex (`updateResolver.service.ts`) + `ORCHESTRATOR_MATCHZY_RELEASE_URL`.
- **How to do it:** branch `rebrand-b-b2-dll` in node-agent + lany; **re-grep first** (e.g.
  `grep -rIn -i 'matchzy\.dll\|plugins/matchzy\|\^matchzy\|MATCHZY_PLUGIN_PATH\|MATCHZY_TEMPLATE_URL' src/`); make the
  renames; gate (node-agent `npm test`+`lint`, lany `npm run build`+`lint`+`test`); deploy the whole set together
  (Querator `Querator.dll` + node-agent + frontend) in a maintenance window WITH the `plugins/MatchZy`→`plugins/Querator`
  migration; cross-repo smoke: install → `css_plugins list` shows `"Querator"` → a match runs end-to-end.
- **Verification (this round):** ✅ `dotnet publish` clean → `Querator.dll`, exit 0. No consumer build / VM e2e (consumers not done).
- **Merge:** `rebrand-b-b2-dll` → `rebrand-b` (Querator, local + pushed). **Not deployed.**
- **Rollback:** revert/delete `rebrand-b-b2-dll` (`git mv` back); no deploy to undo.

### SP-B2 (consumers: lany-node-agent + lany) — Phase B — 2026-06-24 — ✅ done on branches, gates green; ⏳ deploy at cutover
- **Branches:** `rebrand-b-b2-dll` in **lany-node-agent** and **lany** (off each repo's `rebrand-b`). Done now at the
  user's request ("leave nothing for later"); reviewable independently. Per-repo detail: each repo's `REBRAND-TODO.md`.
- **lany-node-agent (consumer of the DLL/path):**
  - `src/services/versions/detector.js` — disk-detect DLL `MatchZy.dll` → `Querator.dll` (+ doc prose).
  - `src/config/index.js` + `.env.example` — `matchzyPluginPath` / `MATCHZY_PLUGIN_PATH` default `plugins/MatchZy` →
    `plugins/Querator` (env var NAME kept → SP-B8).
  - `src/services/updates/plugin.js` — post-install version-gate `/^matchzy$/i` → `/^(matchzy|querator)$/i` so the
    version-record still fires for a `plugins/Querator`-derived name (+ log prose).
  - `src/api/routes/actions.js` — route comment prose. `tests/versions.test.js` — disk-detect fixtures → `Querator.dll`.
  - **Kept (deferred):** the `matchzy` component key (`VmState` Mongo schema, `versions.matchzy`,
    `recordSuccessfulInstall('matchzy')`), camelCase var names, config-root `'matchzy'`, `cfg/MatchZy` — SP-B3/B5/B6/B8.
- **lany (frontend):** `OperationsTab.tsx` install-`targetPath` placeholder `plugins/MatchZy` → `plugins/Querator`. Kept:
  `MATCHZY_TEMPLATE_URL` (release source → SP-C1), the `matchzy` component key + UI labels + `CONFIG_ROOTS` (key sweep / SP-B6).
- **§8a finding (no code change):** the node-agent installer is generic + correct — it copies an archive into the
  caller's `targetPath`. §8a (one-dir-too-deep) is a `targetPath`/zip-structure MISMATCH: the MatchZy/Querator zip is
  **csgo-rooted**, so the correct target is the csgo root (which the frontend template already uses via
  `MATCHZY_TEMPLATE_PATH`). The proper fix is a **flat `Querator-*.zip`** (SP-C1 / `build.yml`) + extract into
  `plugins/Querator` + re-provision the fleet at cutover — not a node-agent code change. Optional installer hardening
  (detect a csgo-rooted archive and refuse/redirect) is noted for SP-C1.
- **Verification:** ✅ node-agent `npm test` (267) + `lint` clean; ✅ lany `npm run build` + `lint` (0 errors) + `test`
  (62 vitest). No deploy / VM e2e (cutover only).
- **⚠️ Deploy:** **NOT deployed.** The detector now matches `Querator`/`Querator.dll`; deployed prod node-agent stays on
  `main` (matches `MatchZy`) until the lockstep cutover, else fleet detection/install breaks.
- **Merge:** `rebrand-b-b2-dll` → `rebrand-b` in node-agent + lany (local + pushed).
- **What's left for SP-B2 to be *deployable*:** SP-C1 (flat `Querator-*.zip` + fleet source switch) + the cutover window
  (deploy all repos together + the `plugins/MatchZy`→`plugins/Querator` migration). The **code** for SP-B2 is now
  complete across all four repos.

### SP-B3 — `matchzy_*` cvars → `querator_*` (Phase B) — 2026-06-24 — ✅ done across all 4 repos (branches, gates green); ⏳ deploy + re-seed at cutover
- **Branches:** `rebrand-b-b3-cvars` in **Querator + lanyBot + lany-node-agent + lany** (off each repo's `rebrand-b`).
- **What:** every one of the ~94 `matchzy_*` server ConVars → `querator_*`, renamed in lockstep across the plugin
  (which defines them), lanyBot + node-agent (which set them via RCON / config templates), and lany (frontend RCON
  list). Done with a protected mechanical rename (`matchzy_`→`querator_`, shielding `matchzy_stats_`), verified per repo.
- **Querator:** ConVar registrations (`ConfigConvars.cs` `FakeConVar`/`ConsoleCommand`, `ConsoleCommands.cs`) + refs in
  `Querator.cs`/`MatchManagement.cs`/`Teams.cs`/`Utility.cs`/`RemoteLogConfig.cs`/`DemoManagement.cs`/`BackupManagement.cs`;
  bundled `cfg/MatchZy/config.cfg` cvar lines; `lang/*.json` (cvar names quoted in messages); engineering docs
  (`docs/*`) + the user-docs site (`documentation/docs/*`). `dotnet publish` → `Querator.dll`, exit 0.
- **lanyBot:** RCON commands + config-gen cvars — `matchzy_pause`/`_unpause` (`cs2.service.ts`),
  `matchzy_remote_log_url`/`_demo_upload_url`/`_remote_log_header_key`/`_header_value`/`_loadmatch_url`
  (`matchzy.service.ts`), comments (`config/index.ts`, `*.controller.ts`, `matchzy.routes.ts`) + the `trace.test.ts`
  fixture (reflowed by prettier). Build + lint (0 errors) + 455 tests green.
- **lany-node-agent:** the `config.cfg` config-template content in `docs/config-template-seed.json` (the cvar lines the
  agent syncs to `cfg/MatchZy/config.cfg`) + `docs/orchestrator-api-spec.md` examples. 267 tests + lint green.
- **lany (frontend):** `OperationsTab.tsx` RCON command quick-list (`matchzy_loadmatch_url`→`querator_loadmatch_url`).
  Build + lint + 62 tests green.
- **Kept (NOT renamed):** `matchzy_stats_*` DB tables (B7); `get5_*` cvar aliases (Get5 compat, D7); `cfg/MatchZy` dir
  path (B6); `/api/matchzy` URL paths (B4); `config.matchzy` config-root (B6); `matchzy.*` lang keys; the lanyBot/lany
  `matchzy` component key + `matchzy.*` file names; the `MatchZy/` demo-dir value (B7).
- **⚠️ Deploy / data note:** **NOT deployed.** The plugin now expects `querator_*` cvars, but the **live
  `cfg/MatchZy/config.cfg` on each server (synced from the node-agent Mongo config-template) still sets `matchzy_*`**.
  At cutover the Mongo config-templates must be **re-seeded from the updated `config-template-seed.json`** so servers
  get `querator_*` lines — in lockstep with deploying the `Querator.dll` build + lanyBot + node-agent + lany. Otherwise
  the renamed cvars never get set on the server.
- **Verification:** ✅ all 4 per-repo gates green (above). No deploy / VM e2e (cutover only).
- **Merge:** `rebrand-b-b3-cvars` → `rebrand-b` in each repo (local + pushed).
- **Rollback:** revert/delete the `rebrand-b-b3-cvars` branches across the 4 repos as a unit.

### SP-B4 — `/api/matchzy/*` → `/api/querator/*` (Phase B) — 2026-06-24 — ✅ done (branches, gates green); ⏳ deploy at cutover
- **Branches:** `rebrand-b-b4-api` in **lanyBot + lany-node-agent + Querator** (lany has no `/api/matchzy` refs).
- **lanyBot:** the webhook/config route paths + callers — `core/WebServer.ts` (rate-limit skip),
  `routes/matchzy.routes.ts` (route mounts), `controllers/matchzy.controller.ts` (doc comments),
  `controllers/commands/admin.controller.ts` (config URL), `services/matchzy.service.ts` (the
  `querator_remote_log_url`/`_demo_upload_url`/loadmatch URL values), `__tests__/utils/trace.test.ts` fixtures.
  Build + lint + 455 tests green.
- **lany-node-agent:** `docs/config-template-seed.json` (the `config.cfg` template URL values) +
  `docs/orchestrator-api-spec.md` (`/webhook/matchzy` example → `/webhook/querator`). 267 tests + lint green.
- **Querator:** no code (the plugin POSTs to whatever URL the cvar holds); only the two "still-MatchZy" naming notes.
- **Kept:** the `matchzy.controller.ts`/`matchzy.routes.ts`/`matchzy.service.ts` file names + the `matchzy` component
  key (later file-name/key sweep); the upstream `github.com/.../MatchZy/releases` source URL (SP-C1).
- **⚠️ Deploy:** NOT deployed. The plugin's `querator_remote_log_url` (set by lanyBot/template) now points at
  `/api/querator/*`, matching the renamed lanyBot route — they flip together at cutover (with the B3 template re-seed).
- **Verification:** ✅ lanyBot build+lint+455; ✅ node-agent 267+lint; Querator docs-only.
- **Merge:** `rebrand-b-b4-api` → `rebrand-b` in each repo (local + pushed).
- **Rollback:** revert/delete the `rebrand-b-b4-api` branches across the 3 repos.

### SP-B5 — `x-matchzy-secret` → `x-querator-secret` (Phase B) — 2026-06-24 — ✅ done (branches, gates green); ⏳ deploy at cutover
- **Branches:** `rebrand-b-b5-secret` in **lanyBot + lany-node-agent + Querator** (lany none). Only the webhook header
  VALUE changes; the env var NAME `MATCHZY_WEBHOOK_HEADER` stays (→ SP-B8).
- **lanyBot:** `src/config/index.ts` (`headerName` default), `src/utils/trace.ts` (secret-redaction regex — keeps the
  header redacted from logs), `.env.example`. Build + lint + 455 tests green.
- **lany-node-agent:** `src/config/index.js` (`matchzyWebhookHeader` default + comment), `.env.example`. 267 + lint green.
- **Querator:** no code (the plugin sends whatever header name `querator_remote_log_header_key` holds); notes only.
- **⚠️ Deploy:** NOT deployed. lanyBot validates `x-querator-secret`; node-agent's `matchzyWebhookHeader` (→ `{{HEADER}}`
  in the config template) sets what the plugin sends — both flip at cutover (with the B3 template re-seed + any
  `MATCHZY_WEBHOOK_HEADER` override on servers). The generic `secret` redaction pattern covers both names meanwhile.
- **Verification:** ✅ lanyBot 455; ✅ node-agent 267+lint. Querator docs-only.
- **Merge:** `rebrand-b-b5-secret` → `rebrand-b` in each repo (local + pushed).
- **Rollback:** revert/delete the `rebrand-b-b5-secret` branches.

### SP-B6 — config-root `'matchzy'` + version component-key → `'querator'` (Phase B) — 2026-06-24 — ✅ code done (branches, all gates green); 🔴 Mongo migration + deploy at cutover
- **Branches:** `rebrand-b-b6-configroot` in **lany-node-agent + lanyBot + lany + Querator** (Querator = ledger only;
  the config-root/component-key are node-agent/lany constructs, not in the plugin).
- **Scope (the version component-key was folded in, per the user's call):** the bare `matchzy` identifier used as
  (a) the **config-root** (live-file-editor / config-template root) and (b) the **version component-key** → `querator`.
  A word-boundary rename (`\bmatchzy\b`) shielded the camelCase vars (`matchzyConfigPath`, `matchzyPluginPath`, …), the
  `matchzy.*.ts` file names, the `MatchZy` UI display labels, the upstream `shobhit-pathak/MatchZy` URL, and `MATCHZY_*`
  env names (all later/other phases).
- **lany-node-agent:** `configRoots.js`, `models/ConfigTemplate.js`, `models/VmState.js` (`versions.matchzy` +
  `lastJobIds.matchzy` schema fields), `services/{snapshot,stateService}.js`, `api/routes/versions.js`,
  `services/updates/plugin.js`, `services/versions/{detector,rconDetector}.js` (the `matchzy:` return key) + tests.
  267 tests + lint green.
- **lanyBot:** `LoadedPluginStack.matchzy` (`cs2.service.ts`) + consumers (`orchestrator.service.ts`), the
  `config.matchzy` config section (`config/index.ts` + accessors), config-root API calls, + test fixtures → `querator`.
  `matchzy.*.ts` file names + the github MatchZy URL kept. Build + lint + 455 tests green.
- **lany:** `orchestratorApi.ts` (`ConfigRoot`/`CONFIG_ROOTS`, `UpdateComponent`, `versions.querator`, plugin-stack
  field), workspace tabs + `ServerCard`/`UpdateBadge`. `MatchZy` UI display labels + `MATCHZY_TEMPLATE_URL` kept
  (cosmetic / SP-C1). Build + lint + 62 tests green.
- **🔴 MongoDB migration (run at cutover, after a DB backup):**
  `lany-node-agent/scripts/migrations/rebrand-b6-config-root-component-key.js` — `$rename` `versions.matchzy`→
  `versions.querator` + `lastJobIds.matchzy`→`lastJobIds.querator` on `VmState`; `$set root:'querator'` on
  `ConfigTemplate{root:'matchzy'}`. lanyBot's cached orchestrator state self-heals on the next snapshot fetch. Verify
  collection names (`db.getCollectionNames()`) first.
- **⚠️ Deploy:** NOT deployed; NOT migrated. Code on branches; the Mongo migration runs at cutover in lockstep with all
  four repos. Prod keeps the matchzy-keyed contract until then.
- **Verification:** ✅ lanyBot 455 · node-agent 267 · lany 62, all + lint. Querator docs-only.
- **Merge:** `rebrand-b-b6-configroot` → `rebrand-b` in each repo (local + pushed).
- **Rollback:** revert/delete the `rebrand-b-b6-configroot` branches; inverse the Mongo `$rename`/`$set` if migrated.

### SP-B7 — match-data identifiers (tables / db file / on-disk dirs) → querator (Phase B) — 2026-06-24 — ✅ code done (branch, build green); 🔴 data migration at cutover
- **Branches:** `rebrand-b-b7-data` in **Querator + lany-node-agent** (lanyBot/lany don't read these — they ingest
  match data into Mongo via events).
- **Querator:** `DatabaseStats.cs` — `matchzy_stats_{matches,maps,players}` → `querator_stats_*` (CREATE/INSERT/UPDATE/
  SELECT/FK + constraint, both SQLite & MySQL dialects) and the SQLite file `matchzy.db` → `querator.db`;
  `BackupManagement.cs` — `MatchZyDataBackup` → `QueratorDataBackup`; `Utility.cs` — `MatchZy_Stats` → `Querator_Stats`
  (CSV stats dir); `DemoManagement.cs` — demo dir default `"MatchZy/"` → `"Querator/"`. Eng docs + docs site updated.
  `dotnet publish` → `Querator.dll`, exit 0.
- **lany-node-agent:** the config-template seed's `querator_demo_path` value `MatchZy/` → `Querator/` (the demo dir the
  agent syncs). Plus an eslint fix on the SP-B6 mongosh migration script (`/* eslint-disable no-undef */` — mongosh
  globals). 267 tests + lint green.
- **🔴 Data migration (PER GAME-SERVER at cutover, after backups, AFTER the SP-B2 `plugins/Querator` move):**
  `Querator/scripts/migrations/rebrand-b7-data-migration.sh` — `mv matchzy.db→querator.db` + `ALTER/RENAME` the three
  `*_stats_*` tables (SQLite & MySQL variants), and `mv` the on-disk dirs (`MatchZy_Stats`, `MatchZyDataBackup`, demo
  `MatchZy/`). Without it the rebrand-b plugin starts an EMPTY `querator.db` and orphans the match history.
- **Kept:** upstream `shobhit-pathak/MatchZy/…zip` release URLs (SP-C1); `cfg/MatchZy` dir + its `exec
  MatchZy/live_override.cfg` (cfg-dir step); `matchzy.*` lang keys.
- **⚠️ Deploy:** NOT deployed / NOT migrated. Code on branches; the per-server data migration runs at cutover.
- **Verification:** ✅ Querator publish; ✅ node-agent 267 + lint. lanyBot/lany untouched.
- **Merge:** `rebrand-b-b7-data` → `rebrand-b` (Querator + node-agent; local + pushed).
- **Rollback:** revert/delete the `rebrand-b-b7-data` branches; reverse the migration (mv back + RENAME back) if run.

### SP-B8 — env var names `MATCHZY_*` / `ORCHESTRATOR_MATCHZY_*` → `QUERATOR_*` (Phase B) — 2026-06-24 — ✅ code done (branches, gates green); ⏳ server `.env` rename at cutover
- **Branches:** `rebrand-b-b8-env` in **lany-node-agent + lanyBot + lany + Querator** (Querator = ledger only; the
  plugin reads no env vars — `build.yml`'s `MATCHZY_VERSION` is the release pipeline, SP-C1, left untouched).
- **lany-node-agent:** `config/index.js` `env('MATCHZY_*' …)` → `env('QUERATOR_*' …)` (CONFIG_PATH, BACKEND_URL,
  WEBHOOK_SECRET/HEADER, PLUGIN_PATH, REPO_CONFIG_DIR) + `.env.example` + tests + docs; cleaned the now-stale "kept
  until SP-B8" comments. 267 tests + lint green.
- **lanyBot:** `config/index.ts` `MATCHZY_WEBHOOK_SECRET/HEADER` + `ORCHESTRATOR_MATCHZY_{TARGET_PATH,SOURCE_SUBDIR,RELEASE_URL}`
  → `QUERATOR_*` / `ORCHESTRATOR_QUERATOR_*` (+ the `NOTABLE_MATCHZY_EVENTS` const). The upstream release URL VALUE
  (`shobhit-pathak/MatchZy`) stays (SP-C1). Build + lint + 455 tests green.
- **lany:** the `MATCHZY_TEMPLATE_URL` / `MATCHZY_TEMPLATE_PATH` const names → `QUERATOR_*` (upstream URL value stays,
  SP-C1). Build + lint + 62 tests green.
- **⚠️ Deploy:** NOT deployed. The env var NAMES changed; each server's `.env` / deployment config must rename
  `MATCHZY_*`→`QUERATOR_*` at cutover (the code now reads `QUERATOR_*`, else falls back to defaults).
- **Verification:** ✅ node-agent 267+lint · lanyBot 455 · lany 62.
- **Merge:** `rebrand-b-b8-env` → `rebrand-b` in each repo (local + pushed).
- **Rollback:** revert/delete the `rebrand-b-b8-env` branches.

### SP-B9 — `cfg/MatchZy/` config dir → `cfg/Querator/` (Phase B) — 2026-06-24 — ✅ code done (branches, gates green); ⏳ live-dir move at cutover
- **Branches:** `rebrand-b-b9-cfgdir` in **Querator + lany-node-agent**.
- **Querator:** `git mv cfg/MatchZy → cfg/Querator` (15 bundled config files); the plugin's cfg-path constants in
  `Utility.cs` (`warmupCfgPath`/`knifeCfgPath`/`liveCfgPath`/`liveWingmanCfgPath`, `admins.json`, `whitelist.cfg`),
  `PracticeMode.cs` (`prac.cfg`/`dryrun.cfg`/`savednades.json`), `SleepMode.cs` (`sleep.cfg`), `Querator.cs`
  (`execifexists Querator/config.cfg`), `DatabaseStats.cs` (`cfg/Querator`) → `Querator/…`; the bundled
  `config.cfg`/`live.cfg`/`live_wingman.cfg` `exec` refs → `Querator/…`; docs. `dotnet publish` → `Querator.dll`, exit 0.
- **lany-node-agent:** `QUERATOR_CONFIG_PATH` default `…/cfg/MatchZy` → `…/cfg/Querator` (`config/index.js` +
  `.env.example` + `docs/config.md`); the config-template seed's `exec MatchZy/live_override.cfg` →
  `exec Querator/live_override.cfg`. 267 tests + lint green.
- **Kept:** `MatchZy-*` demo-upload HTTP headers in `Utility.cs` (separate header sweep); `matchzy.*` lang keys; the
  upstream `MatchZy` release source/attribution (Phase C).
- **⚠️ Deploy:** NOT deployed. At cutover, each server's live `csgo/cfg/MatchZy/` must be moved to `csgo/cfg/Querator/`
  (or re-synced from the renamed config template), in lockstep — the plugin now execs `Querator/*.cfg`.
- **Verification:** ✅ Querator publish; ✅ node-agent 267 + lint.
- **Merge:** `rebrand-b-b9-cfgdir` → `rebrand-b` (Querator + node-agent; local + pushed).
- **Rollback:** revert/delete the `rebrand-b-b9-cfgdir` branches; `git mv` back.

## Phase C — fleet cutover + release pipeline + sweeps

### SP-C1 — release pipeline + fleet source MatchZy → Querator (Phase C) — 2026-06-24 — ✅ code done (branches, gates green); ⏳ release + switch happen at cutover
- **Branch:** `rebrand-c` (off `rebrand-b`) in Querator + lanyBot + lany.
- **Querator `build.yml`:** asset `MatchZy-*.zip` → `Querator-*.zip` (3 zips), publish path `plugins/MatchZy` →
  `plugins/Querator`, version var `MATCHZY_VERSION` → `QUERATOR_VERSION`, release name/body + Discord message →
  Querator, CHANGELOG link → `hamzehlany-gif/Querator`. Runs on push to `main` only — inert until cutover.
- **lanyBot:** fleet release source `config/index.ts` default URL → `hamzehlany-gif/Querator/releases/latest`;
  `updateResolver.service.ts` asset regex `/^MatchZy-.*\.zip$/i` → `/^Querator-.*\.zip$/i`; test fixture + mock matcher
  updated. Build + lint + 455 tests green.
- **lany:** `QUERATOR_TEMPLATE_URL` value → the fork `Querator-1.0.0.zip`. Build + lint + 62 tests green.
- **§8a:** resolved as a `targetPath` concern, not a flat-zip rework — the csgo-rooted zip installs correctly at the
  **csgo root** (which the frontend template + auto-update already use); the fix is re-provisioning nested servers at cutover.
- **Kept (NOT SP-C1):** the `MatchZy-*` demo-upload HTTP headers (coupled Querator↔lanyBot header sweep); upstream
  MatchZy attribution.
- **⚠️ Deploy:** NOT released/deployed. Pushing Querator `main` cuts the public release + Discord; the fleet-source
  switch takes effect when lanyBot deploys. Full manual steps: **`docs/CUTOVER-RUNBOOK.md`** (added this sub-phase).
- **State:** committed on `rebrand-c` (off `rebrand-b`) in Querator/lanyBot/lany; pushed; not merged to `dev`/`main`.

### SP-C3 — cosmetic sweeps toward `grep -ri matchzy` = 0 (Phase C) — 2026-06-24 — ✅ all code/config/lang/identifiers done across all repos; ⏳ only Querator doc-prose remains
- **Branch:** `rebrand-c` (Querator + lanyBot + node-agent + lany) and lany-docs `rebrand-c` (SP-C2).
- **Done — Querator:** `matchzy.*` lang KEYS → `querator.*` (~1686, keys + `Localizer[...]` calls); lang message
  VALUES ("MatchZy is already…") → Querator; ConVar handler method names `MatchZy*Convar` → `Querator*Convar` (~21)
  + `MatchZyPlayerNames`; `matchzyTeam*`/`CreateMatchZyRoundDataBackup`/`matchZyBackupFileName`/`matchZyCoachTeam`;
  ConVar descriptions + log prefixes + comments; **`cfg/Querator/config.cfg` active brand values**
  (`querator_chat_prefix`, `querator_hostname_format` were still `[Green]MatchZy` / `MatchZy | …` and override the
  code defaults at runtime) → Querator; `.gitignore` `MatchZy.sln` → `Querator.sln`; `CLAUDE.md` status note +
  stale paths. `dotnet publish` green.
- **Done — lanyBot:** `queratorService`/`QueratorService`; file renames `matchzy.{service,controller,routes}.ts`
  + 3 tests → `querator.*` (imports updated); env `ORCHESTRATOR_POLICY_MATCHZY` → `_QUERATOR`; `.env.example`;
  all prose/fixtures/comments. **Data field `matchzyMatchId` → `queratorMatchId`** (`matchsessions` UNIQUE +
  `matchevents` indexes) with Mongo migration `scripts/migrations/rebrand-c3-matchid-field-rename.js` (run at
  cutover). The coupled `MatchZy-*` demo-upload headers → `Querator-*` (Querator sends ↔ lanyBot reads). 455 green.
- **Done — node-agent:** camelCase `matchzy{ConfigPath,BackendUrl,WebhookSecret,WebhookHeader,PluginPath}` → `querator*`;
  `detectMatchzyVersion`/`parseMatchzyVersion` → `detect/parseQueratorVersion`; describing comments. KEPT the 2
  deliberate lineage lines ("a MatchZy fork" + "upstream MatchZy (MatchZy.dll)" lockstep note). 267 green.
- **Done — lany:** `MatchZy` UI display labels → Querator. 62 green.
- **Done — lany-docs (SP-C2):** prose `MatchZy` → `Querator` on lany-docs `rebrand-c` (main kept accurate for the
  live MatchZy system + its ops warnings until cutover; merge at cutover).
- **Result:** `grep -ri matchzy` = **0 in all CODE / CONFIG / CONTRACTS / LANG / IDENTIFIERS** across all 6 repos,
  except intentional upstream attribution (Querator `CREDITS`/`LICENSE`/`README`/`ModuleAuthor`; the 2 node-agent
  lineage comments) and the deploy/migration scripts' intentional old-name refs (they migrate FROM the old names).
- **⏳ Remaining (non-functional, doc PROSE only):** ~403 `matchzy` refs in **Querator `docs/*.md` (engineering
  reference)** + **`documentation/docs/*` (public MkDocs manual)**. NOT blanket-swept on purpose: these docs mix
  fork-refs (rename) with genuine **upstream** references that must stay (e.g. "DatHost's 1-click MatchZy installer",
  "MatchZy limitations / fork strategy", "upstream ships `MatchZy-<ver>-with-cssharp`"). Needs per-occurrence editing,
  not sed — a focused follow-up. No functional impact.
- **⚠️ Deploy:** NOT deployed (rides with the cutover). `rebrand-c` pushed in all repos; lany-docs `rebrand-c` pushed.

### Cutover PREP — prod recon + migration corrections (2026-06-25) — ✅ scripts fixed + dry-run verified; NOT executed
Read-only recon of the live VM (`carlos`, 82.212.83.229) + a full read-only Mongo scan caught **the migration
scripts were targeting the wrong collections** (Mongoose-default names, not the real custom names):
- **Real Mongo schema (cluster has 2 app DBs):** `lany-agent` → `vm_states`, `config_templates` (+ `jobs`,
  `manifests`, `backups`); `lanybot` → `matchsessions`, `matchEvents` (camelCase), `orchestratorserverstates`, etc.
- **b6 fixed** (`vmstates`→`vm_states`, `configtemplates`→`config_templates`) + **added** the `config_templates.content`
  transform (closes the #9 "re-seed" gap — done in-place, no admin-UI step) **and** `lanybot.orchestratorserverstates`
  (component-key `versions`/`pluginStack`/`autoUpdate` `.matchzy`→`querator`). As written it would have been a **no-op**.
- **c3 fixed** (`matchevents`→`matchEvents`) — original would have **silently skipped all 125 event docs**.
- **Dry-run write counts (verified, zero writes):** b6 = vm_states 3 + config_templates root 4 + content 2 +
  orchestratorserverstates 3; c3 = matchsessions 17 + matchEvents 125. Total 154 docs / 5 collections / 2 DBs.
- **Decision:** historical/audit records left MatchZy-named (`jobs`, `manifests`, `orchestratoraudits`,
  `matchEvents.payload.cvars.matchzy_*`) — true record of the MatchZy era, not queried by the new code.
- **b7:** no-op on `carlos` (no `matchzy.db`/`MatchZy_Stats`/`MatchZyDataBackup`) — plugin creates `querator.db` fresh;
  run only on VMs that accumulated SQLite/CSV stats.
- **VM facts:** node-agent = `cs2-agent.service` (systemd, user `cs2`, git checkout `/home/cs2/agent` on `main`); update =
  `sudo -u cs2 git -C /home/cs2/agent pull && systemctl restart cs2-agent`; env `/home/cs2/agent/.env`; flat plugin
  install (no §8a here). Fleet = **3 VMs** (`carlos` canary + 2). Backend = `api.lany.gg`.
- **Droplet env risk:** lanyBot prod `.env` still has `MATCHZY_WEBHOOK_SECRET/HEADER` → rename to `QUERATOR_*` with the
  deploy or the rebranded lanyBot fail-closes in prod.

### Cutover EXECUTION — production go-live (2026-06-25) — ✅ FLEET COMPLETE (3/3)
The manual cutover was executed. **Global / one-time steps (done once, all repos):** Querator **1.0.0 release** published
(Discord fired); `lanyBot`/`lany`/`lany-node-agent` `main` merged + deployed (droplet PM2 / Cloudflare); droplet prod
`.env` `MATCHZY_*`→`QUERATOR_*` renamed by the operator before the lanyBot deploy; **Mongo migrations b6 + c3 ran once**
against the shared cluster (154 docs / 5 collections / 2 DBs — matches dry-run). New code confirmed live via POST probe
(`/api/querator/events` → 401 auth; `/api/matchzy/events` → 404).
- **Per-VM cutover** scripted as [`lany-node-agent/scripts/migrations/cutover-vm.sh`](../../lany-node-agent/scripts/migrations/cutover-vm.sh)
  (backup → agent `.env` key rename → stop cs2 → install Querator 1.0.0 + remove MatchZy → b7 SQLite/dir moves (conditional)
  → `git pull` agent → `syncTemplates({root:'querator'})` → restart agent+cs2 → clear stale `vm_states.versions.matchzy` →
  verify load). **Fleet = 3 VMs:** `carlos` 82.212.83.229, `alan` 82.212.83.227, `botez` 82.212.83.228.
- **carlos (.229)** — ✅ done 2026-06-25 (manual sequence; the script's source of truth). End-to-end test match verified:
  `matchsessions` 17→18, `matchEvents` 125→134, `queratorMatchId=1782388514`, 0 matchzy. (Demo upload leg returned 0 docs —
  pre-existing weakness, flagged for follow-up.)
- **botez (.228)** — ✅ done 2026-06-25 via `cutover-vm.sh`. Verified: `Finished loading plugin Querator` @12:57:46 in
  `log-all20260625.txt`; `Querator.dll` present, `MatchZy` plugin removed; `config.cfg`→`/api/querator/events` +
  `x-querator-secret`; `vm_states[cs2-botez].versions.querator=1.0.0`, **0 matchzy** in the doc. (Test match: operator TODO.)
- **alan (.227)** — ✅ done 2026-06-25 via `cutover-vm.sh`. **SSH is on port 2222, not 22** (the earlier ":22 timeout"
  was simply the wrong port — sshd is healthy on 2222; key already authorized). Verified: `Finished loading plugin Querator`
  @13:04:31; `Querator.dll` present, `MatchZy` removed; `config.cfg`→`/api/querator/events` + `x-querator-secret`;
  `vm_states[cs2-alan].versions.querator=1.0.0`, **0 matchzy**. (Test match: operator TODO.)
  → connect with `ssh -i ~/.ssh/querator_deploy -p 2222 root@82.212.83.227`.
- **Two `cutover-vm.sh` bugs found + fixed on the botez run** (committed to node-agent `main`): (1) step-2 `MATCHZY_`-remaining
  check used `grep -c | grep -q` which trips a false FATAL under `set -o pipefail` (grep -c exits 1 on a 0 count) → replaced
  with `if grep -qE`; (2) step-9 verify snapshotted `$LOG` once before the restart, pinning a stale pre-restart log → now
  recomputes the newest log each loop iteration. Both are verify/guard fixes; the proven mutation sequence is unchanged.

### Post-cutover AUDIT + finalization (2026-06-25) — ✅ deployment verified clean
Deep cross-repo audit (6 parallel auditors: one per repo + a cross-repo contract pass) plus live-infra verification.
**Result: 0 runtime blockers; 8/8 cross-repo contracts consistent.** Everything found was stale docs/comments, one
cosmetic code regex, and one dead Mongo key — all fixed.
- **Live infra verified:** all 3 VMs (carlos/botez/alan) — `Querator.dll` loaded, `MatchZy` plugin+cfg+db+stats dirs
  gone, 0 `MATCHZY_` env keys, `config.cfg`→`/api/querator/events`. Backend: POST `/api/querator/events`→401,
  `/api/matchzy/events`→404. Mongo: `vm_states` 3/3 `querator 1.0.0` (0 matchzy); `config_templates` 5 docs root
  `querator` (0 matchzy); `matchsessions` 18/18 + `matchEvents` 134/134 on `queratorMatchId` (0 `matchzyMatchId`,
  indexes correct).
- **One live-data fix:** `lanybot.orchestratorserverstates` had a dead `autoUpdate.matchzy:false` on all 3 docs — b6's
  `$rename` no-op'd because the merge-preserved `autoUpdate` already had a `querator` key (added by post-cutover sync);
  the old key was never unset. `$unset` cleaned all 3 (querator flag preserved); re-verified it stays gone after a sync
  cycle. b6 script hardened with a defensive `$unset` for replays.
- **Code fix:** `lany-node-agent/src/services/updates/plugin.js` find-replace artifact `/^(querator|querator)$/i`
  → `/^querator$/i`.
- **Docs finalized across all repos:** lany-docs `rebrand-c`→`main` (the last cutover step — 29 stale refs → 0);
  Querator README/00-index/02/04/07/13/CHANGELOG (version 0.8.15→1.0.0, "in progress"→done, +1.0.0 changelog entry);
  node-agent orchestrator-api-spec + 5 docs (config-root contract key `matchzy`→`querator`); lanyBot CLAUDE/README/
  explainers (renamed symbols + `QUERATOR_WEBHOOK_SECRET`); lany + node-agent `REBRAND-TODO.md` closed; deploy-script
  comment + test-runbook shortcut.
- **CI hygiene:** Querator `build.yml` + lanyBot `deploy.yml` now `paths-ignore` docs/scripts/markdown so a doc-only
  push no longer re-cuts the 1.0.0 release (re-firing Discord) / redeploys the prod backend.
- **Branch cleanup:** all merged `rebrand-*` branches deleted (local + remote) across Querator/lanyBot/node-agent/lany;
  lany-docs `rebrand-c` deleted after merge.
- **Residue now = intentional only:** `grep -ri matchzy` across all repos returns only attribution (CREDITS/LICENSE/
  README/ModuleAuthor), this ledger + CUTOVER-RUNBOOK, migration scripts, node-agent `detector.js` lineage comments,
  archived handoffs, historical research/changelog/explainer prose, and the closure notes. **Two owner-maintained files
  left to the user:** `lany/CLAUDE.md:114` (one-word `matchzy`→`querator` in a component-key list) and
  `lany-clipper/CLAUDE.md` (2 demo-provenance mentions). Not touched (user files / WIP branch).
- **Deferred (flagged, not blocking):** demo-upload leg returned 0 docs on carlos's test match (pre-existing; spawned
  as a follow-up task). Backups on all 3 VMs (`/home/cs2/rebrand-backup-*`) retained for a 1-month rollback window.
