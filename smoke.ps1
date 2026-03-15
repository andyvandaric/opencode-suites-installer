param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$scriptPath = Join-Path $PSScriptRoot "scripts/smoke/ocs-smoke-windows.ps1"
& $scriptPath @Args
exit $LASTEXITCODE
