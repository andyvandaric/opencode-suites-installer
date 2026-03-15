param(
  [string]$ExaApiKey = "",
  [switch]$RequireExa,
  [int]$TimeoutSeconds = 35
)

$scriptPath = Join-Path $PSScriptRoot "scripts/smoke/ocs-smoke-ci-windows.ps1"
& $scriptPath -ExaApiKey $ExaApiKey -RequireExa:$RequireExa -TimeoutSeconds $TimeoutSeconds
exit $LASTEXITCODE
