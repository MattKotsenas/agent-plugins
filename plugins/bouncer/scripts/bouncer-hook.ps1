# Bouncer PreToolUse hook shim.
# If bouncer is on PATH, forward stdin and exit with its code.
# If bouncer is missing, allow the tool call and warn on stderr.

$ErrorActionPreference = 'Stop'

$bouncerPath = Get-Command bouncer -ErrorAction SilentlyContinue

if ($bouncerPath) {
    $input | & bouncer @args
    exit $LASTEXITCODE
} else {
    Write-Output '{"decision":"allow","reason":"bouncer not found on PATH; allowing by default"}'
    Write-Error "[bouncer] WARNING: bouncer is not installed or not on PATH. All tool calls are being allowed. Install with: dotnet tool install --global bouncer --add-source https://f.feedz.io/matt-kotsenas/bouncer/nuget/index.json"
    exit 0
}
