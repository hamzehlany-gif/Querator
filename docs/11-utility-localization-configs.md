# 11 — Utility.cs, Localization & Runtime Config Files

The shared-helper grab-bag, the localization system, and the `.cfg`/`.json` files the plugin reads at runtime.

---

## 1. `Utility.cs` — the shared helper layer (~2050 lines)

Half of the "core" (with `Querator.cs`). Everything here is part of the one `partial class Querator`, so these methods
are callable from anywhere. Use this as a **navigable index** — grep the name to jump to it.

### Phase transitions & match flow (detailed in [03](03-match-lifecycle.md))
`AutoStart`, `StartWarmup`/`ExecWarmupCfg`, `StartKnifeRound`, `StartAfterKnifeWarmup`, `SetLiveFlags`/
`SetupLiveFlagsAndCfg`/`StartLive`/`ExecLiveCFG`, `ResetMatch`, `StartMatchMode`, `KillPhaseTimers`,
`HandleMatchStart`, `HandleMatchEnd`, `CheckLiveRequired`, `ChangeMap`, `HandleMapChangeCommand`,
`HandleReadyRequiredCommand`.

### Round / knife / pause
`HandlePostRoundStartEvent` (round-start: backup creation, stats init), `HandlePostRoundEndEvent` (round-end: score,
stats, damage report, series progress), `IsTeamSwapRequired`, `DetermineKnifeWinner`/`HandleKnifeWinner`,
`PauseMatch`/`ForcePauseMatch`/`ForceUnpauseMatch`/`UnpauseMatch`/`SetMatchPausedFlags` (see
[08](08-readiness-knife-pausing-coaching.md)).

### Scores, phases, game rules
`GetTeamsScore`, `GetRoundNumer`, `GetMatchWinnerName`, `GetAlivePlayers`, `GetGameRules`, `GetGamePhase`,
`IsHalfTimePhase`, `IsPostGamePhase`, `IsTacticalTimeoutActive`. Game mode: `GetGameMode`/`GetGameType`/
`SetCorrectGameMode`/`IsMapReloadRequiredForGameMode`/`IsWingmanMode`.

### Stats aggregation
**`GetPlayerStatsDict()`** ([`Utility.cs:1603`](../Utility.cs)) — the **big one**. Walks every player's
`ActionTrackingServices.MatchStats` + tracked counters and returns
`(Dictionary<ulong, Dictionary<string,object>>, List<StatsPlayer> team1, List<StatsPlayer> team2)`. The first dict is
what `Database.UpdatePlayerStatsAsync` persists; the `StatsPlayer` lists feed the Get5 events. **This is the bridge
between in-game stats and both the DB and the remote-log/panel shapes** (see
[07](07-match-management-and-get5.md) / [09](09-persistence-database.md)).

### Players
`UpdatePlayersMap` (rebuild `playerData`/`playerReadyStatus` from the server), `IsPlayerValid`, `KickPlayer`,
`SwitchPlayerTeam`, `SetPlayerInvisible`/`SetPlayerVisible` (coach hiding), `DropWeaponByDesignerName`,
`HandlePlayerWhitelist` (kick non-whitelisted when `isWhitelistRequired`), `GetPlayerTeammateColor`, `RandomizeSpawns`
(dryrun).

### Chat / color / admin
`PrintToAllChat`/`PrintToPlayerChat`/`ReplyToUserCommand`/`SendPlayerNotAdminMessage`/`SendAvailableCommandsMessage`
(the `.help` output), `GetColorTreatedString` (replaces `{Green}`… tokens with `ChatColors`), `LoadAdmins`,
`IsPlayerAdmin`.

### ConVars / formatting / IO
`GetConvarStringValue`/`SetConvarValue`/`ExecuteChangedConvars`/`ResetChangedConvars` (the match `cvars` block),
`FormatCvarValue` (substitutes `{TIME}`/`{MATCH_ID}`/`{MAP}`/`{MAPNUMBER}`/`{TEAM1}`/`{TEAM2}`/`{TEAM1_SCORE}`/
`{TEAM2_SCORE}`), `GetConvarValueFromCFGFile` (regex-reads a value out of a `.cfg`), `UpdateHostname`
(applies `querator_hostname_format`), `LoadClientNames`/`WriteClientNamesInFile` (writes a `Match_<id>.ini` name file),
`UploadFileAsync` (the shared HTTP POST for demos & backups), `Log` (the logging helper — **use this, not
`Console.WriteLine`**), `HandleClanTags` (currently a **no-op** — returns early).

> **Key cross-cutting helpers to remember:** `IsPlayerValid` (guard every pawn access), `Log` (logging),
> `GetColorTreatedString`/`FormatCvarValue` (string templating), `GetPlayerStatsDict` (stats), `UpdatePlayersMap`
> (the player dictionaries), `IsPlayerAdmin` (permissions). These show up everywhere.

---

## 2. Localization (`lang/*.json`)

- **12 locale files**, each with **126 keys**, all complete: `en`, `de`, `es-ES`, `fr`, `hu`, `ja`, `pt-BR`, `pt-PT`,
  `ru`, `uz`, `zh-Hans`, `zh-Hant`. `en.json` is the source of truth; add new keys there first.
- The csproj copies `lang/**` to the plugin output (`PreserveNewest`).
- **Usage:** `Localizer["matchzy.<key>", arg0, arg1, …]` (CSSharp `BasePlugin.Localizer`). Values use `{0}`,`{1}`…
  placeholders and inline color tokens (`{green}`, `{red}`, `{default}`, …) that resolve to `ChatColors`.
- **Key namespaces** (the `matchzy.<area>.<name>` convention):
  `ready.*`, `knife.*`, `pause.*`, `restore.*`, `backup.*`, `cvars.*`, `cc.*` (console commands), `mm.*` (match
  management), `pm.*` (practice), `rs.*` (ready system), `sleep.*`, `utility.*`, `pracc.*` (practice nade/damage
  feedback).
- **Adding a user-facing string:** add the key to `lang/en.json` (and ideally the other locales), then use
  `Localizer["matchzy.<area>.<name>", …]`. **Don't hardcode** player-facing strings.
- Chat prefixes (`chatPrefix`/`adminChatPrefix`) and any free-form admin text go through `GetColorTreatedString` so
  `{Green}`-style tokens work outside the localizer too.

---

## 3. Runtime config files — `cfg/Querator/`

These are **not** compiled into the DLL. The release workflow copies `cfg/` into `csgo/cfg/`; for a manual deploy you
copy them yourself (see [02](02-build-test-deploy.md)). The plugin reads them from `csgo/cfg/Querator/` at runtime.

### Phase configs (executed via `exec` on each transition)
| File | When | Notes |
|---|---|---|
| `config.cfg` | plugin load | Sets all the default `querator_*` ConVars (§3a). |
| `warmup.cfg` | warmup | `mp_warmup_*`, full-buy economy, no bots. Fallback string baked into `ExecWarmupCfg`. |
| `knife.cfg` | knife round | knives only, free armor, short round. Fallback in `StartKnifeRound`. |
| `live.cfg` | live (5v5) | competitive ruleset; **ends with `exec MatchZy/live_override.cfg`**. |
| `live_wingman.cfg` | live (wingman) | 2v2 ruleset; ends with `exec MatchZy/live_wingman_override.cfg`. |
| `prac.cfg` | practice | cheats, infinite ammo, full nades, `buddha`, bot fill. |
| `dryrun.cfg` | dryrun | competitive-ish without true match mode. |
| `sleep.cfg` | sleep/idle | quiet idle ruleset (falls back to `gamemode_competitive.cfg`). |
| `live_override.cfg`, `live_wingman_override.cfg` | end of live cfgs | **empty by default — the intended user-customization point.** Put your server's tweaks here so base configs can be updated without losing them. |

> **Robustness:** every phase exec checks `File.Exists`; if the cfg is missing the plugin runs a giant hardcoded
> ConVar string instead (the `ExecLiveCFG` fallback in [`Utility.cs:1307`](../Utility.cs) is the de-facto spec of
> competitive defaults for 5v5 & wingman). So the plugin works even with no cfg files, but the files are how you
> customize.

### 3a. `config.cfg` default ConVars (exact, as shipped)
```
querator_whitelist_enabled_default      false
querator_knife_enabled_default          true
querator_minimum_ready_required         2
querator_demo_recording_enabled         true
querator_demo_path                      MatchZy/
querator_demo_name_format               "{TIME}_{MATCH_ID}_{MAP}_{TEAM1}_vs_{TEAM2}"
querator_stop_command_available         false
querator_stop_command_no_damage         false
querator_use_pause_command_for_tactical_pause  false
querator_enable_tech_pause              true
querator_tech_pause_flag                ""
querator_tech_pause_duration            300
querator_max_tech_pauses_allowed        2
querator_pause_after_restore            true
querator_chat_prefix                    [{Green}MatchZy{Default}]
querator_admin_chat_prefix              [{Red}ADMIN{Default}]
querator_chat_messages_timer_delay      13
querator_playout_enabled_default        false
querator_kick_when_no_match_loaded      false
querator_reset_cvars_on_series_end      true
querator_demo_upload_url                ""
querator_autostart_mode                 1
querator_save_nades_as_global_enabled   false
querator_allow_force_ready              true
querator_max_saved_last_grenades        512
querator_smoke_color_enabled            false
querator_everyone_is_admin              false
querator_show_credits_on_match_start    true
querator_hostname_format                "MatchZy | {TEAM1} vs {TEAM2}"
querator_enable_damage_report           true
querator_match_start_message            ""
```
(Header comment says "Do not add commands other than matchzy config console variables." Full per-ConVar reference:
[04](04-commands-and-convars.md#6-convars).)

### JSON / data files (in `cfg/Querator/`)
| File | Shape | Purpose |
|---|---|---|
| `admins.json` | `{ "<steam64>": "<role>" }` | MatchZy's own admin list (empty role = full admin). Auto-created with a `{"steamid":""}` placeholder if missing. Loaded by `LoadAdmins`; reload with `.reload_admins`. |
| `database.json` | `{ DatabaseType, MySqlHost, MySqlDatabase, MySqlUsername, MySqlPassword, MySqlPort }` | SQLite (default) vs MySQL selection. `DatabaseType` must equal `"mysql"` (case-insensitive) for MySQL; anything else → SQLite. See [09](09-persistence-database.md). |
| `savednades.json` | `{ steamid\|"default": { name: { LineupPos, LineupAng, Desc, Map, Type } } }` | Practice grenade lineups. See [05](05-practice-mode.md#6-saved-nades-lineups). |
| `whitelist.cfg` | one steam64 per line | Player whitelist (enforced when `isWhitelistRequired`). |

### `spawns/coach/<map>.json` (bundled, copied to output)
Coach spawn points for the 8 active-duty maps (`de_ancient/anubis/dust2/inferno/mirage/nuke/overpass/vertigo`):
`{ "2": [ {"Vector":"x y z","QAngle":"p y r"} ], "3": [ … ] }` (2 = T, 3 = CT). Loaded by `GetCoachSpawns`; see
[08](08-readiness-knife-pausing-coaching.md#coach-spawns). `spawns/**` is copied to the plugin output by the csproj.

---

## 4. Fork notes
- **Customize game settings via the `*_override.cfg` files**, not the base cfgs — that's their whole reason to exist.
- The hardcoded fallback ConVar strings in `Utility.cs`/`PracticeMode.cs` duplicate the cfg contents; if you change a
  base cfg meaningfully, consider whether the fallback should match.
- Renaming the plugin touches the `querator_*` ConVar names, the `MatchZy/` cfg folder name, the `matchzy.*` lang keys,
  and the `chatPrefix` defaults — plan it as one coordinated change (see [02](02-build-test-deploy.md#6-fork-specific-gotchas-to-remember)).
