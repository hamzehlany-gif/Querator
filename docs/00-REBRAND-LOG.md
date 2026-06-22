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
| `ModuleVersion 0.8.15` | `1.0.0` | SP3 | planned |
| `ModuleAuthor "WD-…"` | Lany | SP3 | planned |
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
