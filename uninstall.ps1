$script:Mode = "safe"
$script:Yes = $false
$script:ForcePurge = $false
$script:DryRun = $false
$script:NoBackup = $false
$script:BackupDir = "$HOME/.opencode-suites-uninstall-backups"

$ErrorActionPreference = "Stop"
$exitOk = 0
$exitFatal = 1
$exitArg = 2
$script:Step = 0
$script:TotalSteps = 8
$script:PreserveExisting = @()

function Write-Info([string]$Message) { Write-Host "  $Message" }
function Write-Warn([string]$Message) { Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Success([string]$Message) { Write-Host "✅ $Message" -ForegroundColor Green }

function Fail-Arg([string]$Message) {
  Write-Host "❌ $Message" -ForegroundColor Red
  exit $exitArg
}

function Fail-Fatal([string]$Message) {
  Write-Host "❌ $Message" -ForegroundColor Red
  exit $exitFatal
}

function Show-Usage {
  Write-Host @"
Usage: uninstall.ps1 [options]

Options:
  -Mode <safe|purge>         Uninstall mode (default: safe)
  -Yes                       Non-interactive confirmation
  -ForcePurge                Required with -Yes -Mode purge
  -DryRun                    Print actions without mutating filesystem
  -NoBackup                  Skip backup archive creation
  -BackupDir <path>          Backup output directory
  -Help                      Show this help

Exit codes:
  0 = success (including non-fatal warnings)
  1 = fatal execution error
  2 = invalid arguments / missing purge gate
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
        exit $exitOk
      }
      '^(-mode|--mode)$' {
        if ($index + 1 -ge $Arguments.Count) {
          Fail-Arg "Missing value for -Mode"
        }
        $script:Mode = $Arguments[$index + 1].ToLowerInvariant()
        $index += 2
        continue
      }
      '^(-mode:|--mode=)(.+)$' {
        $script:Mode = $matches[2].ToLowerInvariant()
        $index += 1
        continue
      }
      '^(-yes|--yes|-y)$' {
        $script:Yes = $true
        $index += 1
        continue
      }
      '^(-forcepurge|-force-purge|--force-purge)$' {
        $script:ForcePurge = $true
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

  if ($script:Mode -notin @("safe", "purge")) {
    Fail-Arg "Invalid -Mode value: $($script:Mode) (expected safe|purge)"
  }

  if ($script:Mode -eq "safe" -and $script:ForcePurge) {
    Fail-Arg "-ForcePurge can only be used with -Mode purge"
  }
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

  if ($DryRun) {
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

function Remove-InstallerManagedSymlink([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return }

  $item = Get-Item -LiteralPath $Path -Force
  if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    Write-Warn "Skip $Path (not a symlink/reparse point)"
    return
  }

  Write-Info "REMOVE managed link $Path"
  Invoke-Run -Preview "Remove-Item -LiteralPath '$Path' -Force" -Action {
    Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
  }
}

function Stop-RelatedProcesses {
  $patterns = @("opencode", "ocs")
  foreach ($p in $patterns) {
    if ($DryRun) {
      Write-Info "[dry-run] Stop-Process match $p"
      continue
    }

    try {
      Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -match $p
      } | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    catch {
      Write-Warn "Process cleanup warning for pattern '$p'"
    }
  }
}

function Create-Backup {
  if ($NoBackup) { return }

  $sources = @(
    "$HOME/.config/opencode",
    "$HOME/.opencode",
    "$HOME/.opencode-suites",
    "$HOME/.cache/opencode",
    "$HOME/.local/share/opencode"
  ) | Where-Object { Test-Path -LiteralPath $_ }

  if ($sources.Count -eq 0) {
    Write-Info "No directories found for backup."
    return
  }

  $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $archive = Join-Path $BackupDir "ocs-uninstall-backup-$timestamp.zip"
  Write-Info "Creating backup archive: $archive"

  Invoke-Run -Preview "Compress-Archive -> $archive" -Action {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    Compress-Archive -Path $sources -DestinationPath $archive -CompressionLevel Optimal -Force
  }

  if (-not $DryRun) {
    if (-not (Test-Path -LiteralPath $archive)) {
      Fail-Fatal "Backup archive not found after create: $archive"
    }
    Write-Success "Backup created: $archive"
  }
}

function Cleanup-ConfigSafe {
  $configDir = "$HOME/.config/opencode"
  if (-not (Test-Path -LiteralPath $configDir)) { return }

  $preserveExact = @(
    "opencode.json",
    "openai-session-state.json"
  )

  $preserveWildcard = @(
    "openai-accounts*.json",
    "antigravity-accounts*.json"
  )

  Get-ChildItem -LiteralPath $configDir -Force | ForEach-Object {
    $name = $_.Name
    $keep = $false

    if ($preserveExact -contains $name) {
      $keep = $true
    }
    else {
      foreach ($pattern in $preserveWildcard) {
        if ($name -like $pattern) {
          $keep = $true
          break
        }
      }
    }

    if ($keep) {
      Write-Info "PRESERVE $($_.FullName)"
    }
    else {
      Remove-PathIfExists -Path $_.FullName
    }
  }
}

function Capture-SafePreserveTargets {
  $configDir = "$HOME/.config/opencode"
  $script:PreserveExisting = @()

  if (-not (Test-Path -LiteralPath $configDir)) { return }

  $preserveExact = @(
    "opencode.json",
    "openai-session-state.json"
  )

  $preserveWildcard = @(
    "openai-accounts*.json",
    "antigravity-accounts*.json"
  )

  foreach ($name in $preserveExact) {
    $candidate = Join-Path $configDir $name
    if (Test-Path -LiteralPath $candidate) {
      $script:PreserveExisting += $candidate
    }
  }

  $allEntries = Get-ChildItem -LiteralPath $configDir -File -ErrorAction SilentlyContinue
  foreach ($entry in $allEntries) {
    foreach ($pattern in $preserveWildcard) {
      if ($entry.Name -like $pattern) {
        $script:PreserveExisting += $entry.FullName
        break
      }
    }
  }

  $script:PreserveExisting = $script:PreserveExisting | Select-Object -Unique
}

function Verify-SafePreserve {
  if ($DryRun -or $Mode -ne "safe") { return }

  foreach ($file in $script:PreserveExisting) {
    if (-not (Test-Path -LiteralPath $file)) {
      Fail-Fatal "Safe-mode preservation check failed: $file"
    }
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
  }
  else {
    Write-Warn "Some commands still resolve. Open a new shell and re-check."
  }
}

function Uninstall-GlobalPackages {
  if (Get-Command bun -ErrorAction SilentlyContinue) {
    foreach ($pkg in @("opencode-ai", "@opencode-ai/opencode")) {
      if ($DryRun) {
        Write-Info "[dry-run] bun remove -g $pkg"
      }
      else {
        try { bun remove -g $pkg | Out-Null } catch { Write-Warn "bun remove -g $pkg failed (non-fatal)" }
      }
    }
  }

  if (Get-Command npm -ErrorAction SilentlyContinue) {
    foreach ($pkg in @("opencode-ai", "@opencode-ai/opencode")) {
      if ($DryRun) {
        Write-Info "[dry-run] npm uninstall -g $pkg"
      }
      else {
        try { npm uninstall -g $pkg | Out-Null } catch { Write-Warn "npm uninstall -g $pkg failed (non-fatal)" }
      }
    }
  }
}

function Show-Plan {
  Write-Host ""
  Write-Host "Uninstall mode: $Mode"
  Write-Host "Target HOME: $HOME"
  if ($DryRun) { Write-Host "Dry-run: enabled" }

  Write-Host ""
  Write-Host "Will remove:"
  Write-Host "  - local shims/binaries and installer-managed links"
  Write-Host "  - global package links (best effort)"
  Write-Host "  - ~/.opencode, ~/.opencode-suites, ~/.cache/opencode, ~/.local/share/opencode"
  if ($Mode -eq "safe") {
    Write-Host "  - ~/.config/opencode/* except account/API-key files"
  }
  else {
    Write-Host "  - ~/.config/opencode (full purge)"
  }

  Write-Host ""
  Write-Host "Will preserve (safe mode):"
  Write-Host "  - ~/.config/opencode/opencode.json"
  Write-Host "  - ~/.config/opencode/openai-accounts*.json"
  Write-Host "  - ~/.config/opencode/openai-session-state.json"
  Write-Host "  - ~/.config/opencode/antigravity-accounts*.json"
}

function Confirm-Flow {
  Show-Plan

  if ($Mode -eq "purge") {
    if ($Yes) {
      if (-not $ForcePurge) {
        Fail-Arg "-Yes with -Mode purge requires -ForcePurge"
      }
      return
    }

    $token = Read-Host "Type PURGE to continue"
    if ($token -ne "PURGE") {
      Write-Info "Cancelled."
      exit $exitOk
    }
    return
  }

  if ($Yes) { return }

  $ans = Read-Host "Proceed with SAFE uninstall? [y/N]"
  if ($ans -notin @("y", "Y", "yes", "YES")) {
    Write-Info "Cancelled."
    exit $exitOk
  }
}

Parse-Arguments -Arguments $args

if ($Mode -eq "safe") {
  Capture-SafePreserveTargets
}

Confirm-Flow

Next-Step "Create backup"
Create-Backup

Next-Step "Stop related processes"
Stop-RelatedProcesses

Next-Step "Remove local command shims"
Remove-PathIfExists "$HOME/.local/bin/ocs"
Remove-PathIfExists "$HOME/.local/bin/opencode"
Remove-PathIfExists "$HOME/.bun/bin/ocs"
Remove-PathIfExists "$HOME/.bun/bin/opencode"
Remove-PathIfExists "$HOME/.opencode/bin/ocs"
Remove-PathIfExists "$HOME/.opencode/bin/opencode"

Next-Step "Remove installer-managed links"
Remove-InstallerManagedSymlink "$HOME/.local/bin/ocs"
Remove-InstallerManagedSymlink "$HOME/.local/bin/opencode"

Next-Step "Remove global packages (best effort)"
Uninstall-GlobalPackages

Next-Step "Remove runtime/cache directories"
Remove-PathIfExists "$HOME/.opencode"
Remove-PathIfExists "$HOME/.opencode-suites"
Remove-PathIfExists "$HOME/.cache/opencode"
Remove-PathIfExists "$HOME/.local/share/opencode"

Next-Step "Apply config cleanup policy"
if ($Mode -eq "purge") {
  Remove-PathIfExists "$HOME/.config/opencode"
}
else {
  Cleanup-ConfigSafe
}

Next-Step "Verify command/path state"
Verify-SafePreserve
Verify-CommandState

Write-Success "Uninstall flow completed (mode=$Mode)."
Write-Host ""
Write-Host "Next step (clean-room reinstall test):"
Write-Host '  pwsh -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/staging/v2.1.14/install.ps1 | iex"'

exit $exitOk
