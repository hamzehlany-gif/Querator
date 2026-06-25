# deploy-to-vm.ps1 -- build Querator, deploy it to the test VM, restart the CS2 server, and verify the reload.
#
# Runs on the Windows dev machine. Builds here (dotnet publish), packs the publish output as tar.gz, copies it to
# the VM over SSH, extracts it into the plugin folder, restarts the `cs2` systemd service, then polls the
# CounterStrikeSharp log to confirm the plugin re-loaded cleanly.
#
# Why tar.gz (not Compress-Archive/zip): PowerShell's Compress-Archive writes BACKSLASH path separators, which makes
# Linux `unzip` emit a warning and exit 1 -- that non-zero exit silently broke the old `&& systemctl restart` chain,
# so the files updated but the server never restarted. tar uses forward slashes and exits 0, so the chain holds.
#
# One-time setup: authorize ~/.ssh/querator_deploy.pub on the VM's root account:
#   echo "<PUBLIC KEY>" | sudo tee -a /root/.ssh/authorized_keys && sudo chmod 600 /root/.ssh/authorized_keys
#
# Usage:  .\scripts\deploy-to-vm.ps1            (from the repo root)

param(
  [string]$Vm        = "root@82.212.83.229",
  [string]$Key       = "$HOME\.ssh\querator_deploy",
  [string]$Csgo      = "/home/cs2/server/game/csgo",
  [string]$Service   = "cs2",            # the CS2 server unit (NOT cs2-agent / node-agent)
  [string]$PluginDir = "Querator"        # plugins/<PluginDir>. SP-B2 renamed the DLL MatchZy->Querator. NOTE: the
                                         # first Querator.dll deploy must REMOVE the old plugins/MatchZy folder, else
                                         # CSSharp loads both DLLs and double-instantiates the plugin. Coupled to the
                                         # node-agent install path (MATCHZY_PLUGIN_PATH) -- see docs/00-REBRAND-LOG.md SP-B2 TODO.
)
$ErrorActionPreference = "Stop"
$dest = "$Csgo/addons/counterstrikesharp/plugins/$PluginDir"
$ssh  = @("-i", $Key, "-o", "StrictHostKeyChecking=accept-new", "-o", "BatchMode=yes")

Write-Host "==> building (dotnet publish -c Release)..."
dotnet publish -c Release | Out-Null
if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed ($LASTEXITCODE)" }

Write-Host "==> packing publish output (tar.gz)..."
$tar = Join-Path $env:TEMP "querator-deploy.tar.gz"
if (Test-Path $tar) { Remove-Item $tar }
tar -czf $tar -C "bin/Release/net8.0/publish" .
if ($LASTEXITCODE -ne 0) { throw "tar failed ($LASTEXITCODE)" }

Write-Host "==> uploading to $Vm ..."
scp @ssh $tar "${Vm}:/tmp/querator-deploy.tar.gz"
if ($LASTEXITCODE -ne 0) { throw "scp failed ($LASTEXITCODE)" }

Write-Host "==> extracting into plugins/$PluginDir, restarting $Service, verifying reload ..."
# Remote script is base64-piped to avoid PowerShell/sh quoting hell. It: snapshots the CSSharp log line count,
# extracts over the existing plugin folder (keeps runtime data), restarts cs2, then polls up to ~90s for a fresh
# "Finished loading plugin" among the log lines ADDED since the snapshot -- scanning ALL of them, not a fixed tail
# window, because CS2 startup spam can push the load line out of the last N lines. Prints the surrounding load/errors.
$bash = @'
dest="__DEST__"; service="__SERVICE__"; csgo="__CSGO__"
logglob="$csgo/addons/counterstrikesharp/logs/log-cssharp*.txt"
Lbefore=$(ls -t $logglob 2>/dev/null | head -1)
before=$( [ -n "$Lbefore" ] && wc -l < "$Lbefore" || echo 0 )
mkdir -p "$dest"
if ! tar -xzf /tmp/querator-deploy.tar.gz -C "$dest"; then echo "[err] tar extract failed"; exit 1; fi
rm -f /tmp/querator-deploy.tar.gz
echo "[..] restarting $service"
systemctl restart "$service"
# Scan the CSSharp log lines added since the snapshot. Same file -> from line before+1; rotated to a new file ->
# the whole new file is post-restart (start=1). Scanning all new lines (not a fixed tail) is what makes this reliable.
for i in $(seq 1 45); do
  sleep 2
  L=$(ls -t $logglob 2>/dev/null | head -1)
  [ -z "$L" ] && continue
  if [ "$L" = "$Lbefore" ]; then start=$((before+1)); else start=1; fi
  if tail -n +"$start" "$L" | grep -q "Finished loading plugin"; then
    echo "[ok] plugin re-loaded after ~$((i*2))s -- new CSSharp log lines of interest:"
    tail -n +"$start" "$L" | grep -iE "loading plugin|finished loading|error|exception|fail" | tail -10
    err=$(tail -n +"$start" "$L" | grep -icE "error|exception|fail")
    [ "$err" -gt 0 ] && { echo "[warn] $err error/exception line(s) in CSSharp log since restart -- inspect"; exit 3; }
    exit 0
  fi
done
echo "[warn] no fresh load confirmed within ~90s -- inspect: tail -40 $L"
exit 2
'@
$bash = $bash.Replace("__DEST__", $dest).Replace("__SERVICE__", $Service).Replace("__CSGO__", $Csgo)
$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($bash))
ssh @ssh $Vm "echo $b64 | base64 -d | bash"
$rc = $LASTEXITCODE

if ($rc -eq 0) {
  Write-Host "==> done. Deployed '$PluginDir' and verified a clean reload on '$Service'."
} else {
  Write-Host "==> deployed, but reload verification returned $rc -- inspect the server (see [warn] above)."
}
exit $rc
