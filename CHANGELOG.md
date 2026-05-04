## [3.0.0] - 2026-05-05
- Switched the public release wave fully to the `main` lane and aligned pinned install commands to `3.0.0`.
- Shipped the redesigned buyer-facing built-in skill bundle, including `ocs-technical-copy-seo`, `ocs-product-marketing-context`, and `ocs-seo-audit`.
- Added native-first RTK and Caveman bootstrap so installer-managed adjunct runtime dependencies reconcile into OpenCode target state instead of staying policy-only.
- Hardened setup/runtime defaults for Windows, WSL, macOS, and Linux-host users, especially around shell profile persistence, PATH recovery, and noninteractive runtime bootstrap.
- Kept DCP as the default compact path while exposing explicit RTK/Caveman routing policy through the managed compression control plane.

### Automated Release Summary
<!-- OCS_AUTO_SUMMARY_START -->
- Commit window: `HEAD`
- Added: 7
- Fixed: 52
- Changed: 0
- Docs: 31
- Chore/Build/CI: 75
- Other: 11
<!-- OCS_AUTO_SUMMARY_END -->

### Commit Coverage (auto-generated)
<!-- OCS_COMMIT_COVERAGE_START -->
- `329f5f4` chore(installer): sync scripts from opencode-config-suites
- `5f6abbb` chore(installer): sync scripts from opencode-config-suites
- `37896a6` chore(installer): sync scripts from opencode-config-suites
- `6cfdd9d` chore(installer): sync scripts from opencode-config-suites
- `403925c` chore(installer): sync scripts from opencode-config-suites
- `2f5eeb7` chore(installer): sync final v2.3.4 release wave
- `2c2ac70` chore(installer): sync final v2.3.4 release wave
- `1df5dc1` chore(installer): sync scripts from opencode-config-suites
- `e411e5d` chore(installer): sync scripts from opencode-config-suites
- `a0c4fc0` chore(installer): sync scripts from opencode-config-suites
- `a8900db` chore(installer): sync scripts from opencode-config-suites
- `a7cc4db` chore(installer): sync scripts from opencode-config-suites
- `9316cbd` chore(installer): sync scripts from opencode-config-suites
- `5e1ec68` chore(installer): sync scripts from opencode-config-suites
- `da8dd7e` fix(installer): remove empty Join-Path bin on Windows prefix resolution
- `5aab538` chore(installer): sync scripts from opencode-config-suites
- `e563066` fix(uninstall): centralize protected entries and main-oriented reinstall hints
- `4283653` chore(installer): sync scripts from opencode-config-suites
- `31ecb58` fix(installer): default latest flow to main branch assets
- `1ea77a7` chore(installer): sync scripts from opencode-config-suites
- `c29b7a0` chore(installer): sync scripts from opencode-config-suites
- `05e9d1e` chore(installer): sync scripts from opencode-config-suites
- `32f4119` docs: update installer README URLs
- `3caacd5` fix: default installer branch to main
- `178dd7c` fix(docs): update installer README to v2.3.1
- `7423ed8` chore(installer): sync beta v2.3.1 release wave
- `fe09f8b` fix(uninstall): preserve OpenAI and Antigravity account json files
- `0b0ae17` chore(installer): align beta install and uninstall scripts with staging
- `c602c12` chore(installer): sync scripts from opencode-config-suites
- `4db8d2c` chore(installer): align beta setup and MCP readiness with staging
- `d746b2f` chore(installer): sync scripts from opencode-config-suites
- `b05bcf0` Fix Windows installer crash on malformed npm prefix output
- `2c2ec11` fix(installer): align branch hints with beta lane
- `572d4a1` Revert "chore(installer): sync scripts from opencode-config-suites"
- `4ebf46c` chore(installer): sync scripts from opencode-config-suites
- `2448853` fix(readme): point beta install links to beta branch
- `ff68ea3` fix(installer): backport cross-platform hardening for beta
- `a8de28a` chore(installer): sync scripts from opencode-config-suites
- `b41fce3` chore(installer): sync scripts from opencode-config-suites
- `f7aa8f4` chore(installer): sync scripts from opencode-config-suites
- `f986b9c` chore(installer): sync scripts from opencode-config-suites
- `f91d3f4` chore(installer): sync scripts from opencode-config-suites
- `7e39976` chore(installer): sync scripts from opencode-config-suites
- `3c4d164` chore(installer): sync scripts from opencode-config-suites
- `43f9e1f` fix(installer): guard empty pnpm source path on powershell install
- `ade2214` chore(installer): align beta lane pull defaults
- `3279009` chore(release): merge staging v2.3.0 into beta
- `5a575ef` chore(installer): sync staging v2.3.0 release wave
- `57c6cd0` chore(installer): sync staging v2.3.0 release wave
- `1879639` chore(installer): sync staging v2.3.0 release wave
- `317713f` chore(installer): sync staging v2.3.0 release wave
- `4080e27` chore(installer): sync staging v2.3.0 release wave
- `600ae17` chore(installer): sync staging v2.2.1 release wave
- `3b37021` chore(installer): sync staging v2.2.1 release wave
- `40aeab5` chore(installer): sync staging v2.2.1 release wave
- `369b21a` chore(installer): sync staging v2.2.1 release wave
- `3e5b7ac` chore(installer): sync staging v2.2.1 release wave
- `85a9494` fix(installer): align fallback branch hint to staging v2.2.1
- `f0b7a2f` fix(installer): call Ensure-PnpmRuntime in staging script
- `c8a01dc` chore(installer): sync staging v2.2.1 release wave
- `88e0852` chore(installer): sync staging v2.2.1 release wave
- `713b982` chore(installer): sync staging v2.2.1 release wave
- `1ae3c49` chore(installer): sync staging v2.2.1 release wave
- `1fca48b` chore(installer): sync staging v2.2.1 release wave
- `dcf50e6` chore(installer): sync staging v2.2.1 release wave
- `f66e382` chore(installer): sync staging v2.2.0 release wave
- `cb4f644` chore(installer): sync staging v2.2.0 release wave
- `6b01de5` chore(installer): sync staging v2.2.0 release wave
- `63c2533` chore(installer): sync staging v2.2.0 release wave
- `cb8052d` chore(installer): sync staging v2.2.0 release wave
- `36f1942` chore(installer): sync staging v2.2.0 release wave
- `c368b60` chore(installer): sync staging v2.2.0 release wave
- `7dcc4a9` docs(readme): simplify installer page for conversions
- `7e25762` chore(installer): sync staging v2.2.0 release wave
- `ac45974` fix(installer): harden opencode recovery flow for WSL reinstall
- `7a41dd9` fix(installer): harden opencode recovery flow for WSL reinstall
- `affd411` docs(uninstall): add raw one-liner quickstart and README links
- `ba5ac47` docs(uninstall): add raw one-liner quickstart and README links
- `1ec522c` fix(installer): normalize runtime plugin path for OAuth menu
- `4f5918e` fix(installer): normalize runtime plugin path for OAuth menu
- `317d5ce` docs: publish uninstall parity contract and smoke checks
- `21b36de` feat(uninstall): add safe/purge parity across bash and PowerShell
- `99176d6` docs: publish uninstall parity contract and smoke checks
- `8e4c155` feat(uninstall): add safe/purge parity across bash and PowerShell
- `6006228` chore(installer): sync scripts from opencode-config-suites
- `72df281` chore(installer): sync scripts from opencode-config-suites
- `dbdc078` chore(installer): sync scripts from opencode-config-suites
- `978efb3` chore(installer): sync scripts from opencode-config-suites
- `b10cbfa` chore(installer): sync scripts from opencode-config-suites
- `5ec3fc2` chore(installer): align staging docs and branch hints to v2.1.14
- `e23b6e5` chore(installer): sync scripts from opencode-config-suites
- `a682e07` chore(installer): sync scripts from opencode-config-suites
- `63f2c05` chore(installer): sync scripts from opencode-config-suites
- `315913a` chore(installer): sync scripts from opencode-config-suites
- `99266c8` docs(changelog): note OCS skills sync rollout
- `9b2c1c4` fix(installer): preserve hidden bundle directories
- `be9f66d` docs(changelog): note auth menu activation fix
- `3e6746f` docs(changelog): note realtime quota check update
- `5d29eaa` docs(changelog): note exa schema compatibility update
- `e2422c0` docs(changelog): document installer lane resolution fix
- `7cbf454` fix(installer): infer source lane and align fallback branch
- `0cddd62` docs(readme): pin staging installer quickstart paths
- `ed66f03` docs(installer): sync exa onboarding and full changelog chain
- `5c3bc45` chore(installer): sync staging v2.1.13 release wave
- `8a58433` chore(staging): bump installer defaults to v2.1.13 lane
- `5ac7376` fix(installer): detect bun reliably in non-interactive shells
- `93283d7` fix(installer): route staging lane to staging buyer branch
- `f1b10a1` docs(installer): correct main as default branch in help text
- `b1e41f5` fix(installer): default main branch for bundle source
- `4634cc4` fix(installer): force /dev/tty for interactive setup fallback
- `d6e3371` fix(installer): harden headless fallback and WSL launcher path
- `4cad036` fix(smoke): enforce antigravity oauth runtime prompt checks
- `7077225` docs(release): bump beta docs and changelog to v2.1.12
- `dd4cc7d` fix(installer): restore mac parity and harden auth fallback checks
- `f14283f` chore(beta): rewire beta channel to beta sources
- `694c847` docs(readme): point private rollout commands to feat branch
- `510f8f8` feat(installer): align EXA/MCP flow for v2.1.11
- `8ad4c5a` docs(changelog): add missing v2.1.9 continuity entry
- `c825a94` docs(readme): pin installer examples to v2.1.10
- `5991fa1` feat(smoke): add strict CI smoke mode and update changelog
- `eb6d4df` feat(smoke): add cross-platform smoke scripts and wrappers
- `acec59e` Merge branch 'feat/buyer-setup-smoke' into beta
- `051225c` feat(installer): add Windows ocs policy Quick Fix and OS-aware next steps with Exa guidance
- `47780fc` fix(installer): show Exa setup steps in post-install guidance
- `057d5a8` docs(release): sync installer feat line to v2.1.9
- `d746a28` docs(changelog): add installer 2.1.8 auth-hotfix notes
- `d6df29f` docs(changelog): add installer 2.1.8 auth-hotfix notes
- `3197f92` docs(changelog): sync installer entries through 2.1.7
- `abd2cb1` fix(installer): default feat profile to token-saver
- `60172b5` chore(installer): align beta defaults with buyer beta branch
- `6516f40` docs(installer): update buyer branch references to generalized name
- `18f2639` chore(installer): rename buyer setup default branch
- `e587414` docs(installer): clarify script usage and progress claims
- `a7c1ece` fix(installer): make backup script macos-bash compatible
- `e81aadb` docs(installer): refresh quick start and 2.1.4 hardening notes
- `627eb41` feat(installer): add backup restore and uninstall utilities
- `859ac01` fix(installer): harden oauth rebuild and runtime checks
- `9a86c64` docs(installer): clarify antigravity oauth first-run behavior
- `ea69a55` chore(installer): remove legacy install-plugin scripts
- `4cd2f8c` docs(readme): add macos oauth artifact recovery steps
- `dd36668` fix(installer): repair missing oauth plugin artifacts
- `2a43794` docs(readme): refresh install lanes and codex profile guidance
- `04e14a6` fix(installer): add powershell progress execution hardening
- `17585f8` fix(installer): harden opencode recovery on feat setup lane
- `7de7b61` fix(installer): reduce non-fatal PATH warning noise
- `d0f9d58` fix(installer): default source branch to feat buyer 2.1.4
- `a4a8857` fix(installer): block non-Windows usage in install.ps1
- `51bb408` docs(installer): switch quick install commands to install scripts
- `4f83862` fix(installer): add install.sh and install.ps1 entrypoints
- `8c7ccbb` docs(installer): point quick install to feat branch
- `b832d73` docs(installer): add feat branch install commands
- `8246422` fix(installer): sync public scripts for v2 release
- `dda4309` fix(installer): default to codex hybrid performance
- `d399216` chore(installer): refine next-steps guidance text
- `970e054` fix(installer): enforce bun-only dependency retries
- `738b8ae` fix(installer): harden dependency install retries and fallback
- `a125ab4` fix(installer): resolve relative plugin path during bun install
- `4cacfa4` fix(installer): continue in current shell when pwsh relaunch fails
- `82d4d12` fix(installer): harden ps7 relaunch and bun retry diagnostics
- `ceb635f` fix(installer): normalize COMSPEC before setup execution
- `95eb9d5` fix(installer): avoid false local-source detection and use plugin setup path
- `0d4764f` fix(installer): prefer system tar.exe and normalize extraction paths
- `e4a423f` fix(installer): make windows tar extraction fail-fast and compatible
- `334fa1a` fix(installer): prevent token output pollution and enforce access gate
- `a28e0ac` fix(installer): avoid false handoff short-circuit in ps5
- `ab31a30` fix(installer): keep terminal open after pwsh handoff
- `58c731f` fix(installer): persist bun path and improve access-denied flow
- `cfccf04` fix(installer): add resilient token and gh dependency fallbacks
- `f2bdf46` Use gh web login and access gate in installer
- `a9db53e` Auto-relaunch installer in PowerShell 7
- `63de817` Fix PowerShell installer IEX compatibility
- `703791b` Harden installer scripts for auto Bun and setup
- `0b0eeb2` Handle missing SHA256SUMS asset in bash installer
- `75fd5dd` Fix bash installer token resolution output
- `cd19031` Add public installer scripts for release artifacts
- `7518562` Initial commit
<!-- OCS_COMMIT_COVERAGE_END -->
## [2.3.5] - 2026-04-20

- Improved multi-agent orchestration by adding the `gemini-3.1-pro-gpt-oss` profile, perfectly balancing Gemini 3.1 Pro for deep reasoning and GPT-OSS 120B for fast execution.
- Extracted and enhanced `ocs-cocoindex-gate` skill to better manage multi-file background code search and semantic retrieval.
- Expanded domain intelligence in `ocs-delegation-gate` for advanced agent-to-agent delegation routing.

## [2.3.5] - 2026-04-20

- Renamed and optimized the `gemini-3.1-pro-gpt-oss` profile for better role mapping and resource efficiency.
- Improved skill intelligence with dedicated validation and governance gates for safer agent execution.

## [2.3.3] - 2026-04-20

- Fix tool invocation stability issues for Google Gemini and Antigravity models.
- Allow generic OpenCode API wrapper tools to work properly with Antigravity models.

## 2.3.2 - 2026-04-20

- Added support for the `GPT-OSS 120B (Medium)` model and released the `gpt-oss-120b-lead` optimized Antigravity profile.
- Matured skill architecture by extracting CocoIndex background-indexing instructions into a centralized `ocs-cocoindex-gate` skill.
- Improved schema sanitization in the multi-auth plugin to bypass strict Protobuf backend errors on MCP numeric constraints.

## 2.3.1 - 2026-04-19

- Synced installer branch resolution so version-pinned installs default to `staging/v2.3.1` when branch is not explicitly provided.
- Aligned Bash and PowerShell installer fallback behavior to the same lane/version selection logic for consistent WSL/Windows outcomes.
- Captured the local WSL verification gate used for this wave (rebuild tarball, isolated reinstall smoke, and doctor/runtime proof) before lane propagation.
- Synced installer lane defaults/examples to `staging/v2.3.1` and version pins to `2.3.1` so installer fetches the same staged release wave as source and buyer.
- Published high-level parity note for the staged asset refresh without exposing internal stack-level release details.

## 2.3.0 - 2026-04-07

- Synced installer lane defaults/examples to `staging/v2.3.0` and version pins to `2.3.0` across Bash/PowerShell quick-install commands so the public installer mirrors the new CocoIndex/CCC governance wave.
- Documented the CocoIndex MPC-ready automation ladder plus CCC extension/skill-governance guidance so installer release notes match the suite’s new operational narrative.

## 2.2.1 - 2026-04-05

- Synced installer lane defaults/examples to `staging/v2.2.1` and version pins to `2.2.1` across Bash/PowerShell quick-install commands.
- Published high-level staging notes for setup reliability improvements and OpenAI auth robustness updates without exposing internal stack details.
- Added installer-ready CocoIndex Code activation flow (`ccc`) and MCP registration guidance continuity for first-run indexing workflows.

## 2.2.0 - 2026-04-04

- Synced installer lane defaults/examples to `staging/v2.2.0` and version pins to `2.2.0` across Bash/PowerShell quick-install commands.
- Published high-level staging stability/compatibility notes while keeping source/buyer/installer release-line parity.
- Added CocoIndex ready-to-use bootstrap during installer-driven setup with generated env/compose scaffolding for faster first-run indexing workflows.
- Improved OpenAI staging runtime stability for long-running multi-account sessions and reduced unnecessary re-auth interruptions during normal use.

## 2.1.15 - 2026-04-03

- Synced installer lane default branch/examples to `staging/v2.1.15` for the OpenAI on-demand refresh hardening wave.
- Kept source/buyer/installer lane references aligned to the same staging branch and bundle version for reproducible installs.

## 2.1.14 - 2026-04-02

- Synced installer lane to source `staging/v2.1.14` for OpenAI auth/runtime hotfix wave.
- Preserved runtime API credential safety on reinstall by carrying schema-safe provider option restore behavior into installer-delivered setup flow.
- Restored non-TTY OpenAI auth operational parity by ensuring fallback prompts include both `Manage accounts` and `Check quotas` actions.
- Enforced prebuild guardrails in release path so installer-bound bundles fail fast when multi-auth dist/wrapper wiring is stale.

## 2.1.13 - 2026-03-31

- Synced installer lane notes to `staging/v2.1.13` with the EXA MCP activation wave from source/buyer.
- Added explicit EXA onboarding next steps in installer UX (`ocs exa setup`, `ocs exa check`) plus MCP health verification guidance.
- Updated installer-facing README flow to include GitHub MCP token hygiene and cross-platform EXA parity notes (Windows/WSL/Linux/macOS).
- Fixed branch resolution defaults so staging installer URLs resolve staging assets by default, while keeping `--branch` / `OCS_RELEASE_BRANCH` / `OCS_FALLBACK_RELEASE_BRANCH` lane-flexible.
- Fixed PowerShell relaunch fetch path to follow the active installer branch instead of hardcoded `main`.
- Fixed EXA MCP config compatibility by standardizing `x-api-key` header mapping to string token format (`{env:EXA_API_KEY}`) for OpenCode schema validation.
- Updated OpenAI quota check UX to show realtime-only refresh values and forward-looking reset duration formatting (`in Xh Ym`) in staging output.
- Restored OpenAI multi-account menu takeover on installer deployments by bundling the OpenAI auth wrapper plugin and rewriting runtime plugin specs to loader-safe local `file://` plugin directory URLs.
- Fixed installer extraction copy behavior to include hidden bundle directories so `.opencode/skills` is deployed and synced into `~/.config/opencode/skills`.

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
- Documented setup fallback hardening that avoids raw `file:///.../dist/index.js` plugin specs and restores Antigravity OAuth visibility on Linux, macOS, and WSL installs.

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

- Restored high-conversion installer copywriting and CTA blocks while positioning `codex-5.3-token-saver` as the default setup profile.
- Kept GPT-5.4 profile mentions as optional backup lanes (`gpt-5.4-best-perform`, `gpt-5.4-token-saver`) for high-risk tasks.
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
