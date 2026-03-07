# Changelog

## 2.0.14 - 2026-03-07

- Enforced cross-OS PATH persistence for `opencode` (`~/.opencode/bin`, `~/.local/bin`, `~/.bun/bin` and Windows user-path equivalents).
- Improved Linux/WSL auth/download reliability by preferring `gh api` in verification and bundle retrieval flows.
- Removed hidden/long-running post-setup recovery behavior and defaulted to lightweight command health checks.
- Synced installer documentation and workflow checks to the suite artifact naming convention `opencode-config-suites-v*.tar.gz`.
- Added release/changelog governance workflow so installer-impacting PRs must update release notes.

## 2.0.13 - 2026-03-07

- Synced installer branch hardening updates into `main`.
- Improved Linux/WSL auth handling: prefer `gh api`, remove brittle PAT fallback prompts, and clarify interactive guidance.
- Fixed bundle selection/verification flow to use `opencode-config-suites-v*.tar.gz` naming.
- Improved command bootstrap reliability for `ocs` and `opencode` with cross-shell PATH persistence updates.
- Added safeguards to avoid redundant heavy `opencode` auto-recovery after successful setup.
- Updated release governance workflows to enforce changelog linkage for installer-impacting changes.
