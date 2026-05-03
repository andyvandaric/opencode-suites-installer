# Installer Agent Rules

## Scope
This repo is the public installer entrypoint. Keep installer behavior stable across `install.sh` and `install.ps1`.

## Current Invariants
- Buyer source repo is `andyvandaric/andyvand-opencode-config`.
- Default source branch is `main`.
- If a pinned version is missing on the active branch, probe `main` before failing.
- Keep shell and PowerShell behavior aligned for branch and version resolution.
- Installer default banner values and actual headless auto-setup args must stay aligned (profile and resource mode).
- Public installer release/version examples must never advance past the latest published buyer main bundle asset version.
- Source release version, buyer main asset version, and public installer version examples must move together in the same release wave.

## Platform Critical
- `install.sh` must use LF line endings. CRLF breaks WSL with `set: pipefail\r`.
- On Linux/macOS, persist PATH via the active shell profile or a dedicated sourced snippet only; do not blanket-edit every rc file.
- Do not depend on `source ~/.bashrc` in non-interactive installer flow.

## Smoke Test Baseline

- Run WSL smoke test with `--branch main --version 2.2.0`.
- Expected result: installer stays on `main` and completes.

## Troubleshooting Fast Path
- If version lookup fails, verify fallback-to-`main` logic runs before any hard failure.
- If WSL fails near shell options, check `install.sh` line endings first.
- If install was launched with `sudo`, verify the installer targeted the intended user home/profile and did not silently persist into the wrong account.
- When fixing one script, confirm the same behavior in the other script before closing work.
