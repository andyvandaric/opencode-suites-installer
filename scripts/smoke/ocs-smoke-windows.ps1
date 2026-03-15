param(
  [string]$ExaApiKey = "",
  [switch]$ProbeOAuth,
  [int]$TimeoutSeconds = 35
)

$ErrorActionPreference = "Continue"
$script:PassCount = 0
$script:FailCount = 0
$script:WarnCount = 0

function Write-Info([string]$Message) { Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Pass([string]$Message) { Write-Host "[PASS] $Message" -ForegroundColor Green }
function Write-Fail([string]$Message) { Write-Host "[FAIL] $Message" -ForegroundColor Red }
function Write-Warn([string]$Message) { Write-Host "[WARN] $Message" -ForegroundColor Yellow }

function Invoke-Check {
  param(
    [string]$Name,
    [scriptblock]$Action
  )

  try {
    & $Action | Out-Null
    if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) {
      $script:FailCount++
      Write-Fail "$Name (exit=$LASTEXITCODE)"
      return $false
    }

    $script:PassCount++
    Write-Pass $Name
    return $true
  }
  catch {
    $script:FailCount++
    Write-Fail "$Name :: $($_.Exception.Message)"
    return $false
  }
}

function Warn-Skip([string]$Message) {
  $script:WarnCount++
  Write-Warn $Message
}

function Invoke-OAuthProbe {
  param([int]$TimeoutSec)

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = "opencode"
  $psi.Arguments = 'auth login --provider google --method "OAuth with Google (Antigravity)" --print-logs'
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.CreateNoWindow = $true

  $proc = New-Object System.Diagnostics.Process
  $proc.StartInfo = $psi
  $null = $proc.Start()

  if (-not $proc.WaitForExit($TimeoutSec * 1000)) {
    try { $proc.Kill() } catch {}
  }

  $output = ($proc.StandardOutput.ReadToEnd() + "`n" + $proc.StandardError.ReadToEnd())
  if ($output -match "Antigravity OAuth|Project ID|OAuth with Google") {
    $script:PassCount++
    Write-Pass "OAuth probe returned Antigravity prompt signal"
    return $true
  }

  $script:FailCount++
  Write-Fail "OAuth probe did not show expected Antigravity prompt signal"
  if ($output.Trim().Length -gt 0) {
    Write-Host $output
  }
  return $false
}

Write-Info "Starting OCS smoke checks (windows)"

foreach ($cmd in @("bun", "ocs", "opencode")) {
  if (Get-Command $cmd -ErrorAction SilentlyContinue) {
    $script:PassCount++
    Write-Pass "command exists: $cmd"
  }
  else {
    $script:FailCount++
    Write-Fail "missing command: $cmd"
  }
}

Invoke-Check "ocs --help" { ocs --help }
Invoke-Check "ocs doctor" { ocs doctor }
Invoke-Check "ocs prefs --help" { ocs prefs --help }
Invoke-Check "ocs setup profile --help" { ocs setup profile --help }
Invoke-Check "ocs setup update --help" { ocs setup update --help }
Invoke-Check "ocs exa --help" { ocs exa --help }
Invoke-Check "ocs exa setup --help" { ocs exa setup --help }
Invoke-Check "ocs exa check --help" { ocs exa check --help }

Invoke-Check "opencode --help" { opencode --help }
Invoke-Check "opencode auth --help" { opencode auth --help }
Invoke-Check "opencode auth login --help" { opencode auth login --help }

if ($ProbeOAuth) {
  Invoke-OAuthProbe -TimeoutSec $TimeoutSeconds | Out-Null
}
else {
  Warn-Skip "OAuth probe skipped. Manual command: opencode auth login --provider google --method 'OAuth with Google (Antigravity)' --print-logs"
}

if ($ExaApiKey) {
  Invoke-Check "ocs exa setup --persist" { ocs exa setup --api-key $ExaApiKey --persist }
  Invoke-Check "ocs exa check" { ocs exa check }
}
else {
  Warn-Skip "EXA checks skipped. Use -ExaApiKey <key> to enable."
}

Write-Host ""
Write-Host "Summary: PASS=$($script:PassCount) FAIL=$($script:FailCount) WARN=$($script:WarnCount)" -ForegroundColor Cyan

if ($script:FailCount -gt 0) {
  exit 1
}

exit 0
