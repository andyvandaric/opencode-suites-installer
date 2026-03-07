# install.ps1 - Install opencode-multi-auth plugin for OpenCode Config Suites
# Auth path: env token -> cached token -> gh CLI -> secure prompt

#Requires -Version 5.1
param(
    [string]$Version,
    [string]$SourceBranch,
    [string]$PwshPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Config ---
$GITHUB_SOURCE_REPO = "andyvandaric/andyvand-opencode-config"
$REQUESTED_VERSION = if ($Version) { $Version.TrimStart('v') } elseif ($env:OCS_VERSION) { $env:OCS_VERSION.TrimStart('v') } else { "" }
$GITHUB_SOURCE_BRANCH = if ($SourceBranch) { $SourceBranch } elseif ($env:OCS_RELEASE_BRANCH) { $env:OCS_RELEASE_BRANCH } else { "beta" }
$ACCESS_LANDING_PAGE = "https://wa.me/6281289731212?text=Mau%20order%20OCS%20nya%2C%20mohon%20infonya%20ya"
$PLUGIN_DIR = "$env:USERPROFILE\.config\opencode\plugins\opencode-multi-auth"
$TOKEN_FILE = "$env:USERPROFILE\.opencode-suites\.token"
$script:ResolvedReleaseToken = ""
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

    Write-Host "Relaunching installer in PowerShell 7 for better compatibility..."
    $previousRelaunchFlag = $env:OCS_PWSH_RELAUNCHED
    $env:OCS_PWSH_RELAUNCHED = "1"

    $scriptPath = $PSCommandPath
    $exitCode = 0
    $previousVersion = $env:OCS_VERSION
    $previousBranch = $env:OCS_RELEASE_BRANCH

    if ($REQUESTED_VERSION) {
        $env:OCS_VERSION = $REQUESTED_VERSION
    }
    if ($GITHUB_SOURCE_BRANCH) {
        $env:OCS_RELEASE_BRANCH = $GITHUB_SOURCE_BRANCH
    }

    try {
        if ($scriptPath -and (Test-Path $scriptPath)) {
            & $PwshPath -NoProfile -ExecutionPolicy Bypass -File $scriptPath
            if ($LASTEXITCODE -ne $null) {
                $exitCode = $LASTEXITCODE
            }
            if ($exitCode -ne 0) {
                Write-Warning "Relaunched installer exited with code $exitCode"
                return $false
            }
            return $true
        }

        $relaunchUrl = "https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/main/install.ps1"
        $relaunchCommand = '$env:OCS_PWSH_RELAUNCHED=''1''; irm ''' + $relaunchUrl + ''' | iex'
        & $PwshPath -NoProfile -ExecutionPolicy Bypass -Command $relaunchCommand
        if ($LASTEXITCODE -ne $null) {
            $exitCode = $LASTEXITCODE
        }
        if ($exitCode -ne 0) {
            Write-Warning "Relaunched installer exited with code $exitCode"
            return $false
        }
        return $true
    } finally {
        if ($previousVersion) {
            $env:OCS_VERSION = $previousVersion
        } else {
            Remove-Item Env:OCS_VERSION -ErrorAction SilentlyContinue
        }
        if ($previousBranch) {
            $env:OCS_RELEASE_BRANCH = $previousBranch
        } else {
            Remove-Item Env:OCS_RELEASE_BRANCH -ErrorAction SilentlyContinue
        }
        if ($previousRelaunchFlag) {
            $env:OCS_PWSH_RELAUNCHED = $previousRelaunchFlag
        } else {
            Remove-Item Env:OCS_PWSH_RELAUNCHED -ErrorAction SilentlyContinue
        }
    }
}

function Ensure-PowerShellRuntime {
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -ge 7) {
        Write-Host "PowerShell $($psVersion.ToString()) detected"
        return $false
    }

    Write-Warning "Running on Windows PowerShell $($psVersion.ToString()). PowerShell 7+ is recommended."

    $pwshPath = Resolve-PwshPath
    if ($pwshPath) {
        Write-Host "PowerShell 7 is already installed."
        $relaunched = Invoke-PwshRelaunch -PwshPath $pwshPath
        if ($relaunched) {
            Write-Host "Relaunch completed. Keeping current terminal open."
            return $true
        }
        Write-Host "Continuing in current shell."
        return $false
    }

    $installed = $false

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "Attempting PowerShell 7 install via winget..."
        try {
            & winget install --id Microsoft.PowerShell --source winget --accept-package-agreements --accept-source-agreements --silent
            if ($LASTEXITCODE -eq 0) { $installed = $true }
        } catch {
            $installed = $false
        }
    }

    if ((-not $installed) -and (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Attempting PowerShell 7 install via Chocolatey..."
        try {
            & choco install powershell-core -y
            if ($LASTEXITCODE -eq 0) { $installed = $true }
        } catch {
            $installed = $false
        }
    }

    if ((-not $installed) -and (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Host "Attempting PowerShell 7 install via Scoop..."
        try {
            & scoop install pwsh
            if ($LASTEXITCODE -eq 0) { $installed = $true }
        } catch {
            $installed = $false
        }
    }

    $pwshPath = Resolve-PwshPath
    if ($pwshPath) {
        Write-Host "PowerShell 7 detected after installation attempt."
        $relaunched = Invoke-PwshRelaunch -PwshPath $pwshPath
        if ($relaunched) {
            Write-Host "Relaunch completed. Keeping current terminal open."
            return $true
        }
        Write-Host "Continuing in current shell."
    } else {
        Write-Warning "PowerShell 7 installation was skipped or failed. Continuing with current shell."
    }

    return $false
}

function Refresh-SessionPath {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")

    if ($machinePath -and $userPath) {
        $env:PATH = "$machinePath;$userPath"
    } elseif ($machinePath) {
        $env:PATH = $machinePath
    } elseif ($userPath) {
        $env:PATH = $userPath
    }

    $ghBinCandidates = @(
        (Join-Path $env:ProgramFiles "GitHub CLI"),
        (Join-Path $env:LOCALAPPDATA "Programs\GitHub CLI")
    )

    foreach ($ghBin in $ghBinCandidates) {
        if ($ghBin -and (Test-Path (Join-Path $ghBin "gh.exe")) -and ($env:PATH -notlike "*$ghBin*")) {
            $env:PATH = "$ghBin;$env:PATH"
        }
    }

    $opencodeBinCandidates = @(
        (Join-Path $env:USERPROFILE ".opencode\bin"),
        (Join-Path $env:USERPROFILE ".bun\bin")
    )

    foreach ($opencodeBin in $opencodeBinCandidates) {
        if (-not $opencodeBin) { continue }
        $hasOpencodeBinary = (Test-Path (Join-Path $opencodeBin "opencode.exe")) -or (Test-Path (Join-Path $opencodeBin "opencode.cmd")) -or (Test-Path (Join-Path $opencodeBin "opencode.ps1"))
        if ($hasOpencodeBinary -and ($env:PATH -notlike "*$opencodeBin*")) {
            $env:PATH = "$opencodeBin;$env:PATH"
        }
    }
}

function Add-PathEntryToUserPath {
    param([string]$PathEntry)

    if (-not $PathEntry) { return }
    if (-not (Test-Path $PathEntry)) { return }

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $entries = @()
    if ($userPath) {
        $entries = $userPath -split ";"
    }

    $normalized = $PathEntry.TrimEnd("\\")
    $alreadyPresent = $false
    foreach ($entry in $entries) {
        if ($entry -and ($entry.TrimEnd("\\") -ieq $normalized)) {
            $alreadyPresent = $true
            break
        }
    }

    if (-not $alreadyPresent) {
        $newPath = if ($userPath) { "$userPath;$PathEntry" } else { $PathEntry }
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    }

    if (($env:PATH -split ";") -notcontains $PathEntry) {
        $env:PATH = "$PathEntry;$env:PATH"
    }
}

function Ensure-OpencodePathEntries {
    $pathCandidates = @(
        (Join-Path $env:USERPROFILE ".opencode\bin"),
        (Join-Path $env:USERPROFILE ".bun\bin"),
        (Join-Path $env:USERPROFILE ".local\bin")
    )

    foreach ($candidate in $pathCandidates) {
        Add-PathEntryToUserPath -PathEntry $candidate
    }

    Refresh-SessionPath
}

function Ensure-WindowsShellEnv {
    if ($env:OS -ne "Windows_NT") {
        return
    }

    $systemRoot = if ($env:SystemRoot) { $env:SystemRoot } else { "C:\Windows" }
    $fallbackCmd = Join-Path $systemRoot "System32\cmd.exe"

    $currentComSpecRaw = if ($env:ComSpec) { $env:ComSpec } else { $env:COMSPEC }
    $currentComSpec = if ($currentComSpecRaw) {
        $currentComSpecRaw.Trim().Trim('"')
    } else {
        ""
    }

    if ((-not $currentComSpec) -or (-not (Test-Path $currentComSpec))) {
        if (Test-Path $fallbackCmd) {
            $env:ComSpec = $fallbackCmd
            $env:COMSPEC = $fallbackCmd
            Write-Host "Normalized COMSPEC to $fallbackCmd"
        } else {
            Write-Warning "cmd.exe not found at expected path: $fallbackCmd"
        }
    } else {
        $env:ComSpec = $currentComSpec
        $env:COMSPEC = $currentComSpec
    }
}

function Ensure-GitHubCli {
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        return $true
    }

    Write-Warning "GitHub CLI (gh) not found. Attempting auto install..."
    $installed = $false

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "Attempting GitHub CLI install via winget..."
        $wingetIds = @("GitHub.cli", "Microsoft.GitHub.CLI")
        foreach ($wingetId in $wingetIds) {
            if ($installed) { break }
            try {
                & winget install --id $wingetId --exact --silent --accept-package-agreements --accept-source-agreements
                if ($LASTEXITCODE -eq 0) { $installed = $true }
            } catch {
                $installed = $false
            }
        }
    }

    if ((-not $installed) -and (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Attempting GitHub CLI install via Chocolatey..."
        try {
            & choco install gh -y
            if ($LASTEXITCODE -eq 0) { $installed = $true }
        } catch {
            $installed = $false
        }
    }

    if ((-not $installed) -and (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Host "Attempting GitHub CLI install via Scoop..."
        try {
            & scoop install gh
            if ($LASTEXITCODE -eq 0) { $installed = $true }
        } catch {
            $installed = $false
        }
    }

    Refresh-SessionPath
    return [bool](Get-Command gh -ErrorAction SilentlyContinue)
}

function Save-TokenFile {
    param([string]$Token)

    if (-not $Token) { return }

    try {
        $tokenDir = Split-Path -Parent $TOKEN_FILE
        if ($tokenDir -and (-not (Test-Path $tokenDir))) {
            New-Item -ItemType Directory -Path $tokenDir -Force | Out-Null
        }

        Set-Content -Path $TOKEN_FILE -Value $Token -Encoding UTF8
    } catch {
        Write-Warning "Could not persist token cache to $TOKEN_FILE"
    }
}

function Resolve-Token {
    param(
        [switch]$NonInteractive,
        [switch]$SkipTokenCache
    )

    if ($env:GH_TOKEN) {
        Write-Host "Auth: using GH_TOKEN environment variable"
        return $env:GH_TOKEN.Trim()
    }

    if ($env:GITHUB_TOKEN) {
        Write-Host "Auth: using GITHUB_TOKEN environment variable"
        return $env:GITHUB_TOKEN.Trim()
    }

    if ((-not $SkipTokenCache) -and (Test-Path $TOKEN_FILE)) {
        try {
            $cachedToken = (Get-Content -Path $TOKEN_FILE -Raw -Encoding UTF8).Trim()
            if ($cachedToken) {
                Write-Host "Auth: using cached token file"
                return $cachedToken
            }
        } catch {
            Write-Warning "Token cache exists but could not be read: $TOKEN_FILE"
        }
    }

    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        $ghInstalled = Ensure-GitHubCli
        if (-not $ghInstalled) {
            Write-Warning "GitHub CLI auto-install failed. Please install gh and authenticate via browser login."
        }
    }

    if (Get-Command gh -ErrorAction SilentlyContinue) {
        gh auth status 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "GitHub CLI not authenticated. Opening browser login..."
            & gh auth login
            if ($LASTEXITCODE -eq 0) {
                & gh config set -h github.com git_protocol https | Out-Null
                & gh auth refresh -h github.com --scopes repo | Out-Null
            }
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "GitHub CLI login failed."
            }
        }

        $ghToken = gh auth token 2>$null
        if ($LASTEXITCODE -eq 0 -and $ghToken) {
            $trimmed = $ghToken.Trim()
            Write-Host "Auth: using gh CLI token"
            Save-TokenFile -Token $trimmed
            return $trimmed
        }
    }

    if ($NonInteractive) {
        Write-Error "Unable to resolve GitHub token in non-interactive mode. Set GH_TOKEN/GITHUB_TOKEN or authenticate gh."
        exit 1
    }

    Write-Host "Run this command in terminal, then rerun installer:"
    Write-Host "gh auth login"
    Write-Host "Then choose: GitHub.com -> HTTPS -> Yes -> Login with a web browser"
    Write-Host "If browser auto-open fails (WSL), open the shown URL manually and finish login"
    Write-Host "Optional hardening: gh auth refresh -h github.com --scopes repo"
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Host "Install GitHub CLI first: https://cli.github.com/"
    }
    Write-Error "Unable to obtain GitHub token. Complete gh login first, then rerun installer."
    exit 1
}

function Open-LandingPage {
    Write-Output "Open purchase chat: $ACCESS_LANDING_PAGE"
    try {
        Start-Process $ACCESS_LANDING_PAGE | Out-Null
    } catch {
        Write-Warning "Could not open browser automatically. Visit: $ACCESS_LANDING_PAGE"
    }
}

function Test-RepoAccess {
    param(
        [string]$Token,
        [switch]$SuppressLandingPage
    )

    $headers = @{
        Authorization = "token $Token"
        Accept        = "application/vnd.github+json"
    }

    try {
        $response = Invoke-WebRequest -Uri "https://api.github.com/repos/$GITHUB_SOURCE_REPO/branches/$GITHUB_SOURCE_BRANCH" -Headers $headers -UseBasicParsing -ErrorAction Stop
        Write-Host "Repo branch access verified: $GITHUB_SOURCE_REPO@$GITHUB_SOURCE_BRANCH (HTTP $($response.StatusCode))"
        return $true
    } catch {
        $code = 0
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
            $code = $_.Exception.Response.StatusCode.value__
        }

        if ($code -in @(401, 403, 404)) {
            Write-Warning "You do not have OCS beta access yet. Repo/branch: $GITHUB_SOURCE_REPO@$GITHUB_SOURCE_BRANCH"
            Write-Host "GitHub API response: HTTP $code"
            if (-not $SuppressLandingPage) {
                Open-LandingPage
            }
            return $false
        }

        Write-Warning "Cannot access repo branch $GITHUB_SOURCE_REPO@$GITHUB_SOURCE_BRANCH (HTTP $code). Check network and GitHub auth state."
        return $false
    }
}

function Get-PluginBundleFromAssets {
    param(
        [string]$Token,
        [string]$OutPath
    )

    $headers = @{
        Authorization = "token $Token"
        Accept        = "application/vnd.github+json"
    }

    $assetsUri = "https://api.github.com/repos/$GITHUB_SOURCE_REPO/contents/assets?ref=$GITHUB_SOURCE_BRANCH"
    $assets = Invoke-RestMethod -Uri $assetsUri -Headers $headers -ErrorAction Stop
    $bundle = $assets |
        Where-Object { $_.name -match '^opencode-config-suites-v(?<version>\d+\.\d+\.\d+)\.tar\.gz$' } |
        ForEach-Object {
            [PSCustomObject]@{
                Asset   = $_
                Version = [version]$Matches.version
            }
        } |
        Sort-Object Version -Descending

    if ($REQUESTED_VERSION) {
        $bundle = $bundle | Where-Object { $_.Version -eq ([version]$REQUESTED_VERSION) } | Select-Object -First 1
        if (-not $bundle) {
            throw "Requested version $REQUESTED_VERSION not found in assets/ for $GITHUB_SOURCE_REPO@$GITHUB_SOURCE_BRANCH"
        }
    } else {
        $bundle = $bundle | Select-Object -First 1
    }

    if (-not $bundle) {
        throw "No plugin bundle found in assets/ for $GITHUB_SOURCE_REPO@$GITHUB_SOURCE_BRANCH"
    }

    $bundleName = $bundle.Asset.name

    $downloadHeaders = @{
        Authorization = "token $Token"
        Accept        = "application/vnd.github.raw"
    }
    $downloadUri = "https://api.github.com/repos/$GITHUB_SOURCE_REPO/contents/assets/${bundleName}?ref=$GITHUB_SOURCE_BRANCH"
    Invoke-WebRequest -Uri $downloadUri -Headers $downloadHeaders -OutFile $OutPath -UseBasicParsing -ErrorAction Stop
    return $bundleName
}

function Get-Asset {
    param(
        [string]$Token,
        [string]$PrimaryUrl,
        [string]$FallbackUrl,
        [string]$OutPath
    )

    $headers = @{
        Authorization = "token $Token"
        Accept        = "application/octet-stream"
    }

    if ($PrimaryUrl) {
        try {
            Invoke-WebRequest -Uri $PrimaryUrl -Headers $headers -OutFile $OutPath -UseBasicParsing -ErrorAction Stop
            return
        } catch {
            if (-not $FallbackUrl) {
                throw
            }
        }
    }

    if ($FallbackUrl) {
        Invoke-WebRequest -Uri $FallbackUrl -Headers $headers -OutFile $OutPath -UseBasicParsing -ErrorAction Stop
        return
    }

    throw "No release asset URL available."
}

function Extract-TarGz {
    param(
        [string]$ArchivePath,
        [string]$Destination,
        [switch]$StripFirstComponent
    )

    $systemTarPath = Join-Path $env:SystemRoot "System32\tar.exe"
    if (Test-Path $systemTarPath) {
        $tarCommand = @{ Source = $systemTarPath }
    } else {
        $tarCommand = Get-Command tar.exe -ErrorAction SilentlyContinue
        if (-not $tarCommand) {
            $tarCommand = Get-Command tar -ErrorAction SilentlyContinue
        }
    }
    if (-not $tarCommand) {
        throw "tar command not found. Please ensure tar.exe is available on PATH."
    }

    $archiveFullPath = (Resolve-Path $ArchivePath).Path
    $destinationFullPath = (Resolve-Path $Destination).Path

    $args = @("-xzf", $archiveFullPath, "-C", $destinationFullPath)
    if ($StripFirstComponent) {
        $args += "--strip-components=1"
    }

    & $tarCommand.Source @args
    if ($LASTEXITCODE -ne 0) {
        throw "tar extraction failed with exit code $LASTEXITCODE"
    }
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
    $bunBin = Join-Path $env:USERPROFILE ".bun\bin"
    Add-PathEntryToUserPath -PathEntry $bunBin
    Refresh-SessionPath

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

    Add-PathEntryToUserPath -PathEntry $bunBin
    Refresh-SessionPath

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

function Test-OcsWorks {
    $preferredCmd = Join-Path $env:USERPROFILE ".bun\bin\ocs.cmd"
    $commandToRun = ""

    if (Test-Path $preferredCmd) {
        $commandToRun = $preferredCmd
    } else {
        $resolved = Get-Command ocs -ErrorAction SilentlyContinue
        if (-not $resolved) {
            return $false
        }
        $commandToRun = $resolved.Source
    }

    & $commandToRun --version *> $null
    if ($LASTEXITCODE -ne 0) {
        return $false
    }

    & $commandToRun --help *> $null
    if ($LASTEXITCODE -ne 0) {
        return $false
    }

    return $true
}

function Install-OcsFromPath {
    param([string]$SourcePath)

    if (-not $SourcePath) {
        return $false
    }
    if (-not (Test-Path $SourcePath)) {
        return $false
    }

    $resolvedSource = (Resolve-Path $SourcePath).Path
    $maxAttempts = 5

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        $lastOutput = ""
        try {
            Write-Output "Attempting ocs install from local path (attempt $attempt/$maxAttempts)..."
            $bunOutput = & bun install -g $resolvedSource 2>&1
            if ($bunOutput) {
                $lastOutput = ($bunOutput | Out-String).Trim()
            }
            if ($LASTEXITCODE -eq 0) {
                return $true
            }
        } catch {
            $lastOutput = $_.Exception.Message
        }

        if ($attempt -lt $maxAttempts) {
            if (Test-LockRelatedError -Message $lastOutput) {
                Stop-WindowsLockHolders -PathHint $resolvedSource
            }
            Start-Sleep -Milliseconds (700 * $attempt)
            continue
        }

        if ($lastOutput) {
            Write-Warning "bun global install failed: $lastOutput"
        }
    }

    if (Get-Command npm -ErrorAction SilentlyContinue) {
        try {
            Write-Warning "bun global install failed, trying npm global install..."
            & npm install -g $resolvedSource *> $null
            if ($LASTEXITCODE -eq 0) {
                return $true
            }
        } catch {
            Write-Warning "npm global install fallback failed: $($_.Exception.Message)"
        }
    }

    if (Get-Command pnpm -ErrorAction SilentlyContinue) {
        try {
            Write-Warning "npm fallback unavailable/failed, trying pnpm global install..."
            & pnpm add -g $resolvedSource *> $null
            if ($LASTEXITCODE -eq 0) {
                return $true
            }
        } catch {
            Write-Warning "pnpm global install fallback failed: $($_.Exception.Message)"
        }
    }

    return $false
}

function Resolve-AbsolutePathSafe {
    param([string]$BasePath, [string]$Candidate)

    if (-not $Candidate) {
        return ""
    }

    if ([System.IO.Path]::IsPathRooted($Candidate)) {
        return $Candidate
    }

    if (-not $BasePath) {
        return (Resolve-Path $Candidate).Path
    }

    return (Join-Path $BasePath $Candidate)
}

function Install-OcsShimFromBundle {
    param([string]$PluginPath, [string]$BasePath)

    $pluginAbsPath = Resolve-AbsolutePathSafe -BasePath $BasePath -Candidate $PluginPath
    if (-not $pluginAbsPath) {
        return $false
    }

    $ocsJs = Join-Path $pluginAbsPath "bin\ocs.cjs"
    if (-not (Test-Path $ocsJs)) {
        $ocsJs = Join-Path $pluginAbsPath "bin\ocs.js"
    }
    if (-not (Test-Path $ocsJs)) {
        return $false
    }

    $bunBin = Join-Path $env:USERPROFILE ".bun\bin"
    New-Item -ItemType Directory -Path $bunBin -Force | Out-Null

    $cmdPath = Join-Path $bunBin "ocs.cmd"
    $ps1Path = Join-Path $bunBin "ocs.ps1"

    $cmdContent = "@echo off`r`nbun `"$ocsJs`" %*`r`n"
    Set-Content -Path $cmdPath -Value $cmdContent -Encoding ASCII

    $ps1Content = "param([Parameter(ValueFromRemainingArguments=`$true)][string[]]`$Args)`r`n& bun `"$ocsJs`" @Args`r`n"
    Set-Content -Path $ps1Path -Value $ps1Content -Encoding ASCII

    Add-PathEntryToUserPath -PathEntry $bunBin
    Refresh-SessionPath

    & $cmdPath --version *> $null
    if ($LASTEXITCODE -ne 0) {
        return $false
    }
    & $cmdPath --help *> $null
    if ($LASTEXITCODE -ne 0) {
        return $false
    }
    return $true
}

function Install-OcsShimFromOpencode {
    $opencodeCmd = Get-Command opencode -ErrorAction SilentlyContinue
    $cmdLine = if ($opencodeCmd) { "opencode %*" } else { "bunx opencode-ai %*" }
    $psLine = if ($opencodeCmd) { "& opencode @Args" } else { "& bunx opencode-ai @Args" }

    $bunBin = Join-Path $env:USERPROFILE ".bun\bin"
    New-Item -ItemType Directory -Path $bunBin -Force | Out-Null

    $cmdPath = Join-Path $bunBin "ocs.cmd"
    $ps1Path = Join-Path $bunBin "ocs.ps1"

    $cmdContent = "@echo off`r`n$cmdLine`r`n"
    Set-Content -Path $cmdPath -Value $cmdContent -Encoding ASCII

    $ps1Content = "param([Parameter(ValueFromRemainingArguments=`$true)][string[]]`$Args)`r`n$psLine`r`n"
    Set-Content -Path $ps1Path -Value $ps1Content -Encoding ASCII

    Add-PathEntryToUserPath -PathEntry $bunBin
    Refresh-SessionPath

    return (Test-OcsWorks)
}

function Install-OpencodeShimFromBun {
    $bunBin = Join-Path $env:USERPROFILE ".bun\bin"
    New-Item -ItemType Directory -Path $bunBin -Force | Out-Null

    $bunxExe = Join-Path $bunBin "bunx.exe"
    $cmdPath = Join-Path $bunBin "opencode.cmd"
    $ps1Path = Join-Path $bunBin "opencode.ps1"

    $cmdLine = if (Test-Path $bunxExe) {
        "@echo off`r`n`"$bunxExe`" --bun opencode-ai %*`r`n"
    } else {
        "@echo off`r`nbunx --bun opencode-ai %*`r`n"
    }
    Set-Content -Path $cmdPath -Value $cmdLine -Encoding ASCII

    $psLine = if (Test-Path $bunxExe) {
        "param([Parameter(ValueFromRemainingArguments=`$true)][string[]]`$Args)`r`n& `"$bunxExe`" --bun opencode-ai @Args`r`n"
    } else {
        "param([Parameter(ValueFromRemainingArguments=`$true)][string[]]`$Args)`r`n& bunx --bun opencode-ai @Args`r`n"
    }
    Set-Content -Path $ps1Path -Value $psLine -Encoding ASCII

    Add-PathEntryToUserPath -PathEntry $bunBin
    Refresh-SessionPath

    return (Test-Path $cmdPath)
}

function Install-OcsFromPrivateRepo {
    param([string]$Token)

    if (-not $Token) {
        return $false
    }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        return $false
    }

    $suitePath = Join-Path $TMP_DIR "opencode-config-suites"
    if (Test-Path $suitePath) {
        Remove-Item -Recurse -Force $suitePath -ErrorAction SilentlyContinue
    }

    try {
        Write-Output "Attempting ocs install from private repository source..."
        $cloneUrl = "https://x-access-token:$Token@github.com/$GITHUB_SOURCE_REPO.git"
        & git clone --branch $GITHUB_SOURCE_BRANCH --single-branch $cloneUrl $suitePath *> $null
        if ($LASTEXITCODE -ne 0) {
            return $false
        }
        return (Install-OcsFromPath -SourcePath $suitePath)
    } catch {
        return $false
    }
}

function Ensure-OcsCommand {
    param(
        [string]$PluginPath,
        [string]$BasePath,
        [bool]$IsLocalSource = $false
    )

    $bunBin = Join-Path $env:USERPROFILE ".bun\bin"
    Add-PathEntryToUserPath -PathEntry $bunBin
    Refresh-SessionPath

    if (Test-OcsWorks) {
        Write-Output "ocs verification passed."
        return $true
    }

    if (Install-OcsShimFromBundle -PluginPath $PluginPath -BasePath $BasePath) {
        Write-Output "ocs shim install and verification passed."
        return $true
    }

    if (Install-OcsShimFromOpencode) {
        Write-Output "ocs shim via opencode install and verification passed."
        return $true
    }

    $enableGlobalOcsInstall = (($env:OCS_ENABLE_OCS_GLOBAL_INSTALL ?? "1") -eq "1")
    if (-not $enableGlobalOcsInstall) {
        Write-Warning "Skipping global ocs installation fallback (set OCS_ENABLE_OCS_GLOBAL_INSTALL=1 to enable)."
        return $false
    }

    if ($IsLocalSource) {
        $workspaceRoot = (Resolve-Path ".").Path
        if (Install-OcsFromPath -SourcePath $workspaceRoot) {
            Add-PathEntryToUserPath -PathEntry $bunBin
            Refresh-SessionPath
            if (Test-OcsWorks) {
                Write-Output "ocs auto-install and verification passed."
                return $true
            }
        }
    }

    if (Install-OcsFromPrivateRepo -Token $script:ResolvedReleaseToken) {
        Add-PathEntryToUserPath -PathEntry $bunBin
        Refresh-SessionPath
        if (Test-OcsWorks) {
            Write-Output "ocs auto-install and verification passed."
            return $true
        }
    }

    return $false
}

function Test-LockRelatedError {
    param([string]$Message)
    return $Message -match "EBUSY|EFAULT|EPERM|resource busy|being used by another process|Access is denied"
}

function Test-TransientInstallError {
    param([string]$Message)

    if (-not $Message) {
        return $false
    }

    return $Message -match "Resolving dependencies|Enqueue package manifest|ETIMEDOUT|ECONNRESET|ECONNREFUSED|EAI_AGAIN|socket hang up|fetch failed|timed out|TLS|429|5\d\d"
}

function Invoke-BunCachePurge {
    try {
        & bun pm cache rm *> $null
    } catch {
        # best effort only
    }
}

function Apply-InstallerDefaults {
    param([string]$PluginPath)

    $runtimePath = Join-Path $PluginPath "scripts\constants\setup-runtime.json"
    $fallbacksPath = Join-Path $PluginPath "scripts\constants\setup-fallbacks.json"
    $catalogPath = Join-Path $PluginPath "scripts\constants\profile-catalog.json"

    try {
        if (Test-Path $runtimePath) {
            $runtime = Get-Content -Raw -Path $runtimePath | ConvertFrom-Json
            if ($runtime.resourceModes) {
                $runtime.resourceModes.default = "performance"
                foreach ($option in $runtime.resourceModes.options) {
                    if ($option.id -eq "balanced") {
                        $option.label = "Balanced"
                    }
                    if ($option.id -eq "performance") {
                        $option.label = "Performance (Recommended)"
                    }
                }
            }
            ($runtime | ConvertTo-Json -Depth 50) | Set-Content -Path $runtimePath -Encoding UTF8
        }

        if (Test-Path $fallbacksPath) {
            $fallbacks = Get-Content -Raw -Path $fallbacksPath | ConvertFrom-Json
            if ($fallbacks.setupRuntime -and $fallbacks.setupRuntime.resourceModes) {
                $fallbacks.setupRuntime.resourceModes.default = "performance"
                foreach ($option in $fallbacks.setupRuntime.resourceModes.options) {
                    if ($option.id -eq "balanced") {
                        $option.label = "Balanced"
                    }
                    if ($option.id -eq "performance") {
                        $option.label = "Performance (Recommended)"
                    }
                }
            }
            ($fallbacks | ConvertTo-Json -Depth 50) | Set-Content -Path $fallbacksPath -Encoding UTF8
        }

        if (Test-Path $catalogPath) {
            $catalog = Get-Content -Raw -Path $catalogPath | ConvertFrom-Json
            if ($catalog.profileDisplayOrder) {
                $profiles = @($catalog.profileDisplayOrder | Where-Object { $_ -ne "codex-5.3-hybrid" })
                $catalog.profileDisplayOrder = @("codex-5.3-hybrid") + $profiles
            }
            ($catalog | ConvertTo-Json -Depth 50) | Set-Content -Path $catalogPath -Encoding UTF8
        }

        Write-Output "Applied installer defaults: codex-5.3-hybrid + performance mode."
    } catch {
        Write-Warning "Could not apply installer defaults: $($_.Exception.Message)"
    }
}

function Test-BunRegistryReachable {
    try {
        $response = Invoke-WebRequest -Uri "https://registry.npmjs.org/@types%2Fnode" -Method Head -UseBasicParsing -TimeoutSec 20 -ErrorAction Stop
        return [bool]($response.StatusCode -ge 200 -and $response.StatusCode -lt 400)
    } catch {
        return $false
    }
}

function Stop-WindowsLockHolders {
    param([string]$PathHint)

    if ($env:OS -ne "Windows_NT") { return }

    $safeHint = $PathHint.Replace("'", "''")
    $script = @"
$hint = '$safeHint'
$names = @('bun.exe','node.exe','opencode.exe','biome.exe','powershell.exe','bash.exe')
$self = `$PID
$procs = Get-CimInstance Win32_Process | Where-Object {
  `$_.ProcessId -ne `$self -and
  `$_.Name -and
  ($names -contains `$_.Name.ToLower()) -and
  `$_.CommandLine -and
  (`$_.CommandLine -like "*`$hint*" -or `$_.CommandLine -like "*\\.config\\opencode*")
}
foreach (`$p in `$procs) {
  try {
    Stop-Process -Id `$p.ProcessId -Force -ErrorAction Stop
    Write-Output ("   [lock-handler] Killed " + `$p.Name + " PID=" + `$p.ProcessId)
  } catch {}
}
"@

    try {
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($script))
        & powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded *> $null
    } catch {
        # best effort only
    }
}

function Invoke-BunInstallWithRetry {
    param(
        [string]$Directory,
        [int]$MaxAttempts = 5
    )

    $resolvedDirectory = (Resolve-Path $Directory).Path

    Push-Location $resolvedDirectory
    try {
        $finalMessage = "unknown error"

        for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
            $lastOutput = ""

            if ($attempt -eq 3) {
                Write-Warning "Attempt $attempt/${MaxAttempts}: cleaning local node_modules before retry..."
                Remove-Item -Path ".\node_modules" -Recurse -Force -ErrorAction SilentlyContinue
            }

            if ($attempt -eq 4) {
                Write-Warning "Attempt $attempt/${MaxAttempts}: normalizing shell environment before retry..."
                Ensure-WindowsShellEnv
            }

            $args = @("install", "--frozen-lockfile", "--no-progress", "--network-concurrency=16", "--registry", "https://registry.npmjs.org/")
            if ($attempt -ge 5) {
                $args += @("--no-cache", "--force", "--network-concurrency=8")
            }
            if ($attempt -eq $MaxAttempts) {
                $args += "--verbose"
            } else {
                $env:BUN_CONFIG_REGISTRY = "https://registry.npmjs.org/"
            }

            try {
                $bunOutput = & bun @args 2>&1
                if ($bunOutput) {
                    $lastOutput = ($bunOutput | Out-String).Trim()
                }
                if ($LASTEXITCODE -eq 0) {
                    return
                }
            } catch {
                $lastOutput = $_.Exception.Message
            }

            $message = ""
            if ($lastOutput) {
                $lines = $lastOutput -split "`r?`n"
                $tail = $lines | Where-Object { $_ -and $_.Trim() -ne "" } | Select-Object -Last 6
                $message = ($tail -join " | ").Trim()
            }
            if ((-not $message) -and $Error.Count -gt 0 -and $Error[0]) {
                $message = "$($Error[0].Exception.Message)"
            }

            if ($message) {
                Write-Warning "bun install attempt $attempt/${MaxAttempts} failed: $message"
            } else {
                Write-Warning "bun install attempt $attempt/${MaxAttempts} failed with unknown error."
            }

            if ($message) {
                $finalMessage = $message
            }

            if (($attempt -lt $MaxAttempts) -and ($message -match "cmd\.exe|ComSpec|COMSPEC|uv_spawn|spawn")) {
                Write-Warning "Detected shell spawn issue. Re-applying Windows shell environment fixes..."
                Ensure-WindowsShellEnv
                Start-Sleep -Milliseconds (700 * $attempt)
                continue
            }

            if (($attempt -lt $MaxAttempts) -and (Test-LockRelatedError -Message $message)) {
                Write-Warning "Detected likely file-lock issue. Applying lock handler..."
                Stop-WindowsLockHolders -PathHint $resolvedDirectory
                Start-Sleep -Milliseconds (700 * $attempt)
                continue
            }

            if (($attempt -lt $MaxAttempts) -and (Test-TransientInstallError -Message $message)) {
                Write-Warning "Detected likely network/registry issue. Retrying with stronger network settings..."
                if ($attempt -ge 3) {
                    Invoke-BunCachePurge
                }
                if (-not (Test-BunRegistryReachable)) {
                    Write-Warning "Registry check failed for https://registry.npmjs.org/@types%2Fnode (network/proxy/DNS/TLS issue likely)."
                }
                Ensure-WindowsShellEnv
                Start-Sleep -Milliseconds (1500 * $attempt)
                continue
            }

            if ($attempt -lt $MaxAttempts) {
                Start-Sleep -Milliseconds (700 * $attempt)
                continue
            }

            break
        }

        throw "bun install failed after $MaxAttempts attempts. Last error: $finalMessage"
    } finally {
        Pop-Location
    }
}

function Invoke-AutoSetup {
    param([bool]$IsLocalSource)

    $previousInstallerMode = $env:OCS_SETUP_INSTALLER_MODE
    $env:OCS_SETUP_INSTALLER_MODE = "1"

    if ($env:OCS_SKIP_AUTO_SETUP -eq "1") {
        Write-Warning "Skipping auto setup because OCS_SKIP_AUTO_SETUP=1"
        if ($null -eq $previousInstallerMode) {
            Remove-Item Env:OCS_SETUP_INSTALLER_MODE -ErrorAction SilentlyContinue
        } else {
            $env:OCS_SETUP_INSTALLER_MODE = $previousInstallerMode
        }
        return
    }

    $setupScript = "$PLUGIN_DIR\scripts\setup.js"
    if (-not (Test-Path $setupScript)) {
        Write-Warning "Setup script not found at $setupScript. Skipping auto setup."
        return
    }

    Write-Output ""
    Write-Output "Running auto setup (headless, installer defaults)..."

    $headlessSucceeded = $true
    $headlessExitCode = 1

    try {
        & bun $setupScript --headless --profile codex-5.3-all --mode balanced
        $headlessExitCode = if ($LASTEXITCODE -is [int]) { $LASTEXITCODE } else { 0 }
        if ($headlessExitCode -ne 0) {
            $headlessSucceeded = $false
        }
    } catch {
        $headlessSucceeded = $false
    }

    if (($headlessExitCode -ne 0) -or (-not $headlessSucceeded)) {
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
            if ($null -eq $previousInstallerMode) {
                Remove-Item Env:OCS_SETUP_INSTALLER_MODE -ErrorAction SilentlyContinue
            } else {
                $env:OCS_SETUP_INSTALLER_MODE = $previousInstallerMode
            }
            exit 1
        }
    }

    Write-Output "Auto setup completed."
    if ($null -eq $previousInstallerMode) {
        Remove-Item Env:OCS_SETUP_INSTALLER_MODE -ErrorAction SilentlyContinue
    } else {
        $env:OCS_SETUP_INSTALLER_MODE = $previousInstallerMode
    }
}

Write-Output ""
Write-Output "opencode-multi-auth - Plugin Installer"
Write-Output "--------------------------------------"

$relaunchHandled = [bool](Ensure-PowerShellRuntime)
if ($relaunchHandled) {
    return
}
Ensure-Bun
Ensure-WindowsShellEnv

$rootDir = (Resolve-Path ".").Path
$forceLocalSource = (($env:OCS_FORCE_LOCAL_SOURCE ?? "0") -eq "1")
$isLocalSource = $false
$hasLocalSourceMarkers =
    (Test-Path (Join-Path $rootDir "plugins\opencode-multi-auth\package.json")) -and
    (Test-Path (Join-Path $rootDir "scripts\setup.js")) -and
    (Test-Path (Join-Path $rootDir "configs"))

if ($forceLocalSource) {
    if (-not $hasLocalSourceMarkers) {
        Write-Error "OCS_FORCE_LOCAL_SOURCE=1 set, but local source markers are missing in $rootDir."
        exit 1
    }
    $isLocalSource = $true
    Write-Warning "OCS_FORCE_LOCAL_SOURCE=1 enabled. Using local workspace plugin source."
}

$version = "local-source"

if ($isLocalSource) {
    $PLUGIN_DIR = Join-Path $rootDir "plugins\opencode-multi-auth"
} else {
    $PLUGIN_DIR = Join-Path $env:USERPROFILE ".config\opencode\plugins\opencode-multi-auth"
}

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
    $localBundlePath = $env:OCS_LOCAL_BUNDLE_PATH
    $resolvedLocalBundle = $null
    if ($localBundlePath) {
        $resolvedLocalBundle = Resolve-AbsolutePathSafe -BasePath $rootDir -Candidate $localBundlePath
        if (-not (Test-Path $resolvedLocalBundle)) {
            Write-Error "OCS_LOCAL_BUNDLE_PATH not found: $localBundlePath"
            exit 1
        }

        Write-Output "OCS_LOCAL_BUNDLE_PATH detected. Skipping GitHub auth and repo access checks."
    }

    Write-Output ""
    if (-not $resolvedLocalBundle) {
        Write-Output "Resolving GitHub auth..."
        $token = [string](Resolve-Token)
        $script:ResolvedReleaseToken = $token

        Write-Output ""
        Write-Output "Verifying repo access..."
        $hasRepoAccess = [bool](Test-RepoAccess -Token $token -SuppressLandingPage)
        if (-not $hasRepoAccess) {
            Write-Warning "Access check failed with current token. Retrying with fresh authentication..."

            if (Test-Path $TOKEN_FILE) {
                try {
                    Remove-Item -Path $TOKEN_FILE -Force -ErrorAction Stop
                    Write-Host "Cleared cached token at $TOKEN_FILE"
                } catch {
                    Write-Warning "Could not clear cached token: $($_.Exception.Message)"
                }
            }

            $token = [string](Resolve-Token -SkipTokenCache)
            $script:ResolvedReleaseToken = $token
            $hasRepoAccess = [bool](Test-RepoAccess -Token $token)
        }

        if (-not $hasRepoAccess) {
            Write-Output "Installation stopped. Complete access purchase/activation, then rerun installer."
            return
        }
    }

    Write-Output ""
    Write-Output "Preparing plugin bundle source..."

    if (-not (Test-Path $TMP_DIR)) {
        New-Item -ItemType Directory -Force $TMP_DIR | Out-Null
    }
    $tarName = "plugin-bundle.tar.gz"
    $tarPath = Join-Path $TMP_DIR $tarName

    if ($resolvedLocalBundle) {
        Write-Output "Using local bundle: $resolvedLocalBundle"
        Copy-Item -Path $resolvedLocalBundle -Destination $tarPath -Force
        $resolvedBundleName = [System.IO.Path]::GetFileName($resolvedLocalBundle)
        Write-Output "Resolved bundle: $resolvedBundleName"
    } else {
        Write-Output ""
        if ($REQUESTED_VERSION) {
            Write-Output "Downloading plugin bundle v$REQUESTED_VERSION from $GITHUB_SOURCE_REPO@$GITHUB_SOURCE_BRANCH..."
        } else {
            Write-Output "Downloading plugin bundle from $GITHUB_SOURCE_REPO@$GITHUB_SOURCE_BRANCH..."
        }
        Write-Output ""
        Write-Output "Downloading $tarName..."
        $resolvedBundleName = Get-PluginBundleFromAssets -Token $token -OutPath $tarPath
        if ($resolvedBundleName) {
            Write-Output "Resolved bundle: $resolvedBundleName"
        }
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
        Extract-TarGz -ArchivePath $tarName -Destination "./extract" -StripFirstComponent
    } finally {
        Pop-Location
    }

    $pluginSource = $extractTmp
    if (-not (Test-Path (Join-Path $pluginSource "package.json"))) {
        Write-Error "Extraction failed: package.json not found in plugin bundle."
        exit 1
    }

    try {
        $sourcePkg = Get-Content (Join-Path $pluginSource "package.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($sourcePkg.version) { $version = "$($sourcePkg.version)-$GITHUB_SOURCE_BRANCH" }
    } catch {
        $version = "$GITHUB_SOURCE_BRANCH"
    }

    Copy-Item -Path "$pluginSource\*" -Destination $PLUGIN_DIR -Recurse -Force

    if (-not (Test-Path (Join-Path $PLUGIN_DIR "package.json"))) {
        Write-Error "Installation failed: package.json not found in $PLUGIN_DIR after extraction."
        exit 1
    }
}

Write-Output "opencode-multi-auth installed to $PLUGIN_DIR"
$pluginFullPath = (Resolve-Path $PLUGIN_DIR).Path
Apply-InstallerDefaults -PluginPath $pluginFullPath
Write-Output "Installing dependencies..."
Invoke-BunInstallWithRetry -Directory $pluginFullPath -MaxAttempts 5

Invoke-AutoSetup -IsLocalSource:$isLocalSource
Ensure-OpencodePathEntries

if (Test-Path $TMP_DIR) {
    Remove-Item -Recurse -Force $TMP_DIR -ErrorAction SilentlyContinue
}

Write-Output ""
Write-Output "opencode-multi-auth $version installed to $PLUGIN_DIR"
Write-Output ""
Write-Output "Checking global ocs command..."
if (-not (Ensure-OcsCommand -PluginPath $PLUGIN_DIR -BasePath $rootDir -IsLocalSource:$isLocalSource)) {
    $bunBin = Join-Path $env:USERPROFILE ".bun\bin"
    Write-Warning "ocs command still unavailable after auto-install attempts."
    Write-Warning "Manual fallback: clone private suite repo, then run bun install -g <repo-path>."
    Write-Warning "If needed, add to PATH: $bunBin (and open a new terminal)"
}
Write-Output ""
Ensure-OpencodePathEntries
Write-Output "Checking opencode command..."
$opencodeCommand = Get-Command opencode -ErrorAction SilentlyContinue
if (-not $opencodeCommand) {
    if (Install-OpencodeShimFromBun) {
        $opencodeCommand = Get-Command opencode -ErrorAction SilentlyContinue
    }
}

if ($opencodeCommand) {
    Write-Output "opencode verification passed."
} else {
    Write-Warning "opencode command not found. Skipping heavy auto-recovery to avoid long waits."
    Write-Output "Manual check: opencode --version"
}
Write-Output ""
Write-Output "   Next steps:"
Write-Output "   1. Configure profile globally: ocs setup:profile"
Write-Output "   2. Configure preferences: ocs prefs (optional, if needed for advanced users)"
Write-Output "   3. Add account via: opencode auth login"
Write-Output "   4. Running Opencode via web UI:"
Write-Output "      opencode web --port 8089"
Write-Output ""
