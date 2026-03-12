# opencode-suites-installer

OCS (OpenCode Config Suites) quick installer for Multi Agents workflow, AI coding profile setup, and cross-platform OpenCode onboarding (Windows, Linux, macOS).

## Quick Install

### Feat branch (`feat/buyer-v2.1.4-setup-smoke`)

Use this branch for cross-platform validation before main release.

#### macOS / Linux / WSL

```bash
curl -fsSL https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/feat/buyer-v2.1.4-setup-smoke/install.sh | bash
```

Install specific version:

```bash
curl -fsSL https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/feat/buyer-v2.1.4-setup-smoke/install.sh | bash -s -- --version 2.1.4
```

WSL note: run the command inside WSL terminal (`bash`/`zsh`), not from Windows PowerShell.

#### Windows (PowerShell 7)

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/feat/buyer-v2.1.4-setup-smoke/install.ps1 | iex"
```

Install specific version:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -Command '$env:OCS_VERSION = "2.1.4"; irm https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/feat/buyer-v2.1.4-setup-smoke/install.ps1 | iex'
```

Windows note: run via `pwsh` (PowerShell 7), not `powershell.exe` (Windows PowerShell 5.1), to avoid parser errors like `Unexpected token '??'`.

### Stable branch (`main`)

#### macOS / Linux / WSL

```bash
curl -fsSL https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/main/install.sh | bash
```

#### Windows (PowerShell 7)

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/main/install.ps1 | iex"
```

Run installer from your normal user shell. Do not wrap installer command in `sudo`, or profile/config writes may target the wrong home directory.

## Codex Setup Profiles

- `codex-5.3-token-saver`
  - Primary model: `openai/gpt-5.3-codex`
  - Token-efficient worker lane: `openai/gpt-5.1-codex-mini`
  - Recommended default for most users: strongest balance for planning -> execution flow, efficient token usage, and stable precision once your workflow is already tidy.
  - Best for: daily coding sessions where you want high throughput without sacrificing decision quality.
- `codex-5.4-best-perform`
  - Primary model: `openai/gpt-5.4`
  - Fast lane: `openai/gpt-5.3-codex`
  - Best for: maximum-depth architecture reviews and the toughest debugging cases.
- `codex-5.4-token-saver`
  - Primary model: `openai/gpt-5.4`
  - Token-efficient worker lane: `openai/gpt-5.1-codex-mini`
  - Best for: teams that want GPT-5.4 orchestration with tighter token control.

Notes:
- These three setups are selectable from `ocs setup:profile`.
- Model availability still follows your runtime account entitlements (`opencode models openai`).

## Troubleshooting Commands

- Diagnose PATH/shim issues:
  ```bash
  ocs doctor
  ```
- If `ocs` or `opencode` is not detected on macOS/Linux:
  ```bash
  export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$HOME/.bun/bin:$PATH"
  hash -r
  ocs doctor
  ```
- If `ocs` or `opencode` is not detected on Windows PowerShell:
  ```powershell
  Get-Command ocs
  Get-Command opencode
  ocs doctor
  ```

### Windows: PowerShell 7 requirement

- Verify PowerShell 7:
  ```powershell
  pwsh --version
  pwsh -NoProfile -Command "$PSVersionTable.PSVersion"
  ```
- Install PowerShell 7 on Windows:
  - `winget install --id Microsoft.PowerShell --source winget`
  - Microsoft Store: search **PowerShell** (Publisher: Microsoft)
  - MSI installer: https://github.com/PowerShell/PowerShell/releases/latest
- If terminal still opens 5.1, force full path:
  ```powershell
  & "$env:ProgramFiles\PowerShell\7\pwsh.exe" -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/main/install.ps1 | iex"
  ```

## Buat yang Nggak Ada Waktu Ngoprek

Kalau kamu sudah lama ngikutin OpenCode tapi masih bingung setup agent, atau baru mulai dan belum kebayang harus start dari mana, OCS disiapkan buat jalur cepat.

- Tinggal install, add akun, pilih profile, dan pakai.
- Tidak perlu trial and error config dari nol.
- Siap untuk workflow multi-agent harian dengan setup yang lebih rapi.

## OCS v2.1.3 Beta - Yang Sudah Solid

Kalau kamu ngoding pakai AI setiap hari, biasanya yang bikin seret itu kuota cepat habis, workflow single-agent lama, dan pindah tool bikin fokus buyar. OCS dirancang untuk ngatasin problem itu dari awal.

- Multi-agent teamwork dengan 14 agent role-specific (debug, riset docs, review, security audit, eksekusi).
- 11 profile siap pilih (termasuk jalur GPT-5.4 quality-first, GPT-5.4 token-saver, dan Codex 5.3 token-saver).
- Multi-account workflow untuk jalur penggunaan harian.
- LSP + MCP aktif untuk docs lookup dan GitHub code search real-time.
- Hardening installer Linux/WSL/Windows, termasuk stabilisasi `ocs` shim dan deteksi command `opencode`.
- Jalur login Antigravity OAuth dipulihkan dan tervalidasi di `opencode auth login`.

## Nggak pake lama!

Install OCS sekarang:

- https://github.com/andyvandaric/opencode-suites-installer#quick-install

## Channel Mapping

- Buyer beta source repo: `andyvandaric/andyvand-opencode-config`
- Default source branch: `beta`
- Bundle source path: `assets/opencode-config-suites-v*.tar.gz`

## Access Behavior

- If your GitHub account has beta access, installer pulls bundle from buyer beta channel.
- If access is missing, installer redirects to WhatsApp purchase CTA.
