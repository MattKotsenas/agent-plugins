# Warmup: pre-build vigil.cs so subsequent dotnet run calls skip compilation
$vigil = Join-Path $PSScriptRoot "vigil.cs"
dotnet build $vigil 2>&1 | Out-Null
