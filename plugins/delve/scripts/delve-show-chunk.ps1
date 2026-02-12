<#
.SYNOPSIS
    Display a diff chunk in a terminal split pane. If no supported terminal
    multiplexer is detected, exits with code 1 so the caller can fall back
    to inline rendering.

.PARAMETER DiffFile
    Path to the .diff file to display.

.PARAMETER StateDir
    Directory for pane state files (pane.pid, pane.close).

.NOTES
    Exit 0 = pane displayed successfully.
    Exit 1 = no supported terminal; caller should render inline.
#>
param(
    [Parameter(Mandatory)][string]$DiffFile,
    [Parameter(Mandatory)][string]$StateDir
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot

# --- Detect terminal multiplexer ---
if (-not $env:WT_SESSION) {
    exit 1  # Not Windows Terminal — fall back to inline
}

if (-not (Get-Command wt.exe -ErrorAction SilentlyContinue)) {
    exit 1
}

# --- Close any existing pane ---
$signalFile = Join-Path $StateDir 'pane.close'
$pidFile = Join-Path $StateDir 'pane.pid'

if (Test-Path $pidFile) {
    'close' | Set-Content $signalFile
    $oldPid = [int](Get-Content $pidFile -ErrorAction SilentlyContinue)
    if ($oldPid) {
        # Wait up to 2 seconds for clean exit
        for ($i = 0; $i -lt 20; $i++) {
            if (-not (Get-Process -Id $oldPid -ErrorAction SilentlyContinue)) { break }
            Start-Sleep -Milliseconds 100
        }
    }
    Remove-Item $pidFile -ErrorAction SilentlyContinue
    Remove-Item $signalFile -ErrorAction SilentlyContinue
}

# --- Discover our tab index ---
# Walk the process tree up to WindowsTerminal.exe
$wtPid = $null
$ourShellPid = $null
$current = $PID
for ($i = 0; $i -lt 20; $i++) {
    $proc = Get-CimInstance Win32_Process -Filter "ProcessId = $current" -ErrorAction SilentlyContinue
    if (-not $proc) { break }
    if ($proc.Name -eq 'WindowsTerminal.exe') {
        $wtPid = $proc.ProcessId
        break
    }
    # Track the shell process that is a direct child of WT
    $parent = Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.ParentProcessId)" -ErrorAction SilentlyContinue
    if ($parent -and $parent.Name -eq 'WindowsTerminal.exe') {
        $ourShellPid = $proc.ProcessId
        $wtPid = $parent.ProcessId
        break
    }
    $current = $proc.ParentProcessId
}

if (-not $wtPid) { exit 1 }

# Find our tab index by sorting WT's shell children by creation time
$shellNames = @('pwsh.exe', 'powershell.exe', 'cmd.exe', 'bash.exe', 'wsl.exe')
$tabs = Get-CimInstance Win32_Process |
    Where-Object { $_.ParentProcessId -eq $wtPid -and $_.Name -in $shellNames } |
    Sort-Object CreationDate

$tabIndex = 0
$idx = 0
foreach ($tab in $tabs) {
    if ($tab.ProcessId -eq $ourShellPid) {
        $tabIndex = $idx
        break
    }
    $idx++
}

# --- Build the launcher script (runs detached to escape PTY) ---
$paneScriptPath = Join-Path $scriptDir 'delve-pane.ps1'
$launcherContent = @"
Start-Sleep -Milliseconds 300
wt.exe --window 0 focus-tab --target $tabIndex
Start-Sleep -Milliseconds 200
wt.exe --window 0 split-pane --vertical --size 0.5 pwsh -ExecutionPolicy Bypass -NoProfile -File "$paneScriptPath" -DiffFile "$DiffFile" -StateDir "$StateDir"
"@

$launcherPath = Join-Path $StateDir 'delve-launcher.ps1'
Set-Content -Path $launcherPath -Value $launcherContent

# --- Launch detached (escapes the Copilot CLI PTY) ---
Start-Process -FilePath 'pwsh' -ArgumentList '-ExecutionPolicy', 'Bypass', '-NoProfile', '-File', $launcherPath -WindowStyle Hidden

exit 0
