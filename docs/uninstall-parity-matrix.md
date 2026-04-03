# Uninstall Parity Matrix

| Scope | Linux/macOS | WSL (default) | WSL (`--windows-host-cleanup`) | Windows PowerShell |
|---|---|---|---|---|
| Mode `safe` default | ✅ | ✅ | ✅ | ✅ |
| Mode `purge` | ✅ | ✅ | ✅ | ✅ |
| Preserve account/API-key artifacts in `safe` | ✅ | ✅ | ✅ (Linux-side) | ✅ |
| Destructive gate for non-interactive purge | `--yes --force-purge` | `--yes --force-purge` | `--yes --force-purge` | `-Yes -ForcePurge` |
| Dry-run support | `--dry-run` | `--dry-run` | `--dry-run` | `-DryRun` |
| Backup default on | ✅ | ✅ | ✅ | ✅ |
| Process cleanup | `pkill` pattern-bounded | `pkill` pattern-bounded | `pkill` pattern-bounded | `Stop-Process` |
| Global package cleanup | `bun/npm` best-effort | `bun/npm` best-effort | `bun/npm` best-effort | `bun/npm` best-effort |
| Host-boundary cleanup default | N/A | host untouched | explicit opt-in | N/A |
| Exit semantics | `0/1/2` | `0/1/2` | `0/1/2` | `0/1/2` |

## Exit Semantics

- `0`: successful completion (warnings allowed)
- `1`: fatal execution error (safety guard, backup failure, unresolved target)
- `2`: invalid arguments or missing destructive gate requirements

## Safe-Mode Preserve Contract

Safe mode preserves:

- `~/.config/opencode/opencode.json`
- `~/.config/opencode/openai-accounts*.json`
- `~/.config/opencode/openai-session-state.json`
- `~/.config/opencode/antigravity-accounts*.json`

Purge mode removes these artifacts only after destructive gate is satisfied.
