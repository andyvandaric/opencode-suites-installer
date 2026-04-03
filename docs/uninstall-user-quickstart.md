# Uninstall Quickstart (User Guide)

Use this guide when you want to reset OCS quickly without accidentally deleting credentials.

## Safest Reset (Recommended)

`safe` mode keeps account/API-key files and removes installer/runtime artifacts.

### Linux / macOS / WSL

```bash
bash ./uninstall.sh --mode safe --yes
```

Raw (tanpa clone repo):

```bash
curl -fsSL https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/main/uninstall.sh | bash -s -- --mode safe --yes
```

### Windows (PowerShell 7)

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1 -Mode safe -Yes
```

Raw (tanpa clone repo):

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/main/uninstall.ps1'))) -Mode safe -Yes"
```

## Channel-aware Raw Commands

Use branch-specific raw URL if you want uninstall behavior aligned to lane:

- beta:
  - `https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/beta/uninstall.sh`
  - `https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/beta/uninstall.ps1`
- staging/v2.1.14:
  - `https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/staging/v2.1.14/uninstall.sh`
  - `https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/staging/v2.1.14/uninstall.ps1`

## Preview First (No Changes)

### Linux / macOS / WSL

```bash
bash ./uninstall.sh --mode safe --dry-run
```

### Windows (PowerShell 7)

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1 -Mode safe -DryRun
```

## Full Wipe (Destructive)

Use `purge` only if you intentionally want to remove credential/account artifacts too.

### Linux / macOS / WSL

```bash
bash ./uninstall.sh --mode purge --yes --force-purge
```

### Windows (PowerShell 7)

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1 -Mode purge -Yes -ForcePurge
```

## WSL Optional: Also Clean Windows Host Paths

By default, WSL uninstall does **not** touch Windows-host runtime paths.
If you need that cleanup too, add:

```bash
bash ./uninstall.sh --mode safe --yes --windows-host-cleanup
```

## Notes

- Backup is enabled by default.
- Exit code `0` = success, `1` = fatal error, `2` = invalid argument/safety gate not satisfied.
- Safe-mode preserve contract is documented in `docs/uninstall-parity-matrix.md`.
