# Installer Agent Rules

## Scope
This repo is the public installer entrypoint. Keep installer behavior stable across `install.sh` and `install.ps1`.

## Current Invariants
- Buyer source repo is `andyvandaric/andyvand-opencode-config`.
- Default source branch is `beta`.
- If a pinned version is missing on the active branch, probe `beta` before failing.
- Keep shell and PowerShell behavior aligned for branch and version resolution.

## Platform Critical
- `install.sh` must use LF line endings. CRLF breaks WSL with `set: pipefail\r`.

## Smoke Test Baseline
- Run WSL smoke test with `--branch main --version 2.1.1`.
- Expected result: installer falls back to `beta` and completes.

## Troubleshooting Fast Path
- If version lookup fails, verify fallback-to-`beta` logic runs before any hard failure.
- If WSL fails near shell options, check `install.sh` line endings first.
- When fixing one script, confirm the same behavior in the other script before closing work.
