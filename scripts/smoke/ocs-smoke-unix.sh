#!/usr/bin/env bash
set -u

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

EXA_API_KEY=""
PROBE_OAUTH=0
FIX_WSL_SHIM=0
CI_MODE=0
REQUIRE_EXA=0
TIMEOUT_SECONDS=35

SCRIPT_NAME="$(basename "$0")"

if [ -t 1 ]; then
  C_GREEN='\033[32m'
  C_RED='\033[31m'
  C_YELLOW='\033[33m'
  C_BLUE='\033[34m'
  C_RESET='\033[0m'
else
  C_GREEN=''
  C_RED=''
  C_YELLOW=''
  C_BLUE=''
  C_RESET=''
fi

usage() {
  cat <<EOF
OCS Smoke Test (Linux/macOS/WSL)

Usage:
  bash ${SCRIPT_NAME} [options]

Options:
  --exa-key <key>     Run EXA setup/check with provided key
  --probe-oauth       Probe OAuth prompt automatically (interactive)
  --fix-wsl-shim      In WSL, create stable ~/.local/bin/opencode shim if needed
  --ci                Strict non-interactive CI mode (no interactive OAuth probe)
  --require-exa       Fail if EXA key is not provided
  --timeout <sec>     Command timeout in seconds (default: 35)
  --help              Show this help
EOF
}

log_info() { printf "%b[INFO]%b %s\n" "$C_BLUE" "$C_RESET" "$*"; }
log_pass() { printf "%b[PASS]%b %s\n" "$C_GREEN" "$C_RESET" "$*"; }
log_fail() { printf "%b[FAIL]%b %s\n" "$C_RED" "$C_RESET" "$*"; }
log_warn() { printf "%b[WARN]%b %s\n" "$C_YELLOW" "$C_RESET" "$*"; }

mark_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  log_pass "$*"
}

mark_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  log_fail "$*"
}

run_with_timeout() {
  local sec="$1"
  shift

  if command -v timeout >/dev/null 2>&1; then
    timeout "$sec" "$@"
    return $?
  fi

  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$sec" "$@"
    return $?
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$sec" "$@" <<'PY'
import subprocess
import sys

timeout = int(sys.argv[1])
cmd = sys.argv[2:]
try:
    result = subprocess.run(cmd, timeout=timeout)
    raise SystemExit(result.returncode)
except subprocess.TimeoutExpired:
    raise SystemExit(124)
PY
    return $?
  fi

  "$@"
}

run_check() {
  local title="$1"
  shift

  local out
  if out="$(run_with_timeout "$TIMEOUT_SECONDS" "$@" 2>&1)"; then
    mark_pass "$title"
    return 0
  fi

  mark_fail "$title"
  if [ -n "$out" ]; then
    printf "%s\n" "$out"
  fi
  return 1
}

warn_skip() {
  WARN_COUNT=$((WARN_COUNT + 1))
  log_warn "$*"
}

is_wsl() {
  if [ -f /proc/version ] && grep -qiE 'microsoft|wsl' /proc/version; then
    return 0
  fi
  return 1
}

fix_wsl_shim_if_needed() {
  if ! is_wsl; then
    return 0
  fi

  if [ "$FIX_WSL_SHIM" -ne 1 ]; then
    warn_skip "WSL shim auto-fix skipped. Use --fix-wsl-shim if opencode hangs."
    return 0
  fi

  if run_with_timeout 15 opencode --help >/dev/null 2>&1; then
    mark_pass "WSL opencode launcher responsive"
    return 0
  fi

  local direct_bin="$HOME/.bun/install/global/node_modules/opencode-ai/bin/.opencode"
  if [ ! -x "$direct_bin" ]; then
    warn_skip "WSL direct opencode binary not found at $direct_bin"
    return 0
  fi

  mkdir -p "$HOME/.local/bin"
  cat > "$HOME/.local/bin/opencode" <<EOF
#!/usr/bin/env bash
exec "$direct_bin" "\$@"
EOF
  chmod +x "$HOME/.local/bin/opencode"
  export PATH="$HOME/.local/bin:$PATH"
  hash -r

  if run_with_timeout 20 opencode --help >/dev/null 2>&1; then
    mark_pass "WSL stable opencode shim installed"
  else
    warn_skip "WSL shim installed but opencode still not responsive"
  fi
}

check_oauth_non_interactive() {
  local help_out
  if ! help_out="$(run_with_timeout "$TIMEOUT_SECONDS" opencode auth login --help 2>&1)"; then
    mark_fail "OAuth non-interactive check: opencode auth login --help"
    printf "%s\n" "$help_out"
    return 1
  fi

  if ! printf "%s" "$help_out" | grep -q -- "--provider"; then
    mark_fail "OAuth non-interactive check: missing --provider flag"
    printf "%s\n" "$help_out"
    return 1
  fi

  if ! printf "%s" "$help_out" | grep -q -- "--method"; then
    mark_fail "OAuth non-interactive check: missing --method flag"
    printf "%s\n" "$help_out"
    return 1
  fi

  mark_pass "OAuth non-interactive check: login help exposes provider/method flags"

  local config_dir="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
  local config_path="$config_dir/opencode.json"

  if [ ! -f "$config_path" ]; then
    mark_fail "OAuth non-interactive check: missing config file ($config_path)"
    return 1
  fi

  if command -v python3 >/dev/null 2>&1; then
    local py_out
    if py_out="$(python3 - "$config_path" <<'PY' 2>&1
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
cfg = json.loads(path.read_text(encoding='utf-8'))

if cfg.get('google_auth', None) is True:
    raise SystemExit('google_auth must be false for antigravity oauth flow')

plugins = cfg.get('plugin') or []
matches = [p for p in plugins if isinstance(p, str) and p.startswith('opencode-multi-auth')]
if len(matches) != 1:
    raise SystemExit(f'opencode-multi-auth plugin count invalid: {len(matches)}')
if plugins[-1] != matches[0]:
    raise SystemExit('opencode-multi-auth must be last plugin entry')

print('OK')
PY
      )"; then
      mark_pass "OAuth non-interactive check: config wiring valid (google_auth + plugin order)"
    else
      mark_fail "OAuth non-interactive check: config wiring invalid"
      printf "%s\n" "$py_out"
      return 1
    fi
  else
    if grep -q '"google_auth"[[:space:]]*:[[:space:]]*true' "$config_path"; then
      mark_fail "OAuth non-interactive check: google_auth=true in config"
      return 1
    fi
    if ! grep -q 'opencode-multi-auth' "$config_path"; then
      mark_fail "OAuth non-interactive check: opencode-multi-auth not found in plugin list"
      return 1
    fi
    mark_pass "OAuth non-interactive check: basic config markers present"
  fi

  return 0
}

check_oauth_runtime_responsive() {
  local oauth_out
  local oauth_rc

  oauth_out="$(run_with_timeout "$TIMEOUT_SECONDS" opencode auth login --provider google --method "OAuth with Google (Antigravity)" --print-logs 2>&1)"
  oauth_rc=$?

  if [ -n "$oauth_out" ] && printf "%s" "$oauth_out" | grep -qi "Unknown provider"; then
    mark_fail "OAuth runtime check: invalid provider configuration"
    printf "%s\n" "$oauth_out"
    return 1
  fi

  if [ -n "$oauth_out" ] && printf "%s" "$oauth_out" | grep -qi "fetch() URL is invalid"; then
    mark_fail "OAuth runtime check: provider flow failed with invalid URL"
    printf "%s\n" "$oauth_out"
    return 1
  fi

  if [ -n "$oauth_out" ] && printf "%s" "$oauth_out" | grep -qi "Enter your API key"; then
    mark_fail "OAuth runtime check: fell back to API key prompt instead of Antigravity OAuth"
    printf "%s\n" "$oauth_out"
    return 1
  fi

  if [ -n "$oauth_out" ] && printf "%s" "$oauth_out" | grep -qiE "Antigravity OAuth|Project ID|OAuth with Google"; then
    mark_pass "OAuth runtime check: Antigravity prompt flow is reachable"
    return 0
  fi

  if [ "$oauth_rc" -eq 124 ]; then
    mark_fail "OAuth runtime check: command timed out without Antigravity prompt output"
  else
    mark_fail "OAuth runtime check: command exited unexpectedly (rc=$oauth_rc)"
  fi

  if [ -n "$oauth_out" ]; then
    printf "%s\n" "$oauth_out"
  fi
  return 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --exa-key)
      EXA_API_KEY="${2-}"
      shift 2
      ;;
    --probe-oauth)
      PROBE_OAUTH=1
      shift
      ;;
    --fix-wsl-shim)
      FIX_WSL_SHIM=1
      shift
      ;;
    --ci)
      CI_MODE=1
      shift
      ;;
    --require-exa)
      REQUIRE_EXA=1
      shift
      ;;
    --timeout)
      TIMEOUT_SECONDS="${2-35}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      log_fail "Unknown option: $1"
      usage
      exit 2
      ;;
  esac
done

if [ "$CI_MODE" -eq 1 ]; then
  PROBE_OAUTH=0
  log_info "CI mode enabled: strict non-interactive checks active"
fi

log_info "Starting OCS smoke checks (unix)"
fix_wsl_shim_if_needed

for cmd in bun ocs opencode; do
  if command -v "$cmd" >/dev/null 2>&1; then
    mark_pass "command exists: $cmd"
  else
    mark_fail "missing command: $cmd"
  fi
done

run_check "ocs --help" ocs --help
run_check "ocs doctor" ocs doctor
run_check "ocs prefs --help" ocs prefs --help
run_check "ocs setup profile --help" ocs setup profile --help
run_check "ocs setup update --help" ocs setup update --help
run_check "ocs exa --help" ocs exa --help
run_check "ocs exa setup --help" ocs exa setup --help
run_check "ocs exa check --help" ocs exa check --help

run_check "opencode --help" opencode --help
run_check "opencode auth --help" opencode auth --help
run_check "opencode auth login --help" opencode auth login --help

if [ "$CI_MODE" -eq 1 ]; then
  check_oauth_non_interactive
  check_oauth_runtime_responsive
elif [ "$PROBE_OAUTH" -eq 1 ]; then
  oauth_out="$(run_with_timeout "$TIMEOUT_SECONDS" opencode auth login --provider google --method "OAuth with Google (Antigravity)" --print-logs 2>&1 || true)"
  if printf "%s" "$oauth_out" | grep -qiE "Antigravity OAuth|Project ID|OAuth with Google"; then
    mark_pass "OAuth probe returned Antigravity prompt signal"
  else
    mark_fail "OAuth probe did not show expected Antigravity prompt signal"
    if [ -n "$oauth_out" ]; then
      printf "%s\n" "$oauth_out"
    fi
  fi
else
  warn_skip "OAuth probe skipped. Manual command: opencode auth login --provider google --method 'OAuth with Google (Antigravity)' --print-logs"
fi

if [ -n "$EXA_API_KEY" ]; then
  run_check "ocs exa setup --persist" ocs exa setup --api-key "$EXA_API_KEY" --persist
  run_check "ocs exa check" ocs exa check
elif [ "$REQUIRE_EXA" -eq 1 ]; then
  mark_fail "EXA checks required but no key provided (--exa-key <key>)"
else
  warn_skip "EXA checks skipped. Use --exa-key <key> to enable."
fi

printf "\n%bSummary%b: PASS=%d FAIL=%d WARN=%d\n" "$C_BLUE" "$C_RESET" "$PASS_COUNT" "$FAIL_COUNT" "$WARN_COUNT"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi

exit 0
