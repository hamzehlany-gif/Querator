# 10 — Demos, Backups/Restore, Event Forwarding & Damage Report

The plugin's IO / observability surface. Sources: [`DemoManagement.cs`](../DemoManagement.cs),
[`BackupManagement.cs`](../BackupManagement.cs), [`PublishEvents.cs`](../PublishEvents.cs), [`Events.cs`](../Events.cs),
[`DamageInfo.cs`](../DamageInfo.cs). HTTP upload helper `UploadFileAsync` lives in [`Utility.cs`](../Utility.cs).

---

## 1. Demos ([`DemoManagement.cs`](../DemoManagement.cs))

| Field | Default | Meaning |
|---|---|---|
| `demoPath` | `MatchZy/` | Demo subfolder under `csgo/` (must end with `/`, not start with `/`/`.`). |
| `demoNameFormat` | `{TIME}_{MATCH_ID}_{MAP}_{TEAM1}_vs_{TEAM2}` | Filename template. |
| `demoUploadURL` / `demoUploadHeaderKey` / `demoUploadHeaderValue` | "" | HTTP upload target + optional custom header. |
| `activeDemoFile` | "" | Path of the demo currently/last recording. |
| `isDemoRecording` / `isDemoRecordingEnabled` | false / true | recording-now / auto-record-on. |

- **`StartDemoRecording()`**: no-op if disabled or already recording. Builds the filename (`FormatCvarValue`
  substitutes `{TIME}`→`yyyy-MM-dd HH-mm-ss`, `{MATCH_ID}`, `{MAP}`, `{TEAM1}`/`{TEAM2}`; spaces→`_`), `tv_record`s it.
  Called from `StartLive` and after a restore. On exception it falls back to recording into the csgo root.
- **`StopDemoRecording(delay, …)`**: after `delay`, `tv_stoprecord`; then a **nested +15s timer** runs the HTTP
  upload (ensures the `.dem` is flushed to disk).
- **GOTV flush:** the only caller, `HandleMatchEnd`, computes `tvFlushDelay = GetTvDelay() + 15` and also extends
  `mp_match_restart_delay` so the map doesn't change before GOTV finishes. `GetTvDelay()` returns the larger of
  `tv_delay`/`tv_delay1` (0 if `tv_enable` off). **`tv_enable 1` is required for demos.**
- **Upload** (`UploadFileAsync`): POSTs the raw file as `application/octet-stream` with headers `MatchZy-FileName`,
  `MatchZy-MatchId`, `MatchZy-MapNumber`, `MatchZy-RoundNumber` (+ `Get5-*` duplicates), plus the optional custom
  header. ⚠️ **Findings:** demos are **not zipped** (despite `System.IO.Compression` being imported), and the
  `QueratorDemoUploadedEvent` (`demo_upload_ended`) is **defined but never fired** on this path.

---

## 2. Backups & restore ([`BackupManagement.cs`](../BackupManagement.cs))

Two parallel backup layers kept in lock-step:

### Valve native backups
`mp_backup_round_auto 1` (set in every live cfg) makes the engine write one `.txt`/round. `SetupRoundBackupFile()`
sets `mp_backup_round_file matchzy_<liveMatchId>_<CurrentMapNumber>` → engine writes
`csgo/matchzy_<id>_<map>_round<NN>.txt`. Restore uses `mp_backup_restore_load_file`. The `.txt` is the authoritative
low-level snapshot (positions, money, score) — MatchZy treats it as an opaque blob.

### MatchZy JSON backups
`CreateMatchZyRoundDataBackup()` runs at each round start (from `HandlePostRoundStartEvent`; early-returns if
`!isMatchLive || isRoundRestoring`). Writes `csgo/MatchZyDataBackup/matchzy_<id>_<map>_round<NN>.json` — a
`Dictionary<string,string>` with: `matchid, timestamp, map_name, mapnumber, round, team1/team2` (full Team JSON),
`team1_name/flag/tag/side` (+team2), `team1_score/team2_score`, `team1_series_score/team2_series_score`,
`TerroristTimeOuts, CTTimeOuts`, `match_loaded` (=`isMatchSetup`), `match_config` (serialized `matchConfig`), and
**`valve_backup`** (the embedded `.txt` contents). So one `.json` carries **both** layers. `roundNumber = t1+t2 score`.

### `.stop` (`css_stop`, both teams confirm)
Player-only; requires `isStopCommandAvailable && isMatchLive`; rejected during halftime, post-game, or an active
tactical timeout, and — if `matchzy_stop_command_no_damage` is set — if `playerHasTakenDamage` this round. T sets
`stopData["t"]`, CT sets `stopData["ct"]`; when both are set → `RestoreRoundBackup(player, lastQueratorBackupFileName)`
(the current round's `.json`).

### `.restore <round>` (`css_restore`, admin `@css/config`)
Builds `matchzy_<id>_<map>_round<NN>.json` and calls **`RestoreRoundBackup`** — the core restore engine:
- File at `csgo/MatchZyDataBackup/<file>`; missing → error.
- Disables timeout-active flags; sets `isRoundRestoring=true` (suppresses new backups).
- **Deferred-restore state machine:** if the backup's `map_name != Server.MapName` → `ChangeMap` + set
  `isRoundRestorePending`/`pendingRestoreFileName` + **return** (re-runs after the map loads). If in warmup → set
  pending, return; on the second pass set `liveSetupRequired`.
- Reapplies: `liveMatchId` (first, to avoid a new id), `isMatchSetup`, `matchConfig`, both `Team`s, side maps, timeouts,
  and writes/loads the `valve_backup` `.txt` (after a 0/2s timer), then `StartDemoRecording()`. ⚠️ **Scores are NOT
  re-parsed from the JSON** — they're restored via the engine `valve_backup` load (the JSON scores are
  informational).
- **`pauseAfterRoundRestore`** (default true): on success → `mp_pause_match`, clears `stopData`, `isPaused=true`,
  `unpauseData["pauseTeam"]="RoundRestore"`, starts the paused-message timer.

### Remote backups
Every round's `.json` is POSTed (if `backupUploadURL` set) via `UploadFileAsync` (same header scheme as demos, **not
zipped**). Restore-from-remote: `matchzy_loadbackup`/`get5_loadbackup` (file), `matchzy_loadbackup_url`/
`get5_loadbackup_url` (URL → saved as `MatchZyDataBackup/<GUID>.json` → restore), `matchzy_listbackups`/
`get5_listbackups` (list by matchid).

> ⚠️ Dead/odd fields: `lastBackupFileName` is declared but unused; `lastQueratorBackupFileName` is read by `.stop` but
> assigned outside this file (in the round/backup flow) — verify when touching `.stop`.

---

## 3. Event forwarding ([`PublishEvents.cs`](../PublishEvents.cs) + [`Events.cs`](../Events.cs))

- **`SendEventAsync(QueratorEvent)`**: if `matchConfig.RemoteLogURL` is empty, **no-op**. Else serializes the event to
  JSON (System.Text.Json, by runtime type) and **POSTs** it to `RemoteLogURL` with the optional
  `RemoteLogHeaderKey/Value` header. **No retry, no dedup, no batching** — fire-and-forget (callers wrap in
  `Task.Run`). Configured via `matchzy_remote_log_url`/`get5_remote_log_url` (+ header key/value) — see
  [04](04-commands-and-convars.md).
- The OpenAPI schema for these payloads is `documentation/docs/event_schema.yml`.

### Event catalog (class → `event` name → key payload, from [`Events.cs`](../Events.cs))
DTO hierarchy roots: `QueratorEvent` (`event`) → `QueratorMatchEvent` (+`matchid`) → `QueratorMapEvent` (+`map_number`) →
`QueratorRoundEvent` (+`round_number`) → `QueratorTimedRoundEvent` (+`round_time`); plus team/player mixins.

| `event` | Class | Extra payload | Fired from |
|---|---|---|---|
| `series_start` | `QueratorSeriesStartedEvent` | `team1`,`team2` (id+name), `num_maps` | `LoadMatchFromJSON` |
| `series_end` | `QueratorSeriesResultEvent` | `winner`, `team1_series_score`, `team2_series_score`, `time_until_restore` | `EndSeries` |
| `going_live` | `GoingLiveEvent` | (`matchid`,`map_number`) | `StartLive` |
| `round_end` | `QueratorRoundEndedEvent` | `reason`, `winner`, team stats | round-end handler |
| `map_result` | `MapResultEvent` | `winner`, team stats | `HandleMatchEnd` |
| `map_picked` | `QueratorMapPickedEvent` | `team`, `map_name`, `map_number` | veto `PickMap` |
| `map_vetoed` | `QueratorMapVetoedEvent` | `team`, `map_name` | veto `BanMap` |
| `side_picked` | `QueratorSidePickedEvent` | `team`, `map_name`, `map_number`, `side` | veto `PickSide` |
| `player_disconnect` | `QueratorPlayerDisconnectedEvent` | `player` | disconnect handler |
| `demo_upload_ended` | `QueratorDemoUploadedEvent` | `map_number`, `filename`, `success` | ⚠️ **defined but never fired** |

> `Winner` is `{ side: "2"/"3", team: "team1"/"team2" }`. `going_live` is dispatched but never consumed internally
> (the Get5 `going_live` state is derived by proxy — see [07](07-match-management-and-get5.md#6-get5-status-surface-g5apics)).

---

## 4. Damage report ([`DamageInfo.cs`](../DamageInfo.cs))

The "To/From" report printed at the end of each round (and after knife). Gated by `matchzy_enable_damage_report`.

- **`playerDamageInfo`**: `Dictionary<attackerId, Dictionary<targetId, DamagePlayerInfo>>` where
  `DamagePlayerInfo = { DamageHP, Hits }`.
- **`UpdatePlayerDamageInfo(event, targetId)`**: called from the `EventPlayerHurt` handler for **cross-team** damage
  while `matchStarted`; accumulates `DamageHP += DmgHealth` and `Hits++`.
- **`ShowDamageInfo()`**: for each attacker↔target pair (deduped), prints to both players a line
  `To: [dmg / hits] From: [dmg / hits] - <name> - (<hp> hp)`, then **clears `playerDamageInfo`**. Called at round end
  and from `StartAfterKnifeWarmup`.
- `InitPlayerDamageInfo()` pre-seeds the pair dictionaries for valid opposing players.

> This is **separate** from the persisted DB stats — it's an ephemeral per-round chat report, recomputed and cleared
> each round. The richer persisted stats live in [09-persistence-database.md](09-persistence-database.md).

---

## 5. Fork/maintainer notes
- **Demos:** if a panel expects zipped demos or a `demo_upload_ended` event, both are gaps to fix (see §1).
- **Backups:** the JSON backup is self-contained (carries the Valve `.txt`), which is what makes cross-map/cross-restart
  restore work — keep that invariant if you change the format. Score is engine-restored, not JSON-restored.
- **Events:** adding a new forward = a new `MatchZy*Event` DTO + a `Task.Run(() => SendEventAsync(evt))` at the right
  point; keep JSON field names aligned with `event_schema.yml` for panel/consumer compatibility.
- A self-hosted event/demo/backup receiver is a natural Lany integration point (e.g. [`lany-node-agent`](../../lany-node-agent)
  or [`lanyBot`](../../lanyBot)) — see [12-customization-for-lany.md](12-customization-for-lany.md).
