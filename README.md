# opencode-suites-installer

Public installer scripts for OpenCode Config Suites.

## Quick Install (Feature Testing)

Target branch: `feat/buyer-v2.1.4-setup-smoke`

### WSL / Linux / macOS (single script)

```bash
curl -fsSL https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/feat/buyer-v2.1.4-setup-smoke/install.sh | bash
```

Install specific version:

```bash
curl -fsSL https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/feat/buyer-v2.1.4-setup-smoke/install.sh | bash -s -- --version 2.1.4
```

WSL note: run this command inside WSL terminal (`bash`/`zsh`), not Windows PowerShell.

### Windows (PowerShell 7)

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/feat/buyer-v2.1.4-setup-smoke/install.ps1 | iex"
```

Install specific version:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -Command '$env:OCS_VERSION = "2.1.4"; irm https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/feat/buyer-v2.1.4-setup-smoke/install.ps1 | iex'
```

## Stable Install (`main`)

### WSL / Linux / macOS

```bash
curl -fsSL https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/main/install.sh | bash
```

### Windows (PowerShell 7)

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/main/install.ps1 | iex"
```

## Notes

- Installer downloads release assets from private repo: `andyvandaric/andyvand-opencode-config`
- You must have access to that private repo for install to succeed.
