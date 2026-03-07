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

## Buat yang Nggak Ada Waktu Ngoprek

Kalau kamu sudah lama ngikutin OpenCode tapi masih bingung setup agent, atau baru mulai dan belum kebayang harus start dari mana, OCS disiapkan buat jalur cepat.

- Tinggal install, add akun, pilih profile, dan pakai.
- Tidak perlu trial and error config dari nol.
- Siap untuk workflow multi-agent harian dengan setup yang lebih rapi.

## 🚀 OCS v2.0.14 Beta - Yang Sudah Solid

Kalau kamu ngoding pakai AI setiap hari, biasanya yang bikin seret itu kuota cepat habis, workflow single-agent lama, dan pindah tool bikin fokus buyar. OCS dirancang untuk ngatasin problem itu dari awal.

- Multi-agent teamwork dengan 14 agent role-specific (debug, riset docs, review, security audit, eksekusi).
- 8 profile siap pilih (Codex, Sonnet, dan hybrid quota-safe).
- Multi-account workflow untuk jalur penggunaan harian.
- LSP + MCP aktif untuk docs lookup dan GitHub code search real-time.
- Hardening installer Linux/WSL/Windows, termasuk stabilisasi `ocs` shim dan deteksi command `opencode`.
- Jalur login Antigravity OAuth dipulihkan dan tervalidasi di `opencode auth login`.

## Akses Beta Channel

- Buyer beta source repo: `andyvandaric/andyvand-opencode-config`
- Default source branch: `beta`
- Bundle source path: `assets/opencode-config-suites-v*.tar.gz`
- Jika akun punya akses beta, installer pull bundle dari channel beta.
- Jika akses belum ada, installer arahkan ke purchase CTA.
