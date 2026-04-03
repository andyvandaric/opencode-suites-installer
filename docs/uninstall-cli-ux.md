# Uninstall CLI UX Contract

## Command Shapes

### Unix

- `bash uninstall.sh --mode safe`
- `bash uninstall.sh --mode purge`
- `bash uninstall.sh --mode safe --dry-run`
- `bash uninstall.sh --mode purge --yes --force-purge`

### Windows

- `pwsh -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1 -Mode safe`
- `pwsh -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1 -Mode purge`
- `pwsh -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1 -Mode safe -DryRun`
- `pwsh -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1 -Mode purge -Yes -ForcePurge`

## Prompt and Safety Rules

1. `safe` is default mode.
2. Purge mode requires explicit destructive confirmation:
   - interactive: user must type `PURGE`
   - non-interactive: must pass gate flag (`--force-purge` / `-ForcePurge`)
3. Dry-run must display action plan and make no mutations.
4. Backup is enabled by default unless disabled explicitly.
5. Summary must show mode, preserve set, and remove set before execution.

## Deterministic Step Labels

Each run prints ordered step labels:

- backup
- process stop
- shim/link cleanup
- package cleanup
- runtime/cache cleanup
- config policy application
- optional WSL host cleanup
- verification

## Preserve/Remove Behavior

`safe` mode preserves account/API-key artifacts.

When running from WSL with `--windows-host-cleanup`, preserve guarantees apply to Linux-side credential/account files; documented Windows-host runtime paths are removed by explicit opt-in.

`purge` mode removes all installer/runtime artifacts including preserved credential/account files, only after destructive gate checks pass.
