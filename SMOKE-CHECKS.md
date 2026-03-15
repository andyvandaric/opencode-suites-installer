# Post-Install Smoke Checks

These scripts validate `ocs`, `opencode`, OAuth method visibility, and optional EXA wiring.

## Quick Run (Local Clone)

### Linux / macOS / WSL

```bash
bash smoke.sh --exa-key "EXA_KEY_HERE" --probe-oauth
```

If WSL `opencode` is slow/hangs, add:

```bash
bash smoke.sh --fix-wsl-shim --exa-key "EXA_KEY_HERE" --probe-oauth
```

### Windows (PowerShell 7)

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\smoke.ps1 -ExaApiKey "EXA_KEY_HERE" -ProbeOAuth
```

## Quick Run (Without Clone)

### Linux / macOS / WSL

```bash
curl -fsSL https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/beta/scripts/smoke/ocs-smoke-unix.sh | bash -s -- --exa-key "EXA_KEY_HERE" --probe-oauth
```

### Windows (PowerShell 7)

```powershell
$tmp = Join-Path $env:TEMP "ocs-smoke-windows.ps1"
Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/beta/scripts/smoke/ocs-smoke-windows.ps1" -OutFile $tmp
pwsh -NoProfile -ExecutionPolicy Bypass -File $tmp -ExaApiKey "EXA_KEY_HERE" -ProbeOAuth
```

## Exit Code

- `0`: smoke checks passed (warnings allowed)
- `1`: one or more checks failed

## Manual OAuth Probe (if you skip `--probe-oauth`)

```bash
opencode auth login --provider google --method "OAuth with Google (Antigravity)" --print-logs
```
