# Release: end the vigil for the copilot session that spawned this hook
$copilotPid = (Get-CimInstance Win32_Process -Filter "ProcessId = $PID").ParentProcessId

$vigil = Join-Path $PSScriptRoot "vigil.cs"
dotnet run $vigil -- end $copilotPid 2>&1 | Out-Null
