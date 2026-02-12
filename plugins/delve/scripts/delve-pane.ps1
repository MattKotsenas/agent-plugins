<#
.SYNOPSIS
    Runs inside a Windows Terminal split pane to display a diff file.
    Called by delve-show-chunk.ps1 — not intended to be called directly.

.PARAMETER DiffFile
    Path to the .diff file to display.

.PARAMETER StateDir
    Directory for pane state files (pane.pid, pane.close).
#>
param(
    [Parameter(Mandatory)][string]$DiffFile,
    [Parameter(Mandatory)][string]$StateDir
)

$ErrorActionPreference = 'Stop'

$pidFile = Join-Path $StateDir 'pane.pid'
$signalFile = Join-Path $StateDir 'pane.close'

$PID | Set-Content $pidFile
Remove-Item $signalFile -ErrorAction SilentlyContinue

# Detect the user's git pager (delta, diff-so-fancy, etc.)
$pager = git config core.pager 2>$null
if (-not $pager) { $pager = $env:PAGER }

if ($pager -and (Get-Command ($pager -split ' ')[0] -ErrorAction SilentlyContinue)) {
    Get-Content $DiffFile -Raw | & ($pager -split ' ')[0] --paging=never 2>$null
    if ($LASTEXITCODE -ne 0) {
        # Pager didn't accept --paging=never, try without
        Get-Content $DiffFile -Raw | & ($pager -split ' ')[0] 2>$null
    }
} else {
    Get-Content $DiffFile
}

Write-Host ''
Write-Host 'Press Q to close this pane...' -ForegroundColor DarkGray

while ($true) {
    if (Test-Path $signalFile) {
        Remove-Item $signalFile -ErrorAction SilentlyContinue
        break
    }
    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq 'Q') { break }
    }
    Start-Sleep -Milliseconds 100
}

Remove-Item $pidFile -ErrorAction SilentlyContinue
exit 0
