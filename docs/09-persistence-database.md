# 09 — Persistence: the `Database` class & CSV stats

All in [`DatabaseStats.cs`](../DatabaseStats.cs) (~600 lines) — the one substantial non-`partial MatchZy` class. Uses
**Dapper** for every query. Backs SQLite (default) or MySQL.

---

## 1. Selection, connection, init

- **`InitializeDatabase(directory)`** → `ConnectDatabase` → `connection.Open()` → create tables. Wrapped in
  try/catch that logs `[InitializeDatabase - FATAL]` and continues (no throw — game-frame safety).
- **`SetDatabaseConfig`** reads `database.json` from a **hardcoded** path:
  `Server.GameDirectory + "/csgo/cfg/MatchZy/database.json"` (the `directory` arg is ignored here; it's only used for
  the SQLite file location). Missing → writes a default. The `DatabaseConfig` DTO: `DatabaseType`, `MySqlHost`,
  `MySqlDatabase`, `MySqlUsername`, `MySqlPassword`, `MySqlPort`.
- **Selection:** MySQL is chosen **only** if `DatabaseType` (trimmed, lowercased) == `"mysql"`. Anything else — typo,
  null, malformed JSON — **silently falls back to SQLite**.
- **Connection strings:**
  - SQLite: `Data Source=<directory>/querator.db` (`Microsoft.Data.Sqlite.SqliteConnection`).
  - MySQL: `Server=…;Port=…;Database=…;User Id=…;Password=…;` (`MySqlConnector.MySqlConnection`).
- `connection` is a single shared `IDbConnection` field; runtime type is checked everywhere via
  `connection is SqliteConnection` / `is MySqlConnection`.

---

## 2. Schema — **two hand-written dialect copies**

`CreateRequiredTablesSQLite()` and `CreateRequiredTablesSQL()` (MySQL) each create three tables with
`CREATE TABLE IF NOT EXISTS`. **There is no migration path** (`ALTER TABLE` nowhere) — schema changes do **not** apply
to an existing `querator.db`/MySQL DB.

### `querator_stats_matches`
`matchid` (PK, `INTEGER AUTOINCREMENT` SQLite / `INT AUTO_INCREMENT` MySQL), `start_time DATETIME NOT NULL`,
`end_time DATETIME DEFAULT NULL`, `winner`, `series_type`, `team1_name`, `team1_score`, `team2_name`, `team2_score`,
`server_ip` (strings `TEXT` in SQLite / `VARCHAR(255)` in MySQL; scores `INTEGER`/`INT`).

### `querator_stats_maps`
`matchid`, `mapnumber` (`INTEGER` SQLite / `TINYINT(3) UNSIGNED` MySQL), `start_time`, `end_time`, `winner`
(`VARCHAR(16)`), `mapname` (`VARCHAR(64)`), `team1_score`, `team2_score`. PK `(matchid, mapnumber)`; FK → matches.
MySQL adds `INDEX mapnumber_index` and a named FK.

### `querator_stats_players` — the per-player, per-map stats (PK `(matchid, mapnumber, steamid64)`)
Every column (DB order):
`matchid, mapnumber, steamid64, team, name, kills, deaths, damage, assists, enemy5ks, enemy4ks, enemy3ks, enemy2ks,
utility_count, utility_damage, utility_successes, utility_enemies, flash_count, flash_successes,
health_points_removed_total, health_points_dealt_total, shots_fired_total, shots_on_target_total, v1_count, v1_wins,
v2_count, v2_wins, entry_count, entry_wins, equipment_value, money_saved, kill_reward, live_time, head_shot_kills,
cash_earned, enemies_flashed`.

> ⚠️ **No `kast` and no `mvp(s)` columns here.** The richer `PlayerStats` *wire* shape in
> [`MatchData.cs`](../MatchData.cs) (used for Get5 events) has `kast`/`mvp` and many more fields — the **DB schema and
> the event/panel schema are NOT the same set**. Don't assume parity (see [07](07-match-management-and-get5.md#7-stats-wire-shapes-matchdatacs)).

### Dialect divergences (must keep in sync)
`AUTOINCREMENT`↔`AUTO_INCREMENT`; `INTEGER`↔`INT`; `TEXT`↔sized `VARCHAR`; `mapnumber` `INTEGER`↔`TINYINT(3) UNSIGNED`;
`steamid64` `INTEGER`↔`BIGINT`; MySQL has an extra index + named FKs; SQLite `players` has 2 FKs, MySQL 1.

---

## 3. Methods

| Method | Sync/Async | What it does |
|---|---|---|
| `InitMatch(t1,t2,ip,isMatchSetup,liveMatchId,mapNumber,seriesType,matchConfig)` → `long` | **sync** | On `mapNumber==0` inserts the `querator_stats_matches` row (with explicit matchid if match-setup, else auto-id via `last_insert_rowid()`/`LAST_INSERT_ID()`); inserts the `querator_stats_maps` row; returns the matchid. |
| `UpdateTeamData(matchId,t1,t2)` | sync | Updates team names on the matches row. |
| `SetMapEndData(matchId,mapNumber,winner,t1,t2,t1Series,t2Series)` | async | Updates the map row's winner/end_time/scores **and** writes the series score into the matches row. |
| `SetMatchEndData(matchId,winner,t1,t2)` | async | Final winner/end_time/scores on the matches row. |
| `UpdateMapStatsAsync(matchId,mapNumber,t1,t2)` | async | Updates map scores. |
| `UpdatePlayerStatsAsync(matchId,mapNumber, Dictionary<ulong,Dictionary<string,object>>)` | async | **Per-player upsert.** MySQL: `INSERT … ON DUPLICATE KEY UPDATE`; SQLite: `INSERT OR REPLACE`. |
| `WritePlayerStatsToCsv(filePath,matchId,mapNumber)` | async | The **only** read query; exports a CSV (§4). |

- Date expression is dialect-branched: `datetime('now')` (SQLite) vs `NOW()` (MySQL).
- The upsert's parameter binding maps DB columns ← **Get5-PascalCase dict keys** (e.g. `team`←`"TeamName"`,
  `name`←`"PlayerName"`, `utility_successes`←`"UtilitySuccess"`, `v1_count`←`"1v1Count"`, …). Off-by-name typos fail
  silently.
- **There is no `GetPlayerStats`/list method** in this file. The only reads are the CSV query and the last-insert-id
  scalars.

---

## 4. CSV export

`WritePlayerStatsToCsv` runs `SELECT * FROM querator_stats_players WHERE matchid=@ AND mapnumber=@ ORDER BY team,
kills DESC` and writes **dynamically** via CsvHelper (`InvariantCulture`):
- Output: `<filePath>/match_data_map<mapNumber>_<matchId>.csv` (caller passes `filePath`; from `HandleMatchEnd` it's
  `csgo/Querator_Stats/<matchId>`).
- Header = the table's columns in DB order (all 36 above); one row per player.
- Zero rows → empty file, no header (header emission is inside the `firstRow != null` guard).

---

## 5. Maintainer gotchas
1. **Schema lives in ~4 places** for player stats: both `CreateRequiredTables*` methods **and** both branches of
   `UpdatePlayerStatsAsync`'s column lists **and** its parameter object. A column add touches all of them.
2. **No migrations.** `CREATE TABLE IF NOT EXISTS` means existing deployed DBs keep the old schema silently. Plan a
   manual migration for any column change.
3. **Dialect-branched SQL in 3 spots:** date function, last-insert-id, and the upsert form. New writes must replicate
   the branching. `INSERT OR REPLACE` (delete-then-insert, new rowid) ≠ `ON DUPLICATE KEY UPDATE` (in-place) — fine
   here because all columns are always supplied, but partial upserts would diverge.
4. **One un-disposed connection** for process lifetime; **no transactions** (multi-statement sequences aren't atomic);
   **no concurrency guard** on the shared `connection` (callers must serialize awaited ops). No game-thread marshaling
   happens here — it's the caller's job.
5. **MySQL selection is string-exact** → easy to "accidentally run on SQLite." Malformed `database.json` also forces
   SQLite.
6. **All DB errors are swallowed** (logged `… FATAL`, continue). A failed write is invisible except in console logs.
7. SQLite FK enforcement is off by default (no `PRAGMA foreign_keys=ON`), so its FKs are effectively decorative.
8. Cosmetic: some log prefixes are mislabeled (`InitMatch` logs `[InsertMatchData …]`; `UpdateMapStatsAsync` logs
   `[UpdatePlayerStats - FATAL]`).

> **The per-player stat values themselves** (kills, KAST-ish counters, clutches, entries) are computed in the match
> event handlers (round-end stat aggregation), not here — this class only persists what it's handed. The aggregation
> lives in the damage/stat tracking covered in [10-demos-backups-events-damage.md](10-demos-backups-events-damage.md)
> and the round-end handlers in [`Utility.cs`](../Utility.cs).
