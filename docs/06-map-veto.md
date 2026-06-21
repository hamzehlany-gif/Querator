# 06 — Map Veto & Side Selection

The veto subsystem, entirely in [`MapVeto.cs`](../MapVeto.cs). It runs **only in match mode** (a config was loaded
that didn't skip veto). Source of truth for veto behavior.

---

## 1. When veto runs

From the match-start flow ([03-match-lifecycle.md](03-match-lifecycle.md)): `LoadMatchFromJSON` sets `isPreVeto=true`
**iff** `!SkipVeto` and the map pool is larger than `num_maps`. Then on ready-up, `HandleMatchStart()` branches to
`CreateVeto()` when `isPreVeto`.

So the full match loop with veto is:
1. Load config → `isPreVeto=true`, warmup.
2. Teams `.ready` → `HandleMatchStart()` → `CreateVeto()`.
3. Veto runs (match **paused**).
4. `FinishVeto()` → back to warmup, **everyone unreadied**, `readyAvailable=true`.
5. Teams `.ready` **again** → `HandleMatchStart()` (now `isPreVeto=false`) → knife or live.

---

## 2. State & data

| Field | Type | Meaning |
|---|---|---|
| `isPreVeto` | bool | A veto is pending (set at load; cleared when veto finishes/skips). |
| `isVeto` | bool | Veto actively in progress. |
| `vetoCountdownTime` | int (5) | Seconds counted down before the veto starts / between auto steps. |
| `warningsPrinted` | int | Countdown progress counter. |
| `vetoStateTimer` | Timer? | 1s repeating countdown timer. |
| `vetoCaptains` | `Dictionary<string,int>` | `"team1"/"team2"` → captain **userid** (client key in `playerData`). |
| `lastVetoTeam` | CsTeam | The team that made the last ban/pick (drives whose turn / side prompt). |
| `mapChangePending` | bool | A map change is queued after veto. |

The **map pool / order** lives on `matchConfig` (see [07](07-match-management-and-get5.md)):
`MapsPool` (original), `MapsLeftInVetoPool` (shrinks as maps are banned/picked), `Maplist` (the chosen series, grows),
`MapSides` (per-map side decision), `MapBanOrder` (the veto script, e.g. `["team1_ban","team2_ban","team1_pick",…]`),
`MatchSideType`, `NumMaps`, `CurrentMapNumber`.

---

## 3. Entering veto — `CreateVeto()`

1. `SwapPlayersToTeams()` — snap every human to their config team (`GetPlayerTeam`).
2. Pick captains: `GetTeamCaptain("team1"/"team2")` = the **first valid non-bot player** on that team's current side.
3. `mp_warmup_end`, then **`mp_pause_match`** (`isPaused=true`, pauseTeam="Admin") — the match is paused for the whole
   veto.
4. Start `vetoStateTimer` = `AddTimer(1, VetoCountdown, REPEAT)`; `isVeto=true; readyAvailable=false; isWarmup=false`;
   `KillPhaseTimers()`.

`VetoCountdown()` ticks once/sec, printing "Map selection commencing in N"; after `vetoCountdownTime` ticks it prints
the captains and calls `HandleVetoStep()`. If a captain is no longer valid → `AbortVeto()`.

---

## 4. The veto step machine — `HandleVetoStep()`

This is the heart. Each call decides the next action by comparing list sizes:

```
if MapSides.Count < Maplist.Count:          # a picked map still needs a side
    if MatchSideType == "standard":  PromptForSideSelectionInChat(other team)   # captain runs .ct/.t
    else:                            HandleAutomaticSideSelection(); recurse
elif NumMaps > Maplist.Count:               # still need to choose more maps
    if MapsLeftInVetoPool.Count == 1:  pick last by deduction; auto side; FinishVeto()
    else:                              PromptForMapSelectionInChat(GetCurrentMapSelectionOption())
else:                                       # enough maps chosen
    FinishVeto()
```

- **`GetCurrentMapSelectionOption()`** computes the current step from `MapBanOrder` using
  `index = Maplist.Count + mapsBanned`, where `mapsBanned = MapsPool.Count − (MapsLeftInVetoPool.Count + Maplist.Count)`.
  Returns `"team1_ban"|"team2_ban"|"team1_pick"|"team2_pick"|"invalid"`.
- **`SidePickPending()`** = `MapSides.Count < Maplist.Count && MatchSideType == "standard"`. While true, `.ban`/`.pick`
  are blocked (a side must be chosen first).

### Captain actions
- `.ban <map>` → `HandeMapBanCommand` → checks `isVeto`, `!SidePickPending`, the option is a *ban* for this captain's
  team, and `player.UserId == vetoCaptains[team]` → `BanMap()` → `HandleVetoStep()`.
- `.pick <map>` → `HandeMapPickCommand` → analogous for *pick* → `PickMap()` → `HandleVetoStep()`.
- `.ct` / `.t` during veto → `OnCTCommand`/`OnTCommand` → `HandleSideChoice(side, client)` → only the side-picking
  captain (`lastVetoTeam`'s opponent) → `PickSide()` → `HandleVetoStep()`.

### `BanMap` / `PickMap`
Both call **`RemoveMapFromMapPool(mapName)`** then announce and fire an event:
- `PickMap` → append to `Maplist`, fire **`QueratorMapPickedEvent`** (`map_picked`).
- `BanMap` → just remove, fire **`QueratorMapVetoedEvent`** (`map_vetoed`).
- Both set `lastVetoTeam`.

**`RemoveMapFromMapPool` quirks** (worth knowing):
- Matches by **case-insensitive substring** if `mapName.Length >= 4` and the substring is unique; else falls back to
  exact match.
- Special-cases **Cobblestone**: if input contains `"cobble"` but nothing matched, it retries with `"cbble"` (because
  the map id is `de_cbble`).

### Side selection
- `PromptForSideSelectionInChat(team)` asks the non-last-veto captain to `.ct`/`.t` for the just-picked map.
- `PickSide(side, team)` appends the proper `team1_ct`/`team1_t` token to `MapSides` and fires
  **`QueratorSidePickedEvent`** (`side_picked`).
- `HandleAutomaticSideSelection()` (non-standard `MatchSideType`): `random` → random `team1_ct`/`team1_t`;
  `never_knife` → `team1_ct`; otherwise → `"knife"`.

---

## 5. Default veto script — `GenerateDefaultVetoSetup()`

If the config didn't supply `veto_mode` (`MapBanOrder` empty) and veto isn't skipped, this builds `MapBanOrder` based
on `NumMaps` and pool size. The *starting* team is `matchzyTeam1` unless `lastVetoTeam` indicates otherwise.

| Series | Logic |
|---|---|
| **BO1** (`NumMaps==1`) | `poolCount − 1` alternating **bans** (last map decided by deduction). |
| **BO2** (`NumMaps==2`) | pool `<5` → two **picks** (team1 then team2); pool `≥5` → two bans then two picks. |
| **BO3+** (default) | If `poolCount ≥ NumMaps+2`: *start bans* (`pool − (NumMaps+2)`), then `NumMaps−1` **picks**, then *end bans* to exhaust the pool minus the auto-decided last map. Else: alternate `NumMaps` picks and ignore the leftover. |

`ValidateMapBanLogic()` validates a **user-supplied** `veto_mode`: in an N-map series at least `N−1` options must be
picks, and pool size must be exactly one larger than the ban/pick count (unless every map is a pick).

---

## 6. Finishing / aborting / skipping

- **`FinishVeto()`**: announce the decided maps, clear `MapsLeftInVetoPool`, unpause, **`SetMapSides()`**,
  `ExecuteChangedConvars()`, **unready everyone**, and if the game mode or current map doesn't match → `SetCorrectGameMode()`
  + queue `ChangeMap(...)` (7s delay, `mapChangePending=true`). Then `isWarmup=true; readyAvailable=true;
  isPreVeto=false; isVeto=false; StartWarmup()`. → teams ready up again to actually start the map.
- **`AbortVeto()`**: a captain disconnected mid-veto → pause selection, `isPreVeto=true; isVeto=false`, unpause, reset
  captains, unready everyone, `StartWarmup()`. Teams `.ready` to resume (veto restarts from `CreateVeto`).
- **`SkipVeto()`** (admin `.skipveto`/`css_sv`): `isPreVeto=false; isVeto=false`, back to warmup/ready. The maplist is
  then taken as-is (first `NumMaps` maps), sides via `SetMapSides()`.

---

## 7. Events fired during veto (remote log / panel)

`map_picked` (`QueratorMapPickedEvent`), `map_vetoed` (`QueratorMapVetoedEvent`), `side_picked`
(`QueratorSidePickedEvent`) — all carry `matchid`, `team`, `map_name` (+ `map_number`/`side`). See
[10-demos-backups-events-damage.md](10-demos-backups-events-damage.md) and [`Events.cs`](../Events.cs).

---

## 8. Gotchas / TODOs left in code
- `pauseOnVeto` and `displayGotvVeto` cvars are **commented-out TODOs** — veto always pauses, and the post-veto map
  change uses a fixed 7s delay (no GOTV-aware delay).
- Captain = first human on the side; there's no captain-election UI. If that player leaves, veto aborts.
- `AbortVeto` on captain disconnect mid-step is itself marked TODO ("Add AbortVeto() when captain is disconnecting
  in-between veto") — abort only triggers at countdown boundaries.
- BO2 (`num_maps==2`) is supported in veto generation, an unusual case to remember.
