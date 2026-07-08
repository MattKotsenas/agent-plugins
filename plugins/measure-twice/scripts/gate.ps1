#requires -Version 5.1
<#
.SYNOPSIS
measure-twice: an agentStop review gate for Copilot CLI.

.DESCRIPTION
With a control flag, reads or writes configuration: -enable / -disable flip the
current session, -setdefault sets the on/off default for new sessions, -setprompt
sets the review prompt, and -status reports the session mode, its default, and the prompt. With no flag, reads a hook
payload on stdin and runs the review gate: when this session is on, it blocks the
agent from finishing until it runs its reviews and echoes a one-time token.

The gate logic lives in MeasureTwice.psm1; this script is the entry point.
#>
[CmdletBinding()]
param(
    [switch]$enable,
    [switch]$disable,
    [switch]$status,
    [string]$setprompt,
    [ValidateSet('on', 'off')][string]$setdefault
)

$ErrorActionPreference = 'SilentlyContinue'
Import-Module (Join-Path $PSScriptRoot 'MeasureTwice.psm1') -Force

$configPath = Get-MTConfigPath
$config = Get-MTConfig -ConfigPath $configPath

# --- control flags (handled before any stdin read) ---
if ($enable -or $disable) {
    $sessionDir = Get-MTSessionDir
    if (-not $sessionDir) {
        Write-Warning 'measure-twice: no session id (COPILOT_AGENT_SESSION_ID is unset), so I cannot tell which session to change. Refusing, rather than silently changing every session. Use -setdefault to change the new-session default.'
        exit 1
    }
    $mode = if ($enable) { 'on' } else { 'off' }
    try { Set-MTSessionMode -SessionDir $sessionDir -Mode $mode } catch { Write-Warning "measure-twice: could not save session mode: $($_.Exception.Message)"; exit 1 }
    "measure-twice: this session is now $mode (default for new sessions stays $($config.defaultMode))"
    exit 0
}
if ($setdefault) {
    $config.defaultMode = $setdefault
    try { Save-MTConfig $config $configPath } catch { Write-Warning "measure-twice: could not save default: $($_.Exception.Message)"; exit 1 }
    "measure-twice: default for new sessions is now $setdefault"; exit 0
}
if ($setprompt) {
    $config.prompt = $setprompt
    try { Save-MTConfig $config $configPath } catch { Write-Warning "measure-twice: could not save prompt: $($_.Exception.Message)"; exit 1 }
    'measure-twice: review prompt updated'; exit 0
}
if ($status) {
    $sessionDir = Get-MTSessionDir
    $mode = Get-MTSessionMode -SessionDir $sessionDir -DefaultMode $config.defaultMode
    if ($sessionDir) { "measure-twice: this session=$mode (default for new sessions=$($config.defaultMode))" }
    else             { "measure-twice: no session context (default for new sessions=$($config.defaultMode))" }
    "prompt: $($config.prompt)"
    exit 0
}

# --- hook mode: gate only when this session is on ---
$inputJson = [Console]::In.ReadToEnd()
if (-not $inputJson) { exit 0 }
try { $hook = $inputJson | ConvertFrom-Json } catch { exit 0 }

$transcript = $hook.transcriptPath
if (-not $transcript) { exit 0 }              # no transcript: can't read the release token, so don't gate
$sessionDir = Split-Path $transcript -Parent
if ((Get-MTSessionMode -SessionDir $sessionDir -DefaultMode $config.defaultMode) -ne 'on') { exit 0 }

$statePath = Get-MTStatePath -SessionDir $sessionDir
$reason = Invoke-MTGate -Config $config -TranscriptPath $transcript -StatePath $statePath
if ($reason) { [PSCustomObject]@{ decision = 'block'; reason = $reason } | ConvertTo-Json -Compress }
exit 0
