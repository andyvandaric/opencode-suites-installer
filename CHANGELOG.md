# Changelog

## 2.1.0 - 2026-03-07

- Corrected installer semver to `2.1.0` so the public installer channel matches the suite's semver-correct minor release.
- Synced installer README version-pin examples from `2.0.15` to `2.1.0` for Bash and PowerShell flows.
- Kept `2.0.15` available as the earlier beta release while promoting `2.1.0` as the current installer release line.

## 2.0.15 - 2026-03-07

- Restored high-conversion installer copywriting and CTA blocks while keeping GPT-5.4 profile announcements in README.
- Added highlights for two flagship setup profiles: `codex-5.4-best-perform` and `codex-5.4-token-saver` under Quick Install docs.
- Synced installer messaging with suite release v2.0.15 so buyer/dev/public channels show aligned profile guidance.

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
