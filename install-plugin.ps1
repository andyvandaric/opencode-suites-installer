# install-plugin.ps1 - Install opencode-multi-auth plugin for OpenCode Config Suites
# Auth path: GitHub CLI web login only (https protocol)

#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Config ---
$GITHUB_RELEASES_REPO = "andyvandaric/opencode-config-suites-releases"
$ACCESS_LANDING_PAGE = "https://ocs.flowcrate.app/checkout"
$PLUGIN_DIR = ".\plugins\opencode-multi-auth"
$TOKEN_FILE = "$env:USERPROFILE\.opencode-suites\.token"
$TMP_DIR = [System.IO.Path]::Combine(
    [System.IO.Path]::GetTempPath(),
    "ocs-install-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
)

function Resolve-PwshPath {
    $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwshCmd -and $pwshCmd.Path) {
        return $pwshCmd.Path
    }

    $candidates = @(
        (Join-Path $env:ProgramFiles "PowerShell\7\pwsh.exe"),
        (Join-Path $env:LOCALAPPDATA "Microsoft\PowerShell\7\pwsh.exe"),
        (Join-Path $env:USERPROFILE "scoop\shims\pwsh.exe")
    )

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) {
            return $candidate
        }
    }

    return $null
}

function Invoke-PwshRelaunch {
    param([string]$PwshPath)

    if (-not $PwshPath) {
        return $false
    }

    if ($env:OCS_PWSH_RELAUNCHED -eq "1") {
        return $false
    }

    Write-Output "Relaunching installer in PowerShell 7 for better compatibility..."
    $env:OCS_PWSH_RELAUNCHED = "1"

    $scriptPath = $PSCommandPath
    $exitCode = 0

    if ($scriptPath -and (Test-Path $scriptPath)) {
        & $PwshPath -NoProfile -ExecutionPolicy Bypass -File $scriptPath
        if ($LASTEXITCODE -ne $null) {
            $exitCode = $LASTEXITCODE
        }
        exit $exitCode
    }

    $relaunchUrl = "https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/main/install-plugin.ps1"
    $relaunchCommand = '$env:OCS_PWSH_RELAUNCHED=''1''; irm ''' + $relaunchUrl + ''' | iex'
    & $PwshPath -NoProfile -ExecutionPolicy Bypass -Command $relaunchCommand
    if ($LASTEXITCODE -ne $null) {
        $exitCode = $LASTEXITCODE
    }
    exit $exitCode
}

function Ensure-PowerShellRuntime {
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -ge 7) {
        Write-Output "PowerShell $($psVersion.ToString()) detected"
        return
    }

    Write-Warning "Running on Windows PowerShell $($psVersion.ToString()). PowerShell 7+ is recommended."

    $pwshPath = Resolve-PwshPath
    if ($pwshPath) {
        Write-Output "PowerShell 7 is already installed."
        Invoke-PwshRelaunch -PwshPath $pwshPath
        Write-Output "Continuing in current shell."
        return
    }

    $installed = $false

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Output "Attempting PowerShell 7 install via winget..."
        try {
            & winget install --id Microsoft.PowerShell --source winget --accept-package-agreements --accept-source-agreements --silent
            if ($LASTEXITCODE -eq 0) { $installed = $true }
        } catch {
            $installed = $false
        }
    }

    if ((-not $installed) -and (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Output "Attempting PowerShell 7 install via Chocolatey..."
        try {
            & choco install powershell-core -y
            if ($LASTEXITCODE -eq 0) { $installed = $true }
        } catch {
            $installed = $false
        }
    }

    if ((-not $installed) -and (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Output "Attempting PowerShell 7 install via Scoop..."
        try {
            & scoop install pwsh
            if ($LASTEXITCODE -eq 0) { $installed = $true }
        } catch {
            $installed = $false
        }
    }

    $pwshPath = Resolve-PwshPath
    if ($pwshPath) {
        Write-Output "PowerShell 7 detected after installation attempt."
        Invoke-PwshRelaunch -PwshPath $pwshPath
        Write-Output "Continuing in current shell."
    } else {
        Write-Warning "PowerShell 7 installation was skipped or failed. Continuing with current shell."
    }
}

function Resolve-Token {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Error "GitHub CLI (gh) is required. Install from https://cli.github.com/ then rerun installer."
        exit 1
    }

    gh auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Output "GitHub CLI not authenticated. Opening browser login..."
        & gh auth login --hostname github.com --git-protocol https --web
        if ($LASTEXITCODE -ne 0) {
            Write-Error "GitHub CLI login failed. Please run 'gh auth login --hostname github.com --git-protocol https --web' and retry."
            exit 1
        }
    }

    $ghToken = gh auth token 2>&1
    if ($LASTEXITCODE -eq 0 -and $ghToken) {
        Write-Host "Auth: using gh CLI token"
        return $ghToken.Trim()
    }

    Write-Error "Unable to obtain token from GitHub CLI. Run 'gh auth status' to troubleshoot, then retry."
    exit 1
}

function Open-LandingPage {
    Write-Output "Open purchase page: $ACCESS_LANDING_PAGE"
    try {
        Start-Process $ACCESS_LANDING_PAGE | Out-Null
    } catch {
        Write-Warning "Could not open browser automatically. Visit: $ACCESS_LANDING_PAGE"
    }
}

function Test-RepoAccess {
    param([string]$Token)

    $headers = @{
        Authorization = "token $Token"
        Accept        = "application/vnd.github+json"
    }

    try {
        $response = Invoke-WebRequest -Uri "https://api.github.com/repos/$GITHUB_RELEASES_REPO/releases/latest" -Headers $headers -UseBasicParsing -ErrorAction Stop
        Write-Output "Repo access verified (HTTP $($response.StatusCode))"
    } catch {
        $code = 0
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
            $code = $_.Exception.Response.StatusCode.value__
        }

        if ($code -in @(401, 403, 404)) {
            Write-Error "GitHub login succeeded, but your account does not have access to $GITHUB_RELEASES_REPO (HTTP $code)."
            Write-Output "Please buy/activate access first, then rerun installer."
            Open-LandingPage
            exit 1
        }

        Write-Error "Cannot access repo $GITHUB_RELEASES_REPO (HTTP $code). Check network and GitHub auth state."
        exit 1
    }
}

function Get-ReleaseInfo {
    param([string]$Token)

    $headers = @{
        Authorization = "token $Token"
        Accept        = "application/vnd.github+json"
    }

    return Invoke-RestMethod -Uri "https://api.github.com/repos/$GITHUB_RELEASES_REPO/releases/latest" -Headers $headers -ErrorAction Stop
}

function Get-Asset {
    param([string]$Token, [string]$Url, [string]$OutPath)

    $headers = @{
        Authorization = "token $Token"
        Accept        = "application/octet-stream"
    }

    Invoke-WebRequest -Uri $Url -Headers $headers -OutFile $OutPath -UseBasicParsing -ErrorAction Stop
}

function Test-SHA256Sums {
    param([string]$SumsFile, [string]$TargetDir)

    Write-Output "Verifying SHA256SUMS..."
    $lines = Get-Content $SumsFile -Encoding UTF8
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if (-not $trimmed) { continue }

        $parts = $trimmed -split "  ", 2
        if ($parts.Count -ne 2) { continue }

        $expectedHash = $parts[0].Trim()
        $relativePath = $parts[1].Trim()
        $fullPath = Join-Path $TargetDir $relativePath
        if (-not (Test-Path $fullPath)) { continue }

        $actualHash = (Get-FileHash -Path $fullPath -Algorithm SHA256).Hash.ToLower()
        if ($actualHash -ne $expectedHash.ToLower()) {
            Write-Error "Checksum mismatch for $relativePath"
            exit 1
        }
    }

    Write-Output "Checksum verification passed"
}

function Ensure-Bun {
    $bunCmd = Get-Command bun -ErrorAction SilentlyContinue
    if ($bunCmd) {
        $bunVersion = bun --version
        $bunMajor = [int]($bunVersion -split "\.")[0]
        if ($bunMajor -ge 1) {
            Write-Output "Bun $bunVersion detected"
            return
        }
        Write-Warning "Bun version $bunVersion is too old. Attempting upgrade..."
    } else {
        Write-Warning "Bun not found. Attempting auto install..."
    }

    try {
        if (-not (Test-Path $TMP_DIR)) {
            New-Item -ItemType Directory -Force $TMP_DIR | Out-Null
        }

        $bunInstallerPath = Join-Path $TMP_DIR "bun-install.ps1"
        Invoke-WebRequest -Uri "https://bun.sh/install.ps1" -UseBasicParsing -OutFile $bunInstallerPath -ErrorAction Stop

        if (Get-Command pwsh -ErrorAction SilentlyContinue) {
            & pwsh -NoProfile -ExecutionPolicy Bypass -File $bunInstallerPath
        } else {
            & powershell -NoProfile -ExecutionPolicy Bypass -File $bunInstallerPath
        }

        if ($LASTEXITCODE -ne 0) {
            throw "Bun installer exited with code $LASTEXITCODE"
        }
    } catch {
        Write-Error "Failed to auto-install Bun: $($_.Exception.Message)"
        Write-Error "Install Bun manually at https://bun.sh and retry."
        exit 1
    }

    $bunBin = Join-Path $env:USERPROFILE ".bun\bin"
    if ((Test-Path $bunBin) -and (-not (($env:PATH -split ";") -contains $bunBin))) {
        $env:PATH = "$bunBin;$env:PATH"
    }

    if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
        Write-Error "Bun installed but bun command is still unavailable. Restart terminal and retry."
        exit 1
    }

    $installedVersion = bun --version
    $installedMajor = [int]($installedVersion -split "\.")[0]
    if ($installedMajor -lt 1) {
        Write-Error "Bun >= 1.0.0 required (found $installedVersion)."
        exit 1
    }

    Write-Output "Bun $installedVersion detected"
}

function Invoke-AutoSetup {
    param([bool]$IsLocalSource)

    if ($env:OCS_SKIP_AUTO_SETUP -eq "1") {
        Write-Warning "Skipping auto setup because OCS_SKIP_AUTO_SETUP=1"
        return
    }

    $setupScript = if ($IsLocalSource) { ".\scripts\setup.js" } else { "$PLUGIN_DIR\scripts\setup.js" }
    if (-not (Test-Path $setupScript)) {
        Write-Warning "Setup script not found at $setupScript. Skipping auto setup."
        return
    }

    Write-Output ""
    Write-Output "Running auto setup (headless)..."

    $headlessSucceeded = $true
    try {
        & bun $setupScript "--headless" "--profile" "codex-5.3-all" "--mode" "balanced"
    } catch {
        $headlessSucceeded = $false
    }

    if (($LASTEXITCODE -ne 0) -or (-not $headlessSucceeded)) {
        Write-Warning "Headless setup failed. Falling back to interactive setup..."
        try {
            & bun $setupScript
        } catch {
            Write-Error "Auto setup failed: $($_.Exception.Message)"
            Write-Error "Run setup manually: bun $setupScript"
            exit 1
        }

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Interactive setup failed. Run manually: bun $setupScript"
            exit 1
        }
    }

    Write-Output "Auto setup completed."
}

Write-Output ""
Write-Output "opencode-multi-auth - Plugin Installer"
Write-Output "--------------------------------------"

Ensure-PowerShellRuntime
Ensure-Bun

$isLocalSource = (Test-Path ".\plugins\opencode-multi-auth\package.json") -or (Test-Path ".\package.json")
$version = "local-source"

if ($isLocalSource) {
    Write-Output "Detected local plugin source. Skipping download."
    if (-not (Test-Path $PLUGIN_DIR)) {
        Write-Error "Plugin directory $PLUGIN_DIR not found in local workspace."
        exit 1
    }

    $localPkgPath = Join-Path $PLUGIN_DIR "package.json"
    if (Test-Path $localPkgPath) {
        try {
            $localPkg = Get-Content $localPkgPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($localPkg.version) { $version = $localPkg.version }
        } catch {
            # keep fallback label
        }
    }
} else {
    Write-Output ""
    Write-Output "Resolving GitHub auth..."
    $token = Resolve-Token

    Write-Output ""
    Write-Output "Verifying repo access..."
    Test-RepoAccess -Token $token

    Write-Output ""
    Write-Output "Fetching latest release..."
    $release = Get-ReleaseInfo -Token $token
    $version = $release.tag_name
    Write-Output "Latest version: $version"

    $tarAsset = $release.assets | Where-Object { $_.name -like "*.tar.gz" } | Select-Object -First 1
    if (-not $tarAsset) {
        Write-Error "No .tar.gz asset found in latest release."
        exit 1
    }

    if (-not (Test-Path $TMP_DIR)) {
        New-Item -ItemType Directory -Force $TMP_DIR | Out-Null
    }
    $tarPath = Join-Path $TMP_DIR $tarAsset.name

    Write-Output ""
    Write-Output "Downloading $($tarAsset.name)..."
    Get-Asset -Token $token -Url $tarAsset.url -OutPath $tarPath

    $sumsAsset = $release.assets | Where-Object { $_.name -eq "SHA256SUMS" } | Select-Object -First 1
    $tarName = Split-Path -Leaf $tarPath

    if ($sumsAsset) {
        $sumsPath = Join-Path $TMP_DIR "SHA256SUMS"
        Get-Asset -Token $token -Url $sumsAsset.url -OutPath $sumsPath

        $verifyDir = Join-Path $TMP_DIR "verify"
        New-Item -ItemType Directory -Force $verifyDir | Out-Null
        Push-Location $TMP_DIR
        try {
            tar --force-local -xzf $tarName -C "./verify" --strip-components=1
        } finally {
            Pop-Location
        }
        Copy-Item $sumsPath (Join-Path $verifyDir "SHA256SUMS")
        Test-SHA256Sums -SumsFile (Join-Path $verifyDir "SHA256SUMS") -TargetDir $verifyDir
    } else {
        Write-Warning "SHA256SUMS not found in release - skipping checksum verification"
    }

    Write-Output ""
    Write-Output "Extracting to $PLUGIN_DIR..."
    if (-not (Test-Path $PLUGIN_DIR)) {
        New-Item -ItemType Directory -Force $PLUGIN_DIR | Out-Null
    }

    $extractTmp = Join-Path $TMP_DIR "extract"
    New-Item -ItemType Directory -Force $extractTmp | Out-Null
    Push-Location $TMP_DIR
    try {
        tar --force-local -xzf $tarName -C "./extract" --strip-components=1
    } finally {
        Pop-Location
    }

    Copy-Item -Path "$extractTmp\*" -Destination $PLUGIN_DIR -Recurse -Force
}

Write-Output "opencode-multi-auth installed to $PLUGIN_DIR"
Write-Output "Installing dependencies..."
Push-Location $PLUGIN_DIR
try {
    $frozenSucceeded = $true
    try {
        bun install --frozen-lockfile *> $null
    } catch {
        $frozenSucceeded = $false
    }

    if ((-not $frozenSucceeded) -or ($LASTEXITCODE -ne 0)) {
        Write-Output "Retrying bun install without frozen lockfile..."
        bun install
    }
} finally {
    Pop-Location
}

Invoke-AutoSetup -IsLocalSource:$isLocalSource

if (Test-Path $TMP_DIR) {
    Remove-Item -Recurse -Force $TMP_DIR -ErrorAction SilentlyContinue
}

Write-Output ""
Write-Output "opencode-multi-auth $version installed to $PLUGIN_DIR"
Write-Output ""
Write-Output "   Next steps:"
if ($isLocalSource) {
    Write-Output "   1. Run setup (interactive): bun ./scripts/setup.js"
} else {
    Write-Output "   1. Run setup (interactive): bun $PLUGIN_DIR/scripts/setup.js"
}
Write-Output "   2. Verify runtime: opencode auth login"
Write-Output ""
