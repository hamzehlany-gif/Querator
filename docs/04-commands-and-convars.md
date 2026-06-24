# 04 — Commands & ConVars Reference

Exhaustive, source-derived catalog of every command and ConVar as of **0.8.15**. Descriptions are the in-code help
strings. Practice-command *mechanics* are detailed in [05-practice-mode.md](05-practice-mode.md); this doc is the
catalog + routing/permission model.

---

## 1. How a command actually gets invoked (3 routes)

A given handler method is usually reachable **three ways**:

1. **`.cmd` in chat** → caught by MatchZy's own `EventPlayerChat` handler in [`Querator.cs`](../Querator.cs):
   - exact, no-arg → `commandActions` dictionary
   - arg-bearing → `message.StartsWith(".cmd")` → `Handle*Command`
2. **`!cmd` in chat** and **`css_cmd` in server console / RCON** → CSSharp's `[ConsoleCommand("css_cmd")]`
   registration. CSSharp routes the `!` chat prefix to the matching `css_` command.
3. Many handlers carry **both** a `commandActions` entry (`.cmd`) *and* a `[ConsoleCommand]` attribute (`css_cmd`),
   so all three work and call the same method. (E.g. `OnPlayerReady` ← `.ready`/`.r` and ← `css_ready`.)

**Consequence for editing:** if you add a player-facing command, wire it in **both** places to match existing UX
(a `commandActions`/`StartsWith` entry for `.`, and a `[ConsoleCommand("css_…")]` for `!`/console). ConVar setters
(`querator_*`) are the exception — they're console-only.

### ConVar setters are server-only
Every `querator_*` / `get5_*` config command starts with `if (player != null) return;` — i.e. it **only runs from the
server console / RCON / a `.cfg` exec**, never from a player. So players cannot change config cvars in chat.

---

## 2. Admin permission model

`IsPlayerAdmin(player, command, params permissions)` ([`Utility.cs:124`](../Utility.cs)) returns true if **any** of:
- ConVar `querator_everyone_is_admin` is true, **or**
- the player satisfies the CSSharp permission check for `permissions` **+ implicit `@css/root`**
  (CSSharp `admins.json`/groups), **or**
- the player's SteamID is a key in **MatchZy's** `cfg/Querator/admins.json`, **or**
- `player == null` (invoked by the server console / RCON → always admin).

Permission flags actually used in the code:

| Flag | Gates |
|---|---|
| `@css/root` | implicitly added to every check (root can do anything) |
| `@css/config` | match-control admin commands (whitelist, knife, playout, start/restart/endmatch, settings, readyrequired, skipveto, team names, reload_admins) |
| `@css/map` + `@custom/prac` | mode switches & practice (`css_match`, `css_exitprac`, `css_sleep`, practice entry) |
| `@css/rcon` | `css_rcon` / `.rcon` |
| `@css/chat` | `css_asay` / `.asay` |

> The fork's simplest admin path is **MatchZy `admins.json`** (steamid → role string); empty role = full admin. See
> [11-utility-localization-configs.md](11-utility-localization-configs.md).

---

## 3. Player chat commands — exact match (`commandActions`)

Source: the `commandActions` dictionary in [`Querator.cs`](../Querator.cs) `Load()`. (`.`/`!` both work.)

| Command(s) | Handler | Purpose |
|---|---|---|
| `.ready` `.r` | `OnPlayerReady` | Mark self ready. |
| `.unready` `.notready` `.ur` | `OnPlayerUnReady` | Mark self unready. |
| `.forceready` | `OnForceReadyCommandCommand` | Force-ready your whole team (match mode, if `allowForceReady`). |
| `.stay` | `OnTeamStay` | Knife winner keeps side → go live. |
| `.switch` `.swap` | `OnTeamSwitch` | Knife winner swaps side → go live. |
| `.tech` | `OnTechCommand` | Technical pause. |
| `.p` `.pause` | `OnPauseCommand` | Pause (tactical if `querator_use_pause_command_for_tactical_pause`, else normal). |
| `.unpause` `.up` | `OnUnpauseCommand` | Request unpause (both teams confirm). |
| `.forcepause` `.fp` | `OnForcePauseCommand` | Admin pause. |
| `.forceunpause` `.fup` | `OnForceUnpauseCommand` | Admin unpause. |
| `.tac` | `OnTacCommand` | Tactical timeout (uses CS2 `timeout_*`). |
| `.roundknife` `.rk` | `OnKnifeCommand` | Toggle knife round (admin). |
| `.playout` | `OnPlayoutCommand` | Toggle playout/all-rounds (admin). |
| `.start` `.force` `.forcestart` | `OnStartCommand` | Force-start match (admin). |
| `.skipveto` `.sv` | `OnSkipVetoCommand` | Skip veto (admin). |
| `.restart` `.rr` | `OnRestartMatchCommand` | Reset match (admin). |
| `.endmatch` `.forceend` | `OnEndMatchCommand` | End+reset match (admin). |
| `.reloadmap` | `OnMapReloadCommand` | Reload current map (admin). |
| `.settings` | `OnMatchSettingsCommand` | Show current settings (admin). |
| `.whitelist` | `OnWLCommand` | Toggle whitelist (admin). |
| `.globalnades` | `OnSaveNadesAsGlobalCommand` | Toggle global nade pool (admin). |
| `.reload_admins` | `OnReloadAdmins` | Reload `admins.json` (admin). |
| `.tactics` `.prac` | `OnPracCommand` | Enter practice mode. |
| `.match` `.exitprac` | `OnMatchCommand` | Leave practice → match mode. |
| `.uncoach` | `OnUnCoachCommand` | Leave coach slot. |
| `.stop` | `OnStopCommand` | Restore current round (both teams confirm; gated by `querator_stop_command_available`). |
| `.help` | `OnHelpCommand` | Context-sensitive command list. |
| **Practice** (see [05](05-practice-mode.md)) | | `.showspawns` `.hidespawns` `.dryrun`/`.dry` `.noflash`/`.noblind` `.break` `.bot` `.cbot`/`.crouchbot` `.boost` `.crouchboost` `.nobots` `.solid` `.impacts` `.traj`/`.pip` `.god` `.ff`/`.fastforward` `.clear` `.t` `.ct` `.spec` `.fas`/`.watchme` `.last` `.throw`/`.rethrow`/`.rt` `.throwsmoke`/`.rethrowsmoke` `.thrownade`/`.rethrownade`/`.rethrowgrenade`/`.throwgrenade` `.rethrowflash`/`.throwflash` `.rethrowdecoy`/`.throwdecoy` `.throwmolotov`/`.rethrowmolotov` `.timer` `.lastindex` `.bestspawn` `.worstspawn` `.bestctspawn` `.worstctspawn` `.besttspawn` `.worsttspawn` `.savepos` `.loadpos` |

## 4. Player chat commands — arg-bearing (`StartsWith`)

Source: `EventPlayerChat` `message.StartsWith(...)` chain in [`Querator.cs`](../Querator.cs).

| Command(s) | Handler | Purpose |
|---|---|---|
| `.map <map>` | `HandleMapChangeCommand` | Change map. |
| `.readyrequired <n>` | `HandleReadyRequiredCommand` | Set ready threshold (admin). |
| `.restore <round>` | `HandleRestoreCommand` | Restore a round backup (admin). |
| `.asay <msg>` | inline (`@css/chat`) | Admin chat broadcast. |
| `.savenade`/`.sn [name] [desc]` | `HandleSaveNadeCommand` | Save nade lineup. |
| `.delnade`/`.dn`/`.deletenade <name>` | `HandleDeleteNadeCommand` | Delete nade lineup. |
| `.importnade`/`.in <code>` | `HandleImportNadeCommand` | Import lineup from code. |
| `.listnades`/`.lin [filter]` | `HandleListNadesCommand` | List saved lineups. |
| `.loadnade`/`.ln <name>` | `HandleLoadNadeCommand` | Load a lineup. |
| `.spawn <n>` | `HandleSpawnCommand` | Teleport to spawn n (current team). |
| `.ctspawn`/`.cts <n>`, `.tspawn`/`.ts <n>` | `HandleSpawnCommand` | Teleport to CT/T spawn n. |
| `.team1 <name>`, `.team2 <name>` | `HandleTeamNameChangeCommand` | Set team name (admin). |
| `.rcon <cmd>` | inline (`@css/rcon`) | Run server command. |
| `.coach <t\|ct>` | `HandleCoachCommand` | Join a coach slot. |
| `.ban <map>` | `HandeMapBanCommand` | Veto-ban a map. |
| `.pick <map>` | `HandeMapPickCommand` | Veto-pick a map. |
| `.back <n>` | `HandleBackCommand` | Practice: teleport to nade-history index n. |
| `.delay <s>` | `HandleDelayCommand` | Practice: delay rethrow. |
| `.throwindex`/`.throwidx <i...>` | `HandleThrowIndexCommand` | Practice: throw nade(s) by history index. |

## 5. Console / admin commands (`css_*`, `sm_*`, `get5_*`)

These are `[ConsoleCommand]` registrations (console/RCON + `!` chat). Grouped by area. Admin flag shown where the
handler checks one (blank = no explicit check / player-context-only).

### Match control
| Command(s) | Admin | Purpose |
|---|---|---|
| `css_ready` / `css_unready` `css_notready` | — | ready/unready |
| `css_forceready` | (match setup) | force-ready team |
| `css_stay` / `css_switch` `css_swap` | — | knife side decision |
| `css_t` / `css_ct` | — | veto side choice / knife decision / practice team |
| `css_start` `css_force` `css_forcestart` | `@css/config` | force start |
| `css_restart` `css_rr` | `@css/config` | reset match |
| `css_endmatch` `css_forceend` `get5_endmatch` | `@css/config` | end + reset |
| `css_skipveto` `css_sv` | `@css/config` | skip veto |
| `css_roundknife` `css_rk` | `@css/config` | toggle knife |
| `css_playout` | `@css/config` | toggle playout |
| `css_whitelist` `css_wl` | `@css/config` | toggle whitelist |
| `css_save_nades_as_global` `css_globalnades` | `@css/config` | toggle global nades |
| `css_readyrequired` | `@css/config` | set ready count |
| `css_settings` | `@css/config` | show settings |
| `css_team1` / `css_team2` | `@css/config` | set team names |
| `css_map` | (via handler) | change map |
| `css_rmap` | admin | reload map |
| `css_sleep` | `@css/map`/`@custom/prac` | sleep mode |
| `css_match` / `css_exitprac` | `@css/map`/`@custom/prac` | match mode |
| `reload_admins` | `@css/config` | reload admins.json |
| `css_rcon` | `@css/rcon` | run server cmd |
| `css_asay` | `@css/chat` | admin chat |
| `css_help` | — | command list |
| `version` | — | server version (Get5 status probe) |

### Pause / timeout
`css_pause`, `css_tech`, `css_unpause`, `css_tac`, `css_fp` `css_forcepause` `sm_pause`,
`css_fup` `css_forceunpause` `sm_unpause`. See [08-readiness-knife-pausing-coaching.md](08-readiness-knife-pausing-coaching.md).

### Coaching / roster (Teams.cs)
| Command(s) | Purpose |
|---|---|
| `css_coach` | join coach slot (`.coach <t\|ct>`) |
| `css_uncoach` | leave coach slot |
| `querator_addplayer` / `get5_addplayer` | add player to a team (steamid, team, name) |
| `querator_removeplayer` / `get5_removeplayer` | remove player from all teams |

### Match loading (MatchManagement.cs)
| Command(s) | Purpose |
|---|---|
| `querator_loadmatch` | load match from local JSON file (relative to `csgo/`) |
| `querator_loadmatch_url` / `get5_loadmatch_url` | load match from URL (+ optional header name/value) |

### Backups / restore (BackupManagement.cs)
| Command(s) | Purpose |
|---|---|
| `css_stop` | both teams `.stop` → restore current round |
| `css_restore` | admin restore a specific round |
| `querator_loadbackup` / `get5_loadbackup` | restore from a backup file |
| `querator_loadbackup_url` / `get5_loadbackup_url` | restore from a backup URL |
| `querator_listbackups` / `get5_listbackups` | list backups for a matchid |

### Get5 panel surface (G5API.cs)
| Command | Purpose |
|---|---|
| `get5_status` | JSON status payload for G5V/G5API panels |
| `get5_web_available` | reports web-availability for panels |

### Practice (PracticeMode.cs)
All practice `css_*` commands (mechanics in [05](05-practice-mode.md)):
`css_god`, `css_prac` `css_tactics`, `css_dry` `css_dryrun`, `css_spawn`, `css_ctspawn`, `css_tspawn`, `css_bot`,
`css_cbot` `css_crouchbot`, `css_boost`, `css_crouchboost`, `css_nobots`, `css_ff` `css_fastforward`, `css_clear`,
`css_spec`, `css_fas` `css_watchme`, `css_noblind` `css_noflash`, `css_break`, `css_throw` `css_rethrow`,
`css_savepos`, `css_loadpos`, `css_throwsmoke` `css_rethrowsmoke`, `css_throwflash` `css_rethrowflash`,
`css_throwgrenade` `css_rethrowgrenade` `css_thrownade` `css_rethrownade`, `css_throwmolotov` `css_rethrowmolotov`,
`css_throwdecoy` `css_rethrowdecoy`, `css_last`, `css_back`, `css_throwidx` `css_throwindex`, `css_lastindex`,
`css_delay`, `css_timer`, `css_sn` `css_savenade`, `css_ln` `css_loadnade`, `css_lin` `css_listnades`,
`css_importnade` `css_in`, `css_deletenade` `css_delnade` `css_dn`, `css_solid`, `css_impacts`, `css_traj` `css_pip`,
`css_bestspawn`, `css_worstspawn`, `css_bestctspawn`, `css_worstctspawn`, `css_besttspawn`, `css_worsttspawn`,
`css_showspawns`, `css_hidespawns`. (Commented-out: `css_timer2`.)

---

## 6. ConVars

### 6a. `FakeConVar<T>` server cvars (11, all in [`ConfigConvars.cs`](../ConfigConvars.cs))
Read directly as `.Value` in code.

| ConVar | Type | Default | Field/effect |
|---|---|---|---|
| `querator_smoke_color_enabled` | bool | false | per-player smoke color (`smokeColorEnabled`) |
| `querator_enable_tech_pause` | bool | true | `.tech` enabled (`techPauseEnabled`) |
| `querator_tech_pause_flag` | string | "" | flag required for tech pause (`techPausePermission`) |
| `querator_tech_pause_duration` | int | 300 | tech pause seconds (`techPauseDuration`) |
| `querator_max_tech_pauses_allowed` | int | 2 | max tech pauses/team (`maxTechPausesAllowed`) |
| `querator_everyone_is_admin` | bool | false | treat all players as admin (`everyoneIsAdmin`) |
| `querator_show_credits_on_match_start` | bool | true | print credits on start (`showCreditsOnMatchStart`) |
| `querator_hostname_format` | string | `MatchZy \| {TEAM1} vs {TEAM2}` | hostname template (`hostnameFormat`) |
| `querator_enable_damage_report` | bool | true | round damage report (`enableDamageReport`) |
| `querator_stop_command_no_damage` | bool | false | `.stop` unavailable after cross-team damage (`stopCommandNoDamage`) |
| `querator_match_start_message` | string | "" | message on start, `$$$`=newline (`matchStartMessage`) |

### 6b. Config-setter ConVars (`[ConsoleCommand]`, parse `ArgString` → plain field)

| ConVar (+ get5 alias) | Default | Sets |
|---|---|---|
| `querator_whitelist_enabled_default` | false | `isWhitelistRequired` |
| `querator_knife_enabled_default` | true | `isKnifeRequired` |
| `querator_playout_enabled_default` | false | `isPlayOutEnabled` |
| `querator_save_nades_as_global_enabled` | false | `isSaveNadesAsGlobalEnabled` |
| `querator_kick_when_no_match_loaded` | false | `matchModeOnly` |
| `querator_reset_cvars_on_series_end` | true | `resetCvarsOnSeriesEnd` |
| `querator_minimum_ready_required` | **2** (field) / config.cfg sets 2 | `minimumReadyRequired` (help text says "1" — stale) |
| `querator_demo_path` | `MatchZy/` (config.cfg) | `demoPath` (must end with `/`, not start with `/` or `.`) |
| `querator_demo_name_format` | `{TIME}_{MATCH_ID}_{MAP}_{TEAM1}_vs_{TEAM2}` | `demoNameFormat` |
| `querator_demo_recording_enabled` | true | `isDemoRecordingEnabled` |
| `querator_demo_upload_url` / `get5_demo_upload_url` | "" | `demoUploadURL` |
| `querator_demo_upload_header_key` / `get5_demo_upload_header_key` | "" | demo upload header key |
| `querator_demo_upload_header_value` / `get5_demo_upload_header_value` | "" | demo upload header value |
| `querator_stop_command_available` | false | `isStopCommandAvailable` |
| `querator_use_pause_command_for_tactical_pause` | false | `isPauseCommandForTactical` |
| `querator_pause_after_restore` | true | `pauseAfterRoundRestore` |
| `querator_chat_prefix` | `[{Green}MatchZy{Default}]` | `chatPrefix` |
| `querator_admin_chat_prefix` | `[{Red}ADMIN{Default}]` | `adminChatPrefix` |
| `querator_chat_messages_timer_delay` | **13** (field) / help says 12 | `chatTimerDelay` |
| `querator_autostart_mode` | 1 | `autoStartMode` (0 none / 1 match / 2 practice) |
| `querator_allow_force_ready` / `get5_allow_force_ready` | true | `allowForceReady` |
| `querator_max_saved_last_grenades` | 512 | `maxLastGrenadesSavedLimit` (0 disables) |
| `querator_remote_backup_url` / `get5_remote_backup_url` | "" | `backupUploadURL` |
| `querator_remote_backup_header_key` / `get5_remote_backup_header_key` | "" | `backupUploadHeaderKey` |
| `querator_remote_backup_header_value` / `get5_remote_backup_header_value` | "" | `backupUploadHeaderValue` |
| `querator_remote_log_url` / `get5_remote_log_url` | "" | `matchConfig.RemoteLogURL` (event forwarding) |
| `querator_remote_log_header_key` / `get5_remote_log_header_key` | "" | `matchConfig.RemoteLogHeaderKey` |
| `querator_remote_log_header_value` / `get5_remote_log_header_value` | "" | `matchConfig.RemoteLogHeaderValue` |

> Defaults that ship are in `cfg/Querator/config.cfg` (executed on load). See
> [11-utility-localization-configs.md](11-utility-localization-configs.md) for the file's exact contents.

## 7. `get5_*` alias index (panel compatibility — keep stable)

`get5_loadmatch_url`, `get5_endmatch`, `get5_addplayer`, `get5_removeplayer`, `get5_status`, `get5_web_available`,
`get5_loadbackup`, `get5_loadbackup_url`, `get5_listbackups`, `get5_demo_upload_url`, `get5_demo_upload_header_key`,
`get5_demo_upload_header_value`, `get5_remote_log_url`, `get5_remote_log_header_key`, `get5_remote_log_header_value`,
`get5_remote_backup_url`, `get5_remote_backup_header_key`, `get5_remote_backup_header_value`, `get5_allow_force_ready`.

> These exist so G5V/G5API panels (which speak Get5's command vocabulary) can drive Querator unchanged. **If you
> rename the plugin, keep the `get5_*` aliases** or you break panel integration.

## 8. Known code/doc discrepancies (carried from upstream)
- `querator_minimum_ready_required` help says "Default: 1" but the field initializes to **2** and `config.cfg` sets 2.
- `querator_chat_messages_timer_delay` help says "Default: 12" but the field default is **13**.
- `querator_playout_enabled_default` help text is copy-pasted from the knife cvar ("knife round is enabled…").

These are harmless but worth knowing when reconciling docs vs behavior.
