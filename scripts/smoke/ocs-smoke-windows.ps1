param(
  [string]$ExaApiKey = "",
  [switch]$ProbeOAuth,
  [switch]$Ci,
  [switch]$RequireExa,
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

function Mark-Pass([string]$Message) {
  $script:PassCount++
  Write-Pass $Message
}

function Mark-Fail([string]$Message) {
  $script:FailCount++
  Write-Fail $Message
}

function Warn-Skip([string]$Message) {
  $script:WarnCount++
  Write-Warn $Message
}

function Invoke-Check {
  param(
    [string]$Name,
    [scriptblock]$Action
  )

  try {
    & $Action | Out-Null
    if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) {
      Mark-Fail "$Name (exit=$LASTEXITCODE)"
      return $false
    }

    Mark-Pass $Name
    return $true
  }
  catch {
    Mark-Fail "$Name :: $($_.Exception.Message)"
    return $false
  }
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
    Mark-Pass "OAuth probe returned Antigravity prompt signal"
    return $true
  }

  Mark-Fail "OAuth probe did not show expected Antigravity prompt signal"
  if ($output.Trim().Length -gt 0) {
    Write-Host $output
  }
  return $false
}

function Invoke-OAuthNonInteractiveChecks {
  try {
    $help = opencode auth login --help 2>&1 | Out-String
  }
  catch {
    Mark-Fail "OAuth non-interactive check: opencode auth login --help failed"
    return $false
  }

  if ($help -notmatch "--provider") {
    Mark-Fail "OAuth non-interactive check: missing --provider flag"
    return $false
  }

  if ($help -notmatch "--method") {
    Mark-Fail "OAuth non-interactive check: missing --method flag"
    return $false
  }

  Mark-Pass "OAuth non-interactive check: login help exposes provider/method flags"

  $configDir = if ($env:OPENCODE_CONFIG_DIR) { $env:OPENCODE_CONFIG_DIR } else { Join-Path $HOME ".config/opencode" }
  $configPath = Join-Path $configDir "opencode.json"
  if (-not (Test-Path $configPath)) {
    Mark-Fail "OAuth non-interactive check: missing config file ($configPath)"
    return $false
  }

  try {
    $json = Get-Content -Raw -Path $configPath | ConvertFrom-Json
  }
  catch {
    Mark-Fail "OAuth non-interactive check: invalid JSON in $configPath"
    return $false
  }

  if ($null -ne $json.google_auth -and $json.google_auth -eq $true) {
    Mark-Fail "OAuth non-interactive check: google_auth must be false"
    return $false
  }

  $plugins = @($json.plugin)
  $matches = @($plugins | Where-Object { $_ -is [string] -and $_.StartsWith("opencode-multi-auth") })
  if ($matches.Count -ne 1) {
    Mark-Fail "OAuth non-interactive check: opencode-multi-auth plugin count invalid ($($matches.Count))"
    return $false
  }

  if ($plugins[-1] -ne $matches[0]) {
    Mark-Fail "OAuth non-interactive check: opencode-multi-auth must be last plugin entry"
    return $false
  }

  Mark-Pass "OAuth non-interactive check: config wiring valid (google_auth + plugin order)"
  return $true
}

if ($Ci) {
  $ProbeOAuth = $false
  Write-Info "CI mode enabled: strict non-interactive checks active"
}

Write-Info "Starting OCS smoke checks (windows)"

foreach ($cmd in @("bun", "ocs", "opencode")) {
  if (Get-Command $cmd -ErrorAction SilentlyContinue) {
    Mark-Pass "command exists: $cmd"
  }
  else {
    Mark-Fail "missing command: $cmd"
  }
}

Invoke-Check "ocs --help" { ocs --help } | Out-Null
Invoke-Check "ocs doctor" { ocs doctor } | Out-Null
Invoke-Check "ocs prefs --help" { ocs prefs --help } | Out-Null
Invoke-Check "ocs setup profile --help" { ocs setup profile --help } | Out-Null
Invoke-Check "ocs setup update --help" { ocs setup update --help } | Out-Null
Invoke-Check "ocs exa --help" { ocs exa --help } | Out-Null
Invoke-Check "ocs exa setup --help" { ocs exa setup --help } | Out-Null
Invoke-Check "ocs exa check --help" { ocs exa check --help } | Out-Null

Invoke-Check "opencode --help" { opencode --help } | Out-Null
Invoke-Check "opencode auth --help" { opencode auth --help } | Out-Null
Invoke-Check "opencode auth login --help" { opencode auth login --help } | Out-Null

if ($Ci) {
  Invoke-OAuthNonInteractiveChecks | Out-Null
}
elseif ($ProbeOAuth) {
  Invoke-OAuthProbe -TimeoutSec $TimeoutSeconds | Out-Null
}
else {
  Warn-Skip "OAuth probe skipped. Manual command: opencode auth login --provider google --method 'OAuth with Google (Antigravity)' --print-logs"
}

if (-not [string]::IsNullOrWhiteSpace($ExaApiKey)) {
  Invoke-Check "ocs exa setup --persist" { ocs exa setup --api-key $ExaApiKey --persist } | Out-Null
  Invoke-Check "ocs exa check" { ocs exa check } | Out-Null
}
elseif ($RequireExa) {
  Mark-Fail "EXA checks required but no key provided (-ExaApiKey <key>)"
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
