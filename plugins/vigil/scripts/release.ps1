# Release: end the vigil for the copilot session that spawned this hook
# Inlined to avoid DLL locking with the running vigil start process
$copilotPid = (Get-CimInstance Win32_Process -Filter "ProcessId = $PID").ParentProcessId

$pidFile = Join-Path ([System.IO.Path]::GetTempPath()) "vigil" "$copilotPid.pid"
if (Test-Path $pidFile) {
    $vigilPid = [int](Get-Content $pidFile).Trim()
    try { Stop-Process -Id $vigilPid -Force -ErrorAction SilentlyContinue } catch { }
    Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
}
