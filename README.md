# opencode-suites-installer

Public installer entrypoints for OpenCode Config Suites.

## Quick Install

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/main/install.sh | bash
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/main/install.ps1 | iex
```

## Channel Mapping

- Buyer beta source repo: `andyvandaric/andyvand-opencode-config`
- Default source branch: `beta`
- Bundle source path: `assets/opencode-multi-auth-*.tar.gz`

## Access Behavior

- If your GitHub account has beta access, installer pulls bundle from buyer beta channel.
- If access is missing, installer redirects to WhatsApp purchase CTA.
