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

## What's New in GPT-5.4 Setup Profiles

- `codex-5.4-best-perform`
  - Primary model: `openai/gpt-5.4`
  - Fast lane: `openai/gpt-5.3-codex`
  - Best for: architecture-heavy coding, deep debugging, and high-confidence production changes.
- `codex-5.4-token-saver`
  - Primary model: `openai/gpt-5.4`
  - Token-efficient worker lane: `openai/gpt-5.1-codex-mini`
  - Best for: daily implementation throughput, routine refactors, and lower-cost long sessions.

Notes:
- These two setups are now selectable from `ocs setup profile`.
- Model availability still follows your runtime account entitlements (`opencode models openai`).

## Channel Mapping

- Buyer beta source repo: `andyvandaric/andyvand-opencode-config`
- Default source branch: `beta`
- Bundle source path: `assets/opencode-config-suites-v*.tar.gz`

## Access Behavior

- If your GitHub account has beta access, installer pulls bundle from buyer beta channel.
- If access is missing, installer redirects to WhatsApp purchase CTA.
