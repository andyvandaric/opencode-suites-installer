# Changelog

## 2.1.8 - 2026-03-14

- Synced installer release line with buyer bundle hotfix `beta-v2.1.8` for GLM Coding Plan auth-header compatibility.
- Documented that GLM token-saver installs now rely on `zai-coding-plan` namespace alignment in the buyer bundle.

## 2.1.7 - 2026-03-14

- Synced installer public release line to `v2.1.7` to align with buyer release `beta-v2.1.7`.
- Documented GLM comparison rollout support for buyer bundle `2.1.7` (Flash/FlashX lane vs Air lane profiles).
- Kept beta-channel installer continuity while aligning release metadata and notes with the buyer release cadence.

## 2.1.6 - 2026-03-14

- Updated installer beta defaults to pull buyer source branch `beta` instead of feat/smoke branch defaults.
- Set `INSTALLER_DEFAULT_PROFILE` default to `codex-5.3-token-saver` in both shell and PowerShell installer flows.
- Refreshed README examples to use beta installer commands and current pinned version guidance.

## 2.1.5 - 2026-03-14

- Generalized buyer branch naming in installer docs/scripts from version-specific smoke naming to `feat/buyer-setup-smoke` for safer long-term maintenance.
- Added branch/reference alignment updates so installer guidance remains consistent with buyer branch restructuring.

## 2.1.4 - 2026-03-13

- Hardened cross-platform installer behavior for WSL/macOS/Windows on `feat/buyer-setup-smoke`, including safer command resolution and reduced false-warning noise in non-interactive shells.
- Added stronger runtime recovery for `opencode auth login` by validating `opencode-multi-auth` plugin artifacts and auto-rebuilding (`bun run build`/`npm run build`) when OAuth entry files are missing.
- Improved dependency bootstrap reliability with retry-based auto-install flows, plus clearer staged status/retry visibility for long-running install/build steps (with richer live progress on the PowerShell lane).
- Improved PowerShell lane stability by keeping parser-safe behavior for mixed environments (Windows PowerShell 5.1 compatibility checks and PowerShell 7 execution guidance).
- Added operational recovery tooling in repo root: `uninstall.sh` (auto backup + cleanup), `backup.sh` (state snapshot), and `restore.sh` (validated restore with dry-run support).
- Refreshed README quick-start/troubleshooting guidance to document latest feat stabilization flow, pinned install commands, post-install smoke checks, and reset/recovery commands.

## 2.1.3 - 2026-03-08

- Synced installer release notes, headings, and version-pin examples to `2.1.3` so the public installer lane stays aligned with source and buyer beta release metadata.
- Documented the setup fallback fix that avoids raw `file:///.../dist/index.js` plugin specs, restoring Antigravity OAuth visibility on Linux, macOS, and WSL installs.

## 2.1.2 - 2026-03-08

- Synced installer release notes and version-pin examples to `2.1.2` so the public installer lane matches the source dev repo and latest buyer beta bundle asset again.
- Captured the Linux/WSL fallback and command-bootstrap hardening in the installer changelog template so public release notes still describe the active install behavior.
- Added version-sync guardrails so source, buyer beta, and public installer release examples must move together in future releases.

## 2.1.1 - 2026-03-08

- Synced installer README version-pin examples from `2.1.0` to `2.1.1` for Bash and PowerShell flows.
- Promoted installer release line to `2.1.1` so the public installer channel matches the OAuth hotfix release from the main suite.
- Kept prior `2.1.0` release available as the previous semver-correction milestone.

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
