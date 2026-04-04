# opencode-suites-installer

Install OCS (OpenCode Config Suites) in minutes on **Windows, Linux, and macOS**.

OCS is built for people who want to code faster with AI without wasting time on manual setup and trial-error config.

## Why OCS

- 🚀 **Fast start** — install, login, pick a profile, and ship.
- 🧠 **Ready-to-use multi-agent flow** for planning, coding, review, and testing.
- 🔐 **Safer runtime defaults** for auth/session handling in long daily usage.
- 🧩 **Cross-platform consistency** across Windows, WSL, Linux, and macOS.

## Quick Install

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/staging/v2.2.0/install.sh | bash
```

Install specific version:

```bash
curl -fsSL https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/staging/v2.2.0/install.sh | bash -s -- --version 2.2.0
```

### Windows (PowerShell 7)

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/staging/v2.2.0/install.ps1 | iex"
```

Install specific version:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -Command '$env:OCS_VERSION = "2.2.0"; irm https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/staging/v2.2.0/install.ps1 | iex'
```

> Use `pwsh` (PowerShell 7), not `powershell.exe` (5.1), for the smoothest install experience.

## After Install (60 seconds)

```bash
opencode auth login
ocs setup profile
```

Recommended daily profile:

- `codex-5.3-token-saver` (primary)
- `gpt-5.4-best-perform` (backup)
- `gpt-5.4-token-saver` (backup)

## Runtime Recommendation

1. **Primary:** OpenCode VSCode Extension by SST (best stability for long sessions)
2. **Secondary:** Web UI (`opencode web --port 8089`)

## Uninstall

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/staging/v2.2.0/uninstall.sh | bash
```

### Windows (PowerShell 7)

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/staging/v2.2.0/uninstall.ps1 | iex"
```

## Need full technical details?

Public installer docs are intentionally lightweight (install/uninstall + onboarding).

For deep technical docs (MCP setup, advanced runtime tuning, release-level details), use the **buyer repository README/docs**.

---

Install now:

- https://github.com/andyvandaric/opencode-suites-installer#quick-install
