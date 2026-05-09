# opencode-suites-installer

Install OCS (OpenCode Config Suites) in minutes on **Windows, Linux, and macOS**.

OCS is built for people who want to code faster with AI without wasting time on manual setup and trial-error config.

## Temporary Release Lanes

Until OpenAI path convergence is fully finished, the installer temporarily exposes two lanes:

- `v3.0.0` = **local-plugin lane**
- `v3.1.0` = **direct-core lane**

Everything else is intended to stay feature-parity identical. The difference is only the OpenAI runtime path.

- Choose `v3.0.0` if you specifically want the current local-plugin behavior.
- Choose `latest` or pin `v3.1.0` if you want the direct-core behavior.

Version surfaces are unified across setup and CLI commands: `ocs setup profile`, `ocs setup:profile:update`, `ocs --version`, and `ocs doctor` resolve the same bundled version contract.

## POSIX bootstrap contract (installer lane)

`install.sh` is the POSIX bootstrap owner for:

- `apt`
- `dnf`
- `yum`
- `pacman`
- `zypper`
- `apk`
- `brew`

It performs native Node-family bootstrap, activates PATH in the current shell, and persists PATH through `~/.config/opencode/shell/ocs-path.sh` sourced from primary `bash`/`zsh` profiles.

Proof scope for this wave:

- Runtime-proofed lanes: WSL `apt` and source-lane WSL execution.
- macOS/Linux matrix coverage is broader than runtime-smoke proof in this wave; native macOS smoke remains pending.

## Why OCS

- 🚀 **Fast start** — install, login, pick a profile, and ship.
- 🧠 **Ready-to-use multi-agent flow** for planning, coding, review, and testing.
- 🔐 **Safer runtime defaults** for auth/session handling in long daily usage.
- 🧩 **Cross-platform consistency** across Windows, WSL, Linux, and macOS.

## Quick Install

### Prerequisites

- Install GitHub CLI first: https://cli.github.com/
- Authenticate GitHub CLI before running the installer:

```bash
gh auth login -h github.com -w
```

- Windows: install PowerShell 7 first: https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell-on-windows?view=powershell-7.6
- macOS: default zsh is supported. If you intentionally run the installer from legacy `/bin/bash` and Bun bootstrap fails, upgrade Bash or install Bun manually first.

### macOS / Linux

```bash
 curl -fsSL https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/main/install.sh | bash
```

Install specific version:

```bash
curl -fsSL https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/main/install.sh | bash -s -- --version 3.0.0
```

Temporary direct-core lane:

```bash
curl -fsSL https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/main/install.sh | bash -s -- --version 3.1.0
```

### Windows (PowerShell 7)

```powershell
 pwsh -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/main/install.ps1 | iex"
```

Install specific version:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -Command '$env:OCS_VERSION = "3.0.0"; irm https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/main/install.ps1 | iex'
```

Temporary direct-core lane:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -Command '$env:OCS_VERSION = "3.1.0"; irm https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/main/install.ps1 | iex'
```

> Use `pwsh` (PowerShell 7), not `powershell.exe` (5.1), for the smoothest install experience.

If a new shell still cannot see `ocs` or `opencode`, run `ocs doctor` first and then `ocs doctor --fix` when remediation is offered.

## After Install (2 minutes)

```bash
opencode auth login
```

Default recommended path: **OpenAI -> Chatgpt browser**.

Then complete the runtime checks:

1. Create EXA API key: https://dashboard.exa.ai/api-keys

Windows (PowerShell 7):

```powershell
ocs exa setup --api-key <YOUR_EXA_API_KEY>
ocs exa check
opencode mcp list
opencode --port 78617
# if you prefer web UI
opencode web --port 8089
```

macOS / Linux:

```bash
ocs exa setup --api-key <YOUR_EXA_API_KEY>
ocs exa check
opencode mcp list
opencode --port 78617
# if you prefer web UI
opencode web --port 8089
```

Optional later:

- Change from the default ChatGPT/Codex profile: `ocs setup:profile`
- GitHub MCP starts from GitHub CLI install/auth docs: https://cli.github.com/

Recommended daily profile:

- `codex-5.3-token-saver` (primary)
- `gpt-5.4-best-perform` (backup)
- `gpt-5.4-token-saver` (backup)

## Runtime Recommendation

1. **Default:** Terminal mode (`opencode --port 78617`)
2. **Optional:** Web UI (`opencode web --port 8089`)
3. **Editor option:** OpenCode VSCode Extension by SST

## Uninstall

### macOS / Linux

```bash
 curl -fsSL https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/main/uninstall.sh | bash
```

### Windows (PowerShell 7)

```powershell
 pwsh -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/main/uninstall.ps1 | iex"
```

## Need full technical details?

Public installer docs are intentionally lightweight (install/uninstall + onboarding).

For deep technical docs (MCP setup, advanced runtime tuning, release-level details), use the **buyer repository README/docs**.

This installer README is intentionally a separate channel from the buyer root README and should not be used as the buyer-source README replacement.

---

Install now:

- https://github.com/andyvandaric/opencode-suites-installer#quick-install

