param(
  [string]$ExaApiKey = "",
  [switch]$RequireExa,
  [int]$TimeoutSeconds = 35
)

$scriptPath = Join-Path $PSScriptRoot "ocs-smoke-windows.ps1"
& $scriptPath -Ci -ExaApiKey $ExaApiKey -RequireExa:$RequireExa -TimeoutSeconds $TimeoutSeconds
exit $LASTEXITCODE
