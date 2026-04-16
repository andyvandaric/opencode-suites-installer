$ErrorActionPreference = "Stop"

$script:Yes = $false
$script:DryRun = $false
$script:NoBackup = $false
$script:BackupDir = ""
$script:Step = 0
$script:TotalSteps = 9

function Write-Info([string]$Message) { Write-Host "  $Message" }
function Write-Warn([string]$Message) { Write-Host "WARN  $Message" -ForegroundColor Yellow }
function Write-Success([string]$Message) { Write-Host "OK    $Message" -ForegroundColor Green }
function Fail-Arg([string]$Message) {
  Write-Host "ERROR $Message" -ForegroundColor Red
  exit 2
}
function Fail-Fatal([string]$Message) {
  Write-Host "ERROR $Message" -ForegroundColor Red
  exit 1
}

function Show-Usage {
  Write-Host @"
Usage: uninstall.ps1 [options]

Options:
  -Yes                  Non-interactive confirmation
  -DryRun               Print actions without mutating filesystem
  -NoBackup             Skip backup archive creation
  -BackupDir <path>     Backup output directory
  -Help                 Show this help

Environment:
  OCS_TARGET_HOME       Home directory to clean when running elevated

Behavior:
  - Fully removes ~/.config/opencode and other OCS/OpenCode runtime data
  - No safe/partial mode
"@
}

function Parse-Arguments {
  param([string[]]$Arguments)

  $index = 0
  while ($index -lt $Arguments.Count) {
    $arg = $Arguments[$index]
    $lower = $arg.ToLowerInvariant()

    switch -Regex ($lower) {
      '^(-h|--help|-help)$' {
        Show-Usage
        exit 0
      }
      '^(-yes|--yes|-y)$' {
        $script:Yes = $true
        $index += 1
        continue
      }
      '^(-dryrun|-dry-run|--dry-run)$' {
        $script:DryRun = $true
        $index += 1
        continue
      }
      '^(-nobackup|-no-backup|--no-backup)$' {
        $script:NoBackup = $true
        $index += 1
        continue
      }
      '^(-backupdir|-backup-dir|--backup-dir)$' {
        if ($index + 1 -ge $Arguments.Count) {
          Fail-Arg "Missing value for -BackupDir"
        }
        $script:BackupDir = $Arguments[$index + 1]
        $index += 2
        continue
      }
      '^(-backupdir:|-backup-dir:|--backup-dir=)(.+)$' {
        $script:BackupDir = $matches[2]
        $index += 1
        continue
      }
      default {
        Fail-Arg "Unknown option: $arg"
      }
    }
  }
}

function Resolve-HomeDirectory {
  if ($env:OCS_TARGET_HOME) {
    return $env:OCS_TARGET_HOME
  }

  if ($env:HOME) {
    return $env:HOME
  }

  if ($env:USERPROFILE) {
    return $env:USERPROFILE
  }

  try {
    $profileHome = [Environment]::GetFolderPath("UserProfile")
    if ($profileHome) {
      return $profileHome
    }
  } catch {
  }

  if ($env:HOMEDRIVE -and $env:HOMEPATH) {
    return ($env:HOMEDRIVE + $env:HOMEPATH)
  }

  if ($env:TEMP) {
    return $env:TEMP
  }

  Fail-Fatal "Unable to resolve HOME directory."
}

function Next-Step([string]$Message) {
  $script:Step += 1
  Write-Host ""
  Write-Host "[$($script:Step)/$($script:TotalSteps)] $Message"
}

function Invoke-Run {
  param(
    [scriptblock]$Action,
    [string]$Preview
  )

  if ($script:DryRun) {
    Write-Info "[dry-run] $Preview"
    return
  }

  & $Action
}

function Remove-PathIfExists([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return }
  Write-Info "REMOVE $Path"
  Invoke-Run -Preview "Remove-Item -LiteralPath '$Path' -Recurse -Force" -Action {
    Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
  }
}

function Cleanup-OpencodeConfig([string]$HomeDir) {
  $configDir = Join-Path $HomeDir ".config\opencode"
  $authDir = Join-Path $configDir "auth"
  if (-not (Test-Path -LiteralPath $configDir)) { return }

  if (-not (Test-Path -LiteralPath $authDir)) {
    Remove-PathIfExists $configDir
    return
  }

  Write-Info "PRESERVE $authDir"
  $entries = Get-ChildItem -LiteralPath $configDir -Force -ErrorAction SilentlyContinue
  foreach ($entry in $entries) {
    if ($entry.FullName -eq $authDir) {
      continue
    }
    Remove-PathIfExists $entry.FullName
  }
}

function Remove-InstallerManagedSymlink([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return }

  try {
    $item = Get-Item -LiteralPath $Path -Force
    if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
      Write-Warn "Skip $Path (not a symlink/reparse point)"
      return
    }
  } catch {
    Write-Warn "Skip $Path (unable to inspect link metadata)"
    return
  }

  Write-Info "REMOVE managed link $Path"
  Invoke-Run -Preview "Remove-Item -LiteralPath '$Path' -Force" -Action {
    Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
  }
}

function Stop-RelatedProcesses {
  $patterns = @("opencode", "ocs")
  foreach ($pattern in $patterns) {
    if ($script:DryRun) {
      Write-Info "[dry-run] Stop-Process match $pattern"
      continue
    }

    try {
      Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -match $pattern
      } | Stop-Process -Force -ErrorAction SilentlyContinue
    } catch {
      Write-Warn "Process cleanup warning for pattern '$pattern'"
    }
  }
}

function Create-Backup {
  param([string]$HomeDir)

  if ($script:NoBackup) { return }

  $sources = @(
    (Join-Path $HomeDir ".config\opencode"),
    (Join-Path $HomeDir ".opencode"),
    (Join-Path $HomeDir ".opencode-suites"),
    (Join-Path $HomeDir ".cache\opencode"),
    (Join-Path $HomeDir ".local\share\opencode")
  ) | Where-Object { Test-Path -LiteralPath $_ }

  if ($sources.Count -eq 0) {
    Write-Info "No directories found for backup."
    return
  }

  $backupDir = $script:BackupDir
  if (-not $backupDir) {
    $backupDir = Join-Path $HomeDir ".opencode-suites-uninstall-backups"
  }

  $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $archive = Join-Path $backupDir "ocs-uninstall-backup-$timestamp.zip"
  Write-Info "Creating backup archive: $archive"

  Invoke-Run -Preview "Compress-Archive -> $archive" -Action {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    Compress-Archive -Path $sources -DestinationPath $archive -CompressionLevel Optimal -Force
  }

  if (-not $script:DryRun) {
    if (-not (Test-Path -LiteralPath $archive)) {
      Fail-Fatal "Backup archive not found after create: $archive"
    }
    Write-Success "Backup created: $archive"
  }
}

function Uninstall-GlobalPackages {
  if (Get-Command bun -ErrorAction SilentlyContinue) {
    foreach ($pkg in @("opencode-ai", "@opencode-ai/opencode")) {
      if ($script:DryRun) {
        Write-Info "[dry-run] bun remove -g $pkg"
      } else {
        try { bun remove -g $pkg | Out-Null } catch { Write-Warn "bun remove -g $pkg failed (non-fatal)" }
      }
    }
  }

  if (Get-Command npm -ErrorAction SilentlyContinue) {
    foreach ($pkg in @("opencode-ai", "@opencode-ai/opencode")) {
      if ($script:DryRun) {
        Write-Info "[dry-run] npm uninstall -g $pkg"
      } else {
        try { npm uninstall -g $pkg | Out-Null } catch { Write-Warn "npm uninstall -g $pkg failed (non-fatal)" }
      }
    }
  }
}

function Show-Plan([string]$HomeDir) {
  Write-Host ""
  Write-Host "Target HOME: $HomeDir"
  if ($script:DryRun) { Write-Host "Dry-run: enabled" }

  Write-Host ""
  Write-Host "Will remove:"
  Write-Host "  - ~/.config/opencode except ~/.config/opencode/auth"
  Write-Host "  - ~/.opencode"
  Write-Host "  - ~/.opencode-suites"
  Write-Host "  - ~/.cache/opencode"
  Write-Host "  - ~/.local/share/opencode"
  Write-Host "  - local shims and installer-managed links"
  Write-Host "  - global package links (best effort)"
  Write-Host ""
  Write-Host "Will preserve:"
  Write-Host "  - ~/.config/opencode/auth"
}

function Confirm-Flow([string]$HomeDir) {
  Show-Plan $HomeDir

  if ($script:Yes) { return }

  Write-Host ""
  Write-Host "This removes ~/.config/opencode except the auth directory."
  $answer = Read-Host "Continue? [y/N]"
  if ($answer -notin @("y", "Y", "yes", "YES")) {
    Write-Info "Cancelled."
    exit 0
  }
}

function Verify-CommandState {
  $found = $false
  foreach ($cmd in @("ocs", "opencode")) {
    $match = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($null -ne $match) {
      Write-Warn "$cmd still resolves to: $($match.Source)"
      $found = $true
    }
  }

  if (-not $found) {
    Write-Success "No ocs/opencode command found in current PATH."
  } else {
    Write-Warn "Some commands still resolve. Open a new shell and re-check."
  }
}

Parse-Arguments -Arguments $args
$homeDir = Resolve-HomeDirectory

Next-Step "Confirm uninstall plan"
Confirm-Flow $homeDir

Next-Step "Create backup"
Create-Backup $homeDir

Next-Step "Stop related processes"
Stop-RelatedProcesses

Next-Step "Remove local command shims"
Remove-PathIfExists (Join-Path $homeDir ".local\bin\ocs")
Remove-PathIfExists (Join-Path $homeDir ".local\bin\opencode")
Remove-PathIfExists (Join-Path $homeDir ".bun\bin\ocs")
Remove-PathIfExists (Join-Path $homeDir ".bun\bin\opencode")
Remove-PathIfExists (Join-Path $homeDir ".opencode\bin\ocs")
Remove-PathIfExists (Join-Path $homeDir ".opencode\bin\opencode")

Next-Step "Remove installer-managed links"
Remove-InstallerManagedSymlink "$homeDir/.local/bin/ocs"
Remove-InstallerManagedSymlink "$homeDir/.local/bin/opencode"

Next-Step "Remove global packages (best effort)"
Uninstall-GlobalPackages

Next-Step "Remove runtime/cache directories"
Remove-PathIfExists (Join-Path $homeDir ".opencode")
Remove-PathIfExists (Join-Path $homeDir ".opencode-suites")
Remove-PathIfExists (Join-Path $homeDir ".cache\opencode")
Remove-PathIfExists (Join-Path $homeDir ".local\share\opencode")

Next-Step "Clean ~/.config/opencode (preserve auth)"
Cleanup-OpencodeConfig $homeDir

Next-Step "Verify command/path state"
Verify-CommandState

Write-Success "Uninstall flow completed."
Write-Host ""
Write-Host "Next step (clean-room reinstall test):"
Write-Host '  powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/staging/v2.3.1/install.ps1 | iex"'

exit 0
