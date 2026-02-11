# yes-milord: Warcraft II Peasant voice notifications for Copilot CLI / Claude Code
# Plays sounds on prompt submit and when the agent finishes.
param(
    [switch]$toggle,
    [switch]$status,
    [switch]$pause,
    [switch]$resume
)

$ErrorActionPreference = 'SilentlyContinue'

$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }

$configPath = Join-Path $scriptDir 'config.json'
$statePath  = Join-Path $scriptDir '.state.json'
$pausedPath = Join-Path $scriptDir '.paused'

# --- Debug logging ---
$logDir = Join-Path $scriptDir '..'
$logPath = Join-Path $logDir 'debug.log'
function Write-Log($msg) {
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -Path $logPath -Value "[$ts] $msg"
}

# --- CLI subcommands (run before reading stdin) ---
if ($toggle) {
    if (Test-Path $pausedPath) {
        Remove-Item $pausedPath -Force
        Write-Output 'yes-milord: sounds resumed'
    } else {
        New-Item -ItemType File -Path $pausedPath -Force | Out-Null
        Write-Output 'yes-milord: sounds paused'
    }
    exit 0
}

if ($pause) {
    New-Item -ItemType File -Path $pausedPath -Force | Out-Null
    Write-Output 'yes-milord: sounds paused'
    exit 0
}

if ($resume) {
    Remove-Item $pausedPath -Force -ErrorAction SilentlyContinue
    Write-Output 'yes-milord: sounds resumed'
    exit 0
}

if ($status) {
    if (Test-Path $pausedPath) {
        Write-Output 'yes-milord: paused'
    } else {
        Write-Output 'yes-milord: active'
    }
    exit 0
}

# --- Read hook input from stdin ---
$inputJson = [Console]::In.ReadToEnd()
if (-not $inputJson) { exit 0 }

Write-Log "RAW INPUT: $inputJson"

$hookInput = $inputJson | ConvertFrom-Json

# --- Load config ---
$config = @{ enabled = $true; active_pack = 'peasant'; categories = @{ acknowledge = $true; complete = $true } }
if (Test-Path $configPath) {
    try { $config = Get-Content $configPath -Raw | ConvertFrom-Json } catch {}
}

if (-not $config.enabled) { exit 0 }
if (Test-Path $pausedPath) { exit 0 }

# --- Determine category from input fields ---
# Claude Code sends hook_event_name; Copilot CLI we infer from fields
$event = $hookInput.hook_event_name
if (-not $event) {
    if ($hookInput.prompt) { $event = 'UserPromptSubmit' }
    elseif ($hookInput.PSObject.Properties['reason']) { $event = 'Stop' }
}

$category = switch ($event) {
    'UserPromptSubmit'  { 'acknowledge' }
    'Stop'              { 'complete' }
    default             { $null }
}

if (-not $category) {
    Write-Log "NO CATEGORY for event='$event'"
    exit 0
}
Write-Log "RESOLVED event='$event' category='$category'"

# Check if category is enabled
$catEnabled = $true
if ($config.categories -and $config.categories.PSObject.Properties[$category]) {
    $catEnabled = $config.categories.$category
}
if (-not $catEnabled) { exit 0 }

# --- Load sound pack manifest ---
$packName = if ($config.active_pack) { $config.active_pack } else { 'peasant' }
$packDir = Join-Path $scriptDir "..\packs\$packName"
$manifestPath = Join-Path $packDir 'manifest.json'

if (-not (Test-Path $manifestPath)) { exit 0 }

$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
$sounds = $manifest.categories.$category.sounds
if (-not $sounds -or $sounds.Count -eq 0) { exit 0 }

# --- Load state (for repeat avoidance) ---
$state = [PSCustomObject]@{ last_played = [PSCustomObject]@{} }
if (Test-Path $statePath) {
    try { $state = Get-Content $statePath -Raw | ConvertFrom-Json } catch {}
}
if (-not $state.last_played) {
    $state | Add-Member -NotePropertyName 'last_played' -NotePropertyValue ([PSCustomObject]@{}) -Force
}

# --- Pick random sound, avoiding immediate repeat ---
$lastFile = $null
if ($state.last_played.PSObject.Properties[$category]) {
    $lastFile = $state.last_played.$category
}

$candidates = $sounds
if ($sounds.Count -gt 1 -and $lastFile) {
    $candidates = $sounds | Where-Object { $_.file -ne $lastFile }
}

$pick = $candidates | Get-Random
$soundFile = Join-Path $packDir "sounds\$($pick.file)"

if (-not (Test-Path $soundFile)) { exit 0 }

# --- Update state ---
if (-not ($state.last_played -is [PSCustomObject])) {
    $state | Add-Member -NotePropertyName 'last_played' -NotePropertyValue ([PSCustomObject]@{}) -Force
}
$state.last_played | Add-Member -NotePropertyName $category -NotePropertyValue $pick.file -Force
$state | ConvertTo-Json -Depth 5 | Set-Content $statePath -Encoding UTF8

Write-Log "PLAYING $($pick.file)"

# --- Play sound ---
Add-Type -AssemblyName System.Windows.Forms
$player = New-Object System.Media.SoundPlayer $soundFile
$player.PlaySync()

exit 0
