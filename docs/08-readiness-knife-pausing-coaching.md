# 08 — Readiness, Knife, Pausing & Coaching

Four tightly-related match-flow subsystems. Sources: [`ReadySystem.cs`](../ReadySystem.cs),
[`Utility.cs`](../Utility.cs) (`DetermineKnifeWinner`, the pause functions), [`ConsoleCommands.cs`](../ConsoleCommands.cs)
(stay/switch/unpause/tac), [`Pausing.cs`](../Pausing.cs), [`Coach.cs`](../Coach.cs).

---

## 1. Ready system ([`ReadySystem.cs`](../ReadySystem.cs))

- `playerReadyStatus: Dictionary<int,bool>` (userid → ready). `teamReadyOverride: Dictionary<CsTeam,bool>` (force-ready
  latches). `allowForceReady` (default true).
- **`.ready`/`.unready`** (`OnPlayerReady`/`OnPlayerUnReady`) toggle the player's status (only while
  `readyAvailable && !matchStarted`) and call `CheckLiveRequired()` (the phase-advance gate — see
  [03](03-match-lifecycle.md#2-phase-flow-happy-path-for-a-match)).
- **Two ready models** (decided in `CheckLiveRequired`):
  - **Match mode** (`isMatchSetup`): `IsTeamsReady() && IsSpectatorsReady()`. `IsTeamReady(team)` passes if
    (a) `playerCount == readyCount && playerCount >= minPlayers` (everyone present is ready and enough are present), or
    (b) the team is force-readied and `readyCount >= minReady`. Per-team thresholds come from `matchConfig`
    (`PlayersPerTeam`, `MinPlayersToReady`, `MinSpectatorsToReady`).
  - **Pug mode**: `minimumReadyRequired == 0` → every connected player must be ready; else `readyCount >=
    minimumReadyRequired`.
- **`.forceready`** (`OnForceReadyCommandCommand`): match-mode only and requires `allowForceReady`; force-readies the
  caller's whole team (sets every teammate ready + `teamReadyOverride[team]=true`) if at least `minReady` players are
  present, then `CheckLiveRequired()`.
- A repeating "unready players" chat reminder runs during warmup (`SendUnreadyPlayersMessage`, every `chatTimerDelay`).

---

## 2. Knife round & side selection

### Winner — `DetermineKnifeWinner()` ([`Utility.cs:558`](../Utility.cs)) (logic from Get5)
Compares the two sides via `GetAlivePlayers(team)` (alive count + total HP, excluding coaches):
1. More **alive players** wins.
2. Tie → more **total HP** wins.
3. Still tie → **random** (`knifeWinner = random 2|3`).

`knifeWinner`: **3 = CT, 2 = T**. Called from the `EventRoundEnd` (Pre) lambda in [`Querator.cs`](../Querator.cs), which
also rewrites `@event.Winner/Reason` (so the win panel shows the right team), sets `isSideSelectionPhase=true`,
`isKnifeRound=false`, and runs `StartAfterKnifeWarmup()` (re-warmup + repeating "type `.stay`/`.switch`" prompt).
(`HandleKnifeWinner` is an older path kept around but the live flow uses the `EventRoundEnd` lambda — `EventCsWinPanelRound`
stopped firing after the Arms Race update.)

### Side decision
Only the **knife-winning side** (`player.TeamNum == knifeWinner`) can decide:
- **`.stay`** (`OnTeamStay`) → `StartLive()`.
- **`.switch`/`.swap`** (`OnTeamSwitch`) → `mp_swapteams` + `SwapSidesInTeamData(true)` → `StartLive()`.
- **`.ct`/`.t`** during side selection map to stay/switch based on the player's current side (`OnTCommand`/`OnCTCommand`).

---

## 3. Pausing

> **Naming trap:** the dedicated `TechPause()` in [`Pausing.cs`](../Pausing.cs) is **WIP dead code** (`return;` at the
> top). So `.tech` does **not** run it — `.tech` → `OnTechCommand` → **`PauseMatch`** (the normal pause). The
> `matchzy_enable_tech_pause` / `matchzy_tech_pause_flag` cvars are repurposed inside `PauseMatch` to gate **all**
> player pausing (see below). `technicalPauseUsed`/`lastTechPauseDuration`/`techPauseDuration`/`maxTechPausesAllowed`
> are currently inert.

### The four ways to pause
| Command | Function | Notes |
|---|---|---|
| `.pause`/`.p` | `OnPauseCommand` → `PauseMatch` (or `OnTacCommand` if `matchzy_use_pause_command_for_tactical_pause`) | Normal team pause. |
| `.tech` | `OnTechCommand` → `PauseMatch` | Same as normal pause (tech feature WIP). |
| `.tac` | `OnTacCommand` | **CS2 tactical timeout** via `timeout_ct_start`/`timeout_terrorist_start`; uses the engine's `mp_team_timeout_max`/`_time`. Refused if already paused / no timeouts left. |
| `.fp`/`.forcepause`/`sm_pause` | `ForcePauseMatch` | Admin pause (`@css/config`); only admin can unpause. |

### `PauseMatch` ([`Utility.cs:1147`](../Utility.cs)) guards & behavior
Refuses if: already paused, halftime (`IsHalfTimePhase`), post-game (`IsPostGamePhase`), tactical timeout active,
`!techPauseEnabled.Value`, or — if `techPausePermission.Value` is set — the player lacks that flag. Then it records the
**pausing team** (`unpauseData["pauseTeam"]` = team name, or `"Admin"`) and calls `SetMatchPausedFlags()`
(`mp_pause_match`, `isPaused=true`, start the repeating paused-state message, kill the coach timer).

### Unpause
- **`.unpause`/`.up`** (`OnUnpauseCommand`): **both teams must confirm** — T sets `unpauseData["t"]`, CT sets
  `unpauseData["ct"]`; when both → `mp_unpause_match`. An **admin pause** (`pauseTeam=="Admin"`) can only be lifted by
  an admin (a player `.unpause` is rejected).
- **`.fup`/`.forceunpause`/`sm_unpause`** (`ForceUnpauseMatch`, `@css/config`) → `UnpauseMatch()` immediately.
- A **round-restore** auto-pause uses `pauseTeam=="RoundRestore"` (see [10](10-demos-backups-events-damage.md#2-backups--restore)).

---

## 4. Coaching ([`Coach.cs`](../Coach.cs))

Coaches are real players parked in a special slot: they observe their team during the round but are physically
removed from play.

### Joining / leaving
- **`.coach <t|ct>`** (`HandleCoachCommand`): **match mode only**, **not wingman**. Adds the player to
  `team.coach` (a `HashSet<CCSPlayerController>` — note the single-slot check is commented out, so **multiple coaches
  per team are allowed**). Sets `Clan = "[<team> COACH]"`, money 0.
- **`.uncoach`** (`OnUnCoachCommand`): removes from the coach set, clears the clan tag, `SetPlayerVisible`, money 0.
  Also handled on disconnect (`EventPlayerDisconnect`).

### Per-round handling
- **At freeze-time** (`HandleCoaches`): for each coach — zero money & match stats, make **invisible**
  (`SetPlayerInvisible`), freeze (`MOVETYPE_NONE`), remove weapons, and **teleport to a coach spawn** (random pick
  from `coachSpawns[team]`). It also fixes any *players* sitting on non-competitive spawns by moving them onto free
  competitive spawns. A `coachKillTimer` is armed for `mp_freezetime - 1`.
- **`KillCoaches`** (near freeze-end): temporarily zeroes `mp_suicide_penalty`/`spec_freeze_*`, then **suicides** each
  coach (so they don't occupy the round) — unless paused / tactical timeout. `EventRoundFreezeEnd` is a backup that
  forces still-alive coaches back to spectating their team.
- **`TransferCoachBomb`**: if a coach is given the C4 (`EventPlayerGivenC4`), it's moved to the first alive non-coach T.
- Coaches are made silent on team-change events and their suicide isn't broadcast (Pre handlers in
  [`Querator.cs`](../Querator.cs)).

### Coach spawns
`GetCoachSpawns()` loads `<ModuleDir>/spawns/coach/<map>.json` (the bundled files for the 8 active-duty maps): a
`{ "2": [ {Vector, QAngle} ], "3": [ … ] }` map of T(2)/CT(3) coach positions. If no coach-spawn file exists for the
map, coaches aren't repositioned (logged). See [11](11-utility-localization-configs.md) for the `spawns/` layout.

> **Fork notes:** coaching is the most "hacky" subsystem (invisible + frozen + suicided players). It's disabled in
> wingman and absent from the match JSON (add a coach via roster + `.coach`). Adding coach support to a panel, or a
> cleaner spectator-based coach implementation, are plausible Lany customizations.
