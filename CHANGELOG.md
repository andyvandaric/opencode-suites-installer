# Changelog

## 2.0.13 - 2026-03-07

- Synced installer branch hardening updates into `main`.
- Improved Linux/WSL auth handling: prefer `gh api`, remove brittle PAT fallback prompts, and clarify interactive guidance.
- Fixed bundle selection/verification flow to use `opencode-config-suites-v*.tar.gz` naming.
- Improved command bootstrap reliability for `ocs` and `opencode` with cross-shell PATH persistence updates.
- Added safeguards to avoid redundant heavy `opencode` auto-recovery after successful setup.
- Updated release governance workflows to enforce changelog linkage for installer-impacting changes.
