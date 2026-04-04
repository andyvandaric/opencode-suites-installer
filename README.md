# opencode-suites-installer

OCS (OpenCode Config Suites) is the fast lane to a ready-to-work OpenCode environment across Windows, Linux, and macOS.

## Quick Install

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/staging/v2.2.0/install.sh | bash
```

Run it from your normal user shell. Do not wrap the installer in `sudo`, or profile/config writes may target the wrong home directory.

Install specific version:

```bash
curl -fsSL https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/staging/v2.2.0/install.sh | bash -s -- --version 2.2.0
```

### Windows (PowerShell)

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/staging/v2.2.0/install.ps1 | iex"
```

Install specific version:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -Command '$env:OCS_VERSION = "2.2.0"; irm https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/staging/v2.2.0/install.ps1 | iex'
```

Windows note: run via `pwsh` (PowerShell 7), not `powershell.exe` (Windows PowerShell 5.1), to avoid parser errors like `Unexpected token '??'`.

## EXA API Onboarding (Windows/WSL/Linux/macOS parity)

Use the same EXA flow on every platform:

1. Create/sign in account: `https://dashboard.exa.ai`
2. Open API key page: `https://dashboard.exa.ai/api-keys`
3. Create API key and copy it once (store securely).

Wire and verify from terminal:

- macOS / Linux / WSL:
  ```bash
  ocs exa setup --api-key <YOUR_EXA_API_KEY>
  ocs exa check
  ```
- Windows PowerShell 7:
  ```powershell
  ocs exa setup --api-key <YOUR_EXA_API_KEY>
  ocs exa check
  ```
  If script policy blocks shims, use `ocs.cmd` fallback.

To keep GitHub MCP healthy:

- Authenticate once: `gh auth login`
- Export token for MCP config:
  - macOS / Linux / WSL: `export GITHUB_PERSONAL_ACCESS_TOKEN="$(gh auth token)"`
  - Windows PowerShell: `$env:GITHUB_PERSONAL_ACCESS_TOKEN = gh auth token`
- Verify MCP status: `opencode mcp list`

## Codex Setup Profiles

- `codex-5.3-token-saver` (recommended daily default)
  - Best fit for speed, accuracy, and quota stability in long sessions.
- `gpt-5.4-best-perform`
  - Backup profile when you need maximum quality for high-risk tasks.
- `gpt-5.4-token-saver`
  - Backup profile for GPT-quality lanes with lower worker token burn.

Notes:
- These three setups are now selectable from `ocs setup profile`.
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
& "$env:ProgramFiles\PowerShell\7\pwsh.exe" -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/staging/v2.2.0/install.ps1 | iex"
  ```

## Buat yang Nggak Ada Waktu Ngoprek

Kalau kamu sudah lama ngikutin OpenCode tapi masih bingung setup agent, atau baru mulai dan belum kebayang harus start dari mana, OCS disiapkan buat jalur cepat.

- Tinggal install, add akun, pilih profile, dan pakai.
- Tidak perlu trial and error config dari nol.
- Siap untuk workflow multi-agent harian dengan setup yang lebih rapi.

## OCS v2.2.0 Staging - Dependency Modernization Wave

Kalau kamu ngoding pakai AI setiap hari, biasanya yang bikin seret itu kuota cepat habis, workflow single-agent lama, dan pindah tool bikin fokus buyar. OCS dirancang untuk ngatasin problem itu dari awal.

- Multi-agent workflow yang lebih cepat buat planning, coding, review, dan validasi rilis harian.
- Profil siap pakai untuk mode quality-first maupun mode hemat-kuota, tinggal pilih sesuai ritme kerja.
- Alur multi-account yang lebih stabil untuk sesi panjang, dengan gangguan re-auth yang makin minim.
- Integrasi riset dan tooling pendukung aktif dari awal supaya cari referensi dan eksekusi jadi lebih lancar.
- Installer cross-platform makin tahan banting di Linux/WSL/Windows dengan recovery path yang lebih rapi.
- Onboarding langsung siap dipakai: install, login, pilih profile, lanjut ngoding tanpa setup manual berlapis.

## Nggak pake lama!

Install OCS sekarang:

- https://github.com/andyvandaric/opencode-suites-installer#quick-install

## Channel Mapping

- Default source branch: `staging/v2.2.0`
- Bundle source path: `assets/opencode-config-suites-v*.tar.gz`

## Access Behavior

- If your GitHub account has staging access, installer pulls bundle from buyer staging channel.
- If access is missing, installer redirects to WhatsApp purchase CTA.
