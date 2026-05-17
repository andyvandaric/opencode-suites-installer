#Requires -Version 5.1
<#
.SYNOPSIS
  Installs a Windows-first terminal coding stack focused on Unicode/emoji safety.

.DESCRIPTION
  Installs WezTerm, Neovim, Lazygit, Yazi, and supporting CLI tools with WinGet when available.
  If WinGet is unavailable, the script falls back to Chocolatey when elevated, otherwise it performs
  a user-local portable install under %LOCALAPPDATA%\Programs\safe-terminal-stack.

  If WSL is available, it also installs Zellij into the default distro as a user-local binary.

  The script writes managed starter configs for WezTerm and Neovim, and adds a small managed
  helper block to the current user's PowerShell profile without replacing the rest of the file.

.NOTES
  Managed files are only overwritten when -ForceConfig is supplied.
  Existing unmanaged configs are left untouched.
#>

param(
  [switch]$ForceConfig,
  [switch]$SkipWslZellij,
  [switch]$SkipGitInstall,
  [switch]$RunSmokeTests,
  [switch]$SmokeTestsOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($SmokeTestsOnly) {
  $RunSmokeTests = $true
}

$script:ManagedName = "setup-safe-terminal-stack.ps1"
$script:ManagedBlockStart = "# >>> safe-terminal-stack >>>"
$script:ManagedBlockEnd = "# <<< safe-terminal-stack <<<"
$script:ManagedFileHeader = "managed by $($script:ManagedName)"
$script:PortableRoot = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "Programs\safe-terminal-stack"
$script:ShimRoot = Join-Path ([Environment]::GetFolderPath("UserProfile")) ".local\bin"
$script:InstallBackend = $null

function Write-Step {
  param([string]$Message)
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Write-Info {
  param([string]$Message)
  Write-Host "  • $Message" -ForegroundColor Gray
}

function Write-WarnLine {
  param([string]$Message)
  Write-Warning $Message
}

function Test-CommandAvailable {
  param([string]$Name)
  return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Refresh-SessionPath {
  $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  $parts = New-Object System.Collections.Generic.List[string]

  if ($machinePath) {
    foreach ($part in $machinePath.Split(";", [System.StringSplitOptions]::RemoveEmptyEntries)) {
      $parts.Add($part)
    }
  }

  if ($userPath) {
    foreach ($part in $userPath.Split(";", [System.StringSplitOptions]::RemoveEmptyEntries)) {
      $parts.Add($part)
    }
  }

  $env:Path = ((Get-UniquePathEntries -Entries $parts.ToArray()) -join ";")
}

function Get-UniquePathEntries {
  param([string[]]$Entries)

  $seen = @{}
  $unique = New-Object System.Collections.Generic.List[string]

  foreach ($entry in $Entries) {
    if ([string]::IsNullOrWhiteSpace($entry)) {
      continue
    }

    $trimmed = $entry.Trim()
    $key = $trimmed.TrimEnd("\\").ToLowerInvariant()

    if ($seen.ContainsKey($key)) {
      continue
    }

    $seen[$key] = $true
    $unique.Add($trimmed)
  }

  return $unique.ToArray()
}

function Ensure-WinGet {
  if (Test-CommandAvailable -Name "winget") {
    return
  }

  Write-Info "WinGet not found. Attempting App Installer registration."

  try {
    Add-AppxPackage -RegisterByFamilyName -MainPackage "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe"
  } catch {
    Write-WarnLine "App Installer registration did not succeed automatically: $($_.Exception.Message)"
  }

  Refresh-SessionPath

  if (-not (Test-CommandAvailable -Name "winget")) {
    throw "WinGet is required for this script. Install or repair Microsoft App Installer, then run the script again."
  }
}

function Test-IsAdministrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]::new($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Initialize-InstallBackend {
  if (Test-CommandAvailable -Name "winget") {
    $script:InstallBackend = "winget"
    Write-Info "Using WinGet backend."
    return
  }

  try {
    Ensure-WinGet
    $script:InstallBackend = "winget"
    Write-Info "Using WinGet backend after App Installer registration."
    return
  } catch {
    Write-WarnLine $_.Exception.Message
  }

  if ((Test-CommandAvailable -Name "choco") -and (Test-IsAdministrator)) {
    $script:InstallBackend = "choco"
    Write-Info "Using Chocolatey backend."
    return
  }

  if (Test-CommandAvailable -Name "choco") {
    Write-WarnLine "Chocolatey is available but this shell is not elevated. Falling back to a user-local portable install backend."
  } else {
    Write-Info "No package manager backend available. Falling back to a user-local portable install backend."
  }

  $script:InstallBackend = "portable"
}

function Test-WinGetPackageInstalled {
  param([string]$Id)

  $arguments = @("list", "--exact", "--id", $Id, "--accept-source-agreements")
  $output = & winget @arguments 2>$null

  if ($LASTEXITCODE -ne 0) {
    return $false
  }

  return ($output | Out-String) -match [Regex]::Escape($Id)
}

function Install-WinGetPackage {
  param(
    [string]$Id,
    [string]$Label,
    [string[]]$CommandNames = @()
  )

  foreach ($commandName in $CommandNames) {
    if (Test-CommandAvailable -Name $commandName) {
      Write-Info "$Label already available via command '$commandName'. Skipping package install."
      return
    }
  }

  if (Test-WinGetPackageInstalled -Id $Id) {
    Write-Info "$Label already installed ($Id)."
    return
  }

  Write-Info "Installing $Label ($Id)."
  $arguments = @(
    "install",
    "--exact",
    "--id", $Id,
    "--accept-package-agreements",
    "--accept-source-agreements",
    "--silent"
  )

  & winget @arguments

  if ($LASTEXITCODE -ne 0) {
    throw "Failed to install $Label ($Id) with WinGet."
  }
}

function Test-ChocoPackageInstalled {
  param([string]$Id)

  $output = & choco list --local-only --exact $Id 2>$null
  if ($LASTEXITCODE -ne 0) {
    return $false
  }

  return ($output | Out-String) -match "^$([Regex]::Escape($Id))\s"
}

function Install-ChocoPackage {
  param(
    [string]$Id,
    [string]$Label,
    [string[]]$CommandNames = @()
  )

  foreach ($commandName in $CommandNames) {
    if (Test-CommandAvailable -Name $commandName) {
      Write-Info "$Label already available via command '$commandName'. Skipping package install."
      return
    }
  }

  if (Test-ChocoPackageInstalled -Id $Id) {
    Write-Info "$Label already installed ($Id)."
    return
  }

  Write-Info "Installing $Label ($Id) with Chocolatey."
  & choco install $Id -y --no-progress

  if ($LASTEXITCODE -ne 0) {
    throw "Failed to install $Label ($Id) with Chocolatey."
  }
}

function Ensure-Directory {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    $null = New-Item -ItemType Directory -Path $Path -Force
  }
}

function Ensure-UserPathEntry {
  param([string]$PathEntry)

  if ([string]::IsNullOrWhiteSpace($PathEntry)) {
    return
  }

  Ensure-Directory -Path $PathEntry

  $existingPath = [Environment]::GetEnvironmentVariable("Path", "User")
  $parts = @()
  if ($existingPath) {
    $parts = Get-UniquePathEntries -Entries ($existingPath.Split(";", [System.StringSplitOptions]::RemoveEmptyEntries))
  }

  foreach ($part in $parts) {
    if ($part.TrimEnd("\\") -ieq $PathEntry.TrimEnd("\\")) {
      if (-not (($env:Path -split ";") | Where-Object { $_.TrimEnd("\\") -ieq $PathEntry.TrimEnd("\\") })) {
        $env:Path = "$PathEntry;$env:Path"
      }
      return
    }
  }

  $updatedParts = Get-UniquePathEntries -Entries @($parts + $PathEntry)
  [Environment]::SetEnvironmentVariable("Path", ($updatedParts -join ";"), "User")
  $env:Path = "$PathEntry;$env:Path"
  Write-Info "Added $PathEntry to the user PATH."
}

function Get-SmokeTestScriptPath {
  return Join-Path $PSScriptRoot "test-safe-terminal-stack.ps1"
}

function Invoke-SmokeTests {
  $smokeTestScript = Get-SmokeTestScriptPath
  if (-not (Test-Path -LiteralPath $smokeTestScript)) {
    throw "Smoke test script not found at $smokeTestScript"
  }

  Write-Step "Running smoke tests"

  $arguments = @(
    "-NoLogo",
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $smokeTestScript
  )

  if ($SkipWslZellij) {
    $arguments += "-SkipWslZellij"
  }

  & (Get-PreferredShellCommand) @arguments

  if ($LASTEXITCODE -ne 0) {
    throw "Smoke tests failed."
  }
}

function Invoke-DownloadFile {
  param(
    [string]$Uri,
    [string]$DestinationPath
  )

  Write-Info "Downloading $Uri"
  Invoke-WebRequest -Uri $Uri -OutFile $DestinationPath -Headers @{ "User-Agent" = "safe-terminal-stack" }
}

function Get-GitHubLatestRelease {
  param([string]$Repo)

  return Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers @{ "User-Agent" = "safe-terminal-stack" }
}

function Get-ReleaseAsset {
  param(
    [object]$Release,
    [string]$Pattern,
    [string]$Label
  )

  $asset = $Release.assets | Where-Object { $_.name -match $Pattern } | Select-Object -First 1
  if (-not $asset) {
    $assetNames = ($Release.assets | ForEach-Object { $_.name }) -join ", "
    throw "Could not find a release asset for $Label matching pattern '$Pattern'. Assets: $assetNames"
  }

  return $asset
}

function Install-PortableFromZipRelease {
  param(
    [string]$Label,
    [string]$Repo,
    [string]$AssetPattern,
    [string]$DestinationName,
    [string]$PathSuffix = "",
    [string[]]$CommandNames = @()
  )

  foreach ($commandName in $CommandNames) {
    if (Test-CommandAvailable -Name $commandName) {
      Write-Info "$Label already available via command '$commandName'. Skipping portable install."
      return
    }
  }

  Ensure-Directory -Path $script:PortableRoot
  $release = Get-GitHubLatestRelease -Repo $Repo
  $asset = Get-ReleaseAsset -Release $release -Pattern $AssetPattern -Label $Label

  $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("safe-terminal-stack-" + [guid]::NewGuid().ToString("N"))
  $downloadPath = Join-Path $tempRoot $asset.name
  $extractPath = Join-Path $tempRoot "extract"
  $destinationPath = Join-Path $script:PortableRoot $DestinationName

  Ensure-Directory -Path $tempRoot
  Ensure-Directory -Path $extractPath
  Invoke-DownloadFile -Uri $asset.browser_download_url -DestinationPath $downloadPath
  Expand-Archive -LiteralPath $downloadPath -DestinationPath $extractPath -Force

  if (Test-Path -LiteralPath $destinationPath) {
    Remove-Item -LiteralPath $destinationPath -Recurse -Force
  }

  $children = @(Get-ChildItem -LiteralPath $extractPath)
  if ($children.Count -eq 1 -and $children[0].PSIsContainer) {
    Move-Item -LiteralPath $children[0].FullName -Destination $destinationPath
  } else {
    Ensure-Directory -Path $destinationPath
    foreach ($child in $children) {
      Move-Item -LiteralPath $child.FullName -Destination $destinationPath
    }
  }

  $pathToAdd = $destinationPath
  if (-not [string]::IsNullOrWhiteSpace($PathSuffix)) {
    $pathToAdd = Join-Path $destinationPath $PathSuffix
  }

  Ensure-UserPathEntry -PathEntry $pathToAdd
  Remove-Item -LiteralPath $tempRoot -Recurse -Force
  Write-Info "Installed $Label to $destinationPath."
}

function Install-PortableFromReleaseFile {
  param(
    [string]$Label,
    [string]$Repo,
    [string]$AssetPattern,
    [string]$DestinationRelativePath,
    [string[]]$CommandNames = @()
  )

  foreach ($commandName in $CommandNames) {
    if (Test-CommandAvailable -Name $commandName) {
      Write-Info "$Label already available via command '$commandName'. Skipping portable install."
      return
    }
  }

  $release = Get-GitHubLatestRelease -Repo $Repo
  $asset = Get-ReleaseAsset -Release $release -Pattern $AssetPattern -Label $Label
  $destinationPath = Join-Path $script:PortableRoot $DestinationRelativePath
  $destinationDir = Split-Path -Parent $destinationPath

  Ensure-Directory -Path $destinationDir
  Invoke-DownloadFile -Uri $asset.browser_download_url -DestinationPath $destinationPath
  Ensure-UserPathEntry -PathEntry $destinationDir
  Write-Info "Installed $Label to $destinationPath."
}

function Install-PortableTool {
  param(
    [string]$Label,
    [string]$Repo,
    [string]$AssetPattern,
    [string]$DestinationName,
    [string]$PathSuffix = "",
    [string[]]$CommandNames = @(),
    [string]$SingleFileRelativePath = ""
  )

  if ([string]::IsNullOrWhiteSpace($SingleFileRelativePath)) {
    Install-PortableFromZipRelease -Label $Label -Repo $Repo -AssetPattern $AssetPattern -DestinationName $DestinationName -PathSuffix $PathSuffix -CommandNames $CommandNames
    return
  }

  Install-PortableFromReleaseFile -Label $Label -Repo $Repo -AssetPattern $AssetPattern -DestinationRelativePath $SingleFileRelativePath -CommandNames $CommandNames
}

function Install-Tool {
  param(
    [string]$Label,
    [string]$WinGetId = "",
    [string]$ChocoId = "",
    [string]$PortableRepo = "",
    [string]$PortableAssetPattern = "",
    [string]$PortableDestinationName = "",
    [string]$PortablePathSuffix = "",
    [string[]]$CommandNames = @(),
    [string]$PortableSingleFileRelativePath = "",
    [switch]$Optional
  )

  switch ($script:InstallBackend) {
    "winget" {
      if ([string]::IsNullOrWhiteSpace($WinGetId)) {
        if ($Optional) {
          Write-WarnLine "Skipping optional $Label because no WinGet package id is configured."
          return
        }
        throw "No WinGet package id configured for $Label."
      }

      Install-WinGetPackage -Id $WinGetId -Label $Label -CommandNames $CommandNames
      return
    }
    "choco" {
      if ([string]::IsNullOrWhiteSpace($ChocoId)) {
        if ($Optional) {
          Write-WarnLine "Skipping optional $Label because no Chocolatey package id is configured."
          return
        }
        throw "No Chocolatey package id configured for $Label."
      }

      Install-ChocoPackage -Id $ChocoId -Label $Label -CommandNames $CommandNames
      return
    }
    "portable" {
      if ([string]::IsNullOrWhiteSpace($PortableRepo) -or [string]::IsNullOrWhiteSpace($PortableAssetPattern)) {
        if ($Optional) {
          Write-WarnLine "Skipping optional $Label because no portable release mapping is configured."
          return
        }
        throw "No portable release mapping is configured for $Label."
      }

      Install-PortableTool -Label $Label -Repo $PortableRepo -AssetPattern $PortableAssetPattern -DestinationName $PortableDestinationName -PathSuffix $PortablePathSuffix -CommandNames $CommandNames -SingleFileRelativePath $PortableSingleFileRelativePath
      return
    }
    default {
      throw "Install backend has not been initialized."
    }
  }
}

function Test-ManagedFile {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    return $true
  }

  $raw = Get-Content -LiteralPath $Path -Raw
  return $raw -match [Regex]::Escape($script:ManagedFileHeader)
}

function Write-ManagedFile {
  param(
    [string]$Path,
    [string]$Content,
    [string]$Label
  )

  $parent = Split-Path -Parent $Path
  Ensure-Directory -Path $parent

  if ((Test-Path -LiteralPath $Path) -and -not $ForceConfig -and -not (Test-ManagedFile -Path $Path)) {
    Write-WarnLine "Skipped $Label because an unmanaged file already exists at $Path. Re-run with -ForceConfig if you want this script to replace it."
    return
  }

  if (Test-Path -LiteralPath $Path) {
    $existingContent = Get-Content -LiteralPath $Path -Raw
    if ($existingContent -eq $Content) {
      Write-Info "$Label is already up to date at $Path."
      return
    }
  }

  Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8
  Write-Info "Wrote $Label to $Path."
}

function Get-CommandPathIfAvailable {
  param([string[]]$Names)

  foreach ($name in $Names) {
    $command = Get-Command $name -ErrorAction SilentlyContinue
    if (-not $command -or -not $command.Source) {
      continue
    }

    if ($command.CommandType -ne "Application") {
      continue
    }

    $resolvedSource = $command.Source
    if ([System.IO.Path]::GetExtension($resolvedSource).ToLowerInvariant() -eq ".cmd") {
      continue
    }

    $normalizedSource = $resolvedSource.TrimEnd("\\")
    $normalizedShimRoot = $script:ShimRoot.TrimEnd("\\")
    if ($normalizedSource.StartsWith($normalizedShimRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
      continue
    }

    return $resolvedSource
  }

  return $null
}

function Write-CommandShim {
  param(
    [string]$ShimName,
    [string]$TargetPath
  )

  if ([string]::IsNullOrWhiteSpace($TargetPath)) {
    Write-WarnLine "Skipping shim $ShimName because no target path was resolved."
    return
  }

  Ensure-UserPathEntry -PathEntry $script:ShimRoot

  $shimPath = Join-Path $script:ShimRoot ("$ShimName.cmd")
  $content = @"
:: $($script:ManagedFileHeader)
@echo off
"$TargetPath" %*
"@

  Write-ManagedFile -Path $shimPath -Content $content -Label "$ShimName shim"
}

function Write-ManagedCommandShims {
  $shimSpecs = @(
    @{ Shim = "wezterm"; Commands = @("wezterm.exe", "wezterm") },
    @{ Shim = "nvim"; Commands = @("nvim.exe", "nvim") },
    @{ Shim = "lazygit"; Commands = @("lazygit.exe", "lazygit") },
    @{ Shim = "yazi"; Commands = @("yazi.exe", "yazi") },
    @{ Shim = "fd"; Commands = @("fd.exe", "fd") },
    @{ Shim = "fzf"; Commands = @("fzf.exe", "fzf") },
    @{ Shim = "zoxide"; Commands = @("zoxide.exe", "zoxide") },
    @{ Shim = "jq"; Commands = @("jq.exe", "jq") },
    @{ Shim = "rg"; Commands = @("rg.exe", "rg") }
  )

  foreach ($shimSpec in $shimSpecs) {
    $resolvedTarget = Get-CommandPathIfAvailable -Names $shimSpec.Commands
    if (-not $resolvedTarget) {
      Write-WarnLine "Could not resolve a command path for shim '$($shimSpec.Shim)'."
      continue
    }

    Write-CommandShim -ShimName $shimSpec.Shim -TargetPath $resolvedTarget
  }
}

function Set-RegistryDefaultValue {
  param(
    [string]$RegistryPath,
    [string]$Value
  )

  if (-not (Test-Path -LiteralPath $RegistryPath)) {
    $null = New-Item -Path $RegistryPath -Force
  }

  Set-Item -LiteralPath $RegistryPath -Value $Value
}

function Set-RegistryStringValue {
  param(
    [string]$RegistryPath,
    [string]$Name,
    [string]$Value
  )

  if (-not (Test-Path -LiteralPath $RegistryPath)) {
    $null = New-Item -Path $RegistryPath -Force
  }

  New-ItemProperty -LiteralPath $RegistryPath -Name $Name -Value $Value -PropertyType String -Force | Out-Null
}

function Resolve-WezTermExecutablePath {
  $resolved = Get-CommandPathIfAvailable -Names @("wezterm.exe", "wezterm")
  if ($resolved) {
    return $resolved
  }

  $portableWezTerm = Join-Path $script:PortableRoot "wezterm\wezterm.exe"
  if (Test-Path -LiteralPath $portableWezTerm) {
    return $portableWezTerm
  }

  return $null
}

function Resolve-WezTermExplorerIconValue {
  param(
    [Parameter(Mandatory)]
    [string]$WezTermPath
  )

  $wezTermDirectory = Split-Path -Parent $WezTermPath
  $guiExecutable = Join-Path $wezTermDirectory "wezterm-gui.exe"
  $iconPath = if (Test-Path -LiteralPath $guiExecutable) { $guiExecutable } else { $WezTermPath }

  return '"{0}",0' -f $iconPath
}

function Register-WezTermExplorerContextMenu {
  $wezTermPath = Resolve-WezTermExecutablePath
  if (-not $wezTermPath) {
    Write-WarnLine "Skipping Windows Explorer context menu because wezterm.exe could not be resolved."
    return
  }

  $menuName = "Open in WezTerm"
  $backgroundShellKey = "HKCU:\Software\Classes\Directory\Background\shell\SafeTerminalStackWezTerm"
  $backgroundCommandKey = Join-Path $backgroundShellKey "command"
  $directoryShellKey = "HKCU:\Software\Classes\Directory\shell\SafeTerminalStackWezTerm"
  $directoryCommandKey = Join-Path $directoryShellKey "command"
  $backgroundCommand = '"{0}" start --cwd "%V"' -f $wezTermPath
  $directoryCommand = '"{0}" start --cwd "%1"' -f $wezTermPath
  $iconValue = Resolve-WezTermExplorerIconValue -WezTermPath $wezTermPath

  Set-RegistryDefaultValue -RegistryPath $backgroundShellKey -Value $menuName
  Set-RegistryStringValue -RegistryPath $backgroundShellKey -Name "Icon" -Value $iconValue
  Set-RegistryDefaultValue -RegistryPath $backgroundCommandKey -Value $backgroundCommand

  Set-RegistryDefaultValue -RegistryPath $directoryShellKey -Value $menuName
  Set-RegistryStringValue -RegistryPath $directoryShellKey -Name "Icon" -Value $iconValue
  Set-RegistryDefaultValue -RegistryPath $directoryCommandKey -Value $directoryCommand

  Write-Info "Registered Windows Explorer context menu: $menuName."
}

function Upsert-ProfileBlock {
  param(
    [string]$BlockContent,
    [string]$ProfilePath
  )

  $profilePath = $ProfilePath
  $profileDir = Split-Path -Parent $profilePath
  Ensure-Directory -Path $profileDir

  $existing = ""
  if (Test-Path -LiteralPath $profilePath) {
    $existing = Get-Content -LiteralPath $profilePath -Raw
  }

  $block = @(
    $script:ManagedBlockStart,
    $BlockContent.Trim(),
    $script:ManagedBlockEnd
  ) -join [Environment]::NewLine

  $firstStart = $existing.IndexOf($script:ManagedBlockStart, [System.StringComparison]::Ordinal)
  $lastEnd = $existing.LastIndexOf($script:ManagedBlockEnd, [System.StringComparison]::Ordinal)

  if ($firstStart -ge 0 -and $lastEnd -ge $firstStart) {
    $afterEnd = $lastEnd + $script:ManagedBlockEnd.Length
    $beforeBlock = $existing.Substring(0, $firstStart).TrimEnd()
    $afterBlock = $existing.Substring($afterEnd).TrimStart()
    $pieces = @()

    if (-not [string]::IsNullOrWhiteSpace($beforeBlock)) {
      $pieces += $beforeBlock
    }

    $pieces += $block

    if (-not [string]::IsNullOrWhiteSpace($afterBlock)) {
      $pieces += $afterBlock
    }

    $updated = ($pieces -join ([Environment]::NewLine + [Environment]::NewLine)) + [Environment]::NewLine
  } elseif ([string]::IsNullOrWhiteSpace($existing)) {
    $updated = $block + [Environment]::NewLine
  } else {
    $updated = $existing.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + $block + [Environment]::NewLine
  }

  if ($updated -eq $existing) {
    Write-Info "PowerShell profile block is already up to date in $profilePath."
    return
  }

  Set-Content -LiteralPath $profilePath -Value $updated -Encoding UTF8
  Write-Info "Updated PowerShell profile block in $profilePath."
}

function Set-UserEnvironmentValue {
  param(
    [string]$Name,
    [string]$Value
  )

  [Environment]::SetEnvironmentVariable($Name, $Value, "User")
  Set-Item -Path "Env:$Name" -Value $Value
  Write-Info "Set user environment variable $Name."
}

function Set-UserEnvironmentValueIfMissing {
  param(
    [string]$Name,
    [string]$Value
  )

  $existing = [Environment]::GetEnvironmentVariable($Name, "User")
  if (-not [string]::IsNullOrWhiteSpace($existing) -and -not $ForceConfig) {
    Write-Info "Keeping existing user environment variable $Name."
    Set-Item -Path "Env:$Name" -Value $existing
    return
  }

  Set-UserEnvironmentValue -Name $Name -Value $Value
}

function Resolve-GitFileOnePath {
  $git = Get-Command git -ErrorAction SilentlyContinue
  if (-not $git) {
    return $null
  }

  $gitPath = $git.Source
  $gitDir = Split-Path -Parent $gitPath
  $candidates = @(
    (Join-Path $gitDir "..\usr\bin\file.exe"),
    (Join-Path $gitDir "..\..\usr\bin\file.exe"),
    "C:\Program Files\Git\usr\bin\file.exe"
  )

  foreach ($candidate in $candidates) {
    $resolved = [System.IO.Path]::GetFullPath($candidate)
    if (Test-Path -LiteralPath $resolved) {
      return $resolved
    }
  }

  return $null
}

function Get-PreferredShellCommand {
  if (Test-CommandAvailable -Name "pwsh.exe") {
    return "pwsh.exe"
  }

  return "powershell.exe"
}

function Get-PowerShellProfileTargets {
  $targets = New-Object System.Collections.Generic.List[string]
  $currentUserAllHosts = $PROFILE.CurrentUserAllHosts
  if ($currentUserAllHosts) {
    $targets.Add($currentUserAllHosts)
  }

  $documents = [Environment]::GetFolderPath("MyDocuments")
  if (-not [string]::IsNullOrWhiteSpace($documents)) {
    $profileAllHosts = Join-Path $documents "PowerShell\profile.ps1"
    $pwshProfile = Join-Path $documents "PowerShell\Microsoft.PowerShell_profile.ps1"
    $windowsPowerShellAllHosts = Join-Path $documents "WindowsPowerShell\profile.ps1"
    $windowsPowerShellProfile = Join-Path $documents "WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
    if (-not $targets.Contains($profileAllHosts)) {
      $targets.Add($profileAllHosts)
    }
    if (-not $targets.Contains($pwshProfile)) {
      $targets.Add($pwshProfile)
    }
    if (-not $targets.Contains($windowsPowerShellAllHosts)) {
      $targets.Add($windowsPowerShellAllHosts)
    }
    if (-not $targets.Contains($windowsPowerShellProfile)) {
      $targets.Add($windowsPowerShellProfile)
    }
  }

  return $targets.ToArray()
}

function Test-WslDefaultDistroAvailable {
  if (-not (Test-CommandAvailable -Name "wsl.exe")) {
    return $false
  }

  $output = & wsl.exe -l -q 2>$null
  if ($LASTEXITCODE -ne 0) {
    return $false
  }

  foreach ($line in $output) {
    if (-not [string]::IsNullOrWhiteSpace($line)) {
      return $true
    }
  }

  return $false
}

function Install-WslZellijLocal {
  if ($SkipWslZellij) {
    Write-Info "Skipping WSL Zellij installation by request."
    return
  }

  if (-not (Test-CommandAvailable -Name "wsl.exe")) {
    Write-WarnLine "WSL is not available. Skipping Zellij installation."
    return
  }

  if (-not (Test-WslDefaultDistroAvailable)) {
    Write-WarnLine "WSL is installed but no default distro is available. Skipping Zellij installation."
    return
  }

Write-Step "Installing Zellij into the default WSL distro"

  $bashScript = @'
set -eu

profile_file="$HOME/.profile"
touch "$profile_file"
if ! grep -Fq 'export PATH="$HOME/.local/bin:$PATH"' "$profile_file"; then
  printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$profile_file"
fi

if [ -x "$HOME/.local/bin/zellij" ]; then
  echo "zellij already installed at $HOME/.local/bin/zellij"
  exit 0
fi

mkdir -p "$HOME/.local/bin"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

arch="$(uname -m)"
case "$arch" in
  x86_64)
    asset="zellij-x86_64-unknown-linux-musl.tar.gz"
    ;;
  aarch64|arm64)
    asset="zellij-aarch64-unknown-linux-musl.tar.gz"
    ;;
  *)
    echo "Unsupported WSL architecture: $arch" >&2
    exit 1
    ;;
esac

for tool in curl tar install; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "$tool is required inside WSL to install Zellij." >&2
    exit 1
  fi
done

curl -fsSL "https://github.com/zellij-org/zellij/releases/latest/download/$asset" -o "$tmp_dir/zellij.tar.gz"
tar -xzf "$tmp_dir/zellij.tar.gz" -C "$tmp_dir"
install -m 755 "$tmp_dir/zellij" "$HOME/.local/bin/zellij"

echo "Installed zellij to $HOME/.local/bin/zellij"
'@

  $bashScript | wsl.exe sh -s --

  if ($LASTEXITCODE -ne 0) {
    throw "WSL Zellij installation failed."
  }
}

function Write-WezTermConfig {
  $shellCommand = Get-PreferredShellCommand
  $userHome = [Environment]::GetFolderPath("UserProfile")
  $configPath = Join-Path $userHome ".wezterm.lua"

  $content = @"
-- $($script:ManagedFileHeader)
local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

config.default_prog = { "$shellCommand", "-NoLogo" }
config.font = wezterm.font_with_fallback({
  "Cascadia Mono",
  "Segoe UI Emoji",
  "Symbols Nerd Font Mono",
})
config.font_size = 12.0
config.line_height = 1.08
config.harfbuzz_features = { "calt=1", "clig=1", "liga=1" }
config.window_background_opacity = 1.0
config.text_background_opacity = 1.0
config.window_padding = {
  left = 10,
  right = 10,
  top = 8,
  bottom = 8,
}
config.scrollback_lines = 10000
config.scroll_to_bottom_on_input = true
config.enable_scroll_bar = false
config.min_scroll_bar_height = "2cell"
config.enable_kitty_keyboard = false
config.bypass_mouse_reporting_modifiers = "SHIFT"
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.adjust_window_size_when_changing_font_size = false
config.audible_bell = "Disabled"
config.window_decorations = "TITLE | RESIZE"
config.inactive_pane_hsb = {
  saturation = 0.92,
  brightness = 0.72,
}
config.colors = {
  foreground = "#e6edf7",
  background = "#05070c",
  cursor_bg = "#88c0d0",
  cursor_fg = "#05070c",
  cursor_border = "#88c0d0",
  selection_fg = "#e5e9f0",
  selection_bg = "#3b5268",
  scrollbar_thumb = "#36465c",
  split = "#2f3745",
  ansi = {
    "#151b26",
    "#bf616a",
    "#a3be8c",
    "#ebcb8b",
    "#81a1c1",
    "#b48ead",
    "#88c0d0",
    "#d8dee9",
  },
  brights = {
    "#667386",
    "#ec7486",
    "#b1d196",
    "#f2d38f",
    "#8fbcdb",
    "#c895bf",
    "#93ccdc",
    "#eceff4",
  },
  tab_bar = {
    background = "#05070c",
    active_tab = {
      bg_color = "#81a1c1",
      fg_color = "#05070c",
      intensity = "Bold",
    },
    inactive_tab = {
      bg_color = "#101622",
      fg_color = "#9aa8bb",
    },
    inactive_tab_hover = {
      bg_color = "#1b2636",
      fg_color = "#e6edf7",
    },
    new_tab = {
      bg_color = "#05070c",
      fg_color = "#9aa8bb",
    },
    new_tab_hover = {
      bg_color = "#1b2636",
      fg_color = "#e6edf7",
      intensity = "Bold",
    },
  },
}
config.leader = { key = "Space", mods = "CTRL|SHIFT", timeout_milliseconds = 1200 }
config.launch_menu = {
  {
    label = "PowerShell",
    args = { "$shellCommand", "-NoLogo" },
  },
  {
    label = "WSL default distro",
    args = { "wsl.exe" },
  },
  {
    label = "WSL + zellij",
    args = { "wsl.exe", "sh", "-lc", "if [ -x \"`$HOME/.local/bin/zellij\" ]; then exec \"`$HOME/.local/bin/zellij\"; elif command -v zellij >/dev/null 2>&1; then exec zellij; else echo 'zellij is not installed in WSL yet'; exec sh -l; fi" },
  },
}
local right_click_copy_or_paste = wezterm.action_callback(function(window, pane)
  local selection = window:get_selection_text_for_pane(pane)
  if selection and selection ~= "" then
    window:perform_action(act.CopyTo("Clipboard"), pane)
    window:perform_action(act.ClearSelection, pane)
  else
    window:perform_action(act.PasteFrom("Clipboard"), pane)
  end
end)

wezterm.on("toggle-scrollbar", function(window, pane)
  local overrides = window:get_config_overrides() or {}
  overrides.enable_scroll_bar = not overrides.enable_scroll_bar
  window:set_config_overrides(overrides)
end)

config.mouse_bindings = {
  {
    event = { Down = { streak = 1, button = "Right" } },
    mods = "NONE",
    action = right_click_copy_or_paste,
  },
  {
    event = { Down = { streak = 1, button = "Right" } },
    mods = "NONE",
    mouse_reporting = true,
    action = right_click_copy_or_paste,
  },
}
config.keys = {
  {
    key = "End",
    mods = "SHIFT",
    action = act.ScrollToBottom,
  },
  {
    key = "End",
    mods = "CTRL|SHIFT",
    action = act.ScrollToBottom,
  },
  {
    key = "Enter",
    mods = "SHIFT",
    action = act.SendString("\x1b[13;2u"),
  },
  {
    key = "s",
    mods = "CTRL|SHIFT",
    action = act.EmitEvent("toggle-scrollbar"),
  },
  {
    key = "g",
    mods = "CTRL|SHIFT",
    action = wezterm.action.SpawnCommandInNewTab({
      args = { "$shellCommand", "-NoLogo", "-Command", "lazygit" },
    }),
  },
  {
    key = "e",
    mods = "CTRL|SHIFT",
    action = wezterm.action.SpawnCommandInNewTab({
      args = { "$shellCommand", "-NoLogo", "-Command", "nvim" },
    }),
  },
  {
    key = "f",
    mods = "CTRL|SHIFT",
    action = wezterm.action.SpawnCommandInNewTab({
      args = { "$shellCommand", "-NoLogo", "-Command", "yazi" },
    }),
  },
  {
    key = "z",
    mods = "CTRL|SHIFT",
    action = wezterm.action.SpawnCommandInNewTab({
      args = { "wsl.exe", "sh", "-lc", "if [ -x \"`$HOME/.local/bin/zellij\" ]; then exec \"`$HOME/.local/bin/zellij\"; elif command -v zellij >/dev/null 2>&1; then exec zellij; else echo 'zellij is not installed in WSL yet'; exec sh -l; fi" },
    }),
  },
}

return config
"@

  Write-ManagedFile -Path $configPath -Content $content -Label "WezTerm config"
}

function Write-NeovimConfig {
  $appData = [Environment]::GetFolderPath("LocalApplicationData")
  $configPath = Join-Path $appData "nvim\init.lua"

  $content = @"
-- $($script:ManagedFileHeader)
vim.g.mapleader = " "

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = ""
vim.opt.clipboard = "unnamedplus"
vim.opt.termguicolors = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.scrolloff = 6
vim.opt.sidescrolloff = 6
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 200
vim.opt.cursorline = true
vim.opt.wrap = false
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.numberwidth = 4
vim.opt.laststatus = 3
vim.opt.pumheight = 12
vim.opt.completeopt = { "menuone", "noselect" }

vim.cmd.colorscheme("habamax")

local function open_bottom_term(command, height)
  vim.cmd("botright " .. tostring(height or 14) .. "split")
  vim.cmd("terminal " .. command)
  vim.cmd("startinsert")
end

vim.keymap.set("t", "<Esc><Esc>", [[<C-\\><C-n>]], { silent = true })
vim.keymap.set("n", "<leader>gg", function()
  open_bottom_term("lazygit", 18)
end, { silent = true, desc = "Open Lazygit" })
vim.keymap.set("n", "<leader>yy", function()
  open_bottom_term("yazi", 18)
end, { silent = true, desc = "Open Yazi" })
vim.keymap.set("n", "<leader>tt", function()
  open_bottom_term(vim.o.shell, 14)
end, { silent = true, desc = "Open terminal" })
vim.keymap.set("n", "<leader>w", "<cmd>write<cr>", { silent = true, desc = "Write buffer" })
vim.keymap.set("n", "<leader>q", "<cmd>quit<cr>", { silent = true, desc = "Quit window" })
vim.keymap.set("n", "<leader>bd", "<cmd>bdelete<cr>", { silent = true, desc = "Delete buffer" })

vim.api.nvim_create_user_command("Lazygit", function()
  open_bottom_term("lazygit", 18)
end, {})

vim.api.nvim_create_user_command("Yazi", function()
  open_bottom_term("yazi", 18)
end, {})

vim.api.nvim_create_user_command("TermHere", function()
  open_bottom_term(vim.o.shell, 14)
end, {})
"@

  Write-ManagedFile -Path $configPath -Content $content -Label "Neovim config"
}

function Update-PowerShellProfile {
  $block = @"
# $($script:ManagedFileHeader)
function Add-SafeTerminalStackPathEntry {
  param([string]`$PathEntry)

  if ([string]::IsNullOrWhiteSpace(`$PathEntry) -or -not (Test-Path -LiteralPath `$PathEntry)) {
    return
  }

  `$currentParts = @()
  if (-not [string]::IsNullOrWhiteSpace(`$env:Path)) {
    `$currentParts = `$env:Path.Split(";", [System.StringSplitOptions]::RemoveEmptyEntries)
  }

  foreach (`$part in `$currentParts) {
    if (`$part.TrimEnd("\\") -ieq `$PathEntry.TrimEnd("\\")) {
      return
    }
  }

  `$env:Path = "`$PathEntry;`$env:Path"
}

`$safeTerminalPortableRoot = Join-Path `$env:LOCALAPPDATA "Programs\safe-terminal-stack"
`$safeTerminalShimRoot = Join-Path `$HOME ".local\bin"

Add-SafeTerminalStackPathEntry -PathEntry `$safeTerminalShimRoot

if (Test-Path -LiteralPath `$safeTerminalPortableRoot) {
  `$toolDirs = @(Get-ChildItem -LiteralPath `$safeTerminalPortableRoot -Directory -ErrorAction SilentlyContinue | Sort-Object -Property Name)
  foreach (`$toolDir in `$toolDirs) {
    Add-SafeTerminalStackPathEntry -PathEntry `$toolDir.FullName

    `$binChild = Join-Path `$toolDir.FullName "bin"
    if (Test-Path -LiteralPath `$binChild) {
      Add-SafeTerminalStackPathEntry -PathEntry `$binChild
    }
  }
}

Set-Alias -Name v -Value nvim
Set-Alias -Name lg -Value lazygit
Set-Alias -Name yz -Value yazi

function repo {
  param([string]`$Path = ".")
  yazi `$Path
}

function gst {
  git status -sb
}

function glg {
  git log --oneline --graph --decorate -20
}

function zdev {
  wsl.exe sh -lc 'if [ -x "`$HOME/.local/bin/zellij" ]; then exec "`$HOME/.local/bin/zellij"; elif command -v zellij >/dev/null 2>&1; then exec zellij; else echo "zellij is not installed in WSL yet"; exec sh -l; fi'
}
"@

  foreach ($profilePath in (Get-PowerShellProfileTargets)) {
    Upsert-ProfileBlock -BlockContent $block -ProfilePath $profilePath
  }
}

if ($SmokeTestsOnly) {
  Refresh-SessionPath
  Invoke-SmokeTests
  return
}

Write-Step "Selecting installation backend"
Initialize-InstallBackend

Write-Step "Installing Windows packages"

if (-not $SkipGitInstall) {
  Install-Tool -Label "Git for Windows" -WinGetId "Git.Git" -ChocoId "git" -CommandNames @("git.exe", "git") -Optional
}

Install-Tool -Label "WezTerm" -WinGetId "wez.wezterm" -ChocoId "wezterm" -PortableRepo "wez/wezterm" -PortableAssetPattern "^WezTerm-windows-.*\.zip$" -PortableDestinationName "wezterm" -CommandNames @("wezterm.exe", "wezterm")
Install-Tool -Label "Neovim" -WinGetId "Neovim.Neovim" -ChocoId "neovim" -PortableRepo "neovim/neovim" -PortableAssetPattern "^nvim-win64\.zip$" -PortableDestinationName "neovim" -PortablePathSuffix "bin" -CommandNames @("nvim.exe", "nvim")
Install-Tool -Label "Lazygit" -WinGetId "JesseDuffield.lazygit" -ChocoId "lazygit" -PortableRepo "jesseduffield/lazygit" -PortableAssetPattern "windows_x86_64\.zip$" -PortableDestinationName "lazygit" -CommandNames @("lazygit.exe", "lazygit")
Install-Tool -Label "Yazi" -WinGetId "sxyazi.yazi" -ChocoId "yazi" -PortableRepo "sxyazi/yazi" -PortableAssetPattern "x86_64-pc-windows-msvc\.zip$" -PortableDestinationName "yazi" -CommandNames @("yazi.exe", "yazi")
Install-Tool -Label "ripgrep" -WinGetId "BurntSushi.ripgrep.MSVC" -ChocoId "ripgrep" -PortableRepo "BurntSushi/ripgrep" -PortableAssetPattern "x86_64-pc-windows-msvc\.zip$" -PortableDestinationName "ripgrep" -CommandNames @("rg.exe", "rg")
Install-Tool -Label "fd" -WinGetId "sharkdp.fd" -ChocoId "fd" -PortableRepo "sharkdp/fd" -PortableAssetPattern "x86_64-pc-windows-msvc\.zip$" -PortableDestinationName "fd" -CommandNames @("fd.exe", "fd")
Install-Tool -Label "fzf" -WinGetId "junegunn.fzf" -ChocoId "fzf" -PortableRepo "junegunn/fzf" -PortableAssetPattern "windows_amd64\.zip$" -PortableDestinationName "fzf" -CommandNames @("fzf.exe", "fzf")
Install-Tool -Label "zoxide" -WinGetId "ajeetdsouza.zoxide" -ChocoId "zoxide" -PortableRepo "ajeetdsouza/zoxide" -PortableAssetPattern "x86_64-pc-windows-msvc\.zip$" -PortableDestinationName "zoxide" -CommandNames @("zoxide.exe", "zoxide")
Install-Tool -Label "7-Zip" -WinGetId "7zip.7zip" -ChocoId "7zip" -CommandNames @("7z.exe", "7z") -Optional
Install-Tool -Label "jq" -WinGetId "jqlang.jq" -ChocoId "jq" -PortableRepo "jqlang/jq" -PortableAssetPattern "jq-windows-amd64\.exe$" -PortableDestinationName "jq" -PortableSingleFileRelativePath "bin\jq.exe" -CommandNames @("jq.exe", "jq")

Refresh-SessionPath

Write-Step "Configuring user environment"
Set-UserEnvironmentValueIfMissing -Name "EDITOR" -Value "nvim"
Set-UserEnvironmentValueIfMissing -Name "VISUAL" -Value "nvim"

$gitFileOne = Resolve-GitFileOnePath
if ($gitFileOne) {
  Set-UserEnvironmentValueIfMissing -Name "YAZI_FILE_ONE" -Value $gitFileOne
} else {
  Write-WarnLine "Could not find Git's file.exe. Yazi will still work, but MIME detection and previews will be better after Git for Windows is installed and YAZI_FILE_ONE is set."
}

Write-Step "Writing starter configs"
Write-WezTermConfig
Write-NeovimConfig
Update-PowerShellProfile
Write-ManagedCommandShims
Register-WezTermExplorerContextMenu

Install-WslZellijLocal

if ($RunSmokeTests) {
  Invoke-SmokeTests
}

Write-Step "Done"
Write-Host "Restart PowerShell or open a new WezTerm window before using the new aliases and environment variables." -ForegroundColor Green
Write-Host "Recommended first run: wezterm, nvim, lazygit, yazi, and zdev (for WSL zellij)." -ForegroundColor Green
Write-Host "Re-running this script is safe: installed tools are skipped when present, managed configs self-update only when needed, and smoke tests can be run on demand." -ForegroundColor Green
Write-Host "Managed command shims are also written to $($script:ShimRoot) so commands like 'wezterm' can work immediately in shells that already have that directory on PATH." -ForegroundColor Green
