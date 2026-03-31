# Changelog

## 2.1.13 - 2026-03-31

- Synced installer lane notes to `staging/v2.1.13` with the EXA MCP activation wave from source/buyer.
- Added explicit EXA onboarding next steps in installer UX (`ocs exa setup`, `ocs exa check`) plus MCP health verification guidance.
- Updated installer-facing README flow to include GitHub MCP token hygiene and cross-platform EXA parity notes (Windows/WSL/Linux/macOS).

## 2.1.12 - 2026-03-16

- Repacked installer lane with setup self-copy guard parity so bundled plugin sync does not duplicate identical source/target copies.
- Hardened installer interactive behavior with `/dev/tty`-first fallback for safer non-interactive shells and WSL/Linux sessions.

## 2.1.11 - 2026-03-15

- Stabilized EXA onboarding/check operator path for staged usage and aligned installer messaging with that flow.
- Recorded GitHub/Time MCP lane migration context used by buyer/installer parity runs.

## 2.1.10 - 2026-03-15

- Added cross-platform smoke validation script coverage in installer lane release flow.
- Synced installer release narrative with source/buyer `v2.1.10` stabilization wave.

## 2.1.9 - 2026-03-14

- Synced installer metadata continuity with `2.1.9` staged publication line.

## 2.1.8 - 2026-03-14

- Hardened installer setup/auth recovery edges discovered during multi-lane staging synchronization.

## 2.1.7 - 2026-03-14

- Updated installer release metadata/docs continuity for staged parity rollout.

## 2.1.6 - 2026-03-14

- Improved installer setup guard behavior to reduce false-positive breakage during staging tests.

## 2.1.5 - 2026-03-14

- Established early `2.1.x` installer publication baseline used by later `2.1.12` and `2.1.13` parity waves.

## 2.1.4 - 2026-03-11

- Added installer-facing profile/version continuity notes during the initial `2.1.x` parity sweep.

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

## 2.0.12 - 2026-03-06

- Restored valid bundled multi-auth payload resolution so installer deployments no longer crash on malformed plugin source paths.
- Verified OAuth menu visibility recovery in post-setup `opencode auth login` flows on Linux/macOS/WSL.

## 2.0.11 - 2026-03-06

- Enforced installer setup ordering for plugin payload sync before plugin install/spec rewrite.
- Hardened OAuth visibility guard by preserving `google_auth: false` in generated runtime config.

## 2.0.10 - 2026-03-06

- Added artifact-aware plugin spec fallback in setup to prevent stale/missing tarball breakage.
- Synced installer safety checks around OAuth config and setup sequencing.

## 2.0.9 - 2026-03-06

- Corrected `ocs` command detection so installer no longer falls through to conflicting PATH shims.
- Added auto-repair checks for mismatched `ocs`/`opencode` shim precedence.

## 2.0.8 - 2026-03-05

- Improved bundled plugin fallback behavior so setup can continue safely when `.tgz` artifacts are unavailable.

## 2.0.7 - 2026-03-04

- Introduced dynamic routing and quota fallback hardening wave used by installer-driven staging tests.
- Synced corresponding setup/runtime docs for post-install behavior expectations.

## 2.0.6 - 2026-03-04

- Added setup self-healing for corrupted global Bun manifests and duplicate workspace entries.

## 2.0.5 - 2026-03-04

- Hardened `ocs prefs` schema path resolution and setup defaults for stable hybrid OAuth flow.

## 2.0.4 - 2026-03-04

- Fixed installer setup deployment so Antigravity OAuth login options are visible consistently.

## 2.0.3 - 2026-03-04

- Restored interactive setup defaults and added update command alias parity (`setup update`, `setup:update`).

## 2.0.2 - 2026-03-04

- Included root/plugin changelogs in release bundles for stronger release-lane auditability.

## 2.0.1 - 2026-03-04

- Finalized strict preferences validation and plugin status-policy hardening coverage used by installer consumers.

## 2.0.0 - 2026-03-03

- Baseline installer-hardening release wave across Windows/Linux/WSL/macOS setup reliability and path/bootstrap behavior.

## 1.10.5 - 2026-02-21

- Prevented setup from dirtying local repo config during pull/update flows.

## 1.10.4 - 2026-02-21

- Refined quick-start docs for resource modes, plugin stack, and onboarding clarity.

## 1.10.3 - 2026-02-21

- Cleaned generated dependency surface to avoid setup/install noise.

## 1.10.2 - 2026-02-21

- Added `package.json` generation in runtime config dir before plugin install to prevent Bun install failures.

## 1.10.1 - 2026-02-21

- Added post-deploy plugin install step so copied plugin specs are actually installed.

## 1.10.0 - 2026-02-21

- Introduced hardware-aware background concurrency defaults for safer machine-level setup/runtime behavior.

## 1.9.0 - 2026-02-21

- Updated plugin baseline to include context-overflow guard behavior and removed obsolete plugin lane.

## 1.8.0 - 2026-02-20

- Added DCP + safety plugin stack defaults and documented operator commands.

## 1.7.1 - 2026-02-20

- Expanded onboarding docs (load-project flow, cross-drive mapping, and role-selection guidance).

## 1.7.0 - 2026-02-20

- Added constants-driven setup catalog/runtime architecture and profile naming clarifications.

## 1.6.1 - 2026-02-20

- Improved private-repo access onboarding (`gh auth login`) and clone/access troubleshooting guidance.

## 1.6.0 - 2026-02-20

- Added new profile variants for Sonnet/Codex mixed operation lanes.

## 1.5.0 - 2026-02-19

- Added cross-platform installer resilience (taplo install flow, no-winget fallback ladder, and setup docs hardening).

## 1.3.0 - 2026-02-19

- Added EN/ID quick-start documentation split and streamlined README navigation.

## 1.2.0 - 2026-02-19

- Added first public one-command installers for Windows (`install.ps1`) and Linux/macOS (`install.sh`).

## 1.1.0 - 2026-02-19

- Added early branding/tooling improvements and setup compatibility mappings.

## 1.0.3 - 2026-02-18

- Updated Sonnet model baseline from 4.5 to 4.6 across profiles and setup mappings.
