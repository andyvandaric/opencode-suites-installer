# Installer Agent Rules

## Scope
This repo is the public installer entrypoint. Keep installer behavior stable across `install.sh` and `install.ps1`.

## Current Invariants
- Buyer source repo is `andyvandaric/andyvand-opencode-config`.
- Default source branch is `main`.
- If a pinned version is missing on the active branch, probe `main` before failing.
- Keep shell and PowerShell behavior aligned for branch and version resolution.
- Setup and CLI version surfaces must resolve one bundled-version contract (`ocs setup profile`, `ocs setup:profile:update`, `ocs --version`, `ocs doctor`).
- No installer/setup lane may normalize shipped `v0.0.0` as acceptable output.
- Installer default banner values and actual headless auto-setup args must stay aligned (profile and resource mode).
- Public installer release/version examples must never advance past the latest published buyer main bundle asset version.
- Source release version, buyer main asset version, and public installer version examples must move together in the same release wave.
- Public installer README is a separate channel from buyer root README; never treat one as a drop-in source for the other.

## Platform Critical
- `install.sh` must use LF line endings. CRLF breaks WSL with `set: pipefail\r`.
- `install.sh` is first-class POSIX bootstrap owner for `apt`, `dnf`, `yum`, `pacman`, `zypper`, `apk`, and `brew`.
- On Linux/macOS, persist PATH via the active shell profile or a dedicated sourced snippet only; do not blanket-edit every rc file.
- Do not depend on `source ~/.bashrc` in non-interactive installer flow.
- Keep bash/zsh persistence explicit: source `~/.config/opencode/shell/ocs-path.sh` from primary shell profiles.
- Setup and doctor must reject mounted-Windows Node-family tools on Linux/WSL (`/mnt/<drive>/...` node/npm/npx/corepack/pnpm).

## Smoke Test Baseline

- Run WSL smoke test with `--branch main --version 3.1.0`.
- Expected result: installer stays on `main`, POSIX bootstrap completes on apt, and setup/CLI version surfaces agree.
- Runtime-proof claims are currently limited to WSL `apt` + source-lane WSL execution; do not over-claim native macOS runtime smoke until that lane is proven.

## Troubleshooting Fast Path
- If version lookup fails, verify fallback-to-`main` logic runs before any hard failure.
- If WSL fails near shell options, check `install.sh` line endings first.
- If install was launched with `sudo`, verify the installer targeted the intended user home/profile and did not silently persist into the wrong account.
- If commands are missing in a fresh shell, run `ocs doctor` then `ocs doctor --fix` before suggesting manual PATH exports.
- When fixing one script, confirm the same behavior in the other script before closing work.
