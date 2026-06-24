#!/usr/bin/env bash
# Rebrand SP-B7 — data migration: match-stats DB tables, SQLite db file, on-disk data dirs.
#   matchzy_stats_*    -> querator_stats_*       (3 tables)
#   matchzy.db         -> querator.db            (SQLite file)
#   MatchZy_Stats/     -> Querator_Stats/        (per-match CSV stats dir)
#   MatchZyDataBackup/ -> QueratorDataBackup/    (round-backup dir)
#   <demo dir> MatchZy/-> Querator/              (querator_demo_path default)
#
# RUN PER GAME-SERVER AT CUTOVER ONLY, AFTER a backup, AFTER the plugins/MatchZy -> plugins/Querator
# move (SP-B2), and in lockstep with deploying the rebrand-b Querator.dll build. The rebrand-b plugin
# opens querator.db + querator_stats_* tables; without this migration it starts an EMPTY db and the
# match history is orphaned. Safe to re-run (already-renamed items are skipped).
#
# Usage:  CSGO=/home/cs2/server/game/csgo bash rebrand-b7-data-migration.sh
set -euo pipefail
CSGO="${CSGO:-/home/cs2/server/game/csgo}"
PLUGINDIR="$CSGO/addons/counterstrikesharp/plugins/Querator"   # ModuleDirectory (post-SP-B2)

# 1) SQLite (default backend): rename the db file, then the tables.
DB_OLD="$PLUGINDIR/matchzy.db"; DB_NEW="$PLUGINDIR/querator.db"
if [ -f "$DB_OLD" ] && [ ! -f "$DB_NEW" ]; then
  mv "$DB_OLD" "$DB_NEW"
  sqlite3 "$DB_NEW" <<'SQL'
ALTER TABLE matchzy_stats_matches RENAME TO querator_stats_matches;
ALTER TABLE matchzy_stats_maps    RENAME TO querator_stats_maps;
ALTER TABLE matchzy_stats_players RENAME TO querator_stats_players;
SQL
  echo "[B7] SQLite querator.db + querator_stats_* tables ready."
else
  echo "[B7] SQLite: nothing to do (no matchzy.db, or querator.db already present)."
fi

# 1b) MySQL backend instead (database.json DatabaseType=MySQL) — run this in place of the SQLite block:
#   RENAME TABLE matchzy_stats_matches TO querator_stats_matches,
#                matchzy_stats_maps    TO querator_stats_maps,
#                matchzy_stats_players TO querator_stats_players;
#   (FKs follow the rename in MySQL; the internal constraint name matchzy_stats_maps_matchid may remain.)

# 2) On-disk data dirs (top-level under csgo/).
[ -d "$CSGO/MatchZy_Stats" ]     && mv "$CSGO/MatchZy_Stats"     "$CSGO/Querator_Stats"     && echo "[B7] MatchZy_Stats -> Querator_Stats"
[ -d "$CSGO/MatchZyDataBackup" ] && mv "$CSGO/MatchZyDataBackup" "$CSGO/QueratorDataBackup" && echo "[B7] MatchZyDataBackup -> QueratorDataBackup"
[ -d "$CSGO/MatchZy" ]           && mv "$CSGO/MatchZy"           "$CSGO/Querator"           && echo "[B7] demo dir MatchZy -> Querator"

echo "[B7] done. Rollback: reverse the mv commands + RENAME tables back + querator.db -> matchzy.db."
