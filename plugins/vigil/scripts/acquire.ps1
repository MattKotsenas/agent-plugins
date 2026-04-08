# Acquire: start a vigil for the copilot session that spawned this hook
# Hook parent = copilot, so $PID's parent is the copilot PID
$copilotPid = (Get-CimInstance Win32_Process -Filter "ProcessId = $PID").ParentProcessId

$vigil = Join-Path $PSScriptRoot "vigil.cs"
Start-Process -FilePath "dotnet" -ArgumentList "run",$vigil,"--","start",$copilotPid -WindowStyle Hidden
