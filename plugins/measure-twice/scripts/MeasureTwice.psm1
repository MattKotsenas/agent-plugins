#requires -Version 5.1
<#
Gate logic for measure-twice, in small functions each easy to test on its own.
The home config lives under <COPILOT_HOME>/measure-twice; each session's on/off
and per-turn gate state live in that session's own folder.
#>

$script:DefaultPrompt = 'A review gate is active. If this turn produced anything you are presenting to the user - code, a document, a PR description, a review comment - run your review agents now and address any Critical or High findings before finishing. If this turn was pure investigation with nothing to hand over, just proceed.'

function Get-MTCopilotHome {
    if ($env:COPILOT_HOME) { $env:COPILOT_HOME } else { Join-Path $env:USERPROFILE '.copilot' }
}

function Get-MTConfigPath {
    Join-Path (Join-Path (Get-MTCopilotHome) 'measure-twice') 'config.json'
}

function Get-MTSessionDir {
    # Control commands have no hook payload, so they locate the session folder via
    # COPILOT_AGENT_SESSION_ID. Returns $null when it is unset; the caller must
    # then refuse rather than change global behavior. Hook mode uses the transcript
    # path directly, so it never needs this fallback.
    if ($env:COPILOT_AGENT_SESSION_ID) {
        return Join-Path (Join-Path (Get-MTCopilotHome) 'session-state') $env:COPILOT_AGENT_SESSION_ID
    }
    $null
}

function Get-MTConfig {
    # Home config: the review prompt and the default on/off for new sessions. An
    # unreadable or corrupt file falls back to defaults rather than a null config.
    param([string]$ConfigPath)
    $config = [PSCustomObject]@{ defaultMode = 'on'; prompt = $script:DefaultPrompt }
    if (Test-Path $ConfigPath) {
        try {
            $loaded = Get-Content $ConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            if ($loaded) { $config = $loaded }
        } catch { }
    }
    if (-not $config.PSObject.Properties['defaultMode']) { $config | Add-Member -NotePropertyName defaultMode -NotePropertyValue 'on' -Force }
    if (-not $config.PSObject.Properties['prompt']) { $config | Add-Member -NotePropertyName prompt -NotePropertyValue $script:DefaultPrompt -Force }
    $config
}

function Save-MTConfig {
    # Write in place so a symlinked config.json (managed from dotfiles) keeps its
    # link; never remove-and-recreate, which would swap the link for a plain file.
    # Throws on failure so a control command never reports a save that did not happen.
    param($Config, [string]$ConfigPath)
    New-Item -ItemType Directory -Force -Path (Split-Path $ConfigPath -Parent) -ErrorAction Stop | Out-Null
    $Config | ConvertTo-Json -Depth 5 | Set-Content -Path $ConfigPath -Encoding UTF8 -ErrorAction Stop
}

function Get-MTSessionMode {
    # This session's effective on/off: the session override if set, else the home
    # default. An override file that exists but is unreadable or holds an invalid
    # value fails closed to 'on' - better to over-gate than to silently skip a
    # session someone configured on purpose. $SessionDir may be $null.
    param([string]$SessionDir, [string]$DefaultMode)
    if ($SessionDir) {
        $path = Join-Path $SessionDir 'measure-twice-mode.json'
        if (Test-Path $path) {
            try { $mode = [string](Get-Content $path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop).mode } catch { return 'on' }
            if ($mode -eq 'on' -or $mode -eq 'off') { return $mode }
            return 'on'
        }
    }
    $DefaultMode
}

function Set-MTSessionMode {
    # Throws on failure so -enable / -disable never claim a change that did not persist.
    param([string]$SessionDir, [string]$Mode)
    New-Item -ItemType Directory -Force -Path $SessionDir -ErrorAction Stop | Out-Null
    [PSCustomObject]@{ mode = $Mode } | ConvertTo-Json | Set-Content -Path (Join-Path $SessionDir 'measure-twice-mode.json') -Encoding UTF8 -ErrorAction Stop
}

function Get-MTStatePath {
    param([string]$SessionDir)
    Join-Path $SessionDir 'measure-twice-state.json'
}

function Get-MTLastAssistantMessage {
    param([string]$TranscriptPath)
    if (-not ($TranscriptPath -and (Test-Path $TranscriptPath))) { return '' }
    $lines = Get-Content $TranscriptPath
    for ($i = $lines.Length - 1; $i -ge 0; $i--) {
        if ($lines[$i] -notmatch 'assistant\.message') { continue }
        try { $evt = $lines[$i] | ConvertFrom-Json } catch { continue }
        if ($evt.type -eq 'assistant.message') { return [string]$evt.data.content }
    }
    ''
}

function Invoke-MTGate {
    <#
    The state machine. Returns a block-reason string to block the stop, or $null
    to let the turn finish. A random per-turn token guards against loops; a block
    cap is the safety valve.
    #>
    param($Config, [string]$TranscriptPath, [string]$StatePath, [int]$MaxBlocks = 3)

    $assistantText = Get-MTLastAssistantMessage -TranscriptPath $TranscriptPath

    $nonce = ''
    $count = 0
    if (Test-Path $StatePath) {
        try { $state = Get-Content $StatePath -Raw | ConvertFrom-Json } catch { $state = $null }
        if ($state -and ([string]$state.nonce -match '^MT\d{7}$')) {
            $nonce = [string]$state.nonce
            $count = [int]$state.count
        }
    }

    if ($nonce) {
        if ($assistantText -match [regex]::Escape($nonce)) { Remove-Item $StatePath -Force; return $null }  # uttered: reviewed
        if ($count -ge $MaxBlocks)                          { Remove-Item $StatePath -Force; return $null }  # safety valve
        $count++
    } else {
        $nonce = 'MT' + (Get-Random -Minimum 1000000 -Maximum 9999999)
        $count = 1
    }

    New-Item -ItemType Directory -Force -Path (Split-Path $StatePath -Parent) | Out-Null
    [PSCustomObject]@{ nonce = $nonce; count = $count } | ConvertTo-Json | Set-Content -Path $StatePath -Encoding UTF8

    # Split the token with a space so the prompt never contains it verbatim; the
    # agent must rejoin it to satisfy the gate.
    $mid = [Math]::Floor($nonce.Length / 2)
    $split = $nonce.Substring(0, $mid) + ' ' + $nonce.Substring($mid)
    "$($Config.prompt)`n`nWhen you are done, output this token on its own line with the internal space removed, then stop: $split"
}

Export-ModuleMember -Function Get-MTCopilotHome, Get-MTConfigPath, Get-MTSessionDir, Get-MTConfig, Save-MTConfig, Get-MTSessionMode, Set-MTSessionMode, Get-MTStatePath, Get-MTLastAssistantMessage, Invoke-MTGate
