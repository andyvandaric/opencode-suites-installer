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
$INSTALLER_SOURCE_BRANCH_HINT = "main"
$INFERRED_INSTALLER_SOURCE_BRANCH = ""

$invocationLine = $MyInvocation.Line
if ($invocationLine -and $invocationLine -match "raw\.githubusercontent\.com/andyvandaric/opencode-suites-installer/(.+?)/install\.ps1") {
    $INFERRED_INSTALLER_SOURCE_BRANCH = $matches[1]
}

if (-not $INFERRED_INSTALLER_SOURCE_BRANCH) {
    try {
        $currentProcess = Get-CimInstance Win32_Process -Filter "ProcessId = $PID" -ErrorAction Stop
        $parentId = [int]$currentProcess.ParentProcessId
        if ($parentId -gt 0) {
            $parentProcess = Get-CimInstance Win32_Process -Filter "ProcessId = $parentId" -ErrorAction SilentlyContinue
            if ($parentProcess -and $parentProcess.CommandLine -match "raw\.githubusercontent\.com/andyvandaric/opencode-suites-installer/(.+?)/install\.ps1") {
                $INFERRED_INSTALLER_SOURCE_BRANCH = $matches[1]
            }
        }
    } catch {
        # best-effort branch inference; keep fallback chain below
    }
}

$REQUESTED_VERSION = if ($Version) { $Version.TrimStart('v') } elseif ($env:OCS_VERSION) { $env:OCS_VERSION.TrimStart('v') } else { "" }
$GITHUB_SOURCE_BRANCH = if ($SourceBranch) { $SourceBranch } elseif ($env:OCS_RELEASE_BRANCH) { $env:OCS_RELEASE_BRANCH } elseif ($INFERRED_INSTALLER_SOURCE_BRANCH) { $INFERRED_INSTALLER_SOURCE_BRANCH } elseif ($REQUESTED_VERSION) { "main" } else { $INSTALLER_SOURCE_BRANCH_HINT }
$DEFAULT_RELEASE_BRANCH = if ($env:OCS_FALLBACK_RELEASE_BRANCH) { $env:OCS_FALLBACK_RELEASE_BRANCH } else { $GITHUB_SOURCE_BRANCH }
$INSTALLER_DEFAULT_PROFILE = "gpt-5.4-best-perform"
$INSTALLER_DEFAULT_MODE = "performance"
$ACCESS_LANDING_PAGE = "https://wa.me/6281289731212?text=Mau%20order%20OCS%20nya%2C%20mohon%20infonya%20ya"
$script:ResolvedReleaseToken = ""
$script:ResolvedSourceBranch = $GITHUB_SOURCE_BRANCH
$TMP_DIR = [System.IO.Path]::Combine(
    [System.IO.Path]::GetTempPath(),
    "ocs-install-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
)
$script:PathResolutionRunId = [System.Guid]::NewGuid().ToString('N')
$script:PathResolutionDiagnosticFile = [System.IO.Path]::Combine($TMP_DIR, 'diagnostics', "path-resolution-$($script:PathResolutionRunId).log")

function Get-ProgressNarrationThresholdMilliseconds {
    param([string]$Channel)

    switch ($Channel) {
        'install' { return 3000 }
        'doctor' { return 5000 }
        'index' { return 5000 }
        'release' { return 8000 }
        default { return 4000 }
    }
}

function Get-ProgressNarrationMessages {
    param(
        [string]$Channel,
        [string]$Scenario = 'default'
    )

    switch ("$Channel::$Scenario") {
        'install::dependency-install' {
            return @(
                'Installing runtime dependencies so OCS commands behave consistently in new shells.',
                'Package manager work can stay quiet for a moment while downloads and lock checks finish.',
                'Once this step completes, plugin commands and shims should be ready to use.'
            )
        }
        'install::setup-profile' {
            return @(
                'Applying your selected OCS profile and runtime defaults.',
                'OCS is keeping account state while refreshing the managed config surface.',
                'You will be able to use the updated profile as soon as this setup step completes.'
            )
        }
        'install::cocoindex-bootstrap' {
            return @(
                'Checking CocoIndex support for this project session.',
                'If CocoIndex is already healthy, OCS will reuse it instead of rebuilding from scratch.',
                'Python and MCP checks can take a little longer on fresh environments.'
            )
        }
        'install::runtime-bootstrap' {
            return @(
                'Checking native support tools that OCS uses for command routing and recovery.',
                'If a healthy runtime already exists, OCS will reuse it instead of rebuilding from scratch.',
                'First-time native tool setup can pause briefly while installers and shell hooks are verified.'
            )
        }
        default {
            return @(
                'Still working: preparing your OCS runtime and profile wiring.',
                'This can take a bit on first install because package tools are being checked.',
                'OCS is validating command paths so new shells work without manual fixes.'
            )
        }
    }
}

function Test-ProgressNarrationEnabled {
    if ($env:OCS_PROGRESS_TEXT -eq '0') {
        return $false
    }

    if ($env:OCS_QUIET -eq '1') {
        return $false
    }

    if (("$($env:CI)".ToLowerInvariant()) -eq 'true') {
        return $false
    }

    try {
        if ([Console]::IsOutputRedirected) {
            return $false
        }
    } catch {
        return $false
    }

    return $true
}

function Resolve-ProgressNarrationHost {
    if ($PwshPath -and (Test-Path $PwshPath)) {
        return $PwshPath
    }

    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwsh) {
        return $pwsh.Source
    }

    $powershell = Get-Command powershell -ErrorAction SilentlyContinue
    if ($powershell) {
        return $powershell.Source
    }

    return $null
}

function Start-ProgressNarration {
    param(
        [string]$Channel,
        [string]$Scenario = 'default',
        [int]$ThresholdMilliseconds = (Get-ProgressNarrationThresholdMilliseconds -Channel $Channel),
        [int]$IntervalMilliseconds = 4000
    )

    if (-not (Test-ProgressNarrationEnabled)) {
        return $null
    }

    $messages = Get-ProgressNarrationMessages -Channel $Channel -Scenario $Scenario
    if (-not $messages -or $messages.Count -eq 0) {
        return $null
    }

    $hostCommand = Resolve-ProgressNarrationHost
    if (-not $hostCommand) {
        return $null
    }

    $json = ($messages | ConvertTo-Json -Compress)
    $progressScript = @"
`$messages = ConvertFrom-Json @'
$json
'@
Start-Sleep -Milliseconds $ThresholdMilliseconds
`$index = 0
while (`$true) {
    [Console]::WriteLine("   ⏳ " + `$messages[`$index % `$messages.Count])
    `$index += 1
    Start-Sleep -Milliseconds $IntervalMilliseconds
}
"@

    try {
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($progressScript))
        $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $hostCommand
        $startInfo.Arguments = "-NoProfile -EncodedCommand $encoded"
        $startInfo.UseShellExecute = $false
        return [System.Diagnostics.Process]::Start($startInfo)
    } catch {
        return $null
    }
}

function Stop-ProgressNarration {
    param([System.Diagnostics.Process]$Process)

    if (-not $Process) {
        return
    }

    try {
        if (-not $Process.HasExited) {
            $Process.Kill()
            $null = $Process.WaitForExit(250)
        }
    } catch {
        # best effort only
    } finally {
        try {
            $Process.Dispose()
        } catch {
            # ignore dispose issues
        }
    }
}

function Is-EnvPathSafe {
    param([string]$Value)

    if (-not $Value) {
        return $false
    }

    $trimmed = $Value.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        return $false
    }

    if (-not [System.IO.Path]::IsPathRooted($trimmed)) {
        return $false
    }

    if ($trimmed -match '[\*\?]') {
        return $false
    }

    return $true
}

function Get-EnvFallbackCandidatePath {
    param(
        [string]$RelativePath,
        [System.Environment+SpecialFolder]$FallbackFolder
    )

    $basePath = [System.Environment]::GetFolderPath($FallbackFolder)
    if (-not [string]::IsNullOrWhiteSpace($basePath)) {
        $basePath = $basePath.Trim()
        if ($RelativePath) {
            return Join-Path $basePath $RelativePath
        }
        return $basePath
    }

    return $null
}

function Determine-PathResolutionReason {
    param(
        [string]$PrimaryPath,
        [string]$FallbackPath
    )

    $primary = if ($PrimaryPath) { $PrimaryPath.Trim() } else { '' }
    $fallback = if ($FallbackPath) { $FallbackPath.Trim() } else { '' }
    $systemRoot = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Windows)

    if ($primary) {
        if ($primary -match '[\*\?]') {
            return 'E_FALLBACK_INVALID'
        }
        if ($primary -match 'PolicyDefinitions|GroupPolicy') {
            return 'E_POLICY_BLOCKED'
        }
        if ($systemRoot -and $primary.StartsWith($systemRoot, [System.StringComparison]::InvariantCultureIgnoreCase)) {
            return 'E_HOME_NOT_WRITABLE'
        }
        if (-not (Is-EnvPathSafe $primary)) {
            return 'E_FALLBACK_INVALID'
        }
        return 'E_HOME_RESOLVED'
    }

    if ($fallback) {
        if ($fallback -match '[\*\?]') {
            return 'E_FALLBACK_INVALID'
        }
        if ($fallback -match 'PolicyDefinitions|GroupPolicy') {
            return 'E_POLICY_BLOCKED'
        }
        if ($systemRoot -and $fallback.StartsWith($systemRoot, [System.StringComparison]::InvariantCultureIgnoreCase)) {
            return 'E_HOME_NOT_WRITABLE'
        }
        if (-not (Is-EnvPathSafe $fallback)) {
            return 'E_FALLBACK_INVALID'
        }
        return 'E_HOME_EMPTY'
    }

    return 'E_HOME_UNRESOLVED'
}

function Get-ShortReasonForPathCode {
    param([string]$ReasonCode)

    switch ($ReasonCode) {
        'E_HOME_EMPTY' { return 'Home environment variables resolved to an empty or missing value while fallback is available.' }
        'E_HOME_RESOLVED' { return 'Primary home path is validated as safe for installer artifacts.' }
        'E_HOME_UNRESOLVED' { return 'Unable to resolve a valid home or fallback path for installer artifacts.' }
        'E_HOME_NOT_WRITABLE' { return 'Resolved fallback path is located in a system area that is not user-writable.' }
        'E_FALLBACK_INVALID' { return 'Fallback path contains invalid, wildcard, or unsafe characters.' }
        'E_POLICY_BLOCKED' { return 'Resolved path appears to be managed by Windows policy and cannot be trusted.' }
        default { return 'Home path resolution guard blocked an unsafe path.' }
    }
}

function Emit-PathResolutionDiagnostic {
    param(
        [string]$Context,
        [string]$ReasonCode,
        [string]$PrimaryPath,
        [string]$FallbackPath,
        [string]$ShortReason
    )

    $psVersion = $PSVersionTable.PSVersion.ToString()
    $hostName = [System.Environment]::MachineName
    $runId = $script:PathResolutionRunId
    $diagFile = $script:PathResolutionDiagnosticFile
    $shortReasonValue = if ($ShortReason) { $ShortReason } else { Get-ShortReasonForPathCode -ReasonCode $ReasonCode }
    $primaryDisplay = if ([string]::IsNullOrWhiteSpace($PrimaryPath)) { '<missing>' } else { $PrimaryPath.Trim() }
    $fallbackDisplay = if ([string]::IsNullOrWhiteSpace($FallbackPath)) { '<missing>' } else { $FallbackPath.Trim() }

    $payload = @{
        marker = '[OCS_INSTALLER_PATH_RESOLUTION_FAILED]'
        reasonCode = $ReasonCode
        shortReason = "${Context}: $shortReasonValue"
        primaryPath = $primaryDisplay
        fallbackPath = $fallbackDisplay
        host = $hostName
        psVersion = $psVersion
        runId = $runId
        diagnosticFilePath = $diagFile
        context = $Context
        timestamp = (Get-Date).ToString('o')
        envSnapshot = @{
            USERPROFILE = $env:USERPROFILE
            HOME = $env:HOME
        }
    }

    $diagDir = Split-Path $diagFile -Parent
    if (-not (Test-Path $diagDir)) {
        New-Item -ItemType Directory -Path $diagDir -Force | Out-Null
    }

    $payload | ConvertTo-Json -Depth 5 | Set-Content -Path $diagFile -Encoding UTF8

    $fieldStrings = @(
        "reasonCode=$ReasonCode",
        "shortReason=$($payload.shortReason)",
        "primaryPath=$primaryDisplay",
        "fallbackPath=$fallbackDisplay",
        "host=$hostName",
        "psVersion=$psVersion",
        "runId=$runId",
        "diagnosticFilePath=$diagFile"
    )

    Write-Error -Message "[OCS_INSTALLER_PATH_RESOLUTION_FAILED] $($fieldStrings -join '; ')" -ErrorAction Continue
    Write-Error -Message "Actions: 1) Verify USERPROFILE/HOME 2) Ensure fallback path is writable 3) Rerun with OCS_USER_HOME override 4) Attach diagnostic file for support: $diagFile" -ErrorAction Continue
}

function Ensure-EnvPathValue {
    param(
        [string]$Value,
        [string]$Context,
        [string]$FallbackHint = '',
        [string]$FallbackPath = '',
        [switch]$Fail
    )

    $isSafe = Is-EnvPathSafe $Value
    $reasonCode = Determine-PathResolutionReason -PrimaryPath $Value -FallbackPath $FallbackPath
    $restrictedReasons = @('E_HOME_NOT_WRITABLE', 'E_POLICY_BLOCKED', 'E_FALLBACK_INVALID')

    if ($isSafe -and (-not ($restrictedReasons -contains $reasonCode))) {
        return $true
    }

    $detail = if ($FallbackHint) { " ($FallbackHint)" } else { '' }
    $message = "Hybrid path guard: $Context resolved to an empty or unsafe path.$detail Please verify USERPROFILE/HOME or the fallback folder."

    if ($Fail) {
        Write-Error -Message $message -ErrorAction Continue
        Emit-PathResolutionDiagnostic -Context $Context -ReasonCode $reasonCode -PrimaryPath $Value -FallbackPath $FallbackPath -ShortReason (Get-ShortReasonForPathCode -ReasonCode $reasonCode)
    } else {
        Write-Warning $message
    }

    return $false
}

function Get-SafeEnvValue {
    param(
        [string[]]$Names,
        [System.Environment+SpecialFolder]$FallbackFolder
    )

    foreach ($name in $Names) {
        if (-not $name) { continue }
        $value = [System.Environment]::GetEnvironmentVariable($name)
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value.Trim()
        }
    }

    if ($PSBoundParameters.ContainsKey('FallbackFolder')) {
        $fallbackPath = [System.Environment]::GetFolderPath($FallbackFolder)
        if (-not [string]::IsNullOrWhiteSpace($fallbackPath)) {
            return $fallbackPath
        }
    }

    return $null
}

function Join-SafeEnvPath {
    param(
        [string[]]$EnvNames,
        [string]$RelativePath,
        [System.Environment+SpecialFolder]$FallbackFolder
    )

    $rootPath = if ($PSBoundParameters.ContainsKey('FallbackFolder')) {
        Get-SafeEnvValue -Names $EnvNames -FallbackFolder $FallbackFolder
    } else {
        Get-SafeEnvValue -Names $EnvNames
    }
    if (-not (Is-EnvPathSafe $rootPath)) {
        return $null
    }

    if (-not $RelativePath) {
        return $rootPath
    }

    return Join-Path $rootPath $RelativePath
}

function Get-InstallerPathContract {
    $homeDir = Get-SafeEnvValue -Names @("USERPROFILE", "HOME") -FallbackFolder ([System.Environment+SpecialFolder]::UserProfile)
    $explicitTargetConfigDir = [System.Environment]::GetEnvironmentVariable("OPENCODE_CONFIG_DIR")
    if (-not [string]::IsNullOrWhiteSpace($explicitTargetConfigDir)) {
        $explicitTargetConfigDir = $explicitTargetConfigDir.Trim()
    }

    if ($explicitTargetConfigDir) {
        $configHome = Split-Path -Parent $explicitTargetConfigDir
        $targetConfigDir = $explicitTargetConfigDir
    } else {
        $configHome = Get-SafeEnvValue -Names @("XDG_CONFIG_HOME")
        if ([string]::IsNullOrWhiteSpace($configHome)) {
            $configHome = Join-Path $homeDir ".config"
        }
        $targetConfigDir = Join-Path $configHome "opencode"
    }

    $skillsRoot = Join-Path $targetConfigDir "skills"
    $pluginsRoot = Join-Path $targetConfigDir "plugins"
    $pluginDir = Join-Path $pluginsRoot "opencode-multi-auth"
    $shellSnippetDir = Join-Path $targetConfigDir "shell"
    $cavemanSkillDir = Join-Path $skillsRoot "caveman"

    return [pscustomobject]@{
        HomeDir = $homeDir
        ConfigHome = $configHome
        TargetConfigDir = $targetConfigDir
        SkillsRoot = $skillsRoot
        PluginsRoot = $pluginsRoot
        PluginDir = $pluginDir
        TokenFile = Join-Path $homeDir '.opencode-suites\.token'
        NativeBinDir = Join-Path $homeDir '.opencode\bin'
        LocalBinDir = Join-Path $homeDir '.local\bin'
        ShellSnippetDir = $shellSnippetDir
        ShellSnippetPath = Join-Path $shellSnippetDir 'ocs-path.sh'
        RtkPluginPath = Join-Path $pluginsRoot 'rtk.ts'
        CavemanSkillDir = $cavemanSkillDir
        CavemanSkillPath = Join-Path $cavemanSkillDir 'SKILL.md'
        OcsCliCjsPath = Join-Path $targetConfigDir 'bin\ocs.cjs'
        OcsCliJsPath = Join-Path $targetConfigDir 'bin\ocs.js'
        PluginOcsCliCjsPath = Join-Path $pluginDir 'bin\ocs.cjs'
        PluginOcsCliJsPath = Join-Path $pluginDir 'bin\ocs.js'
    }
}

$script:InstallerPathContract = Get-InstallerPathContract
$PLUGIN_DIR = $script:InstallerPathContract.PluginDir
$TOKEN_FILE = $script:InstallerPathContract.TokenFile

$tokenFallbackHint = 'env: USERPROFILE/HOME; fallback: UserProfile special folder'
$tokenFallbackPath = Get-EnvFallbackCandidatePath -RelativePath '.opencode-suites\.token' -FallbackFolder ([System.Environment+SpecialFolder]::UserProfile)
if (-not (Ensure-EnvPathValue -Value $TOKEN_FILE -Context 'token cache file path' -FallbackHint $tokenFallbackHint -FallbackPath $tokenFallbackPath -Fail)) {
    exit 1
}

function Resolve-PwshPath {
    $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwshCmd -and $pwshCmd.Path) {
        return $pwshCmd.Path
    }

    $candidates = @(
        (Join-SafeEnvPath -EnvNames @("ProgramFiles", "ProgramW6432", "ProgramFiles(x86)") -RelativePath 'PowerShell\7\pwsh.exe' -FallbackFolder ([System.Environment+SpecialFolder]::ProgramFiles)),
        (Join-SafeEnvPath -EnvNames @("LOCALAPPDATA", "APPDATA", "USERPROFILE", "HOME") -RelativePath 'Microsoft\PowerShell\7\pwsh.exe' -FallbackFolder ([System.Environment+SpecialFolder]::LocalApplicationData)),
        (Join-SafeEnvPath -EnvNames @("USERPROFILE", "HOME") -RelativePath 'scoop\shims\pwsh.exe' -FallbackFolder ([System.Environment+SpecialFolder]::UserProfile))
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

        $relaunchUrl = "https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/$GITHUB_SOURCE_BRANCH/install.ps1"
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
        (Join-SafeEnvPath -EnvNames @("ProgramFiles", "ProgramW6432", "ProgramFiles(x86)") -RelativePath 'GitHub CLI' -FallbackFolder ([System.Environment+SpecialFolder]::ProgramFiles)),
        (Join-SafeEnvPath -EnvNames @("LOCALAPPDATA", "APPDATA", "USERPROFILE", "HOME") -RelativePath 'Programs\GitHub CLI' -FallbackFolder ([System.Environment+SpecialFolder]::LocalApplicationData))
    )

    foreach ($ghBin in $ghBinCandidates) {
        if ($ghBin -and (Test-Path (Join-Path $ghBin "gh.exe")) -and ($env:PATH -notlike "*$ghBin*")) {
            $env:PATH = "$ghBin;$env:PATH"
        }
    }

    $opencodeBinCandidates = @(
        (Join-SafeEnvPath -EnvNames @("USERPROFILE", "HOME") -RelativePath '.opencode\bin' -FallbackFolder ([System.Environment+SpecialFolder]::UserProfile)),
        (Join-SafeEnvPath -EnvNames @("USERPROFILE", "HOME") -RelativePath '.bun\bin' -FallbackFolder ([System.Environment+SpecialFolder]::UserProfile))
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

function Get-PythonPathCandidates {
    $allCandidates = @(
        (Join-SafeEnvPath -EnvNames @("USERPROFILE", "HOME") -RelativePath '.local\bin' -FallbackFolder ([System.Environment+SpecialFolder]::UserProfile)),
        (Join-SafeEnvPath -EnvNames @("USERPROFILE", "HOME") -RelativePath '.local\pipx\bin' -FallbackFolder ([System.Environment+SpecialFolder]::UserProfile)),
        (Join-SafeEnvPath -EnvNames @("USERPROFILE", "HOME") -RelativePath '.local\share\uv\tools\bin' -FallbackFolder ([System.Environment+SpecialFolder]::UserProfile)),
        (Join-SafeEnvPath -EnvNames @("APPDATA", "LOCALAPPDATA", "USERPROFILE", "HOME") -RelativePath 'Python\Scripts' -FallbackFolder ([System.Environment+SpecialFolder]::ApplicationData))
    )

    $pythonRoots = @(
        (Join-SafeEnvPath -EnvNames @("LOCALAPPDATA", "APPDATA", "USERPROFILE", "HOME") -RelativePath 'Programs\Python' -FallbackFolder ([System.Environment+SpecialFolder]::LocalApplicationData)),
        (Join-SafeEnvPath -EnvNames @("APPDATA", "LOCALAPPDATA", "USERPROFILE", "HOME") -RelativePath 'Python' -FallbackFolder ([System.Environment+SpecialFolder]::ApplicationData))
    )

    foreach ($root in $pythonRoots) {
        if (-not $root -or -not (Test-Path $root)) {
            continue
        }

        Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $allCandidates += $_.FullName
            $allCandidates += (Join-Path $_.FullName "Scripts")
        }
    }

    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $result = @()
    foreach ($candidate in $allCandidates) {
        if (-not $candidate) { continue }
        $normalized = $candidate.TrimEnd("\\")
        if ($seen.Add($normalized)) {
            $result += $normalized
        }
    }

    return $result
}

function Get-NodeGlobalPaths {
    $paths = @()
    $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
    if (-not $npmCmd) {
        return $paths
    }

    try {
        $prefix = & npm config get prefix 2>$null
    } catch {
        $prefix = ""
    }

    $prefix = $prefix.Trim()
    if (-not $prefix) {
        return $paths
    }

    $normalized = $prefix.TrimEnd('\', '/')
    if (-not $normalized) {
        return $paths
    }

    $paths += $normalized

    return $paths
}

function Get-PnpmBinDirectories {
    $paths = @()
    $pnpmCmd = Get-Command pnpm -ErrorAction SilentlyContinue
    if ($pnpmCmd) {
        $binDir = Split-Path -Parent $pnpmCmd.Source
        if ($binDir) {
            $paths += $binDir
        }
    }
    return $paths
}

function Ensure-OpencodePathEntries {
    $pathCandidates = @(
        (Join-SafeEnvPath -EnvNames @("USERPROFILE", "HOME") -RelativePath '.opencode\bin' -FallbackFolder ([System.Environment+SpecialFolder]::UserProfile)),
        (Join-SafeEnvPath -EnvNames @("USERPROFILE", "HOME") -RelativePath '.bun\bin' -FallbackFolder ([System.Environment+SpecialFolder]::UserProfile)),
        (Join-SafeEnvPath -EnvNames @("USERPROFILE", "HOME") -RelativePath '.local\bin' -FallbackFolder ([System.Environment+SpecialFolder]::UserProfile)),
        (Join-SafeEnvPath -EnvNames @("USERPROFILE", "HOME") -RelativePath '.local\pipx\bin' -FallbackFolder ([System.Environment+SpecialFolder]::UserProfile)),
        (Join-SafeEnvPath -EnvNames @("USERPROFILE", "HOME") -RelativePath '.local\share\uv\tools\bin' -FallbackFolder ([System.Environment+SpecialFolder]::UserProfile))
    )

    $pathCandidates += @(
        (Join-SafeEnvPath -EnvNames @("USERPROFILE", "HOME") -RelativePath '.node\bin' -FallbackFolder ([System.Environment+SpecialFolder]::UserProfile)),
        (Join-SafeEnvPath -EnvNames @("USERPROFILE", "HOME") -RelativePath '.npm\bin' -FallbackFolder ([System.Environment+SpecialFolder]::UserProfile)),
        (Join-SafeEnvPath -EnvNames @("USERPROFILE", "HOME") -RelativePath '.npm-global\bin' -FallbackFolder ([System.Environment+SpecialFolder]::UserProfile)),
        (Join-SafeEnvPath -EnvNames @("USERPROFILE", "HOME") -RelativePath '.pnpm\bin' -FallbackFolder ([System.Environment+SpecialFolder]::UserProfile)),
        (Join-SafeEnvPath -EnvNames @("USERPROFILE", "HOME") -RelativePath '.local\share\pnpm\bin' -FallbackFolder ([System.Environment+SpecialFolder]::UserProfile))
    )

    $pathCandidates += Get-NodeGlobalPaths
    $pathCandidates += Get-PnpmBinDirectories

    $pathCandidates += Get-PythonPathCandidates

    foreach ($candidate in $pathCandidates) {
        Add-PathEntryToUserPath -PathEntry $candidate
    }

    Refresh-SessionPath
}

function Find-CavemanSkillSource {
    $homeRoot = $script:InstallerPathContract.HomeDir

    $candidates = @(
        (Join-Path $homeRoot '.agents\skills\caveman'),
        (Join-Path $homeRoot '.claude\plugins\marketplaces\caveman\skills\caveman'),
        (Join-Path $homeRoot '.claude\plugins\marketplaces\caveman\plugins\caveman\skills\caveman')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path (Join-Path $candidate 'SKILL.md')) {
            return $candidate
        }
    }

    $cacheRoot = Join-Path $homeRoot '.claude\plugins\cache\caveman\caveman'
    if (Test-Path $cacheRoot) {
        Get-ChildItem -Path $cacheRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $nested = @(
                (Join-Path $_.FullName 'skills\caveman'),
                (Join-Path $_.FullName 'plugins\caveman\skills\caveman')
            )
            foreach ($candidate in $nested) {
                if (Test-Path (Join-Path $candidate 'SKILL.md')) {
                    return $candidate
                }
            }
        }
    }

    return $null
}

function Sync-CavemanSkillMarker {
    $skillsRoot = $script:InstallerPathContract.SkillsRoot
    $targetDir = $script:InstallerPathContract.CavemanSkillDir
    $targetMarker = $script:InstallerPathContract.CavemanSkillPath
    if (Test-Path $targetMarker) {
        return $true
    }

    $sourceDir = Find-CavemanSkillSource
    if (-not $sourceDir) {
        return $false
    }

    New-Item -ItemType Directory -Force -Path $skillsRoot | Out-Null
    if (Test-Path $targetDir) {
        Remove-Item -Path $targetDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    Copy-Item -Path $sourceDir -Destination $targetDir -Recurse -Force
    return (Test-Path $targetMarker)
}

function Ensure-AdjunctRuntimeReady {
    $nativeBin = $script:InstallerPathContract.NativeBinDir
    if ($nativeBin) {
        Add-PathEntryToUserPath -PathEntry $nativeBin
        Refresh-SessionPath
    }

    $rtkPlugin = $script:InstallerPathContract.RtkPluginPath
    $cavemanMarker = $script:InstallerPathContract.CavemanSkillPath

    if (-not (Test-Path $cavemanMarker)) {
        if (Sync-CavemanSkillMarker) {
            Write-Output "Synced Caveman skill into target OpenCode skills dir: $(Split-Path -Parent $cavemanMarker)"
        }
    }

    $rtkReady = $false
    if ((Get-Command rtk -ErrorAction SilentlyContinue) -and (Test-Path $rtkPlugin)) {
        try {
            & rtk --version *> $null
            & rtk init --show *> $null
            & rtk gain *> $null
            if ($LASTEXITCODE -eq 0) {
                $rtkReady = $true
            }
        } catch {
            $rtkReady = $false
        }
    }

    if ($rtkReady) {
        Write-Output 'RTK runtime verification passed.'
    } else {
        Write-Warning "RTK runtime is not fully ready yet. Expected PATH entry: $nativeBin"
        Write-Output 'Verify manually: rtk --version ; rtk init --show ; rtk gain'
    }

    if (Test-Path $cavemanMarker) {
        Write-Output 'Caveman skill marker present after install.'
    } else {
        Write-Warning "Caveman skill marker missing after install: $cavemanMarker"
        Write-Output 'Verify manually: npx -y skills add JuliusBrussee/caveman -a opencode -s "*" -g -y'
    }
}

function Get-PythonRuntimeStatus {
    $candidates = @(
        @{ Name = "python"; Args = @("--version") },
        @{ Name = "python3"; Args = @("--version") },
        @{ Name = "py"; Args = @("-3", "--version") }
    )

    foreach ($candidate in $candidates) {
        if (-not (Get-Command $candidate.Name -ErrorAction SilentlyContinue)) {
            continue
        }

        try {
            $output = & $candidate.Name @($candidate.Args) 2>&1
            $versionLine = ($output | Select-Object -First 1)
            if ($versionLine) {
                return @{
                    Ready = $true
                    Command = $candidate.Name
                    Version = [string]$versionLine
                }
            }
        } catch {
            # continue probing
        }
    }

    return @{
        Ready = $false
        Command = ""
        Version = ""
    }
}

function Ensure-PythonRuntimeForAgents {
    $status = Get-PythonRuntimeStatus
    if ($status.Ready) {
        Write-Output "Python runtime ready: $($status.Version)"
        return $true
    }

    Write-Warning "Python runtime not found. Attempting auto-install for agent dependencies..."
    $installed = $false

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $wingetIds = @("Python.Python.3.12", "Python.Python.3.11")
        foreach ($wingetId in $wingetIds) {
            if ($installed) { break }
            try {
                & winget install --id $wingetId --exact --silent --accept-package-agreements --accept-source-agreements
                if ($LASTEXITCODE -eq 0) {
                    $installed = $true
                }
            } catch {
                $installed = $false
            }
        }
    }

    if ((-not $installed) -and (Get-Command choco -ErrorAction SilentlyContinue)) {
        try {
            & choco install python -y
            if ($LASTEXITCODE -eq 0) {
                $installed = $true
            }
        } catch {
            $installed = $false
        }
    }

    if ((-not $installed) -and (Get-Command scoop -ErrorAction SilentlyContinue)) {
        try {
            & scoop install python
            if ($LASTEXITCODE -eq 0) {
                $installed = $true
            }
        } catch {
            $installed = $false
        }
    }

    Refresh-SessionPath
    Ensure-OpencodePathEntries

    $status = Get-PythonRuntimeStatus
    if ($status.Ready) {
        Write-Output "Python runtime ready: $($status.Version)"
        return $true
    }

    Write-Warning "Python runtime is still unavailable. CocoIndex bootstrap may need manual Python installation."
    return $false
}

function Ensure-PnpmRuntime {
    if (Get-Command pnpm -ErrorAction SilentlyContinue) {
        Write-Output "pnpm already available."
        return $true
    }

    Write-Warning "pnpm not found. Bootstrapping via corepack/npm..."
    $bootstrapped = $false

    $corepackCmd = Get-Command corepack -ErrorAction SilentlyContinue
    if ($corepackCmd) {
        try {
            & corepack enable 2>$null
            & corepack prepare pnpm@latest --activate 2>$null
            if ($LASTEXITCODE -eq 0) { $bootstrapped = $true }
        } catch {
            Write-Warning "corepack bootstrap for pnpm failed: $($_.Exception.Message)"
        }
    }

    if ((-not $bootstrapped) -and (Get-Command npm -ErrorAction SilentlyContinue)) {
        try {
            & npm install -g pnpm *> $null
            if ($LASTEXITCODE -eq 0) { $bootstrapped = $true }
        } catch {
            Write-Warning "npm install -g pnpm failed: $($_.Exception.Message)"
        }
    }

    $npmPrefix = $null
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        try {
            $npmPrefix = (& npm config get prefix 2>$null).Trim()
        } catch {
            $npmPrefix = $null
        }
    }

    if ($npmPrefix) {
        $npmBin = Join-Path $npmPrefix 'bin'
        Add-PathEntryToUserPath -PathEntry $npmBin
    }

    Refresh-SessionPath

    if (Get-Command pnpm -ErrorAction SilentlyContinue) {
        Write-Output "pnpm ready for plugin workflows."
        return $true
    }

    Write-Warning "pnpm remains unavailable after auto-bootstrap. Manual install may be required."
    return $false
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

    if (-not (Ensure-EnvPathValue -Value $TOKEN_FILE -Context 'token cache file path' -FallbackHint 'env: USERPROFILE/HOME; fallback: UserProfile special folder')) {
        return
    }

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

    $tokenFileAvailable = Is-EnvPathSafe $TOKEN_FILE
    if ((-not $SkipTokenCache) -and $tokenFileAvailable -and (Test-Path $TOKEN_FILE)) {
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
            Write-Warning "You do not have OCS release access yet. Repo/branch: $GITHUB_SOURCE_REPO@$GITHUB_SOURCE_BRANCH"
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

    function Get-BranchAssets([string]$Branch) {
        $assetsUri = "https://api.github.com/repos/$GITHUB_SOURCE_REPO/contents/assets?ref=$Branch"
        return Invoke-RestMethod -Uri $assetsUri -Headers $headers -ErrorAction Stop
    }

    function Resolve-BundleFromAssets($Assets) {
        $Assets |
            Where-Object { $_.name -match '^opencode-config-suites-v(?<version>\d+\.\d+\.\d+)\.tar\.gz$' } |
            ForEach-Object {
                [PSCustomObject]@{
                    Asset   = $_
                    Version = [version]$Matches.version
                }
            } |
            Sort-Object Version -Descending
    }

    $resolvedBranch = $GITHUB_SOURCE_BRANCH
    $assets = Get-BranchAssets $resolvedBranch
    $bundle = Resolve-BundleFromAssets $assets

    if ($REQUESTED_VERSION) {
        $bundleName = "opencode-config-suites-v$REQUESTED_VERSION.tar.gz"
        Write-Output "Requested bundle asset: $bundleName"
        Write-Output "Checking branch $resolvedBranch for requested version..."
        $selectedBundle = $bundle | Where-Object { $_.Asset.name -eq $bundleName } | Select-Object -First 1
        if (-not $selectedBundle) {
            Write-Output "Requested version v$REQUESTED_VERSION not found on branch $resolvedBranch."
            Write-Output "Checking fallback branch $DEFAULT_RELEASE_BRANCH..."
            if ($resolvedBranch -eq $DEFAULT_RELEASE_BRANCH) {
                $fallbackAssets = $assets
            } else {
                $fallbackAssets = Get-BranchAssets $DEFAULT_RELEASE_BRANCH
            }

            $fallbackBundle = (Resolve-BundleFromAssets $fallbackAssets | Where-Object { $_.Asset.name -eq $bundleName } | Select-Object -First 1)
            if ($fallbackBundle) {
                Write-Warning "Requested version $REQUESTED_VERSION not found in assets/ for $GITHUB_SOURCE_REPO@$resolvedBranch. Falling back to $DEFAULT_RELEASE_BRANCH."
                $selectedBundle = $fallbackBundle
                $resolvedBranch = $DEFAULT_RELEASE_BRANCH
            } else {
                throw "Requested version $REQUESTED_VERSION not found in assets/ for $GITHUB_SOURCE_REPO@$resolvedBranch. Checked branches $resolvedBranch and $DEFAULT_RELEASE_BRANCH, and the asset is missing on both."
            }
        }
        $bundle = $selectedBundle
    } else {
        $bundle = $bundle | Select-Object -First 1
    }

    if (-not $bundle) {
        throw "No plugin bundle found in assets/ for $GITHUB_SOURCE_REPO@$resolvedBranch"
    }

    $bundleName = $bundle.Asset.name
    $script:ResolvedSourceBranch = $resolvedBranch
    Write-Output "Resolved bundle source branch: $($script:ResolvedSourceBranch)"
    Write-Output "Resolved bundle asset: $bundleName"

    $downloadHeaders = @{
        Authorization = "token $Token"
        Accept        = "application/vnd.github.raw"
    }
    $downloadUri = "https://api.github.com/repos/$GITHUB_SOURCE_REPO/contents/assets/${bundleName}?ref=$($script:ResolvedSourceBranch)"
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

    $systemTarPath = Join-SafeEnvPath -EnvNames @("SystemRoot", "windir") -RelativePath 'System32\tar.exe' -FallbackFolder ([System.Environment+SpecialFolder]::Windows)
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
    $bunBin = Join-SafeEnvPath -EnvNames @("USERPROFILE", "HOME") -RelativePath '.bun\bin' -FallbackFolder ([System.Environment+SpecialFolder]::UserProfile)
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

        # Detect whether curl.exe is available — fresh Windows installs may not have it.
        # Bun's official installer uses curl.exe by default but falls back to Invoke-RestMethod.
        # However, when curl.exe is completely absent, PowerShell throws a terminating error
        # that bypasses the fallback. Passing -DownloadWithoutCurl skips curl.exe entirely.
        $hasCurl = [bool](Get-Command curl.exe -ErrorAction SilentlyContinue)
        $bunInstallerArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $bunInstallerPath)
        if (-not $hasCurl) {
            $bunInstallerArgs += '-DownloadWithoutCurl'
            Write-Output "   curl.exe not found — using PowerShell native download for Bun installer."
        }

        $shellCmd = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
        & $shellCmd @bunInstallerArgs

        if ($LASTEXITCODE -ne 0) {
            throw "Bun installer exited with code $LASTEXITCODE"
        }
    } catch {
        Write-Error "Failed to auto-install Bun: $($_.Exception.Message)"
        Write-Error "Install Bun manually: irm bun.sh/install.ps1 -OutFile install-bun.ps1; .\install-bun.ps1 -DownloadWithoutCurl"
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
    $bunBin = Join-SafeEnvPath -EnvNames @("USERPROFILE", "HOME") -RelativePath '.bun\bin' -FallbackFolder ([System.Environment+SpecialFolder]::UserProfile)
    $preferredCmd = if ($bunBin) { Join-Path $bunBin "ocs.cmd" } else { $null }
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

    $helpOutput = & $commandToRun --help 2>$null | Out-String
    if ($LASTEXITCODE -ne 0) {
        return $false
    }

    if (-not $helpOutput -or -not $helpOutput.Contains("OpenCode Config Suites CLI")) {
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
            $progressProcess = Start-ProgressNarration -Channel 'install' -Scenario 'dependency-install'
            try {
                $bunOutput = & bun install -g $resolvedSource 2>&1
            } finally {
                Stop-ProgressNarration -Process $progressProcess
            }
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
    $baseAbsPath = Resolve-AbsolutePathSafe -BasePath $null -Candidate $BasePath

    $candidatePaths = @()
    if ($pluginAbsPath) {
        $candidatePaths += (Join-Path $pluginAbsPath "bin\ocs.cjs")
        $candidatePaths += (Join-Path $pluginAbsPath "bin\ocs.js")
    }
    if ($baseAbsPath) {
        $candidatePaths += (Join-Path $baseAbsPath "bin\ocs.cjs")
        $candidatePaths += (Join-Path $baseAbsPath "bin\ocs.js")
    }

    $ocsJs = $candidatePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $ocsJs) {
        return $false
    }

    $bunBin = Join-SafeEnvPath -EnvNames @("USERPROFILE", "HOME") -RelativePath '.bun\bin' -FallbackFolder ([System.Environment+SpecialFolder]::UserProfile)
    if (-not (Ensure-EnvPathValue -Value $bunBin -Context 'bun shim target directory' -FallbackHint 'env: USERPROFILE/HOME; fallback: UserProfile special folder')) {
        return $false
    }
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

function Resolve-OcsRuntimeEntrypoint {
    $candidatePaths = @(
        $script:InstallerPathContract.OcsCliCjsPath,
        $script:InstallerPathContract.OcsCliJsPath,
        $script:InstallerPathContract.PluginOcsCliCjsPath,
        $script:InstallerPathContract.PluginOcsCliJsPath
    )

    return $candidatePaths | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}

function Install-OcsShimFromOpencode {
    $ocsJs = Resolve-OcsRuntimeEntrypoint

    if (-not $ocsJs) {
        Write-Warning "Unable to repair ocs shim because no OCS entrypoint was found."
        return $false
    }

    $bunBin = Join-SafeEnvPath -EnvNames @("USERPROFILE", "HOME") -RelativePath '.bun\bin' -FallbackFolder ([System.Environment+SpecialFolder]::UserProfile)
    if (-not (Ensure-EnvPathValue -Value $bunBin -Context 'bun shim directory (opencode)' -FallbackHint 'env: USERPROFILE/HOME; fallback: UserProfile special folder')) {
        return $false
    }
    New-Item -ItemType Directory -Path $bunBin -Force | Out-Null

    $cmdPath = Join-Path $bunBin "ocs.cmd"
    $ps1Path = Join-Path $bunBin "ocs.ps1"

    $bunExe = Join-Path $bunBin "bun.exe"
    $cmdLine = if (Test-Path $bunExe) { "`"$bunExe`" `"$ocsJs`" %*" } else { "bun `"$ocsJs`" %*" }
    $psLine = if (Test-Path $bunExe) { "& `"$bunExe`" `"$ocsJs`" @Args" } else { "& bun `"$ocsJs`" @Args" }

    $cmdContent = "@echo off`r`n$cmdLine`r`n"
    Set-Content -Path $cmdPath -Value $cmdContent -Encoding ASCII

    $ps1Content = "param([Parameter(ValueFromRemainingArguments=`$true)][string[]]`$Args)`r`n$psLine`r`n"
    Set-Content -Path $ps1Path -Value $ps1Content -Encoding ASCII

    Add-PathEntryToUserPath -PathEntry $bunBin
    Refresh-SessionPath

    return (Test-OcsWorks)
}

function Install-OpencodeShimFromBun {
    $bunBin = Join-SafeEnvPath -EnvNames @("USERPROFILE", "HOME") -RelativePath '.bun\bin' -FallbackFolder ([System.Environment+SpecialFolder]::UserProfile)
    if (-not (Ensure-EnvPathValue -Value $bunBin -Context 'bun shim directory (opencode fallback)' -FallbackHint 'env: USERPROFILE/HOME; fallback: UserProfile special folder')) {
        return $false
    }
    New-Item -ItemType Directory -Path $bunBin -Force | Out-Null

    $bunxExe = Join-Path $bunBin "bunx.exe"
    $bunExe = Join-Path $bunBin "bun.exe"
    $cmdPath = Join-Path $bunBin "opencode.cmd"
    $ps1Path = Join-Path $bunBin "opencode.ps1"
    $nativeBinary = Resolve-OpencodeNativeBinary

    $cmdLine = if ($nativeBinary) {
        "@echo off`r`n`"$nativeBinary`" %*`r`n"
    } elseif (Test-Path $bunxExe) {
        "@echo off`r`n`"$bunxExe`" --bun opencode-ai %*`r`n"
    } else {
        "@echo off`r`nbunx --bun opencode-ai %*`r`n"
    }
    Set-Content -Path $cmdPath -Value $cmdLine -Encoding ASCII

    $psLine = if ($nativeBinary) {
        "param([Parameter(ValueFromRemainingArguments=`$true)][string[]]`$Args)`r`n& `"$nativeBinary`" @Args`r`n"
    } elseif (Test-Path $bunxExe) {
        "param([Parameter(ValueFromRemainingArguments=`$true)][string[]]`$Args)`r`n& `"$bunxExe`" --bun opencode-ai @Args`r`n"
    } else {
        "param([Parameter(ValueFromRemainingArguments=`$true)][string[]]`$Args)`r`n& bunx --bun opencode-ai @Args`r`n"
    }
    Set-Content -Path $ps1Path -Value $psLine -Encoding ASCII

    Add-PathEntryToUserPath -PathEntry $bunBin
    Refresh-SessionPath

    return (Test-Path $cmdPath)
}

function Resolve-OpencodeNativeBinary {
    $userHome = Join-SafeEnvPath -EnvNames @("USERPROFILE", "HOME") -RelativePath '' -FallbackFolder ([System.Environment+SpecialFolder]::UserProfile)
    $candidates = @(
        (Join-Path $userHome '.opencode\bin\opencode.exe'),
        (Join-Path $userHome '.opencode\bin\opencode'),
        (Join-Path $userHome '.bun\install\global\node_modules\opencode-ai\bin\.opencode.exe'),
        (Join-Path $userHome '.bun\install\global\node_modules\opencode-ai\bin\.opencode')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    return $null
}

function Test-OpencodeWorks {
    $bunBin = Join-SafeEnvPath -EnvNames @("USERPROFILE", "HOME") -RelativePath '.bun\bin' -FallbackFolder ([System.Environment+SpecialFolder]::UserProfile)
    $managedCmdPath = Join-Path $bunBin 'opencode.cmd'

    $opencodeCommandPath = if (Test-Path $managedCmdPath) {
        $managedCmdPath
    } else {
        $opencodeCommand = Get-Command opencode -ErrorAction SilentlyContinue
        if ($opencodeCommand) { $opencodeCommand.Source } else { $null }
    }

    if (-not $opencodeCommandPath) {
        return $false
    }

    try {
        & $opencodeCommandPath --version *> $null
        if ($LASTEXITCODE -eq 0) {
            $helpOutput = & $opencodeCommandPath --help 2>&1 | Out-String
            if ($LASTEXITCODE -ne 0) {
                return $false
            }
            if ($helpOutput -match 'Usage:\s+oh-my-opencode' -or $helpOutput -match 'The ultimate OpenCode plugin') {
                return $false
            }
            return $true
        }
    } catch {
    }

    try {
        $helpOutput = & $opencodeCommandPath --help 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            return $false
        }
        if ($helpOutput -match 'Usage:\s+oh-my-opencode' -or $helpOutput -match 'The ultimate OpenCode plugin') {
            return $false
        }
        return $true
    } catch {
        return $false
    }
}

function Ensure-OpencodeCommand {
    if (Test-OpencodeWorks) {
        return $true
    }

    if (Install-OpencodeShimFromBun) {
        Refresh-SessionPath
        if (Test-OpencodeWorks) {
            return $true
        }
    }

    $bunBin = Join-SafeEnvPath -EnvNames @("USERPROFILE", "HOME") -RelativePath '.bun\bin' -FallbackFolder ([System.Environment+SpecialFolder]::UserProfile)
    $bunExe = Join-Path $bunBin 'bun.exe'
    $bunCommand = if (Test-Path $bunExe) { $bunExe } else { 'bun' }

    try {
        & $bunCommand add -g opencode-ai@latest *> $null
        if ($LASTEXITCODE -ne 0) {
            return $false
        }
    } catch {
        return $false
    }

    if (Install-OpencodeShimFromBun) {
        Refresh-SessionPath
        return (Test-OpencodeWorks)
    }

    return $false
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

    $bunBin = Join-SafeEnvPath -EnvNames @("USERPROFILE", "HOME") -RelativePath '.bun\bin' -FallbackFolder ([System.Environment+SpecialFolder]::UserProfile)
    Add-PathEntryToUserPath -PathEntry $bunBin
    Refresh-SessionPath

    if ($IsLocalSource) {
        if (Install-OcsShimFromBundle -PluginPath $PluginPath -BasePath $BasePath) {
            Write-Output "ocs shim refreshed from local source and verification passed."
            return $true
        }
    }

    if (Install-OcsShimFromOpencode) {
        Write-Output "ocs shim refreshed from installed runtime and verification passed."
        return $true
    }

    if (Install-OcsShimFromBundle -PluginPath $PluginPath -BasePath $BasePath) {
        Write-Output "ocs shim install and verification passed."
        return $true
    }

    if (Test-OcsWorks) {
        Write-Output "ocs verification passed."
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

function Get-DependencyFingerprint {
    param([string]$Directory)

    $files = @(
        "package.json",
        "bun.lock",
        "bun.lockb",
        "bunfig.toml",
        "package-lock.json",
        "pnpm-lock.yaml",
        "yarn.lock"
    )

    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($file in $files) {
        $fullPath = Join-Path $Directory $file
        if (-not (Test-Path $fullPath)) {
            continue
        }

        try {
            $hashValue = (Get-FileHash -Path $fullPath -Algorithm SHA256).Hash.ToLower()
            $parts.Add("${file}:$hashValue")
        } catch {
            continue
        }
    }

    if ($parts.Count -eq 0) {
        return ""
    }

    return ($parts -join "`n")
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
                $runtime.resourceModes.default = $INSTALLER_DEFAULT_MODE
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
                $fallbacks.setupRuntime.resourceModes.default = $INSTALLER_DEFAULT_MODE
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
                $profiles = @($catalog.profileDisplayOrder | Where-Object { $_ -ne $INSTALLER_DEFAULT_PROFILE })
                $catalog.profileDisplayOrder = @($INSTALLER_DEFAULT_PROFILE) + $profiles
            }
            ($catalog | ConvertTo-Json -Depth 50) | Set-Content -Path $catalogPath -Encoding UTF8
        }

        Write-Output "Applied installer defaults: $INSTALLER_DEFAULT_PROFILE + $INSTALLER_DEFAULT_MODE mode."
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
    $stateDir = Join-Path $resolvedDirectory ".ocs-install-state"
    $fingerprintFile = Join-Path $stateDir "bun-install.fingerprint"
    $fingerprint = Get-DependencyFingerprint -Directory $resolvedDirectory

    if ($fingerprint -and (Test-Path (Join-Path $resolvedDirectory "node_modules")) -and (Test-Path $fingerprintFile)) {
        try {
            $previousFingerprint = (Get-Content -Path $fingerprintFile -Raw -ErrorAction Stop).Trim()
            if ($previousFingerprint -eq $fingerprint.Trim()) {
                Write-Output "Dependency fingerprint unchanged. Skipping bun install in $resolvedDirectory."
                return
            }
        } catch {
            # ignore unreadable marker and continue with install
        }
    }

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
                $progressProcess = Start-ProgressNarration -Channel 'install' -Scenario 'dependency-install'
                try {
                    $bunOutput = & bun @args 2>&1
                } finally {
                    Stop-ProgressNarration -Process $progressProcess
                }
                if ($bunOutput) {
                    $lastOutput = ($bunOutput | Out-String).Trim()
                }
                if ($LASTEXITCODE -eq 0) {
                    $freshFingerprint = Get-DependencyFingerprint -Directory $resolvedDirectory
                    if ($freshFingerprint) {
                        New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
                        Set-Content -Path $fingerprintFile -Value $freshFingerprint -Encoding UTF8
                    }
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
    param(
        [bool]$IsLocalSource,
        [string]$SetupEntrypoint
    )

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

    if (-not (Test-Path $setupEntrypoint)) {
        Write-Warning "Setup entrypoint not found at $setupEntrypoint. Skipping auto setup."
        return
    }

    Write-Output ""
    Write-Output "Running auto setup (headless, installer defaults)..."

    $headlessSucceeded = $true
    $headlessExitCode = 1

    try {
        $progressProcess = Start-ProgressNarration -Channel 'install' -Scenario 'setup-profile'
        try {
            & bun $setupEntrypoint --headless --profile $INSTALLER_DEFAULT_PROFILE --mode $INSTALLER_DEFAULT_MODE
        } finally {
            Stop-ProgressNarration -Process $progressProcess
        }
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
            $progressProcess = Start-ProgressNarration -Channel 'install' -Scenario 'setup-profile'
            try {
                & bun $setupEntrypoint
            } finally {
                Stop-ProgressNarration -Process $progressProcess
            }
        } catch {
            Write-Error "Auto setup failed: $($_.Exception.Message)"
            Write-Error "Run setup manually: bun $setupEntrypoint"
            exit 1
        }

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Interactive setup failed. Run manually: bun $setupEntrypoint"
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

function Get-InstalledPluginVersion {
    param([string]$PluginDir)

    $packageJson = Join-Path $PluginDir "package.json"
    if (-not (Test-Path $packageJson)) {
        return ""
    }

    try {
        $pkg = Get-Content $packageJson -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($pkg.version) {
            return [string]$pkg.version
        }
    } catch {
        return ""
    }

    return ""
}

function Test-TrustedInstalledSameVersionSkip {
    param(
        [string]$RequestedVersion,
        [string]$PluginDir,
        [string]$ConfigRoot
    )

    $installedVersion = Get-InstalledPluginVersion -PluginDir $PluginDir
    if ([string]::IsNullOrWhiteSpace($installedVersion)) {
        Write-Warning "Identity unknown: unable to read installed plugin version from $(Join-Path $PluginDir 'package.json')."
        return $false
    }

    if ($installedVersion -ne $RequestedVersion) {
        Write-Warning "Identity unknown: installed plugin version v$installedVersion does not match requested v$RequestedVersion."
        return $false
    }

    $provenancePath = Join-Path $ConfigRoot "BUILD_PROVENANCE.json"
    if (-not (Test-Path $provenancePath)) {
        Write-Warning "Skip denied: missing installed provenance at $provenancePath; identity is unknown."
        return $false
    }

    try {
        $provenance = Get-Content -Raw -Path $provenancePath -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Write-Warning "Skip denied: provenance file at $provenancePath is unreadable or malformed; identity is unknown."
        return $false
    }

    if ($null -eq $provenance -or $provenance -isnot [pscustomobject]) {
        Write-Warning "Skip denied: provenance file at $provenancePath is malformed; identity is unknown."
        return $false
    }

    $provenanceVersion = ""
    if ($provenance.PSObject.Properties.Name -contains "version" -and $null -ne $provenance.version) {
        $provenanceVersion = [string]$provenance.version
    }

    $source = $null
    if ($provenance.PSObject.Properties.Name -contains "source") {
        $source = $provenance.source
    }

    $gitTag = ""
    $isDirty = $null
    if ($null -ne $source -and $source -is [pscustomobject]) {
        if ($source.PSObject.Properties.Name -contains "gitTag" -and $null -ne $source.gitTag) {
            $gitTag = [string]$source.gitTag
        }

        if ($source.PSObject.Properties.Name -contains "isDirty") {
            $isDirty = $source.isDirty
        }
    }

    if ($provenanceVersion -ne $RequestedVersion) {
        $displayVersion = if ([string]::IsNullOrWhiteSpace($provenanceVersion)) { "<missing>" } else { $provenanceVersion }
        Write-Warning "Identity unknown: provenance version $displayVersion does not match requested v$RequestedVersion."
        return $false
    }

    if ($gitTag -ne "v$RequestedVersion") {
        $displayTag = if ([string]::IsNullOrWhiteSpace($gitTag)) { "<missing>" } else { $gitTag }
        Write-Warning "Identity unknown: provenance gitTag $displayTag does not match expected v$RequestedVersion."
        return $false
    }

    if (($null -eq $isDirty) -or ($isDirty -ne $false)) {
        $displayDirty = if ($null -eq $isDirty) { "<missing>" } else { [string]$isDirty }
        Write-Warning "Identity unknown: provenance source.isDirty=$displayDirty is not clean."
        return $false
    }

    Write-Host "Trusted installed provenance accepted from $provenancePath (version v$RequestedVersion, tag v$RequestedVersion, clean tree)."
    return $true
}

function Sync-BundleRuntimeRoot {
    param(
        [string]$BundleRoot,
        [string]$TargetRoot
    )

    if (-not (Test-Path $BundleRoot)) {
        Write-Error "Bundle root $BundleRoot not found for runtime sync."
        exit 1
    }

    if (-not (Test-Path $TargetRoot)) {
        New-Item -ItemType Directory -Force $TargetRoot | Out-Null
    }

    Get-ChildItem -Path $BundleRoot -Force | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $TargetRoot -Recurse -Force
    }

    Write-Output "Synced bundled runtime root to $TargetRoot"
}

function Resolve-InstallerSetupEntrypoint {
    param(
        [bool]$IsLocalSource,
        [string]$PluginDir,
        [string]$ConfigRoot
    )

    if ($IsLocalSource) {
        return (Join-Path $PluginDir "dist\installer\setup.cjs")
    }

    $targetRootScript = Join-Path $ConfigRoot "dist\installer\setup.cjs"
    if (Test-Path $targetRootScript) {
        return $targetRootScript
    }

    return (Join-Path $PluginDir "dist\installer\setup.cjs")
}

function Assert-AntigravityOauthIntegrity {
    param([string]$SetupEntrypoint)

    $configDir = $script:InstallerPathContract.TargetConfigDir
    $configFallbackPath = Join-Path $script:InstallerPathContract.HomeDir '.config\opencode'
    if (-not (Ensure-EnvPathValue -Value $configDir -Context 'opencode config directory' -FallbackHint 'env: USERPROFILE/HOME; fallback: UserProfile special folder' -FallbackPath $configFallbackPath -Fail)) {
        throw "Installer cannot continue without a valid opencode config directory."
    }
    $runtimeOpencode = Join-Path $configDir "opencode.json"
    $runtimeAntigravity = Join-Path $configDir "antigravity.json"
    $templateAntigravity = Join-Path $PLUGIN_DIR "backups\antigravity.json.template"
    $needsRepair = $false

    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Force $configDir | Out-Null
    }

    if (Test-Path $runtimeAntigravity) {
        Write-Output "Existing Antigravity storage detected. Preserving current account state."
    } elseif (Test-Path $templateAntigravity) {
        Copy-Item -Path $templateAntigravity -Destination $runtimeAntigravity -Force
        $needsRepair = $true
    }

    if (Test-Path $runtimeOpencode) {
        $runtimeContent = Get-Content -Raw -Path $runtimeOpencode -Encoding UTF8
        if ($runtimeContent -match 'file:///.*dist/index\.js|plugins/.*/dist/index\.js') {
            $needsRepair = $true
        }
    }

    if ($needsRepair) {
        Write-Output "Repairing final Antigravity OAuth visibility before installer exit..."
        $previousInstallerMode = $env:OCS_SETUP_INSTALLER_MODE
        $env:OCS_SETUP_INSTALLER_MODE = "1"
        try {
            & bun $SetupEntrypoint --headless --profile $INSTALLER_DEFAULT_PROFILE --mode $INSTALLER_DEFAULT_MODE *> $null
        } catch {
            # best effort repair
        } finally {
            if ($null -eq $previousInstallerMode) {
                Remove-Item Env:OCS_SETUP_INSTALLER_MODE -ErrorAction SilentlyContinue
            } else {
                $env:OCS_SETUP_INSTALLER_MODE = $previousInstallerMode
            }
        }

        if ((-not (Test-Path $runtimeAntigravity)) -and (Test-Path $templateAntigravity)) {
            Copy-Item -Path $templateAntigravity -Destination $runtimeAntigravity -Force
        }
    }

    if (-not (Test-Path $runtimeAntigravity)) {
        throw "Final Antigravity OAuth integrity check failed: antigravity.json is missing."
    }

    if (Test-Path $runtimeOpencode) {
        $runtimeContent = Get-Content -Raw -Path $runtimeOpencode -Encoding UTF8
        if ($runtimeContent -match 'file:///.*dist/index\.js|plugins/.*/dist/index\.js') {
            throw "Final Antigravity OAuth integrity check failed: runtime config still references a raw dist/index.js plugin path."
        }
    }

    Write-Output "Antigravity OAuth integrity check passed."
}

function Reset-RuntimePluginsDirectory {
    $purgePlugins = $env:OCS_INSTALLER_PURGE_PLUGINS
    if ([string]::IsNullOrWhiteSpace($purgePlugins)) {
        $purgePlugins = "1"
    }

    if ($purgePlugins -ne "1") {
        Write-Output "Skipping plugin directory purge because OCS_INSTALLER_PURGE_PLUGINS=$purgePlugins"
        return
    }

    $pluginsRoot = $script:InstallerPathContract.PluginsRoot

    if (Test-Path $pluginsRoot) {
        Write-Warning "Removing existing plugin directory to avoid stale plugin manager conflicts: $pluginsRoot"
        Remove-Item -Path $pluginsRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    New-Item -ItemType Directory -Path $pluginsRoot -Force | Out-Null
    Write-Output "Plugin directory reset complete: $pluginsRoot"
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
Ensure-OpencodePathEntries
Ensure-PnpmRuntime | Out-Null
Ensure-PythonRuntimeForAgents | Out-Null
Write-Output "Installer source branch: $GITHUB_SOURCE_BRANCH"
Write-Output "Fallback release branch: $DEFAULT_RELEASE_BRANCH"
if ($REQUESTED_VERSION) {
    Write-Output "Requested version pin: v$REQUESTED_VERSION"
}

$rootDir = (Resolve-Path ".").Path
$forceLocalSource = (($env:OCS_FORCE_LOCAL_SOURCE ?? "0") -eq "1")
$isLocalSource = $false
$hasLocalSourceMarkers =
    (Test-Path (Join-Path $rootDir "plugins\opencode-multi-auth\package.json")) -and
    (Test-Path (Join-Path $rootDir "dist\installer\setup.cjs")) -and
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
$installedVersion = ""

if ($isLocalSource) {
    $PLUGIN_DIR = Join-Path $rootDir "plugins\opencode-multi-auth"
} else {
    $PLUGIN_DIR = $script:InstallerPathContract.PluginDir
}

    $pluginContext = if ($isLocalSource) { 'local workspace plugin directory' } else { 'env-derived plugin directory' }
    $pluginFallbackHint = if ($isLocalSource) { 'local workspace path' } else { 'env: USERPROFILE/HOME; fallback: UserProfile special folder' }
    if (-not $isLocalSource) {
        $pluginFallbackPath = $script:InstallerPathContract.PluginDir
    } else {
        $pluginFallbackPath = ''
    }
    if (-not (Ensure-EnvPathValue -Value $PLUGIN_DIR -Context $pluginContext -FallbackHint $pluginFallbackHint -FallbackPath $pluginFallbackPath -Fail)) {
        exit 1
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

    if (-not $resolvedLocalBundle -and $REQUESTED_VERSION) {
        $installedVersion = Get-InstalledPluginVersion -PluginDir $PLUGIN_DIR
        if ($installedVersion -and ($installedVersion -eq $REQUESTED_VERSION)) {
            if (Test-TrustedInstalledSameVersionSkip -RequestedVersion $REQUESTED_VERSION -PluginDir $PLUGIN_DIR -ConfigRoot $script:InstallerPathContract.TargetConfigDir) {
                Write-Output "Requested version v$REQUESTED_VERSION is already installed at $PLUGIN_DIR."
                Write-Output "Trusted installed identity was detected, but the normal installer path will still purge and refresh plugin payloads so same-version patches land correctly."
            } else {
                Write-Output "Same-version installed payload found, but trusted identity was not established; continuing with the normal purge-and-refresh path."
            }
        }
    }

    Write-Output "Resolved installer target root: $($script:InstallerPathContract.TargetConfigDir)"
    Write-Output "Resolved installer plugin dir: $PLUGIN_DIR"
    Reset-RuntimePluginsDirectory

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
        if ($sourcePkg.version) { $version = "$($sourcePkg.version)-$($script:ResolvedSourceBranch)" }
    } catch {
        $version = "$($script:ResolvedSourceBranch)"
    }

    Get-ChildItem -Path $pluginSource -Force | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $PLUGIN_DIR -Recurse -Force
    }

    $configRoot = $script:InstallerPathContract.TargetConfigDir
    if (-not (Ensure-EnvPathValue -Value $configRoot -Context 'env-derived opencode config root' -FallbackHint 'env: USERPROFILE/HOME; fallback: UserProfile special folder' -FallbackPath (Join-Path $script:InstallerPathContract.HomeDir '.config\opencode') -Fail)) {
        exit 1
    }
    Sync-BundleRuntimeRoot -BundleRoot $pluginSource -TargetRoot $configRoot

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

$resolvedConfigRoot = $script:InstallerPathContract.TargetConfigDir
$resolvedSetupEntrypoint = Resolve-InstallerSetupEntrypoint -IsLocalSource:$isLocalSource -PluginDir $PLUGIN_DIR -ConfigRoot $resolvedConfigRoot
Invoke-AutoSetup -IsLocalSource:$isLocalSource -SetupEntrypoint $resolvedSetupEntrypoint
Assert-AntigravityOauthIntegrity -SetupEntrypoint $resolvedSetupEntrypoint
Ensure-OpencodePathEntries
Ensure-AdjunctRuntimeReady

if (Test-Path $TMP_DIR) {
    Remove-Item -Recurse -Force $TMP_DIR -ErrorAction SilentlyContinue
}

Write-Output ""
Write-Output "opencode-multi-auth $version installed to $PLUGIN_DIR"
Write-Output "Bundle source branch used: $($script:ResolvedSourceBranch)"
Write-Output ""
Write-Output "Checking global ocs command..."
if (-not (Ensure-OcsCommand -PluginPath $PLUGIN_DIR -BasePath $rootDir -IsLocalSource:$isLocalSource)) {
    $bunBin = Join-SafeEnvPath -EnvNames @("USERPROFILE", "HOME") -RelativePath '.bun\bin' -FallbackFolder ([System.Environment+SpecialFolder]::UserProfile)
    Write-Warning "ocs command still unavailable after auto-install attempts."
    Write-Warning "Manual fallback: clone private suite repo, then run bun install -g <repo-path>."
    Write-Warning "If needed, add to PATH: $bunBin (and open a new terminal)"
}
Write-Output ""
Ensure-OpencodePathEntries
Write-Output "Checking opencode command..."
if (Ensure-OpencodeCommand) {
    Write-Output "opencode verification passed."
} else {
    Write-Warning "opencode command is still unavailable after automatic repair."
    Write-Output "Manual check: opencode --version"
}
Write-Output ""
Write-Output "   Next steps:"
Write-Output "   1. Add account / login: opencode auth login"
Write-Output "      - Default recommended path: OpenAI > Chatgpt browser"
Write-Output "   2. Create EXA API key: https://dashboard.exa.ai/api-keys"
Write-Output "   3. Setup Exa MCP: ocs exa setup --api-key <YOUR_EXA_API_KEY>"
Write-Output "     If script policy blocks, use: ocs.cmd exa setup --api-key <YOUR_EXA_API_KEY>"
Write-Output "   4. Verify Exa MCP: ocs exa check"
Write-Output "     If script policy blocks, use: ocs.cmd exa check"
Write-Output "   5. Verify MCP status: opencode mcp list"
Write-Output "   6. Default runtime: opencode --port 78617"
Write-Output "   7. If you prefer web UI: opencode web --port 8089"
Write-Output ""
Write-Output "   Optional later:"
Write-Output "   - Change from the default ChatGPT/Codex profile: ocs setup:profile"
Write-Output "   - GitHub MCP: start from GitHub CLI install/auth docs https://cli.github.com/"
Write-Output "   - VS Code extension: OpenCode VSCode Extension by SST"
Write-Output ""


