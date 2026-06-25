# Privatize the Querator repo — runbook

Goal: make the **Querator GitHub repo + Releases private** (it currently contradicts the "Lany-only, never
shared" intent in [`12-customization-for-lany.md`](12-customization-for-lany.md)) **without breaking the
node-agent deploy**, which installs the plugin by downloading the release archive.

> **Not urgent / not a security fix.** The repo contains **no secrets** (webhook secret, Mongo URI, RCON
> passwords all live in VM `.env` / Mongo / GitHub Actions secrets, never in code). This is an IP/visibility
> choice. MIT permits a private derivative as long as `LICENSE`/`CREDITS` are retained (they are).

## Why it isn't a settings toggle
`hamzehlany-gif/Querator` is a **GitHub fork** of `shobhit-pathak/MatchZy` (`"fork": true`). GitHub **locks forks
to public** — the visibility control in Settings is disabled. You must break the fork link first.

## Code is already prepped (backward-compatible, inert until you flip)
Committed to `lany-node-agent` — these are **no-ops while the repo is public** (token unset ⇒ unauthenticated
download, exactly as today):
- `src/utils/httpUtil.js` — `downloadToFile(url, dest, log, { authToken })`; the token is sent **only** to
  `github.com`/`api.github.com` and **dropped on redirect** to the signed asset host.
- `src/config/index.js` — reads optional `QUERATOR_RELEASE_TOKEN`.
- `src/services/updates/plugin.js` — passes the token to the release download.
- `scripts/migrations/cutover-vm.sh` — reads `QUERATOR_RELEASE_TOKEN` from the agent `.env`; `curl -f` so a 404
  fails loudly.
- `.env.example` — documents `QUERATOR_RELEASE_TOKEN`.

So the switch is just: **detach + privatize the repo, then set the token on each VM.**

## Steps (GitHub-account actions — operator)

1. **Break the fork link** (pick one):
   - **(a) Detach via GitHub Support (recommended — least disruptive).** Ask Support to "detach this repository
     from its fork network." Keeps the same repo name, URL, history, and the existing `1.0.0` Release intact.
     Then **Settings → Danger Zone → Change visibility → Private.**
   - **(b) Self-service mirror.** Rename the fork (e.g. `Querator-old`) to free the name → create a **new private**
     `hamzehlany-gif/Querator` → `git clone --mirror <old>.git` then `git push --mirror <new>.git` → repoint local
     `origin` → **recreate the `1.0.0` Release with `Querator-1.0.0.zip`** (mirror copies tags, *not* Release
     objects/assets — push the tag and let `build.yml` rebuild, or upload manually) → delete the old fork.

2. **Create a fine-grained PAT.** Scope: **only** the Querator repo. Permission: **Contents → Read-only**. Set an
   expiry and put a rotation reminder on the calendar (PATs expire — an expired token silently breaks installs).

3. **Put the token on each VM.** Append to `/home/cs2/agent/.env`:
   `QUERATOR_RELEASE_TOKEN=github_pat_...` (keep the file `0600`), then `systemctl restart cs2-agent`.
   (If lanyBot/orchestrator ever performs the install download itself rather than delegating to the agent, set the
   same token there too — currently the agent does the download.)

4. **Validate on ONE VM before rolling the fleet.** Trigger a plugin reinstall (or re-run `cutover-vm.sh`) on e.g.
   `botez` and confirm the authed download succeeds and the plugin loads. Sanity check: an *unauthenticated*
   `curl -sI <release-url>` should now be `404` (proves private), while the agent's authed download works.

5. **If you re-hosted under a different name (path b)** update the release URL refs: `REL` in
   `cutover-vm.sh` and `QUERATOR_TEMPLATE_URL` in the frontend `OperationsTab.tsx`. (Path a keeps the URL, so no
   ref changes.)

## Rollback
If downloads break, either remove `QUERATOR_RELEASE_TOKEN` and make the repo public again, or fix the token —
unauthenticated download of a public release always works. No data is at risk.

## Alternative (decouple from GitHub entirely)
Mirror release artifacts to **R2** (already used for demos; `lany-node-agent/src/services/r2.js`) on each release
and point the download URL at R2. More moving parts, but the repo can be fully private with no PAT to rotate. Not
done here — token-auth was chosen as the lighter path.
