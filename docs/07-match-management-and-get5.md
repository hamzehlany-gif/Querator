# 07 — Match Management & Get5 Compatibility

Loading matches, the match-config JSON contract, team/roster handling, series logic, and the Get5 panel surface.
Sources: [`MatchManagement.cs`](../MatchManagement.cs), [`MatchConfig.cs`](../MatchConfig.cs),
[`MatchData.cs`](../MatchData.cs), [`G5API.cs`](../G5API.cs), [`Teams.cs`](../Teams.cs).

> **This is the external-API surface.** The JSON field names here are consumed/produced by G5V/G5API web panels and
> the Get5 ecosystem. Treat `[JsonPropertyName]` strings as a wire contract — don't rename casually.

---

## 1. Loading a match

| Command | Source | Behavior |
|---|---|---|
| `matchzy_loadmatch <file>` | `LoadMatch` ([`MatchManagement.cs:46`](../MatchManagement.cs)) | Reads a JSON file relative to `csgo/`. Console-only. |
| `matchzy_loadmatch_url <url> [hdrName] [hdrVal]` / `get5_loadmatch_url` | `LoadMatchFromURL` ([`MatchManagement.cs:85`](../MatchManagement.cs)) | HTTP GET (optional custom header), then load. Console-only. |

Both refuse if `isMatchSetup` already, and on parse/validation failure call `ResetMatch()`. Both funnel into
**`LoadMatchFromJSON(jsonData)`** which:
1. `ValidateMatchJsonStructure` (see §3). On error, returns false.
2. Reads `matchid` → `liveMatchId`; team1/team2 names (special chars stripped), ids, `players`.
3. Builds a fresh `matchConfig` (MapsPool/MapsLeftInVetoPool/NumMaps/MinPlayersToReady).
4. `GetOptionalMatchValues` (optional fields), then decides veto vs skip:
   - `MapsPool.Count == NumMaps` → `SkipVeto=true`, `isPreVeto=false`.
   - `MapsPool.Count < NumMaps` → **fail** (pool too small).
   - else (`SkipVeto` false) → validate `veto_mode` (`ValidateMapBanLogic`) or `GenerateDefaultVetoSetup`.
5. `GetCvarValues` (the `cvars` block → `ChangedCvars`/`OriginalCvars`).
6. `LoadClientNames()`, set up maplist/sides, change map if needed, `readyAvailable=true`,
   `ExecuteChangedConvars()`, `StartWarmup()`, `isMatchSetup=true`, `SetTeamNames()`, `UpdateHostname()`, fire
   **`MatchZySeriesStartedEvent`** (`series_start`).

---

## 2. The `MatchConfig` model ([`MatchConfig.cs`](../MatchConfig.cs))

Every field with its JSON name + default:

| JSON field | Type | Default | Notes |
|---|---|---|---|
| `maplist` | `List<string>` | `[]` | The chosen series maps (grows during veto). |
| `maps_pool` | `List<string>` | `[]` | Original pool. |
| `maps_left_in_veto_pool` | `List<string>` | `[]` | Shrinks during veto. |
| `map_ban_order` | `List<string>` | `[]` | The veto script (`veto_mode` in input JSON). |
| `skip_veto` | bool | **true** | If true, first `num_maps` of `maplist` are played as-is. |
| `match_id` | long | 0 | |
| `num_maps` | int | 1 | Series length (BO1/2/3/5). |
| `players_per_team` | int | 5 | Used by ready gating. |
| `min_players_to_ready` | int | 12 | Per-team min (note default 12 — overridden by input/`minimumReadyRequired`). |
| `min_spectators_to_ready` | int | 0 | |
| `current_map_number` | int | 0 | Index into `maplist` of the current map. |
| `map_sides` | `List<string>` | `[]` | Per-map side: `team1_ct/team1_t/team2_ct/team2_t/knife`. |
| `series_can_clinch` | bool | true | If true, series ends as soon as a team reaches `num_maps/2+1`. |
| `scrim` | bool | false | |
| `wingman` | bool | false | Drives `game_mode 2` + map reload. |
| `match_side_type` | string | **"standard"** | ⚠️ see note below. |
| `changed_cvars` | `Dictionary<string,string>` | `{}` | cvars to apply for this match. |
| `original_cvars` | `Dictionary<string,string>` | `{}` | their prior values (restored on series end). |
| `spectators` | `JToken` | `{}` | spectator roster. |
| `remote_log_url` / `remote_log_header_key` / `remote_log_header_value` | string | "" | event-forwarding target. |

> **`match_side_type` gotcha:** it is **read** by the veto auto-side logic (`"standard"`, `"random"`, `"never_knife"`,
> `"always_knife"`) but is **never assigned anywhere** — `GetOptionalMatchValues` does **not** parse it from the
> match JSON. In practice it is always `"standard"`. If you want random/forced sides, you must wire parsing yourself.

---

## 3. Match JSON contract (input)

`ValidateMatchJsonStructure` ([`MatchManagement.cs:148`](../MatchManagement.cs)) enforces:

**Required:** `maplist` (array, ≥1 map), `team1`, `team2` (each an object with a `players` object), `num_maps` (int,
must be ≤ `maplist` length).

**Optional (validated when present):**
- `matchid`, `players_per_team`, `min_players_to_ready`, `min_spectators_to_ready` — ints.
- `cvars` — object.
- `spectators` — object (with `players`).
- `veto_mode` — array (→ `MapBanOrder`).
- `map_sides` — array; each must be one of `team1_ct|team1_t|team2_ct|team2_t|knife`; length ≥ `num_maps`.
- `skip_veto`, `clinch_series`, `wingman` — booleans.

**Team object shape:**
```json
"team1": { "id": "<optional>", "name": "<string>", "players": { "<steam64>": "<display name>" } }
```
Players are a **steamid64 → name** map. Only Steam64 is supported (no Steam2/Steam3).

**Coaches are NOT a JSON field** — the documented workaround is: add the coach to a team's `players`, then have them run
`.coach <t|ct>` in-game (see [08](08-readiness-knife-pausing-coaching.md)).

---

## 4. Teams & roster ([`Teams.cs`](../Teams.cs))

### The `Team` class
Fields: `id`, `teamName` (required), `teamFlag`, `teamTag`, `teamPlayers` (`JToken` — the steamid→name map),
`coach` (`HashSet<CCSPlayerController>`, JSON-ignored), `seriesScore` (int). Two instances: `matchzyTeam1`,
`matchzyTeam2`. `teamSides`/`reverseTeamSides` map a `Team` ↔ `"CT"`/`"TERRORIST"`.

### Live roster commands
| Command | Behavior |
|---|---|
| `matchzy_addplayer <steam64> <team1\|team2\|spec> "<name>"` / `get5_addplayer` | Adds to the team's `teamPlayers` JToken (or `spectators`). Refused if no match setup, during halftime, or if already rostered. |
| `matchzy_removeplayer <steam64>` / `get5_removeplayer` | Removes from all teams; if the player is connected, **kicks** them. Refused during halftime. |

`AddPlayerToTeam`/`RemovePlayerFromTeam` mutate the `JToken` rosters directly (JObject `steamid→name`, or JArray for
some shapes) and call `LoadClientNames()`. Player→team mapping at connect uses `GetPlayerTeam` (steamid lookup in the
rosters) — that's how match mode locks players to sides.

### Default team naming
If a team name is still the default (`COUNTER-TERRORISTS`/`TERRORISTS`) at match start, `HandleMatchStart` derives
`team_<playername>` from a player on that side.

---

## 5. Series & sides

- `SetMapSides()` ([`MatchManagement.cs:387`](../MatchManagement.cs)): reads `map_sides[CurrentMapNumber]` to assign
  CT/TERRORIST to team1/team2 (and sets `isKnifeRequired` true iff the entry is `"knife"`). Calls `SetTeamNames()`
  (`mp_teamname_1/2`).
- `SwapSidesInTeamData(swap)`: swaps `teamSides`/`reverseTeamSides` (used on knife `.switch` and halftime).
- **Series end / clinch** is in `HandleMatchEnd` + `EndSeries` (detailed in
  [03-match-lifecycle.md](03-match-lifecycle.md)): clinch when a team reaches `NumMaps/2+1` (if `SeriesCanClinch`),
  else play all maps; `EndSeries` resets cvars (if `resetCvarsOnSeriesEnd`) and `ResetMatch` after a delay.
- **Pugs (`!isMatchSetup`)** are treated as a 1-map series; BO3/BO5 pugs are an explicit TODO.

### cvars block lifecycle
`GetCvarValues` records each `cvars` entry into `ChangedCvars` and snapshots the current value into `OriginalCvars`.
`ExecuteChangedConvars()` applies them (called before warmup so e.g. `get5_remote_log_url` is set in time);
`ResetChangedConvars()` restores `OriginalCvars` on series end when `resetCvarsOnSeriesEnd` is true.

---

## 6. Get5 status surface ([`G5API.cs`](../G5API.cs))

Panels poll these console commands; both reply with JSON via `command.ReplyToCommand`.

### `get5_status`
Builds a `Get5Status`:
`plugin_version` (**hardcoded `"0.15.0"`** — the *Get5 protocol version emulated*, NOT Querator's `0.8.15`),
`gamestate` (string), `paused`, `loaded_config_file`, `matchid`, `map_number`, `round_number`, `round_time`,
`team1`/`team2` (`Get5StatusTeam`: `name`, `series_score`, `current_map_score`, `connected_clients`, `ready`,
`side`), `maps`.

### `get5_web_available`
Replies `{ gamestate:<int>, available:1, plugin_version:"0.15.0" }`.

### Game-state mapping — `getGet5Gamestate()`
Maps the internal flags to the Get5 `Get5GameState` enum / strings (order matters!):

| Condition | Get5 state |
|---|---|
| `!isMatchSetup` | `none` |
| `isVeto` | `veto` |
| `isPreVeto` | `pre_veto` |
| `isKnifeRound` | `knife` |
| `isSideSelectionPhase` | `waiting_for_knife_decision` |
| `IsPostGamePhase()` | `post_game` |
| `isMatchLive` | `live` |
| `isRoundRestoring` | `pending_restore` |
| `matchStarted` | `live` |
| `isWarmup` | `warmup` |

> **Documented Get5-parity gaps (from code TODOs):** `connected_clients` returns `-1` (not implemented);
> `team.ready` reports whether *everyone* is ready, not per-team; `round_time` is `null` (not tracked); `matchid`
> is wrong in scrim/manual mode; there's no real `going_live` state (the `GoingLiveEvent` is dispatched but never
> read back). KAST / teammates-flashed / flash-assists / knife-kills / bomb stats are not surfaced to panels.

---

## 7. Stats wire shapes ([`MatchData.cs`](../MatchData.cs))

Used by remote-log events and (partially) the DB/CSV. `PlayerStats` is the Get5/PugSharp-compatible per-player shape:

`kills, deaths, assists, flash_assists, team_kills, suicides, damage, utility_damage, enemies_flashed,
friendlies_flashed, knife_kills, headshot_kills, rounds_played, bomb_defuses, bomb_plants, 1k, 2k, 3k, 4k, 5k,
1v1, 1v2, 1v3, 1v4, 1v5, first_kills_t, first_kills_ct, first_deaths_t, first_deaths_ct, trade_kills, kast, score,
mvp`.

Wrappers: `StatsPlayer` (`steamid`, `name`, `stats`), `MatchZyTeamWrapper` (`id`, `name`),
`MatchZyStatsTeam` (+ `series_score`, `score`, `score_ct`, `score_t`, `players`), `Winner` (`side`, `team`).

> ⚠️ Note these `PlayerStats` JSON fields are a **different, richer set** than the DB's
> `matchzy_stats_players` columns (which use names like `enemy5ks`, `utility_successes`, `v1_count`, and notably
> have **no `kast`/`mvp` columns**). The event/panel shape and the DB shape are not 1:1 — see
> [09-persistence-database.md](09-persistence-database.md).

---

## 8. Fork notes
- The whole Get5 surface (`get5_*` commands, `plugin_version 0.15.0`, JSON field names) exists for panel interop.
  Keep it intact if Lany uses (or might use) a G5V/G5API panel; otherwise it's safe but inert.
- `match_side_type` parsing is a cheap, isolated feature to add if you want random/forced sides without veto.
- BO3/BO5 **pug** support and the Get5-parity gaps above are natural first customization targets.
