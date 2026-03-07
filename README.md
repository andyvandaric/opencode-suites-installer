# opencode-suites-installer

OCS (OpenCode Config Suites) quick installer for Multi Agents workflow, AI coding profile setup, and cross-platform OpenCode onboarding (Windows, Linux, macOS).

## Quick Install

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/main/install.sh | bash
```

Install specific version:

```bash
curl -fsSL https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/main/install.sh | bash -s -- --version 2.0.15
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

## Buat yang Nggak Ada Waktu Ngoprek

Kalau kamu sudah lama ngikutin OpenCode tapi masih bingung setup agent, atau baru mulai dan belum kebayang harus start dari mana, OCS disiapkan buat jalur cepat.

- Tinggal install, add akun, pilih profile, dan pakai.
- Tidak perlu trial and error config dari nol.
- Siap untuk workflow multi-agent harian dengan setup yang lebih rapi.

## OCS v2.0.15 Beta - Yang Sudah Solid

Kalau kamu ngoding pakai AI setiap hari, biasanya yang bikin seret itu kuota cepat habis, workflow single-agent lama, dan pindah tool bikin fokus buyar. OCS dirancang untuk ngatasin problem itu dari awal.

- Multi-agent teamwork dengan 14 agent role-specific (debug, riset docs, review, security audit, eksekusi).
- 10 profile siap pilih (termasuk jalur GPT-5.4 quality-first dan token-saver).
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
