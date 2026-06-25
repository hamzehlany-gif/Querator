# Querator cutover runbook (MatchZy → Querator, Phase B/C deploy)

> **Purpose:** the exact manual steps to take the rebrand from `rebrand-b`/`rebrand-c` branches (all code done, gated,
> NOT deployed) to **live**. This is the irreversible, coordinated part — run it in a maintenance window with backups.
> Canonical change ledger: [`docs/00-REBRAND-LOG.md`](00-REBRAND-LOG.md). Per-repo notes: each repo's `REBRAND-TODO.md`.
>
> **State going in:** Phase B (B1–B9) + Phase C SP-C1 are committed on `rebrand-b` / `rebrand-c` in all 4 repos
> (Querator, lanyBot, lany-node-agent, lany), every per-repo gate green, **nothing deployed or migrated**. Prod (if any)
> still runs upstream MatchZy. The fork's first release will be **Querator 1.0.0**.

## 0. Prerequisites (do NOT skip)
- [ ] **Maintenance window** — no live match running on any server (the plugin must not hot-reload mid-match).
- [ ] **Backups:** Mongo dump (node-agent VmState/ConfigTemplate + lanyBot DB); each game-server's SQLite `matchzy.db`
      + `csgo/MatchZy_Stats` + `csgo/MatchZyDataBackup` + `csgo/cfg/MatchZy`.
- [ ] **lanyBot `updateResolver` / version check:** the fork releases as `1.0.0` (> upstream 0.8.x). Confirm the resolver
      won't fight it (it now matches `/^Querator-.*\.zip$/i` and sources `hamzehlany-gif/Querator/releases/latest`).
- [ ] **Decide canary:** pick ONE server to cut over first; roll the fleet only after it smokes green.

## 1. Land the branches (per repo)
Phase B/C lives on `rebrand-c` (which contains `rebrand-b`). For each repo, merge to the deploy line:
- **Querator:** `rebrand-c` → `dev` → `main`. **Pushing `main` triggers `build.yml`** → builds `Querator-1.0.0.zip`
  (+ with-cssharp variants), creates the GitHub release tagged `1.0.0`, and **posts to Discord** ("A new release of
  Querator…"). Verify the release + assets exist before continuing.
- **lany-node-agent / lanyBot / lany:** `rebrand-c` → `main`, then deploy each (PM2 / your deploy) so the running
  services use the `querator`-keyed contract.

## 2. Switch the fleet source (already coded — verify)
- lanyBot `config.orchestrator…releaseUrl` default → `hamzehlany-gif/Querator/releases/latest`; asset regex
  `/^Querator-.*\.zip$/i`. Override env `ORCHESTRATOR_QUERATOR_RELEASE_URL` if you pin a specific release.
- lany `QUERATOR_TEMPLATE_URL` → the fork `1.0.0` zip.

## 3. Rename server env (config-template CONTENT is migrated by b6, not re-seeded manually)
- [ ] **Each CS2 VM** `/home/cs2/agent/.env`: rename `MATCHZY_{CONFIG_PATH,PLUGIN_PATH,BACKEND_URL,WEBHOOK_SECRET,WEBHOOK_HEADER}`
      → `QUERATOR_*` (keep the values — e.g. `MATCHZY_WEBHOOK_HEADER=x-matchzy-secret` becomes
      `QUERATOR_WEBHOOK_HEADER=x-querator-secret`). The agent (`cs2-agent.service`) reads `QUERATOR_*` after restart.
- [ ] **lanyBot droplet `.env`**: rename `MATCHZY_WEBHOOK_SECRET`→`QUERATOR_WEBHOOK_SECRET` and
      `MATCHZY_WEBHOOK_HEADER`→`QUERATOR_WEBHOOK_HEADER` (same values). ⚠️ **The rebranded lanyBot fail-closes in prod
      without `QUERATOR_WEBHOOK_SECRET`** — do this with the lanyBot deploy. (`ORCHESTRATOR_*` use code defaults already
      pointed at the fork.)
- The `querator_*` cvars + `/api/querator` + `x-querator-secret` + `Querator/` demo dir inside the config templates are
  migrated **in place by b6** (`config_templates.content` transform). **No manual admin-UI re-seed needed.**

## 4. Run the data migrations (after backups) — collection names + counts VERIFIED against prod 2026-06-25
Both Mongo scripts use `getSiblingDB`, so run each with **any** `<MONGO_URI>` on the cluster (they target the
right DB themselves). Idempotent.
- [ ] **Mongo b6 (once):** `mongosh "<MONGO_URI>" lany-node-agent/scripts/migrations/rebrand-b6-config-root-component-key.js`
      — `lany-agent.vm_states` `versions.matchzy`→`querator` (3); `lany-agent.config_templates` `root` (4) + `content`
      transform → `querator_*`/`/api/querator`/`x-querator-secret`/`Querator/` (2); `lanybot.orchestratorserverstates`
      `versions`/`pluginStack`/`autoUpdate` `.matchzy`→`querator` (3).
- [ ] **Mongo c3 (once):** `mongosh "<MONGO_URI>" lanyBot/scripts/migrations/rebrand-c3-matchid-field-rename.js`
      — `matchzyMatchId`→`queratorMatchId` on `lanybot.matchsessions` (17, UNIQUE idx) + `lanybot.matchEvents`
      (**125**, camelCase collection); drops/recreates the indexes.
- [ ] **Per game-server b7 (ONLY where old SQLite/stats exist):**
      `CSGO=/home/cs2/server/game/csgo bash Querator/scripts/migrations/rebrand-b7-data-migration.sh`
      — `matchzy.db`→`querator.db` + tables + `MatchZy_Stats`/`MatchZyDataBackup`/demo dirs → `Querator*`. **NOTE:**
      on `carlos` none of those exist → no-op; the plugin creates `querator.db` fresh. Run only on VMs that accumulated stats.
- **Left MatchZy-named by design** (historical/audit): `jobs`, `manifests`, `orchestratoraudits`,
  `matchEvents.payload.cvars.matchzy_*`.

## 5. Install the Querator fork on the fleet (via node-agent)
- [ ] Trigger the plugin install/update from the fork release. **`targetPath` MUST be the csgo root**
      (`/home/cs2/server/game/csgo`) — the zip is csgo-rooted (`addons/…/plugins/Querator/` + `cfg/Querator/`). The
      frontend template (`QUERATOR_TEMPLATE_PATH`) and the auto-update (`ORCHESTRATOR_QUERATOR_TARGET_PATH`) already use it.
- [ ] **§8a cleanup:** on any server provisioned with the old nested layout, remove the stale
      `plugins/MatchZy/` tree (and the duplicate nested `cfg/MatchZy`) so CSSharp loads exactly one `Querator.dll` from
      `plugins/Querator/`.

## 6. Smoke test (canary, then fleet)
- [ ] `css_plugins list` over RCON shows `[#N:LOADED]: "Querator" (1.0.0) …`.
- [ ] node-agent `/versions` + lanyBot plugin-stack probe report `querator` healthy.
- [ ] Run a full match: warmup → knife → live → round events → POST to `/api/querator/events` (header `x-querator-secret`)
      → lanyBot ingests → Glicko ratings update → a row in `querator.db` `querator_stats_*` + a CSV in `Querator_Stats/`
      → demo uploads. Green on the canary → roll the rest of the fleet.

## 7. Rollback (if the canary fails)
- Revert each repo's deploy to its prior `main`; node-agent reinstalls upstream MatchZy.
- Restore the Mongo dump + per-server SQLite/dirs from backup (or reverse the migration scripts: inverse `$rename`/`$set`
  + `mv` dirs back + RENAME tables back + `querator.db`→`matchzy.db`).
- Re-seed the old `matchzy_*` config templates. The maintenance window + canary bound the blast radius.

## 8. Cosmetic sweeps — DONE on the branches (ride with the cutover)
The SP-C3 cosmetic sweeps are **complete on `rebrand-c`** (see ledger SP-C3): `matchzy.*` lang keys + values, the
`MatchZy-*`/`Querator-*` demo-upload headers, all camelCase var/fn names, the `matchzy.*.ts` file renames, the lanyBot
`queratorMatchId` field (migration above), `cfg/Querator/config.cfg` active brand values, lany UI labels, and lany-docs
prose (on its own `rebrand-c`). `grep -ri matchzy` = 0 in all code/config/contracts/lang across the 6 repos.
- **Still TODO (non-functional, do any time):** ~403 prose refs in Querator `docs/*.md` + `documentation/docs/*` —
  must be edited per-occurrence (they mix fork-refs to rename with genuine **upstream** references to keep).
- **Keep forever:** upstream MatchZy attribution (CREDITS / LICENSE / README / ModuleAuthor + the node-agent lineage
  comments + the migration scripts' old-name refs).
