# toasty: Windows toast notifications for Copilot CLI.
# Fires toasty.exe when the agent finishes a turn, asks a question, or hits an error.

$ErrorActionPreference = 'SilentlyContinue'

$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }

# --- Debug logging (opt-in: create a debug.log file to enable) ---
$logDir  = Join-Path $scriptDir '..'
$logPath = Join-Path $logDir 'debug.log'
$debug   = Test-Path $logPath

function Write-Log($msg) {
    if (-not $debug) { return }
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -Path $logPath -Value "[$ts] $msg"
}

# --- Check toasty is available ---
$toasty = Get-Command toasty -ErrorAction SilentlyContinue
if (-not $toasty) {
    Write-Log 'toasty not found on PATH'
    exit 0
}

# --- Read hook input from stdin ---
$inputJson = [Console]::In.ReadToEnd()
if (-not $inputJson) { exit 0 }

Write-Log "RAW INPUT: $inputJson"

$hookInput = $inputJson | ConvertFrom-Json

# --- Only notify for the main agent, not subagents ---
# The main agent's sessionId is the CLI session GUID; a subagent's stop carries the spawning
# tool-call id instead (e.g. "toolu_...", "call_..."), which is never a GUID.
if ($hookInput.sessionId -and $hookInput.sessionId -notmatch '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$') {
    Write-Log "SKIP: subagent event (sessionId=$($hookInput.sessionId))"
    exit 0
}

# --- Determine event type from payload ---
# agentStop:      { timestamp, cwd, sessionId, transcriptPath, stopReason }
# errorOccurred:  { timestamp, cwd, error: { message, name, stack } }
# preToolUse:     { timestamp, cwd, sessionId, toolName, toolArgs }
$message = $null
$title   = $null
$key     = $null

if ($hookInput.PSObject.Properties['error']) {
    $errMsg = $hookInput.error.message
    $message = if ($errMsg) { "Copilot hit an error: $errMsg" } else { 'Copilot hit an error' }
    $title   = 'Error'
    $key     = 'error'
} elseif ($hookInput.PSObject.Properties['toolName']) {
    # preToolUse hook - only notify for ask_user, ignore all other tools
    if ($hookInput.toolName -ne 'ask_user') { exit 0 }
    $message = 'Copilot has a question'
    $title   = 'Input Requested'
    $key     = 'ask_user'
} elseif ($hookInput.PSObject.Properties['stopReason']) {
    $message = 'Copilot is waiting for you'
    $title   = 'Copilot'
    $key     = 'agentStop'
} else {
    exit 0
}

Write-Log "EVENT: $key"

# --- Debounce (per-type, 10s cooldown via per-key state files) ---
$statePath = Join-Path $scriptDir ".toasty-lastnotify-$key"
$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

if (Test-Path $statePath) {
    $last = 0
    try { $last = [long](Get-Content $statePath -Raw).Trim() } catch {}
    if (($now - $last) -lt 10) {
        Write-Log "DEBOUNCE: skipped ($key last=$last now=$now)"
        exit 0
    }
}

$now.ToString() | Set-Content $statePath -Encoding UTF8

# --- Suppress if the user is already looking at this terminal ---
# In tmux: suppress only if our pane is active AND the terminal window is focused.
# Outside tmux: suppress if any terminal window is focused.
# If focus detection fails, show the toast anyway.
try {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class ToastyWin32 {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
}
"@
    $hwnd = [ToastyWin32]::GetForegroundWindow()
    [uint32]$fgPid = 0
    [void][ToastyWin32]::GetWindowThreadProcessId($hwnd, [ref]$fgPid)
    $fgProc = Get-Process -Id $fgPid -ErrorAction SilentlyContinue
    $terminals = @('WindowsTerminal', 'WindowsTerminalPreview', 'WindowsTerminalCanary', 'conhost')
    $terminalFocused = $fgProc -and $fgProc.ProcessName -in $terminals

    if ($env:TMUX_PANE) {
        # Inside tmux: suppress only when our pane is active AND terminal is focused
        $paneActive = tmux display-message -p '#{pane_active}' 2>$null
        if ($terminalFocused -and $paneActive -eq '1') {
            Write-Log "SUPPRESSED: tmux pane active + terminal focused"
            exit 0
        }
    } elseif ($terminalFocused) {
        Write-Log "SUPPRESSED: terminal has focus ($($fgProc.ProcessName))"
        exit 0
    }
} catch {
    # If focus detection fails, show the toast anyway
}

Write-Log "TOASTING: $message ($title)"

# --- Fire toasty ---
& toasty $message -t $title --app copilot

exit 0
