# install-plugin.ps1 - Install opencode-multi-auth plugin for OpenCode Config Suites
# Supports 3 auth paths: gh CLI -> GITHUB_TOKEN env -> interactive prompt

#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Config ---
$GITHUB_RELEASES_REPO = 'andyvandaric/opencode-config-suites-releases'
$PLUGIN_DIR = '.\plugins\opencode-multi-auth'
$TOKEN_FILE = "$env:USERPROFILE\.opencode-suites\.token"
$TMP_DIR = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "ocs-install-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))")

# --- Auth: resolve GitHub token ---
function Resolve-Token {
    # Path 1: gh CLI
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        gh auth status 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning 'GitHub CLI (gh) is installed but not authenticated.'
            Write-Host 'Logging in via GitHub CLI (browser flow)...'
            gh auth login --git-protocol https -w
        }

        $ghToken = gh auth token 2>&1
        if ($LASTEXITCODE -eq 0 -and $ghToken) {
            Write-Host 'Auth: using gh CLI token'
            return $ghToken.Trim()
        }
    } else {
        Write-Warning 'GitHub CLI (gh) is not installed. It is highly recommended for managing access.'
        Write-Warning 'Please install it from https://cli.github.com/ or provide a token manually.'
    }
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        $ghStatus = gh auth status 2>&1
        if ($LASTEXITCODE -eq 0) {
            $ghToken = gh auth token 2>&1
            if ($LASTEXITCODE -eq 0 -and $ghToken) {
                Write-Host 'Auth: using gh CLI token'
                return $ghToken.Trim()
            }
        }
    }

    # Path 2: GITHUB_TOKEN env var
    if ($env:GITHUB_TOKEN) {
        Write-Host 'Auth: using GITHUB_TOKEN environment variable'
        return $env:GITHUB_TOKEN
    }

    # Path 3: stored token file
    if (Test-Path $TOKEN_FILE) {
        $stored = Get-Content $TOKEN_FILE -Raw -Encoding UTF8
        $stored = $stored.Trim()
        if ($stored) {
            Write-Host "Auth: using stored token from $TOKEN_FILE"
            return $stored
        }
    }

    # Path 3b: interactive prompt
    Write-Warning 'No GitHub token found. Generate one at:'
    Write-Warning 'https://github.com/settings/tokens/new?scopes=repo'
    Write-Host ''
    $secureToken = Read-Host 'GitHub Personal Access Token (repo scope)' -AsSecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
    $token = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

    if (-not $token) {
        Write-Error 'No token provided. Cannot continue.'
        exit 1
    }

    # Save for future use
    $tokenDir = Split-Path $TOKEN_FILE -Parent
    if (-not (Test-Path $tokenDir)) {
        New-Item -ItemType Directory -Force $tokenDir | Out-Null
    }
    Set-Content -Path $TOKEN_FILE -Value $token -Encoding UTF8
    Write-Host "Token saved to $TOKEN_FILE"
    return $token
}

# --- Verify repo access ---
function Test-RepoAccess {
    param([string]$Token)

    $headers = @{
        Authorization = "token $Token"
        Accept        = 'application/vnd.github+json'
    }

    try {
        $response = Invoke-WebRequest `
            -Uri "https://api.github.com/repos/$GITHUB_RELEASES_REPO/releases/latest" `
            -Headers $headers `
            -UseBasicParsing `
            -ErrorAction Stop
        Write-Output "Repo access verified (HTTP $($response.StatusCode))"
    } catch {
        $code = $_.Exception.Response.StatusCode.value__
        Write-Error "Cannot access repo $GITHUB_RELEASES_REPO (HTTP $code). Check token scopes or repo access."
        exit 1
    }
}

# --- Get latest release info ---
function Get-ReleaseInfo {
    param([string]$Token)

    $headers = @{
        Authorization = "token $Token"
        Accept        = 'application/vnd.github+json'
    }

    $response = Invoke-RestMethod `
        -Uri "https://api.github.com/repos/$GITHUB_RELEASES_REPO/releases/latest" `
        -Headers $headers `
        -ErrorAction Stop

    return $response
}

# --- Download asset ---
function Get-Asset {
    param([string]$Token, [string]$Url, [string]$OutPath)

    $headers = @{
        Authorization = "token $Token"
        Accept        = 'application/octet-stream'
    }

    Invoke-WebRequest `
        -Uri $Url `
        -Headers $headers `
        -OutFile $OutPath `
        -UseBasicParsing `
        -ErrorAction Stop
}

# --- Verify SHA256 ---
function Test-SHA256Sums {
    param([string]$SumsFile, [string]$TargetDir)

    Write-Output 'Verifying SHA256SUMS...'
    $lines = Get-Content $SumsFile -Encoding UTF8

    foreach ($line in $lines) {
        $line = $line.Trim()
        if (-not $line) { continue }

        # Format: <hash>  <relative-path> (double-space separator)
        $parts = $line -split '  ', 2
        if ($parts.Count -ne 2) { continue }

        $expectedHash = $parts[0].Trim()
        $relativePath = $parts[1].Trim()
        $fullPath = Join-Path $TargetDir $relativePath

        if (-not (Test-Path $fullPath)) { continue }

        $actualHash = (Get-FileHash -Path $fullPath -Algorithm SHA256).Hash.ToLower()
        if ($actualHash -ne $expectedHash.ToLower()) {
            Write-Error "Checksum mismatch for $relativePath`nExpected: $expectedHash`nActual:   $actualHash"
            exit 1
        }
    }

    Write-Output 'Checksum verification passed'
}

# --- Main Logic ---
Write-Output ''
Write-Output 'opencode-multi-auth - Plugin Installer'
Write-Output '--------------------------------------'

# Bun version check
if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
    Write-Error 'Bun not found. Install at https://bun.sh'
    exit 1
}
$bunVersion = bun --version
$bunMajor = [int]($bunVersion -split '\.')[0]
if ($bunMajor -lt 1) {
    Write-Error "Bun >= 1.0.0 required (found $bunVersion). Install at https://bun.sh"
    exit 1
}
Write-Output "Bun $bunVersion detected"
# Check if we are running in the repo locally
$isLocalSource = (Test-Path '.\plugins\opencode-multi-auth\package.json') -or (Test-Path '.\package.json')
$version = 'local-source'

if ($isLocalSource) {
    Write-Output 'Detected local plugin source. Skipping download.'
    if (-not (Test-Path $PLUGIN_DIR)) {
        Write-Error "Plugin directory $PLUGIN_DIR not found in local workspace."
        exit 1
    }

    $localPkgPath = Join-Path $PLUGIN_DIR 'package.json'
    if (Test-Path $localPkgPath) {
        try {
            $localPkg = Get-Content $localPkgPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($localPkg.version) {
                $version = $localPkg.version
            }
        } catch {
            # Keep fallback local-source version label
        }
    }
} else {
    Write-Output ''
    Write-Output 'Resolving GitHub auth...'
    $token = Resolve-Token

    Write-Output ''
    Write-Output 'Verifying repo access...'
    Test-RepoAccess -Token $token

    Write-Output ''
    Write-Output 'Fetching latest release...'
    $release = Get-ReleaseInfo -Token $token
    $version = $release.tag_name
    Write-Output "Latest version: $version"

    # Find tar.gz asset
    $tarAsset = $release.assets | Where-Object { $_.name -like '*.tar.gz' } | Select-Object -First 1
    if (-not $tarAsset) {
        Write-Error 'No .tar.gz asset found in latest release.'
        exit 1
    }

    if (-not (Test-Path $TMP_DIR)) {
        New-Item -ItemType Directory -Force $TMP_DIR | Out-Null
    }
    $tarPath = Join-Path $TMP_DIR $tarAsset.name

    Write-Output ''
    Write-Output "Downloading $($tarAsset.name)..."
    Get-Asset -Token $token -Url $tarAsset.url -OutPath $tarPath

    # Download and verify SHA256SUMS
    $sumsAsset = $release.assets | Where-Object { $_.name -eq 'SHA256SUMS' } | Select-Object -First 1
    $tarName = Split-Path -Leaf $tarPath

    if ($sumsAsset) {
        $sumsPath = Join-Path $TMP_DIR 'SHA256SUMS'
        Get-Asset -Token $token -Url $sumsAsset.url -OutPath $sumsPath

        # Extract for verification
        $verifyDir = Join-Path $TMP_DIR 'verify'
        New-Item -ItemType Directory -Force $verifyDir | Out-Null
        Push-Location $TMP_DIR
        try {
            tar --force-local -xzf $tarName -C './verify' --strip-components=1
        } finally {
            Pop-Location
        }
        Copy-Item $sumsPath (Join-Path $verifyDir 'SHA256SUMS')
        Test-SHA256Sums -SumsFile (Join-Path $verifyDir 'SHA256SUMS') -TargetDir $verifyDir
    } else {
        Write-Warning 'SHA256SUMS not found in release - skipping checksum verification'
    }

    Write-Output ''
    Write-Output "Extracting to $PLUGIN_DIR..."
    if (-not (Test-Path $PLUGIN_DIR)) {
        New-Item -ItemType Directory -Force $PLUGIN_DIR | Out-Null
    }

    $extractTmp = Join-Path $TMP_DIR 'extract'
    New-Item -ItemType Directory -Force $extractTmp | Out-Null
    Push-Location $TMP_DIR
    try {
        tar --force-local -xzf $tarName -C './extract' --strip-components=1
    } finally {
        Pop-Location
    }

    Copy-Item -Path "$extractTmp\*" -Destination $PLUGIN_DIR -Recurse -Force
}
Write-Output "opencode-multi-auth installed to $PLUGIN_DIR"
Write-Output 'Installing dependencies...'
Push-Location $PLUGIN_DIR
try {
    # Try frozen lockfile first
    $frozenSucceeded = $true
    try {
        bun install --frozen-lockfile *> $null
    } catch {
        $frozenSucceeded = $false
    }
    if ((-not $frozenSucceeded) -or ($LASTEXITCODE -ne 0)) {
        Write-Output 'Retrying bun install without frozen lockfile...'
        bun install
    }
} finally {
    Pop-Location
}

# Cleanup
if (Test-Path $TMP_DIR) {
    Remove-Item -Recurse -Force $TMP_DIR -ErrorAction SilentlyContinue
}

Write-Output ''
Write-Output "opencode-multi-auth $version installed to $PLUGIN_DIR"
Write-Output ''
Write-Output '   Next steps:'
if ($isLocalSource) {
    Write-Output '   1. Run setup (interactive): bun ./scripts/setup.js'
} else {
    Write-Output "   1. Run setup (interactive): bun $PLUGIN_DIR/scripts/setup.js"
}
Write-Output '   2. Verify runtime: opencode auth login'
Write-Output ''
