# opencode-suites-installer

Public installer scripts for OpenCode Config Suites.

## Quick Install (Feature Testing)

Target branch: `feat/buyer-v2.1.4-setup-smoke`

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/feat/buyer-v2.1.4-setup-smoke/install-plugin.sh | bash
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/feat/buyer-v2.1.4-setup-smoke/install-plugin.ps1 | iex
```

## Stable Install (`main`)

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/main/install-plugin.sh | bash
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/main/install-plugin.ps1 | iex
```

## Notes

- Installer downloads release assets from private repo: `andyvandaric/opencode-config-suites-releases`
- You must have access to that private repo for install to succeed.
