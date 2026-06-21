# Querator Rebrand Log — MatchZy → Querator

Append-only ledger of the multi-sub-phase rebrand (see the approved plan). Purpose: traceability, justification, and
reversibility of every change "in case we need it some day." Records changes across **all** Lany repos, even though it
lives in Querator. Companion to [`LANY.md`](../../LANY.md) and the engineering docs in [`docs/`](00-index.md).

> Scope rule: we erase "matchzy" **branding**; the upstream MIT attribution is retained on purpose (see `CREDITS`).

## Master old → new mapping (canonical dictionary)

| Old | New | Sub-phase | Status |
|---|---|---|---|
| MatchZy (project identity / branding, docs, comments) | Querator | SP1 / SP3 | in progress |
| `namespace MatchZy` / `class MatchZy` | `namespace Querator` / `class Querator` | SP2 | planned |
| `MatchZy*Event` / `MatchZyStats*` (DTO type names) | `Querator*Event` / `QueratorStats*` | SP2 | planned |
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
| `lastMatchZyBackupFileName` (variable) | `lastQueratorBackupFileName` | SP2 (with identifiers) | planned |

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
