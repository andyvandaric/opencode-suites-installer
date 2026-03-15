param(
  [string]$ExaApiKey = "",
  [switch]$ProbeOAuth,
  [int]$TimeoutSeconds = 35
)

$scriptPath = Join-Path $PSScriptRoot "scripts/smoke/ocs-smoke-windows.ps1"
& $scriptPath -ExaApiKey $ExaApiKey -ProbeOAuth:$ProbeOAuth -TimeoutSeconds $TimeoutSeconds
exit $LASTEXITCODE
