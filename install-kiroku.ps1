# install-kiroku.ps1 — Install Kiroku for Windows
# Usage: irm 'https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/main/install-kiroku.ps1' | iex
$ErrorActionPreference = "Stop"

$GITHUB_SOURCE_REPO = "andyvandaric/andyvand-opencode-config"
$GITHUB_SOURCE_BRANCH = "main"
$WHATSAPP_ORDER_URL = "https://wa.me/6281289731212?text=Mau%20order%20Kiroku%20nya%2C%20mohon%20infonya%20ya"
$INSTALL_DIR = Join-Path $env:USERPROFILE ".kiroku\bin"
$KIRO_CLI_PATH = Join-Path $env:LOCALAPPDATA "Kiro-Cli\kiro-cli.exe"

function Write-Info($msg) { Write-Host "  $msg" }
function Write-Ok($msg) { Write-Host "✅ $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "⚠️  $msg" -ForegroundColor Yellow }
function Write-Err($msg) { Write-Host "❌ $msg" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "🥷 Kiroku — Multi-Provider Router for Kiro CLI" -ForegroundColor Magenta
Write-Host "────────────────────────────────────────────────"
Write-Host ""

# ─── Ensure kiro-cli ─────────────────────────────────────────────────────────
Write-Info "Checking kiro-cli..."
if (Test-Path $KIRO_CLI_PATH) {
    $kiroVersion = & $KIRO_CLI_PATH --version 2>$null
    Write-Ok "kiro-cli found: $kiroVersion"
} elseif (Get-Command kiro-cli -ErrorAction SilentlyContinue) {
    $kiroVersion = kiro-cli --version 2>$null
    Write-Ok "kiro-cli found in PATH: $kiroVersion"
} else {
    Write-Info "kiro-cli not found. Installing from https://cli.kiro.dev ..."
    try {
        Invoke-Expression (Invoke-RestMethod 'https://cli.kiro.dev/install.ps1')
        if (Test-Path $KIRO_CLI_PATH) {
            Write-Ok "kiro-cli installed successfully"
        } else {
            Write-Warn "kiro-cli install may have succeeded but binary not found at expected path"
            Write-Info "Continuing anyway — kiroku will check again at runtime"
        }
    } catch {
        Write-Warn "kiro-cli auto-install failed: $_"
        Write-Info "Install manually: irm 'https://cli.kiro.dev/install.ps1' | iex"
        Write-Info "Continuing with Kiroku install..."
    }
}

# ─── Resolve GitHub token ────────────────────────────────────────────────────
Write-Host ""
Write-Info "Resolving GitHub auth..."

$token = $null

if ($env:GITHUB_TOKEN) {
    $token = $env:GITHUB_TOKEN
    Write-Info "Auth: using GITHUB_TOKEN env var"
} elseif (Get-Command gh -ErrorAction SilentlyContinue) {
    try {
        $ghStatus = gh auth status 2>&1
        if ($LASTEXITCODE -eq 0) {
            $token = (gh auth token 2>$null).Trim()
            if ($token) { Write-Info "Auth: using gh CLI token" }
        }
    } catch {}

    if (-not $token) {
        Write-Info "gh CLI not authenticated. Running: gh auth login"
        try {
            gh auth login
            $token = (gh auth token 2>$null).Trim()
        } catch {}
    }
}

if (-not $token) {
    Write-Err "No GitHub auth available. Install gh CLI (https://cli.github.com) and run: gh auth login"
}

# ─── Verify repo access ─────────────────────────────────────────────────────
Write-Host ""
Write-Info "Verifying buyer repo access..."

$headers = @{ Authorization = "token $token"; Accept = "application/vnd.github+json" }
try {
    $resp = Invoke-RestMethod "https://api.github.com/repos/$GITHUB_SOURCE_REPO/contents/assets/kiroku?ref=$GITHUB_SOURCE_BRANCH" -Headers $headers -ErrorAction Stop
    Write-Ok "Repo access verified"
} catch {
    $code = $_.Exception.Response.StatusCode.value__
    if ($code -eq 401 -or $code -eq 403 -or $code -eq 404) {
        Write-Warn "You do not have Kiroku access yet (HTTP $code)."
        Write-Host ""
        Write-Host "  Purchase Kiroku: $WHATSAPP_ORDER_URL" -ForegroundColor Cyan
        Write-Host ""
        try { Start-Process $WHATSAPP_ORDER_URL } catch {}
        exit 1
    }
    Write-Err "GitHub API error (HTTP $code): $_"
}

# ─── Download manifest ───────────────────────────────────────────────────────
Write-Host ""
Write-Info "Fetching release manifest..."

try {
    $manifestUrl = "https://api.github.com/repos/$GITHUB_SOURCE_REPO/contents/assets/kiroku/manifest.json?ref=$GITHUB_SOURCE_BRANCH"
    $manifestResp = Invoke-RestMethod $manifestUrl -Headers @{ Authorization = "token $token"; Accept = "application/vnd.github.raw" }
    if ($manifestResp -is [string]) { $manifest = $manifestResp | ConvertFrom-Json } else { $manifest = $manifestResp }
    Write-Ok "Manifest: v$($manifest.version)"
} catch {
    Write-Err "Failed to fetch manifest: $_"
}

# ─── Determine artifact ──────────────────────────────────────────────────────
$arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "x64" }
$artifactKey = "windows-$arch"
$artifact = $manifest.artifacts.$artifactKey

if (-not $artifact) { Write-Err "No artifact found for $artifactKey in manifest" }

$fileName = $artifact.file
$expectedSha = $artifact.sha256
Write-Info "Artifact: $fileName ($artifactKey)"

# ─── Download binary ─────────────────────────────────────────────────────────
Write-Host ""
Write-Info "Downloading $fileName..."

$tmpFile = Join-Path $env:TEMP "kiroku-install-$([guid]::NewGuid().ToString('N').Substring(0,8)).exe"
try {
    # Use gh CLI for reliable LFS download (handles auth + redirects)
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        $lfsDir = Join-Path $env:TEMP "kiroku-lfs-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        Write-Info "Cloning binary via git LFS..."
        git clone --depth 1 --filter=blob:none --sparse "https://x-access-token:${token}@github.com/$GITHUB_SOURCE_REPO.git" $lfsDir 2>$null
        Push-Location $lfsDir
        git sparse-checkout set "assets/kiroku/$fileName" 2>$null
        git lfs pull --include="assets/kiroku/$fileName" 2>$null
        Pop-Location
        if (Test-Path "$lfsDir/assets/kiroku/$fileName") {
            Copy-Item "$lfsDir/assets/kiroku/$fileName" $tmpFile -Force
        }
        Remove-Item $lfsDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Fallback: download_url from contents API
    if (-not (Test-Path $tmpFile) -or (Get-Item $tmpFile).Length -lt 1000000) {
        $dlInfoUrl = "https://api.github.com/repos/$GITHUB_SOURCE_REPO/contents/assets/kiroku/${fileName}?ref=$GITHUB_SOURCE_BRANCH"
        $fileInfo = Invoke-RestMethod $dlInfoUrl -Headers @{ Authorization = "token $token"; Accept = "application/vnd.github+json" } -UseBasicParsing
        if ($fileInfo.download_url) {
            Invoke-WebRequest $fileInfo.download_url -OutFile $tmpFile -UseBasicParsing
        }
    }

    $dlSize = (Get-Item $tmpFile).Length
    if ($dlSize -lt 1000000) { Write-Err "Download failed: file too small ($dlSize bytes). LFS download may have failed." }
    Write-Ok "Downloaded: $([math]::Round($dlSize / 1MB, 1)) MB"
} catch {
    Write-Err "Download failed: $_"
}

# ─── Verify SHA-256 ──────────────────────────────────────────────────────────
Write-Info "Verifying SHA-256..."
$actualSha = (Get-FileHash $tmpFile -Algorithm SHA256).Hash.ToLower()
if ($actualSha -ne $expectedSha) {
    Remove-Item $tmpFile -Force
    Write-Err "SHA-256 mismatch! Expected: $expectedSha, Got: $actualSha"
}
Write-Ok "Checksum verified"

# ─── Install ─────────────────────────────────────────────────────────────────
Write-Host ""
Write-Info "Installing to $INSTALL_DIR..."

New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
$destPath = Join-Path $INSTALL_DIR "kiroku.exe"

# Kill existing kiroku if running
Get-Process kiroku -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

Move-Item $tmpFile $destPath -Force
Write-Ok "Installed: $destPath"

# ─── Add to PATH ─────────────────────────────────────────────────────────────
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -notlike "*$INSTALL_DIR*") {
    [Environment]::SetEnvironmentVariable("PATH", "$INSTALL_DIR;$userPath", "User")
    $env:PATH = "$INSTALL_DIR;$env:PATH"
    Write-Ok "Added $INSTALL_DIR to user PATH"
} else {
    Write-Info "PATH already contains $INSTALL_DIR"
}

# ─── Verify ──────────────────────────────────────────────────────────────────
Write-Host ""
Write-Info "Verifying installation..."
$ver = & $destPath --version 2>$null
if ($ver -match "kiroku") {
    Write-Ok "$ver installed and working!"
} else {
    Write-Warn "Binary installed but version check failed. Try opening a new terminal."
}

# ─── Done ────────────────────────────────────────────────────────────────────

# ─── Auto-install WezTerm if not present ─────────────────────────────────────
$wezterm = Get-Command wezterm -ErrorAction SilentlyContinue
if (-not $wezterm) {
    Write-Host ""
    Write-Info "Installing WezTerm (recommended terminal with Shift+Enter support)..."
    try {
        $weztermScript = "https://api.github.com/repos/$GITHUB_SOURCE_REPO/contents/assets/kiroku/install-wezterm.ps1?ref=$GITHUB_SOURCE_BRANCH"
        $weztermInfo = Invoke-RestMethod $weztermScript -Headers @{ Authorization = "token $token"; Accept = "application/vnd.github+json" }
        $weztermContent = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($weztermInfo.content))
        Invoke-Expression $weztermContent
        Write-Ok "WezTerm installed"
    } catch {
        Write-Warn "WezTerm auto-install skipped: $_"
        Write-Info "Install manually later from buyer repo: assets/kiroku/install-wezterm.ps1"
    }
} else {
    Write-Info "WezTerm already installed: $($wezterm.Source)"
}

# ─── Summary ─────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "────────────────────────────────────────────────" -ForegroundColor Magenta
Write-Ok "Kiroku v$($manifest.version) installed!"
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor White
Write-Host "    1. Open a new terminal (for PATH to take effect)"
Write-Host "    2. kiroku account list     — Check your accounts"
Write-Host "    3. kiroku chat             — Start chatting"
Write-Host "    4. kiroku watcher start    — Enable auto-rotation"
Write-Host "    5. kiroku dashboard        — Open usage dashboard"
Write-Host ""
