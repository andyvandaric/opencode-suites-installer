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

## Public Repo Scope (Strict)

This public installer repository is intentionally minimal.

### Allowed in `main`

- `README.md`
- `install.ps1`
- `install.sh`

### Not Allowed in `main`

- Any source directories (for example `plugins/`, `apps/`, `scripts/`, `plans/`, `.github/`).
- Any release/build/runtime artifacts (`node_modules/`, coverage files, temp files).
- Any config or internal orchestration files from private development repos.

### Release Gate (must pass before merge)

1. `git ls-files` returns only the 3 allowed files above.
2. PR diff only touches `README.md`, `install.ps1`, or `install.sh`.
3. Installer smoke run resolves the latest semantic bundle from `assets/opencode-multi-auth-vX.Y.Z.tar.gz`.

If a change needs anything outside these 3 files, it belongs in the private source workflow, not in this public installer repo.
