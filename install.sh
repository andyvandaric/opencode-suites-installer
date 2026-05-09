#!/usr/bin/env bash
# install.sh — Install opencode-multi-auth plugin for OpenCode Config Suites
# Supports 3 auth paths: gh CLI → GITHUB_TOKEN env → interactive prompt
set -euo pipefail

home_dir_is_invalid() {
  local home_dir="${1:-}"
  if [[ -z "${home_dir}" ]]; then
    return 0
  fi

  if [[ "${home_dir}" != /* ]]; then
    return 0
  fi

  if [[ "${home_dir}" == "/home" ]]; then
    return 0
  fi

  return 1
}

recover_home_dir() {
  local recovered_home=""
  recovered_home="$(getent passwd "$(id -u)" | cut -d: -f6 2>/dev/null || true)"
  if [[ -z "${recovered_home}" ]]; then
    recovered_home="$(cd ~ 2>/dev/null && pwd || true)"
  fi
  if [[ -z "${recovered_home}" ]]; then
    recovered_home="/tmp"
  fi

  printf '%s\n' "${recovered_home}"
}

resolve_runtime_user_name() {
  local runtime_user="${USER:-${LOGNAME:-}}"
  if [[ -n "${runtime_user}" ]]; then
    printf '%s\n' "${runtime_user}"
    return 0
  fi

  runtime_user="$(id -un 2>/dev/null || true)"
  if [[ -n "${runtime_user}" ]]; then
    printf '%s\n' "${runtime_user}"
  fi
}

# Recover HOME when missing or malformed (can happen in pipe-to-bash and WSL env contamination).
if home_dir_is_invalid "${HOME:-}"; then
  HOME="$(recover_home_dir)"
  export HOME
fi

if [[ -z "${USER:-}" ]]; then
  USER="$(resolve_runtime_user_name)"
  export USER
fi

if [[ -z "${LOGNAME:-}" && -n "${USER:-}" ]]; then
  LOGNAME="${USER}"
  export LOGNAME
fi

resolve_target_home_early() {
  if [[ -n "${OCS_TARGET_HOME:-}" ]]; then
    printf '%s\n' "${OCS_TARGET_HOME}"
    return 0
  fi

  if [[ "${EUID:-$(id -u)}" -eq 0 && -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    local sudo_home=""
    sudo_home="$(getent passwd "${SUDO_USER}" | cut -d: -f6 2>/dev/null || true)"
    if [[ -z "${sudo_home}" ]]; then
      sudo_home="$(eval printf '%s' "~${SUDO_USER}" 2>/dev/null || true)"
    fi
    if [[ -n "${sudo_home}" ]]; then
      printf '%s\n' "${sudo_home}"
      return 0
    fi
  fi

  if home_dir_is_invalid "${HOME:-}"; then
    recover_home_dir
    return 0
  fi

  printf '%s\n' "${HOME:-/tmp}"
}

TARGET_HOME="$(resolve_target_home_early)"
if [[ -n "${TARGET_HOME}" && "${TARGET_HOME}" != "${HOME}" ]]; then
  HOME="${TARGET_HOME}"
  export HOME
fi

resolve_path_contract_home_dir() {
  if [[ -n "${HOME:-}" ]]; then
    printf '%s\n' "${HOME}"
    return 0
  fi

  if [[ -n "${USERPROFILE:-}" ]]; then
    printf '%s\n' "${USERPROFILE}"
    return 0
  fi

  if [[ -n "${HOMEDRIVE:-}" && -n "${HOMEPATH:-}" ]]; then
    printf '%s%s\n' "${HOMEDRIVE}" "${HOMEPATH}"
    return 0
  fi

  printf '%s\n' "/tmp"
}

resolve_path_contract_config_home() {
  if [[ -n "${OPENCODE_CONFIG_DIR:-}" ]]; then
    dirname "${OPENCODE_CONFIG_DIR}"
    return 0
  fi

  if [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
    printf '%s\n' "${XDG_CONFIG_HOME}"
    return 0
  fi

  printf '%s/.config\n' "$(resolve_path_contract_home_dir)"
}

resolve_path_contract_target_config_dir() {
  if [[ -n "${OPENCODE_CONFIG_DIR:-}" ]]; then
    printf '%s\n' "${OPENCODE_CONFIG_DIR}"
    return 0
  fi

  printf '%s/opencode\n' "$(resolve_path_contract_config_home)"
}

resolve_path_contract_shell_config_home() {
  if [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
    printf '%s\n' "${XDG_CONFIG_HOME}"
    return 0
  fi

  printf '%s/.config\n' "$(resolve_path_contract_home_dir)"
}

resolve_path_contract_native_bin_dir() {
  printf '%s/.opencode/bin\n' "$(resolve_path_contract_home_dir)"
}

resolve_path_contract_local_bin_dir() {
  printf '%s/.local/bin\n' "$(resolve_path_contract_home_dir)"
}

resolve_path_contract_plugin_dir() {
  printf '%s/plugins/opencode-multi-auth\n' "$(resolve_path_contract_target_config_dir)"
}

resolve_path_contract_token_file() {
  printf '%s/.opencode-suites/.token\n' "$(resolve_path_contract_home_dir)"
}

resolve_path_contract_shell_snippet_dir() {
  printf '%s/opencode/shell\n' "$(resolve_path_contract_shell_config_home)"
}

resolve_path_contract_shell_snippet_path() {
  printf '%s/ocs-path.sh\n' "$(resolve_path_contract_shell_snippet_dir)"
}

resolve_path_contract_caveman_skill_dir() {
  printf '%s/skills/caveman\n' "$(resolve_path_contract_target_config_dir)"
}

resolve_path_contract_caveman_skill_path() {
  printf '%s/SKILL.md\n' "$(resolve_path_contract_caveman_skill_dir)"
}

resolve_path_contract_rtk_plugin_path() {
  printf '%s/plugins/rtk.ts\n' "$(resolve_path_contract_target_config_dir)"
}

resolve_path_contract_ocs_cli_cjs_path() {
  printf '%s/bin/ocs.cjs\n' "$(resolve_path_contract_target_config_dir)"
}

resolve_path_contract_ocs_cli_js_path() {
  printf '%s/bin/ocs.js\n' "$(resolve_path_contract_target_config_dir)"
}

resolve_path_contract_plugin_ocs_cli_cjs_path() {
  printf '%s/bin/ocs.cjs\n' "$(resolve_path_contract_plugin_dir)"
}

resolve_path_contract_plugin_ocs_cli_js_path() {
  printf '%s/bin/ocs.js\n' "$(resolve_path_contract_plugin_dir)"
}

# ─── Config ──────────────────────────────────────────────────────────────────
GITHUB_SOURCE_REPO="andyvandaric/andyvand-opencode-config"
INSTALLER_SOURCE_BRANCH_HINT="main"
GITHUB_SOURCE_BRANCH="${OCS_RELEASE_BRANCH:-}"
DEFAULT_RELEASE_BRANCH="${OCS_FALLBACK_RELEASE_BRANCH:-}"
INSTALLER_DEFAULT_PROFILE="codex-5.3-token-saver"
INSTALLER_DEFAULT_MODE="performance"
WHATSAPP_ORDER_URL="https://wa.me/6281289731212?text=Mau%20order%20OCS%20nya%2C%20mohon%20infonya%20ya"
CONFIG_HOME="$(resolve_path_contract_config_home)"
CONFIG_ROOT="$(resolve_path_contract_target_config_dir)"
PLUGIN_DIR="$(resolve_path_contract_plugin_dir)"
TOKEN_FILE="$(resolve_path_contract_token_file)"
NATIVE_BIN_DIR="$(resolve_path_contract_native_bin_dir)"
LOCAL_BIN_DIR="$(resolve_path_contract_local_bin_dir)"
SHELL_SNIPPET_DIR="$(resolve_path_contract_shell_snippet_dir)"
SHELL_SNIPPET_PATH="$(resolve_path_contract_shell_snippet_path)"
RTK_PLUGIN_PATH="$(resolve_path_contract_rtk_plugin_path)"
CAVEMAN_SKILL_DIR="$(resolve_path_contract_caveman_skill_dir)"
CAVEMAN_SKILL_PATH="$(resolve_path_contract_caveman_skill_path)"
OCS_CLI_CJS_PATH="$(resolve_path_contract_ocs_cli_cjs_path)"
OCS_CLI_JS_PATH="$(resolve_path_contract_ocs_cli_js_path)"
PLUGIN_OCS_CLI_CJS_PATH="$(resolve_path_contract_plugin_ocs_cli_cjs_path)"
PLUGIN_OCS_CLI_JS_PATH="$(resolve_path_contract_plugin_ocs_cli_js_path)"
TMP_DIR="$(mktemp -d /tmp/ocs-install-XXXXXX)"
REQUESTED_VERSION="${OCS_VERSION:-}"
RESOLVED_SOURCE_BRANCH=""

# ─── Cleanup on exit ─────────────────────────────────────────────────────────
trap 'rm -rf "${TMP_DIR}"' EXIT

# ─── Helpers ─────────────────────────────────────────────────────────────────
info()    { echo "  $*"; }
success() { echo "✅ $*"; }
error()   { echo "❌ $*" >&2; exit 1; }
warn()    { echo "⚠️  $*" >&2; }

progress_threshold_seconds() {
  case "$1" in
    install) printf '%s\n' '3' ;;
    doctor|index) printf '%s\n' '5' ;;
    release) printf '%s\n' '8' ;;
    *) printf '%s\n' '4' ;;
  esac
}

progress_messages() {
  case "$1:$2" in
    install:dependency-install)
      cat <<'EOF'
Installing runtime dependencies so OCS commands behave consistently in new shells.
Package manager work can stay quiet for a moment while downloads and lock checks finish.
Once this step completes, plugin commands and shims should be ready to use.
EOF
      ;;
    install:setup-profile)
      cat <<'EOF'
Applying your selected OCS profile and runtime defaults.
OCS is keeping account state while refreshing the managed config surface.
You will be able to use the updated profile as soon as this setup step completes.
EOF
      ;;
    install:cocoindex-bootstrap)
      cat <<'EOF'
Checking CocoIndex support for this project session.
If CocoIndex is already healthy, OCS will reuse it instead of rebuilding from scratch.
Python and MCP checks can take a little longer on fresh environments.
EOF
      ;;
    install:runtime-bootstrap)
      cat <<'EOF'
Checking native support tools that OCS uses for command routing and recovery.
If a healthy runtime already exists, OCS will reuse it instead of rebuilding from scratch.
First-time native tool setup can pause briefly while installers and shell hooks are verified.
EOF
      ;;
    *)
      cat <<'EOF'
Still working: preparing your OCS runtime and profile wiring.
This can take a bit on first install because package tools are being checked.
OCS is validating command paths so new shells work without manual fixes.
EOF
      ;;
  esac
}

progress_narration_enabled() {
  [[ "${OCS_PROGRESS_TEXT:-1}" != "0" ]] || return 1
  [[ "${OCS_QUIET:-0}" != "1" ]] || return 1
  [[ "${CI:-}" != "true" ]] || return 1
}

start_progress_narration() {
  local channel="$1"
  local scenario="${2:-default}"
  local threshold="${3:-$(progress_threshold_seconds "$channel")}" 
  local interval="${4:-4}"
  local raw_messages=""

  progress_narration_enabled || return 1
  raw_messages="$(progress_messages "$channel" "$scenario")"
  [[ -n "$raw_messages" ]] || return 1

  OCS_PROGRESS_MESSAGES=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && OCS_PROGRESS_MESSAGES+=("$line")
  done <<EOF
$raw_messages
EOF

  [[ ${#OCS_PROGRESS_MESSAGES[@]} -gt 0 ]] || return 1

  (
    sleep "$threshold"
    local index=0
    while true; do
      printf '  ⏳ %s\n' "${OCS_PROGRESS_MESSAGES[$((index % ${#OCS_PROGRESS_MESSAGES[@]}))]}"
      index=$((index + 1))
      sleep "$interval"
    done
  ) &
  OCS_PROGRESS_PID=$!
  return 0
}

stop_progress_narration() {
  if [[ -n "${OCS_PROGRESS_PID:-}" ]]; then
    kill "${OCS_PROGRESS_PID}" >/dev/null 2>&1 || true
    wait "${OCS_PROGRESS_PID}" 2>/dev/null || true
    unset OCS_PROGRESS_PID
  fi
  unset OCS_PROGRESS_MESSAGES
}

sync_bundle_runtime_root() {
  local bundle_root="$1"
  local target_root="$2"

  [[ -d "${bundle_root}" ]] || error "Bundle root ${bundle_root} not found for runtime sync."
  mkdir -p "${target_root}"
  cp -R "${bundle_root}/." "${target_root}/"
  success "Synced bundled runtime root to ${target_root}"
}

resolve_installer_setup_script() {
  local is_local_source="$1"
  local plugin_dir="$2"
  local config_root="$3"

  if [[ "${is_local_source}" == "true" ]]; then
    printf '%s\n' "${plugin_dir}/scripts/setup.js"
    return 0
  fi

  local target_root_script="${config_root}/scripts/setup.js"
  if [[ -f "${target_root_script}" ]]; then
    printf '%s\n' "${target_root_script}"
    return 0
  fi

  printf '%s\n' "${plugin_dir}/scripts/setup.js"
}

is_root_user() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]]
}

run_with_privilege() {
  if is_root_user; then
    "$@"
    return $?
  fi

  if command -v sudo >/dev/null 2>&1; then
    if sudo -n true >/dev/null 2>&1; then
      sudo -n "$@"
      return $?
    fi

    if [[ -t 0 && -t 1 ]]; then
      sudo "$@"
      return $?
    fi

    return 1
  fi

  if command -v su >/dev/null 2>&1; then
    if [[ -t 0 && -t 1 ]]; then
      su -c "$(printf '%q ' "$@")"
      return $?
    fi

    return 1
  fi

  return 127
}

run_apt_command_with_elevation() {
  if run_with_privilege "$@"; then
    return 0
  fi

  if is_root_user; then
    return 1
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    return 1
  fi

  warn "apt command needs elevated privileges. Retrying with sudo (password prompt may appear)..."
  if sudo "$@"; then
    return 0
  fi

  return 1
}

run_with_retries() {
  local attempts="$1"
  shift
  local try=1

  while (( try <= attempts )); do
    if "$@"; then
      return 0
    fi

    if (( try == attempts )); then
      return 1
    fi

    sleep 2
    try=$((try + 1))
  done

  return 1
}

resolve_absolute_path_safe() {
  local candidate="$1"
  if [[ -z "$candidate" ]]; then
    return 1
  fi

  if command -v realpath >/dev/null 2>&1; then
    realpath "$candidate"
    return $?
  fi

  if command -v readlink >/dev/null 2>&1; then
    local linked
    linked="$(readlink -f "$candidate" 2>/dev/null || true)"
    if [[ -n "$linked" ]]; then
      printf '%s\n' "$linked"
      return 0
    fi
  fi

  if [[ "$candidate" = /* ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  printf '%s/%s\n' "$(pwd)" "$candidate"
}

is_legacy_macos_bash() {
  [[ "$(uname -s 2>/dev/null || true)" == "Darwin" ]] || return 1

  local bash_major="${BASH_VERSINFO[0]:-0}"
  [[ "$bash_major" =~ ^[0-9]+$ ]] || bash_major=0
  (( bash_major > 0 && bash_major < 4 ))
}

enable_legacy_shell_fallbacks() {
  if is_legacy_macos_bash; then
    warn "Detected legacy macOS bash (${BASH_VERSION:-unknown}). Enabling POSIX CocoIndex shim fallback for setup."
    export OCS_SETUP_FORCE_POSIX_CCC_SHIM=1
  fi
}

show_usage() {
  cat <<'EOF'
Usage: install.sh [--version <x.y.z>] [--branch <name>] [--help]

Options:
  --version, -v   Install specific bundle version (example: 2.0.15)
  --branch        Override source branch (default: inferred from installer URL, fallback: main)
  --help, -h      Show this help

Env alternatives:
  OCS_VERSION         Same as --version
  OCS_RELEASE_BRANCH  Same as --branch
  OCS_FALLBACK_RELEASE_BRANCH  Override fallback branch for missing requested asset
EOF
}

detect_installer_branch_from_parent_commandline() {
  local cmdline=""

  if [[ -r "/proc/${PPID}/cmdline" ]]; then
    cmdline="$(tr '\0' ' ' <"/proc/${PPID}/cmdline" 2>/dev/null || true)"
  fi

  if [[ -z "$cmdline" ]] && command -v ps >/dev/null 2>&1; then
    cmdline="$(ps -o command= -p "${PPID}" 2>/dev/null || true)"
  fi

  [[ -n "$cmdline" ]] || return 1

  local marker="raw.githubusercontent.com/andyvandaric/opencode-suites-installer/"
  local tail="${cmdline#*"${marker}"}"
  [[ "$tail" != "$cmdline" ]] || return 1

  local branch="${tail%%/install.sh*}"
  branch="${branch%%\"*}"
  branch="${branch%%\'*}"
  branch="${branch%% *}"
  [[ -n "$branch" ]] || return 1

  printf '%s\n' "$branch"
}

resolve_release_branch_config() {
  if [[ -z "${GITHUB_SOURCE_BRANCH}" ]]; then
    local detected_branch=""
    detected_branch="$(detect_installer_branch_from_parent_commandline || true)"

    if [[ -n "$detected_branch" ]]; then
      GITHUB_SOURCE_BRANCH="$detected_branch"
    elif [[ -n "${REQUESTED_VERSION}" ]]; then
      GITHUB_SOURCE_BRANCH="main"
    else
      GITHUB_SOURCE_BRANCH="${INSTALLER_SOURCE_BRANCH_HINT}"
    fi
  fi

  if [[ -z "${DEFAULT_RELEASE_BRANCH}" ]]; then
    DEFAULT_RELEASE_BRANCH="${GITHUB_SOURCE_BRANCH}"
  fi

  RESOLVED_SOURCE_BRANCH="${GITHUB_SOURCE_BRANCH}"
}

parse_cli_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version|-v)
        [[ $# -ge 2 ]] || error "Missing value for $1"
        REQUESTED_VERSION="${2#v}"
        shift 2
        ;;
      --branch)
        [[ $# -ge 2 ]] || error "Missing value for --branch"
        GITHUB_SOURCE_BRANCH="$2"
        shift 2
        ;;
      --help|-h)
        show_usage
        exit 0
        ;;
      *)
        error "Unknown option: $1 (use --help for usage)"
        ;;
    esac
  done
}

detect_package_manager() {
  if command -v apt-get >/dev/null 2>&1; then echo "apt"; return; fi
  if command -v dnf >/dev/null 2>&1; then echo "dnf"; return; fi
  if command -v yum >/dev/null 2>&1; then echo "yum"; return; fi
  if command -v pacman >/dev/null 2>&1; then echo "pacman"; return; fi
  if command -v zypper >/dev/null 2>&1; then echo "zypper"; return; fi
  if command -v apk >/dev/null 2>&1; then echo "apk"; return; fi
  if command -v brew >/dev/null 2>&1; then echo "brew"; return; fi
  echo ""
}

supported_posix_package_managers() {
  printf '%s\n' 'apt, dnf, yum, pacman, zypper, apk, brew'
}

is_macos_host() {
  [[ "$(uname -s 2>/dev/null || true)" == "Darwin" ]]
}

resolve_node_runtime_packages() {
  case "$1" in
    brew)
      printf '%s\n' 'node'
      ;;
    apt)
      printf '%s\n' 'NodeSource 22.x nodejs'
      ;;
    dnf|yum|pacman|zypper|apk)
      printf '%s\n' 'nodejs npm'
      ;;
    *)
      printf '%s\n' ''
      ;;
  esac
}

required_node_major_version() {
  printf '%s\n' '22'
}

install_nodesource_node_runtime() {
  local setup_tmp=""
  local conflicting_packages=()
  local package_name=""
  setup_tmp="$(mktemp)"
  trap '[[ -n "${setup_tmp:-}" ]] && rm -f "${setup_tmp}"' RETURN

  while IFS= read -r package_name; do
    [[ -n "${package_name}" ]] || continue
    conflicting_packages+=("${package_name}")
  done < <(
    dpkg-query -W -f='${Package}\n' 2>/dev/null | grep -E '^(nodejs|npm|libnode-dev|libnode[0-9]+|nodejs-doc)$' || true
  )

  if [[ ${#conflicting_packages[@]} -gt 0 ]]; then
    run_with_privilege env DEBIAN_FRONTEND=noninteractive apt-get remove -y "${conflicting_packages[@]}" || return 1
    run_with_privilege env DEBIAN_FRONTEND=noninteractive apt-get autoremove -y || return 1
  fi

  curl -fsSL https://deb.nodesource.com/setup_22.x >"${setup_tmp}" || return 1
  run_with_privilege env DEBIAN_FRONTEND=noninteractive bash "${setup_tmp}" || return 1
  run_with_privilege env DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::Retries=3 install -y nodejs || return 1
}

resolve_local_node_version() {
  local node_cmd
  node_cmd="$(resolve_local_runtime_command_path node 2>/dev/null || true)"
  [[ -n "${node_cmd}" ]] || return 1
  "${node_cmd}" -p 'process.versions.node' 2>/dev/null | tr -d '\r\n'
}

local_node_runtime_meets_minimum() {
  local version
  local major
  local required_major
  version="$(resolve_local_node_version 2>/dev/null || true)"
  [[ -n "${version}" ]] || return 1
  major="${version%%.*}"
  required_major="$(required_node_major_version)"
  [[ "${major}" =~ ^[0-9]+$ ]] || return 1
  [[ "${required_major}" =~ ^[0-9]+$ ]] || return 1
  (( major >= required_major ))
}

error_missing_supported_package_manager() {
  local subject="$1"

  if is_macos_host; then
    error "Cannot auto-install ${subject} on macOS because Homebrew is unavailable or not on PATH. Install Homebrew, then rerun install.sh."
  fi

  error "Cannot auto-install ${subject}: no supported package manager detected. Supported POSIX managers: $(supported_posix_package_managers)."
}

error_package_manager_bootstrap_failure() {
  local pm="$1"
  local subject="$2"
  local packages="$3"

  case "$pm" in
    apt)
      error "Failed to auto-install ${subject} via apt (${packages}). This POSIX bootstrap lane requires native package installation with sudo/root access before setup can continue."
      ;;
    dnf|yum|pacman|zypper|apk)
      error "Failed to auto-install ${subject} via ${pm} (${packages}). This package-manager lane is supported only when native bootstrap succeeds, so install.sh stopped before setup and adjunct runtime work."
      ;;
    brew)
      error "Failed to auto-install ${subject} via brew (${packages}). Ensure Homebrew is installed, healthy, and able to install native runtimes in this shell, then rerun install.sh."
      ;;
    *)
      error "Failed to auto-install ${subject} via ${pm} (${packages})."
      ;;
  esac
}

error_pnpm_runtime_bootstrap_failure() {
  local pm="$1"

  case "$pm" in
    apt)
      error "Failed to bootstrap pnpm after native Node.js repair on apt. install.sh requires corepack or npm-based pnpm activation to succeed before setup continues."
      ;;
    dnf|yum|pacman|zypper|apk)
      error "Failed to bootstrap pnpm after native Node.js repair on ${pm}. This package-manager lane is explicitly supported only when pnpm activation succeeds, so install.sh stopped before setup and adjunct runtime work."
      ;;
    brew)
      error "Failed to bootstrap pnpm after native Homebrew Node.js repair. Ensure brew installed a working node/corepack toolchain, or rerun after native npm can install pnpm."
      ;;
    *)
      error "Failed to bootstrap pnpm after native Node.js repair."
      ;;
  esac
}

report_rejected_cross_os_node_tools() {
  local tool_name
  local resolved_path
  local debug_cross_os_runtime="${OCS_DEBUG_CROSS_OS_RUNTIME:-0}"

  for tool_name in node npm pnpm corepack; do
    resolved_path="$(command -v "${tool_name}" 2>/dev/null || true)"
    [[ -n "${resolved_path}" ]] || continue
    if is_windows_mounted_command_path "${resolved_path}"; then
      if [[ "${debug_cross_os_runtime}" == "1" ]]; then
        warn "Debug: filtered Windows-mounted ${tool_name} candidate at ${resolved_path}."
      fi
    fi
  done
}

resolve_local_runtime_command_path() {
  local command_name="$1"
  local resolved_path=""

  while IFS= read -r resolved_path; do
    [[ -n "${resolved_path}" ]] || continue
    if is_windows_mounted_command_path "${resolved_path}"; then
      continue
    fi
    printf '%s\n' "${resolved_path}"
    return 0
  done < <(type -aP "${command_name}" 2>/dev/null || true)

  resolved_path="$(command -v "${command_name}" 2>/dev/null || true)"
  [[ -n "${resolved_path}" ]] || return 1
  if is_windows_mounted_command_path "${resolved_path}"; then
    return 1
  fi
  printf '%s\n' "${resolved_path}"
}

install_packages_auto() {
  local pm="$1"
  shift
  local pkgs=("$@")
  local dep_retries="${OCS_DEP_INSTALL_RETRIES:-2}"

  case "$pm" in
    apt)
      run_with_retries "$dep_retries" run_apt_command_with_elevation env DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::Retries=3 update && run_with_retries "$dep_retries" run_apt_command_with_elevation env DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::Retries=3 install -y "${pkgs[@]}"
      ;;
    dnf)
      run_with_retries "$dep_retries" run_with_privilege dnf install -y "${pkgs[@]}"
      ;;
    yum)
      run_with_retries "$dep_retries" run_with_privilege yum install -y "${pkgs[@]}"
      ;;
    pacman)
      run_with_retries "$dep_retries" run_with_privilege pacman -Sy --noconfirm --needed "${pkgs[@]}"
      ;;
    zypper)
      run_with_retries "$dep_retries" run_with_privilege zypper --non-interactive install --no-recommends "${pkgs[@]}"
      ;;
    apk)
      run_with_retries "$dep_retries" run_with_privilege apk add --no-cache "${pkgs[@]}"
      ;;
    brew)
      run_with_retries "$dep_retries" brew install "${pkgs[@]}"
      ;;
    *)
      return 2
      ;;
  esac
}

ensure_shell_dependencies() {
  local required=(curl git tar)
  local missing=()
  local dep
  local total
  local idx=0

  if ! command_is_usable_local_runtime bun; then
    required+=(unzip)
  fi

  total=${#required[@]}
  info "Checking required dependencies..."

  for dep in "${required[@]}"; do
    idx=$((idx + 1))
    printf "  [%d/%d] %-5s ... " "$idx" "$total" "$dep"
    if ! command -v "$dep" >/dev/null 2>&1; then
      printf "MISSING\n"
      missing+=("$dep")
    else
      printf "OK\n"
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    success "All required dependencies already available."
    return 0
  fi

  warn "Missing dependencies: ${missing[*]}"

  local pm
  pm="$(detect_package_manager)"
  if [[ -z "$pm" ]]; then
    error_missing_supported_package_manager "dependencies (${missing[*]})"
  fi

  info "Attempting to auto-install dependencies via ${pm}..."
  info "Installing: ${missing[*]}"
  if ! install_packages_auto "$pm" "${missing[@]}"; then
    error_package_manager_bootstrap_failure "$pm" "dependencies" "${missing[*]}"
  fi

  local verify_total
  local verify_idx=0
  verify_total=${#missing[@]}
  info "Verifying installed dependencies..."
  for dep in "${missing[@]}"; do
    verify_idx=$((verify_idx + 1))
    printf "  [%d/%d] %-5s ... " "$verify_idx" "$verify_total" "$dep"
    if ! command -v "$dep" >/dev/null 2>&1; then
      printf "MISSING\n"
      error "Dependency '${dep}' still missing after auto-install"
    fi
    printf "OK\n"
  done

  success "Dependencies installed: ${missing[*]}"
}

ocs_works() {
  if ! command -v ocs >/dev/null 2>&1; then
    return 1
  fi
  ocs --version >/dev/null 2>&1 || return 1
  local help_output
  help_output="$(ocs --help 2>/dev/null || true)"
  [[ -n "$help_output" ]] || return 1
  grep -q "OpenCode Config Suites CLI" <<<"$help_output" || return 1
  return 0
}

resolve_primary_shell_profile() {
  local profile
  profile="$(resolve_primary_shell_profiles | head -1)"
  printf '%s\n' "${profile}"
}

resolve_shell_name() {
  local shell_path="${OCS_INSTALLER_SHELL_PATH:-${SHELL:-}}"
  local shell_name="${shell_path##*/}"

  if [[ -z "${shell_name}" || "${shell_name}" == "${shell_path}" ]]; then
    shell_name="sh"
  fi

  printf '%s\n' "${shell_name}"
}

append_unique_value() {
  local value="$1"
  shift
  local existing

  for existing in "$@"; do
    if [[ "${existing}" == "${value}" ]]; then
      return 1
    fi
  done

  printf '%s\n' "${value}"
  return 0
}

normalize_path_entry() {
  local entry="$1"

  while [[ "${entry}" == */ && "${entry}" != "/" ]]; do
    entry="${entry%/}"
  done

  printf '%s\n' "${entry}"
}

join_safe_env_path() {
  local relative_path="$1"
  local home_dir="${HOME}"

  [[ -n "${relative_path}" ]] || return 1
  [[ -n "${home_dir}" ]] || return 1

  if [[ "${relative_path}" = /* ]]; then
    printf '%s\n' "$(normalize_path_entry "${relative_path}")"
    return 0
  fi

  printf '%s\n' "$(normalize_path_entry "${home_dir}/${relative_path}")"
}

resolve_primary_shell_profiles() {
  local shell_name
  shell_name="$(resolve_shell_name)"
  local candidate
  local candidates=()
  local selected=()

  case "${shell_name}" in
    zsh)
      candidates=("${HOME}/.zprofile" "${HOME}/.zshrc")
      ;;
    bash)
      candidates=("${HOME}/.bash_profile" "${HOME}/.profile")
      if [[ -f "${HOME}/.bashrc" ]]; then
        candidates+=("${HOME}/.bashrc")
      fi
      ;;
    fish)
      candidates=()
      ;;
    *)
      candidates=("${HOME}/.profile")
      ;;
  esac

  for candidate in "${candidates[@]}"; do
    [[ -n "${candidate}" ]] || continue
    if append_unique_value "${candidate}" "${selected[@]}" >/dev/null; then
      selected+=("${candidate}")
    fi
  done

  printf '%s\n' "${selected[@]}"
}

resolve_supported_shell_profiles() {
  local selected=()
  local candidate

  for candidate in \
    "${HOME}/.zprofile" \
    "${HOME}/.zshrc" \
    "${HOME}/.bash_profile" \
    "${HOME}/.profile"
  do
    [[ -n "${candidate}" ]] || continue
    if append_unique_value "${candidate}" "${selected[@]}" >/dev/null; then
      selected+=("${candidate}")
    fi
  done

  if [[ -f "${HOME}/.bashrc" ]]; then
    if append_unique_value "${HOME}/.bashrc" "${selected[@]}" >/dev/null; then
      selected+=("${HOME}/.bashrc")
    fi
  fi

  printf '%s\n' "${selected[@]}"
}

profile_contains_ocs_path_source() {
  local profile="$1"
  [[ -f "${profile}" ]] || return 1
  grep -Fq 'ocs-path.sh' "${profile}"
}

rewrite_ocs_path_source_lines() {
  local profile="$1"
  local source_line="$2"
  [[ -f "${profile}" ]] || return 0

  python3 - "$profile" "$source_line" <<'PY'
from pathlib import Path
import sys

profile = Path(sys.argv[1])
source_line = sys.argv[2]
lines = profile.read_text(encoding="utf-8").splitlines()
rewritten = []
replaced = False

for line in lines:
    if "ocs-path.sh" in line:
        if not replaced:
            rewritten.append(source_line)
            replaced = True
        continue
    rewritten.append(line)

text = "\n".join(rewritten)
if lines:
    text += "\n"
profile.write_text(text, encoding="utf-8")
PY
}

resolve_binary_dir() {
  local bin="$1"
  if [[ -z "$bin" ]]; then
    return 1
  fi

  local resolved
  resolved="$(resolve_local_runtime_command_path "$bin" 2>/dev/null || true)"
  if [[ -z "$resolved" ]]; then
    return 1
  fi

  dirname "$resolved"
}

collect_node_bin_entries() {
  local entries=(
    "${HOME}/.node/bin"
    "${HOME}/.npm/bin"
    "${HOME}/.npm-global/bin"
    "${HOME}/.local/share/pnpm/bin"
    "${HOME}/.pnpm/bin"
  )
  local prefix
  local bin_dir
  local npm_cmd
  local pnpm_cmd

  if command_is_usable_local_runtime npm; then
    npm_cmd="$(resolve_local_runtime_command_path npm 2>/dev/null || true)"
    prefix="$("${npm_cmd}" config get prefix 2>/dev/null || true)"
    if [[ -n "$prefix" && "$prefix" != "undefined" && "$prefix" != "null" ]]; then
      entries+=("${prefix}/bin")
    fi
    bin_dir="$(resolve_binary_dir npm 2>/dev/null || true)"
    if [[ -n "$bin_dir" ]]; then
      entries+=("$bin_dir")
    fi
  fi

  if command_is_usable_local_runtime pnpm; then
    pnpm_cmd="$(resolve_local_runtime_command_path pnpm 2>/dev/null || true)"
    prefix="$("${pnpm_cmd}" config get prefix 2>/dev/null || true)"
    if [[ -n "$prefix" && "$prefix" != "undefined" && "$prefix" != "null" ]]; then
      entries+=("${prefix}/bin")
    fi
    bin_dir="$(resolve_binary_dir pnpm 2>/dev/null || true)"
    if [[ -n "$bin_dir" ]]; then
      entries+=("$bin_dir")
    fi
  fi

  local entry
  for entry in "${entries[@]}"; do
    [[ -n "$entry" ]] && printf '%s\n' "$entry"
  done
}

resolve_native_user_home() {
  if [[ -n "${OCS_NATIVE_USER_HOME:-}" ]]; then
    printf '%s\n' "${OCS_NATIVE_USER_HOME}"
    return 0
  fi

  printf '%s\n' "${HOME}"
}

collect_node_manager_bin_entries() {
  local native_home
  native_home="$(resolve_native_user_home)"
  local candidates=(
    "${native_home}/.volta/bin"
  )

  local nvm_glob
  for nvm_glob in "${native_home}"/.nvm/versions/node/*/bin; do
    [[ -d "${nvm_glob}" ]] || continue
    candidates+=("${nvm_glob}")
  done

  local entry
  for entry in "${candidates[@]}"; do
    [[ -d "${entry}" ]] || continue
    printf '%s\n' "${entry}"
  done
}

ensure_node_runtime_paths() {
  local entries=()
  local entry
  while IFS= read -r entry; do
    [[ -n "${entry}" ]] || continue
    entries+=("${entry}")
  done < <(collect_node_manager_bin_entries)
  while IFS= read -r entry; do
    [[ -n "${entry}" ]] || continue
    entries+=("${entry}")
  done < <(collect_node_bin_entries)

  local path_prefix=""
  for entry in "${entries[@]}"; do
    entry="$(normalize_path_entry "${entry}")"
    [[ -n "${entry}" ]] || continue
    case ":${PATH}:" in
      *":${entry}:"*)
        continue
        ;;
    esac

    if [[ -z "${path_prefix}" ]]; then
      path_prefix="${entry}"
    else
      path_prefix="${path_prefix}:${entry}"
    fi
  done

  if [[ -n "${path_prefix}" ]]; then
    export PATH="${path_prefix}:${PATH}"
    hash -r 2>/dev/null || true
  fi
  ensure_native_node_tool_shims
}

ensure_native_npm_user_prefix() {
  local npm_prefix="${HOME}/.npm-global"
  mkdir -p "${npm_prefix}/bin"
  export NPM_CONFIG_PREFIX="${npm_prefix}"
  export npm_config_prefix="${npm_prefix}"
  if [[ ":${PATH}:" != *":${npm_prefix}/bin:"* ]]; then
    export PATH="${npm_prefix}/bin:${PATH}"
  fi
  hash -r 2>/dev/null || true
}

ensure_native_node_tool_shims() {
  local target_dir="${NATIVE_BIN_DIR}"
  local tool_name
  local resolved_path
  local shim_path

  mkdir -p "${target_dir}" 2>/dev/null || true

  for tool_name in node npm pnpm corepack; do
    resolved_path="$(resolve_local_runtime_command_path "${tool_name}" 2>/dev/null || true)"
    [[ -n "${resolved_path}" ]] || continue
    shim_path="${target_dir}/${tool_name}"
    cat >"${shim_path}" <<EOF
#!/usr/bin/env bash
exec "${resolved_path}" "\$@"
EOF
    chmod +x "${shim_path}" 2>/dev/null || true
  done

  export PATH="${target_dir}:${PATH}"
  hash -r 2>/dev/null || true
}

is_windows_mounted_command_path() {
  local resolved_path="$1"
  [[ -n "$resolved_path" && "$resolved_path" == /mnt/[A-Za-z]/* ]]
}

command_is_usable_local_runtime() {
  local command_name="$1"
  local resolved_path
  resolved_path="$(resolve_local_runtime_command_path "$command_name" 2>/dev/null || true)"
  [[ -n "$resolved_path" ]]
}

ensure_text_file_exists_if_writable() {
  local file_path="$1"
  local parent_dir
  parent_dir="$(dirname "${file_path}")"

  mkdir -p "${parent_dir}" 2>/dev/null || true
  if [[ -f "${file_path}" ]]; then
    [[ -w "${file_path}" ]]
    return $?
  fi

  if [[ -w "${parent_dir}" ]]; then
    : > "${file_path}"
    return 0
  fi

  return 1
}

find_caveman_skill_source() {
  local base_home="${HOME}"
  local candidates=(
    "${base_home}/.agents/skills/caveman"
    "${base_home}/.claude/plugins/marketplaces/caveman/skills/caveman"
    "${base_home}/.claude/plugins/marketplaces/caveman/plugins/caveman/skills/caveman"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -f "${candidate}/SKILL.md" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  local root
  for root in "${base_home}/.claude/plugins/cache/caveman/caveman"/*; do
    [[ -d "${root}" ]] || continue
    for candidate in \
      "${root}/skills/caveman" \
      "${root}/plugins/caveman/skills/caveman"; do
      if [[ -f "${candidate}/SKILL.md" ]]; then
        printf '%s\n' "${candidate}"
        return 0
      fi
    done
  done

  return 1
}

sync_caveman_skill_marker() {
  local target_dir="${CAVEMAN_SKILL_DIR}"
  local target_marker="${target_dir}/SKILL.md"
  [[ ! -f "${target_marker}" ]] || return 0

  local source_dir=""
  source_dir="$(find_caveman_skill_source)" || return 1

  mkdir -p "$(dirname "${target_dir}")"
  rm -rf "${target_dir}"
  cp -R "${source_dir}" "${target_dir}"
  [[ -f "${target_marker}" ]]
}

ensure_adjunct_runtime_ready() {
  local native_bin="${NATIVE_BIN_DIR}"
  local rtk_plugin="${RTK_PLUGIN_PATH}"
  local caveman_marker="${CAVEMAN_SKILL_PATH}"

  if [[ -d "${native_bin}" ]]; then
    export PATH="${native_bin}:${PATH}"
    hash -r 2>/dev/null || true
  fi

  if [[ ! -f "${caveman_marker}" ]]; then
    if sync_caveman_skill_marker; then
      success "Synced Caveman skill into target OpenCode skills dir: ${CAVEMAN_SKILL_DIR}"
    fi
  fi

  local rtk_ok=0
  if command -v rtk >/dev/null 2>&1 && [[ -f "${rtk_plugin}" ]]; then
    if rtk --version >/dev/null 2>&1 && rtk init --show >/dev/null 2>&1 && rtk gain >/dev/null 2>&1; then
      rtk_ok=1
      success "RTK runtime verification passed."
    fi
  fi

  if (( ! rtk_ok )); then
    warn "RTK runtime is not fully ready yet. Expected PATH entry: ${native_bin}"
    info "Verify manually: rtk --version && rtk init --show && rtk gain"
  fi

  if [[ -f "${caveman_marker}" ]]; then
    success "Caveman skill marker present after install."
  else
    warn "Caveman skill marker missing after install: ${caveman_marker}"
    info "Verify manually: npx -y skills add JuliusBrussee/caveman -a opencode -s '*' -g -y"
  fi
}

ensure_antigravity_oauth_integrity() {
  local setup_script="$1"
  local config_dir="${CONFIG_ROOT}"
  local runtime_opencode="${config_dir}/opencode.json"
  local runtime_antigravity="${config_dir}/antigravity.json"
  local template_antigravity="${PLUGIN_DIR}/backups/antigravity.json.template"
  local needs_repair=0

  mkdir -p "${config_dir}" 2>/dev/null || true

  if [[ -f "${runtime_antigravity}" ]]; then
    info "Existing Antigravity storage detected. Preserving current account state."
  elif [[ -f "${template_antigravity}" ]]; then
    cp "${template_antigravity}" "${runtime_antigravity}"
    needs_repair=1
  fi

  if [[ -f "${runtime_opencode}" ]] && grep -Eq 'file:///.*dist/index\.js|plugins/.*/dist/index\.js' "${runtime_opencode}"; then
    needs_repair=1
  fi

  if (( needs_repair )); then
    info "Repairing final Antigravity OAuth visibility before installer exit..."
    export OCS_SETUP_INSTALLER_MODE=1
    "$(resolve_local_runtime_command_path bun)" "${setup_script}" --headless --profile "${INSTALLER_DEFAULT_PROFILE}" --mode "${INSTALLER_DEFAULT_MODE}" >/dev/null 2>&1 || true
    unset OCS_SETUP_INSTALLER_MODE
    if [[ ! -f "${runtime_antigravity}" && -f "${template_antigravity}" ]]; then
      cp "${template_antigravity}" "${runtime_antigravity}"
    fi
  fi

  [[ -f "${runtime_antigravity}" ]] || error "Final Antigravity OAuth integrity check failed: antigravity.json is missing."

  if [[ -f "${runtime_opencode}" ]] && grep -Eq 'file:///.*dist/index\.js|plugins/.*/dist/index\.js' "${runtime_opencode}"; then
    error "Final Antigravity OAuth integrity check failed: runtime config still references a raw dist/index.js plugin path."
  fi

  success "Antigravity OAuth integrity check passed."
}

opencode_works() {
  local bun_bin local_bin opencode_cmd
  bun_bin="$(join_safe_env_path '.bun/bin')"
  local_bin="$(join_safe_env_path '.local/bin')"

  if [[ -x "${bun_bin}/opencode" ]]; then
    opencode_cmd="${bun_bin}/opencode"
  elif [[ -x "${local_bin}/opencode" ]]; then
    opencode_cmd="${local_bin}/opencode"
  else
    opencode_cmd="$(command -v opencode 2>/dev/null || true)"
  fi

  [[ -n "$opencode_cmd" ]] || return 1

  if command -v timeout >/dev/null 2>&1; then
    timeout 8 "$opencode_cmd" --version >/dev/null 2>&1 || return 1
    local help_output
    help_output="$(timeout 8 "$opencode_cmd" --help 2>/dev/null)" || return 1
    grep -q "Usage: oh-my-opencode" <<<"$help_output" && return 1
    grep -q "The ultimate OpenCode plugin" <<<"$help_output" && return 1
    return 0
  fi

  return 0
}

resolve_opencode_native_binary() {
  local candidates=(
    "${HOME}/.opencode/bin/opencode"
    "${HOME}/.opencode/bin/opencode.exe"
    "${HOME}/.bun/install/global/node_modules/opencode-ai/bin/.opencode"
    "${HOME}/.bun/install/global/node_modules/opencode-ai/bin/.opencode.exe"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

install_opencode_shim() {
  local bun_bin="${HOME}/.bun/bin"
  local local_bin="${HOME}/.local/bin"
  local bun_exec="${HOME}/.bun/bin/bun"
  local bunx_exec="${HOME}/.bun/bin/bunx"
  local native_binary
  mkdir -p "$bun_bin" "$local_bin"

  native_binary="$(resolve_opencode_native_binary || true)"

cat > "${bun_bin}/opencode" <<EOF
#!/usr/bin/env bash
if [[ -n "$native_binary" ]] && [[ -x "$native_binary" ]]; then
  exec "$native_binary" "\$@"
fi
if [[ -x "$bunx_exec" ]]; then
  exec "$bunx_exec" --bun opencode-ai "\$@"
fi
exec bunx --bun opencode-ai "\$@"
EOF
  chmod +x "${bun_bin}/opencode"

cat > "${local_bin}/opencode" <<EOF
#!/usr/bin/env bash
if [[ -n "$native_binary" ]] && [[ -x "$native_binary" ]]; then
  exec "$native_binary" "\$@"
fi
if [[ -x "$bunx_exec" ]]; then
  exec "$bunx_exec" --bun opencode-ai "\$@"
fi
exec bunx --bun opencode-ai "\$@"
EOF
  chmod +x "${local_bin}/opencode"

  export PATH="${local_bin}:${bun_bin}:${PATH}"
  hash -r 2>/dev/null || true
  opencode_works
}

install_opencode_official() {
  command -v curl >/dev/null 2>&1 || return 1

  info "Installing opencode via official installer..."
  if ! curl -fsSL https://opencode.ai/install | bash >/tmp/ocs-opencode-official.log 2>&1; then
    warn "$(cat /tmp/ocs-opencode-official.log 2>/dev/null || true)"
    return 1
  fi

  export PATH="${HOME}/.local/bin:${HOME}/.bun/bin:${PATH}"
  hash -r 2>/dev/null || true
  opencode_works
}

install_opencode_bun_global() {
  local bun_cmd
  bun_cmd="$(resolve_local_runtime_command_path bun 2>/dev/null || true)"
  [[ -n "${bun_cmd}" ]] || return 1

  info "Installing opencode-ai via bun global package..."
  if ! "${bun_cmd}" add -g opencode-ai@latest >/tmp/ocs-opencode-bun-global.log 2>&1; then
    warn "$(cat /tmp/ocs-opencode-bun-global.log 2>/dev/null || true)"
    return 1
  fi

  export PATH="${HOME}/.bun/bin:${HOME}/.local/bin:${PATH}"
  hash -r 2>/dev/null || true
  opencode_works
}

ensure_opencode_command() {
  if opencode_works; then
    return 0
  fi

  finalize_opencode_repair() {
    install_opencode_shim >/dev/null 2>&1 || true
    export PATH="${HOME}/.opencode/bin:${HOME}/.local/bin:${HOME}/.bun/bin:${PATH}"
    hash -r 2>/dev/null || true
    opencode_works
  }

  warn "opencode command not healthy. Trying official installer..."
  if install_opencode_official && finalize_opencode_repair; then
    return 0
  fi

  warn "official installer did not recover opencode. Trying bun global install..."
  if install_opencode_bun_global && finalize_opencode_repair; then
    return 0
  fi

  warn "opencode command not healthy. Installing bunx shim..."
  if install_opencode_shim && opencode_works; then
    return 0
  fi

  if [[ "${OCS_ENABLE_NODE_AUTO_INSTALL:-0}" == "1" ]]; then
    warn "bunx shim did not recover opencode. Trying Node.js + npm global install..."
    if ensure_nodejs_runtime && install_opencode_npm_global && opencode_works; then
      return 0
    fi
  else
    warn "Skipping Node.js auto-install fallback (set OCS_ENABLE_NODE_AUTO_INSTALL=1 to enable)."
  fi

  return 1
}

ensure_nodejs_runtime() {
  ensure_node_runtime_paths

  if command_is_usable_local_runtime node && command_is_usable_local_runtime npm && local_node_runtime_meets_minimum; then
    return 0
  fi

  local pm
  pm="$(detect_package_manager)"
  [[ -n "$pm" ]] || return 1

  info "Attempting to auto-install Node.js runtime via ${pm}..."
  case "$pm" in
    apt)
      install_nodesource_node_runtime || return 1
      ;;
    dnf|yum|zypper|apk)
      install_packages_auto "$pm" nodejs npm || return 1
      ;;
    pacman)
      install_packages_auto "$pm" nodejs npm || return 1
      ;;
    brew)
      install_packages_auto "$pm" node || return 1
      ;;
    *)
      return 1
      ;;
  esac

  ensure_node_runtime_paths
  command_is_usable_local_runtime node && command_is_usable_local_runtime npm && local_node_runtime_meets_minimum
}

ensure_nodejs_runtime_or_stop() {
  report_rejected_cross_os_node_tools

  if ensure_nodejs_runtime; then
    return 0
  fi

  local pm
  pm="$(detect_package_manager)"
  if [[ -z "$pm" ]]; then
    error_missing_supported_package_manager "native Node.js runtime"
  fi

  local packages
  packages="$(resolve_node_runtime_packages "${pm}")"
  [[ -n "${packages}" ]] || packages="nodejs npm"
  local detected_node_version
  detected_node_version="$(resolve_local_node_version 2>/dev/null || true)"
  if [[ -n "${detected_node_version}" ]]; then
    error "Failed to provision a supported native Node.js runtime via ${pm}. Detected native node ${detected_node_version}, but install.sh requires Node >=$(required_node_major_version) before setup can continue."
  fi
  error_package_manager_bootstrap_failure "$pm" "native Node.js runtime" "${packages}"
}

ensure_pnpm_runtime() {
  ensure_node_runtime_paths

  local pnpm_version
  local pnpm_log="/tmp/ocs-pnpm-install.log"
  local pnpm_cmd
  local npm_cmd
  local corepack_cmd
  if [[ "${OCS_ENABLE_PNPM_AUTO_INSTALL:-1}" != "1" ]]; then
    warn "pnpm auto-install disabled (set OCS_ENABLE_PNPM_AUTO_INSTALL=1 to enable)."
    return 1
  fi

  if command_is_usable_local_runtime pnpm; then
    pnpm_cmd="$(resolve_local_runtime_command_path pnpm 2>/dev/null || true)"
    pnpm_version="$(${pnpm_cmd} --version 2>/dev/null || true)"
    info "pnpm already available: ${pnpm_version:-unknown version}."
    return 0
  fi

  if ! command_is_usable_local_runtime node || ! command_is_usable_local_runtime npm || ! local_node_runtime_meets_minimum; then
    info "Native Node.js runtime incomplete. Repairing node/npm before pnpm bootstrap..."
    if ! ensure_nodejs_runtime; then
      warn "Native Node.js runtime unavailable; pnpm auto-install skipped."
      return 1
    fi
    ensure_node_runtime_paths
  fi

  rm -f "$pnpm_log" >/dev/null 2>&1 || true

  if command_is_usable_local_runtime corepack; then
    corepack_cmd="$(resolve_local_runtime_command_path corepack 2>/dev/null || true)"
    info "Enabling pnpm via corepack..."
    if "${corepack_cmd}" enable pnpm >>"$pnpm_log" 2>&1; then
      "${corepack_cmd}" prepare pnpm@10 --activate >>"$pnpm_log" 2>&1 || true
    else
      warn "corepack enable pnpm failed. See $pnpm_log for details."
    fi

    if command_is_usable_local_runtime pnpm; then
      pnpm_cmd="$(resolve_local_runtime_command_path pnpm 2>/dev/null || true)"
      pnpm_version="$(${pnpm_cmd} --version 2>/dev/null || true)"
      success "pnpm ${pnpm_version:-available via corepack}."
      return 0
    fi
  fi

  if command_is_usable_local_runtime npm; then
    npm_cmd="$(resolve_local_runtime_command_path npm 2>/dev/null || true)"
    info "Installing pnpm via npm global install..."
    ensure_native_npm_user_prefix
    if env NPM_CONFIG_PREFIX="${NPM_CONFIG_PREFIX}" npm_config_prefix="${npm_config_prefix}" "${npm_cmd}" install -g pnpm@10 >>"$pnpm_log" 2>&1; then
      ensure_node_runtime_paths
      if command_is_usable_local_runtime pnpm; then
        pnpm_cmd="$(resolve_local_runtime_command_path pnpm 2>/dev/null || true)"
        pnpm_version="$(${pnpm_cmd} --version 2>/dev/null || true)"
        ensure_native_node_tool_shims
        ensure_shell_path_priority
        source_shell_path_priority
        success "pnpm ${pnpm_version:-installed via npm}."
        return 0
      fi
    else
      warn "npm install -g pnpm failed. See $pnpm_log for details."
    fi
  else
    warn "npm command not available; pnpm auto-install skipped."
  fi

  if command_is_usable_local_runtime pnpm; then
    pnpm_cmd="$(resolve_local_runtime_command_path pnpm 2>/dev/null || true)"
    pnpm_version="$(${pnpm_cmd} --version 2>/dev/null || true)"
    success "pnpm ${pnpm_version:-available}."
    return 0
  fi

  warn "pnpm still unavailable after auto-install attempts. Plugin tests may need pnpm installed manually."
  return 1
}

ensure_pnpm_runtime_or_stop() {
  if ensure_pnpm_runtime; then
    return 0
  fi

  local pm
  pm="$(detect_package_manager)"
  if [[ -z "$pm" ]]; then
    error_missing_supported_package_manager "pnpm runtime bootstrap"
  fi

  error_pnpm_runtime_bootstrap_failure "$pm"
}

ensure_posix_bootstrap_prerequisites() {
  ensure_nodejs_runtime_or_stop
  ensure_pnpm_runtime || true
  ensure_pnpm_runtime_or_stop
  ensure_shell_path_priority
  source_shell_path_priority
}

install_opencode_npm_global() {
  command_is_usable_local_runtime npm || return 1
  local npm_cmd
  npm_cmd="$(resolve_local_runtime_command_path npm 2>/dev/null || true)"

  info "Installing opencode-ai globally via npm..."
  if ! "${npm_cmd}" install -g opencode-ai@latest >/tmp/ocs-opencode-npm.err 2>&1; then
    warn "$(cat /tmp/ocs-opencode-npm.err 2>/dev/null || true)"
    return 1
  fi

  local npm_prefix
  npm_prefix="$("${npm_cmd}" config get prefix 2>/dev/null || true)"
  if [[ -n "$npm_prefix" && -d "$npm_prefix/bin" ]]; then
    export PATH="$npm_prefix/bin:${PATH}"
  fi
  hash -r 2>/dev/null || true
  opencode_works
}

install_bun_global_with_retry() {
  local source_path="$1"
  local attempts=5
  local i
  local bun_cmd

  bun_cmd="$(resolve_local_runtime_command_path bun 2>/dev/null || true)"
  [[ -n "${bun_cmd}" ]] || return 1

  for ((i=1; i<=attempts; i++)); do
    start_progress_narration "install" "dependency-install" || true
    if "${bun_cmd}" install -g "$source_path" >/tmp/ocs-bun-global.err 2>&1; then
      stop_progress_narration
      return 0
    fi
    stop_progress_narration

    local err
    err="$(cat /tmp/ocs-bun-global.err 2>/dev/null || true)"

    if (( i < attempts )); then
      warn "bun global install failed (attempt ${i}/${attempts}), retrying..."
      if is_lock_error "$err"; then
        stop_windows_lock_holders
      fi
      sleep "$i"
      continue
    fi

    warn "$err"
    return 1
  done

  return 1
}

install_ocs_from_path() {
  local source_path="$1"
  [[ -n "$source_path" && -d "$source_path" ]] || return 1
  info "Attempting ocs install from local path..."

  if install_bun_global_with_retry "$source_path"; then
    if [[ -d "${HOME}/.bun/bin" ]]; then
      export PATH="${HOME}/.bun/bin:${PATH}"
    fi
    ocs_works && return 0
  fi

  if command_is_usable_local_runtime npm; then
    local npm_cmd
    npm_cmd="$(resolve_local_runtime_command_path npm 2>/dev/null || true)"
    warn "bun global install failed, trying npm global install..."
    if "${npm_cmd}" install -g "$source_path" >/tmp/ocs-npm-global.err 2>&1; then
      if [[ -d "${HOME}/.bun/bin" ]]; then
        export PATH="${HOME}/.bun/bin:${PATH}"
      fi
      ocs_works && return 0
    else
      warn "$(cat /tmp/ocs-npm-global.err 2>/dev/null || true)"
    fi
  fi

  if command_is_usable_local_runtime pnpm; then
    local pnpm_cmd
    pnpm_cmd="$(resolve_local_runtime_command_path pnpm 2>/dev/null || true)"
    warn "npm fallback unavailable/failed, trying pnpm global install..."
    if "${pnpm_cmd}" add -g "$source_path" >/tmp/ocs-pnpm-global.err 2>&1; then
      if [[ -d "${HOME}/.bun/bin" ]]; then
        export PATH="${HOME}/.bun/bin:${PATH}"
      fi
      ocs_works && return 0
    else
      warn "$(cat /tmp/ocs-pnpm-global.err 2>/dev/null || true)"
    fi
  fi

  return 1
}

install_ocs_from_private_repo() {
  local token="$1"
  [[ -n "$token" ]] || return 1
  command -v git >/dev/null 2>&1 || return 1

  local suite_tmp="${TMP_DIR}/opencode-config-suites"
  rm -rf "$suite_tmp"
  info "Attempting ocs install from private repository source..."
  git clone --branch "${GITHUB_SOURCE_BRANCH}" --single-branch "https://x-access-token:${token}@github.com/${GITHUB_SOURCE_REPO}.git" "$suite_tmp" >/dev/null 2>&1 || return 1
  install_ocs_from_path "$suite_tmp"
}

open_purchase_page() {
  echo "  Open purchase chat: ${WHATSAPP_ORDER_URL}"
  if command -v open >/dev/null 2>&1; then
    open "${WHATSAPP_ORDER_URL}" >/dev/null 2>&1 || true
    return
  fi
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "${WHATSAPP_ORDER_URL}" >/dev/null 2>&1 || true
    return
  fi
}

install_ocs_shim_from_bundle() {
  local plugin_path="$1"
  local root_path="${2:-}"
  local ocs_js=""
  local candidate
  local candidates=(
    "${plugin_path}/bin/ocs.cjs"
    "${plugin_path}/bin/ocs.js"
    "${root_path}/bin/ocs.cjs"
    "${root_path}/bin/ocs.js"
  )

  if [[ -z "$root_path" ]]; then
    candidates=(
      "${plugin_path}/bin/ocs.cjs"
      "${plugin_path}/bin/ocs.js"
    )
  fi

  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      ocs_js="$candidate"
      break
    fi
  done

  [[ -f "$ocs_js" ]] || return 1

  local bun_bin="${HOME}/.bun/bin"
  local local_bin="${HOME}/.local/bin"
  local bun_exec="${HOME}/.bun/bin/bun"
  mkdir -p "$bun_bin" "$local_bin"

cat > "${bun_bin}/ocs" <<EOF
#!/usr/bin/env bash
set -e

BUN_EXEC="$bun_exec"
[[ -x "\${BUN_EXEC}" ]] || BUN_EXEC="bun"

resolve_windows_ocs_entry() {
  local cmd_path
  while IFS= read -r cmd_path; do
    [[ -f "\${cmd_path}" ]] || continue
    local line
    line=\$(sed -n '2p' "\${cmd_path}" 2>/dev/null || true)
    [[ -n "\${line}" ]] || continue
    local win_path
    win_path=\$(printf '%s' "\${line}" | sed -n 's/^bun "\\(.*\\)" %\\*$/\\1/p')
    [[ -n "\${win_path}" ]] || continue
    local wsl_path
    wsl_path=\$(wslpath -u "\${win_path}" 2>/dev/null || true)
    if [[ -n "\${wsl_path}" && -f "\${wsl_path}" ]]; then
      printf '%s\n' "\${wsl_path}"
      return 0
    fi
  done < <(find /mnt/c/Users -maxdepth 3 -type f -path '*/.bun/bin/ocs.cmd' 2>/dev/null)
  return 1
}

CANDIDATES=(
  "$ocs_js"
  "$OCS_CLI_CJS_PATH"
  "$OCS_CLI_JS_PATH"
  "$PLUGIN_OCS_CLI_CJS_PATH"
  "$PLUGIN_OCS_CLI_JS_PATH"
)

for candidate in "\${CANDIDATES[@]}"; do
  if [[ -f "\${candidate}" ]]; then
    exec "\${BUN_EXEC}" "\${candidate}" "\$@"
  fi
done

if win_entry=\$(resolve_windows_ocs_entry); then
  exec "\${BUN_EXEC}" "\${win_entry}" "\$@"
fi

echo "error: cannot resolve ocs entrypoint (checked local config and Windows bun launcher)" >&2
exit 1
EOF
  chmod +x "${bun_bin}/ocs"

cat > "${local_bin}/ocs" <<EOF
#!/usr/bin/env bash
set -e

BUN_EXEC="$bun_exec"
[[ -x "\${BUN_EXEC}" ]] || BUN_EXEC="bun"

resolve_windows_ocs_entry() {
  local cmd_path
  while IFS= read -r cmd_path; do
    [[ -f "\${cmd_path}" ]] || continue
    local line
    line=\$(sed -n '2p' "\${cmd_path}" 2>/dev/null || true)
    [[ -n "\${line}" ]] || continue
    local win_path
    win_path=\$(printf '%s' "\${line}" | sed -n 's/^bun "\\(.*\\)" %\\*$/\\1/p')
    [[ -n "\${win_path}" ]] || continue
    local wsl_path
    wsl_path=\$(wslpath -u "\${win_path}" 2>/dev/null || true)
    if [[ -n "\${wsl_path}" && -f "\${wsl_path}" ]]; then
      printf '%s\n' "\${wsl_path}"
      return 0
    fi
  done < <(find /mnt/c/Users -maxdepth 3 -type f -path '*/.bun/bin/ocs.cmd' 2>/dev/null)
  return 1
}

CANDIDATES=(
  "$ocs_js"
  "$OCS_CLI_CJS_PATH"
  "$OCS_CLI_JS_PATH"
  "$PLUGIN_OCS_CLI_CJS_PATH"
  "$PLUGIN_OCS_CLI_JS_PATH"
)

for candidate in "\${CANDIDATES[@]}"; do
  if [[ -f "\${candidate}" ]]; then
    exec "\${BUN_EXEC}" "\${candidate}" "\$@"
  fi
done

if win_entry=\$(resolve_windows_ocs_entry); then
  exec "\${BUN_EXEC}" "\${win_entry}" "\$@"
fi

echo "error: cannot resolve ocs entrypoint (checked local config and Windows bun launcher)" >&2
exit 1
EOF
  chmod +x "${local_bin}/ocs"

  export PATH="${bun_bin}:${local_bin}:${PATH}"
  hash -r 2>/dev/null || true

  ocs_works
}

resolve_runtime_ocs_entry() {
  local candidate
  local candidates=(
    "$OCS_CLI_CJS_PATH"
    "$OCS_CLI_JS_PATH"
    "$PLUGIN_OCS_CLI_CJS_PATH"
    "$PLUGIN_OCS_CLI_JS_PATH"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  local cmd_path
  while IFS= read -r cmd_path; do
    [[ -f "${cmd_path}" ]] || continue
    local line
    line=$(sed -n '2p' "${cmd_path}" 2>/dev/null || true)
    [[ -n "${line}" ]] || continue
    local win_path
    win_path=$(printf '%s' "${line}" | sed -n 's/^bun "\(.*\)" %\*$/\1/p')
    [[ -n "${win_path}" ]] || continue
    local wsl_path
    wsl_path=$(wslpath -u "${win_path}" 2>/dev/null || true)
    if [[ -n "${wsl_path}" && -f "${wsl_path}" ]]; then
      printf '%s\n' "${wsl_path}"
      return 0
    fi
  done < <(find /mnt/c/Users -maxdepth 3 -type f -path '*/.bun/bin/ocs.cmd' 2>/dev/null)

  return 1
}

install_ocs_shim_from_opencode() {
  local bun_exec="${HOME}/.bun/bin/bun"
  local ocs_js=""
  local shim_cmd=""

  if ! ocs_js="$(resolve_runtime_ocs_entry)"; then
    warn "Unable to repair ocs shim because no OCS entrypoint was found."
    return 1
  fi

  if [[ -x "$bun_exec" ]]; then
    printf -v shim_cmd '"%s" "%s" "$@"' "$bun_exec" "$ocs_js"
  else
    printf -v shim_cmd 'bun "%s" "$@"' "$ocs_js"
  fi

  local bun_bin="${HOME}/.bun/bin"
  local local_bin="${HOME}/.local/bin"
  mkdir -p "$bun_bin" "$local_bin"

cat > "${bun_bin}/ocs" <<EOF
#!/usr/bin/env bash
${shim_cmd}
EOF
  chmod +x "${bun_bin}/ocs"

cat > "${local_bin}/ocs" <<EOF
#!/usr/bin/env bash
${shim_cmd}
EOF
  chmod +x "${local_bin}/ocs"

  export PATH="${bun_bin}:${local_bin}:${PATH}"
  hash -r 2>/dev/null || true
  ocs_works
}

ensure_ocs_command() {
  local token="$1"
  local root_dir="$2"
  local is_local_source="$3"
  local plugin_dir="$4"

  if [[ -d "${HOME}/.bun/bin" ]]; then
    export PATH="${HOME}/.bun/bin:${PATH}"
  fi

  if [[ "$is_local_source" == "true" ]]; then
    if install_ocs_shim_from_bundle "$plugin_dir" "$root_dir"; then
      success "ocs shim refreshed from local source and verification passed."
      return 0
    fi
  fi

  if install_ocs_shim_from_opencode; then
    success "ocs shim refreshed from installed runtime and verification passed."
    return 0
  fi

  if install_ocs_shim_from_bundle "$plugin_dir" "$root_dir"; then
    success "ocs shim install and verification passed."
    return 0
  fi

  if ocs_works; then
    info "ocs verification passed."
    return 0
  fi

  if [[ "$is_local_source" == "true" ]]; then
    if install_ocs_from_path "$root_dir"; then
      success "ocs auto-install and verification passed."
      return 0
    fi
  fi

  if install_ocs_from_private_repo "$token"; then
    success "ocs auto-install and verification passed."
    return 0
  fi

  return 1
}

ensure_shell_path_priority() {
  local snippet_dir="${SHELL_SNIPPET_DIR}"
  local snippet_path="${SHELL_SNIPPET_PATH}"
  local profile
  local shell_name
  shell_name="$(resolve_shell_name)"
  local profile
  local base_entries=(
    "${NATIVE_BIN_DIR}"
    "${LOCAL_BIN_DIR}"
    "${HOME}/.local/pipx/bin"
    "${HOME}/.local/share/uv/tools/bin"
    "${HOME}/.bun/bin"
  )
  local dynamic_entries=()
  local entry

  while IFS= read -r entry; do
    dynamic_entries+=("$entry")
  done < <(collect_node_bin_entries)

  local combined_entries=("${base_entries[@]}" "${dynamic_entries[@]}")
  local unique_entries=()

  for entry in "${combined_entries[@]}"; do
    [[ -z "$entry" ]] && continue
    entry="$(normalize_path_entry "$entry")"
    [[ -z "$entry" ]] && continue
    local already_seen=""
    for existing in "${unique_entries[@]}"; do
      if [[ "${existing}" == "${entry}" ]]; then
        already_seen="1"
        break
      fi
    done
    [[ -n "${already_seen}" ]] && continue
    unique_entries+=("$entry")
  done

  local path_prefix=""
  for entry in "${unique_entries[@]}"; do
    if [[ -z "$path_prefix" ]]; then
      path_prefix="$entry"
    else
      path_prefix="${path_prefix}:$entry"
    fi
  done

  local export_line
  if [[ -n "$path_prefix" ]]; then
    export_line="export PATH=\"${path_prefix}:\$PATH\""
    export PATH="${path_prefix}:${PATH}"
  else
    export_line='export PATH="\$PATH"'
  fi
  hash -r 2>/dev/null || true

  local source_line="[ -f \"${snippet_path}\" ] && . \"${snippet_path}\""

  mkdir -p "${snippet_dir}" 2>/dev/null || true
  if ! ensure_text_file_exists_if_writable "${snippet_path}"; then
    warn "Cannot persist shell PATH snippet at ${snippet_path}. Keep using current-session PATH export only."
  else
    printf '# OCS installer path\n%s\n' "${export_line}" > "${snippet_path}"
  fi

  while IFS= read -r profile; do
    [[ -n "${profile}" ]] || continue
    if ensure_text_file_exists_if_writable "${profile}"; then
      if profile_contains_ocs_path_source "${profile}"; then
        rewrite_ocs_path_source_lines "${profile}" "${source_line}"
      else
        printf '\n# OCS installer path\n%s\n' "${source_line}" >> "${profile}"
      fi
    else
      warn "Cannot write to shell profile ${profile}. Current-session PATH is active, but persistence was skipped."
    fi
  done < <(resolve_supported_shell_profiles)
}

source_shell_path_priority() {
  local shell_snippet="${SHELL_SNIPPET_PATH}"
  if [[ -f "$shell_snippet" ]]; then
    # shellcheck disable=SC1090
    source "$shell_snippet" >/dev/null 2>&1 || true
    hash -r 2>/dev/null || true
  fi
}

resolve_python_command_for_agents() {
  if command -v python3 >/dev/null 2>&1; then
    printf '%s\n' "python3"
    return 0
  fi

  if command -v python >/dev/null 2>&1; then
    printf '%s\n' "python"
    return 0
  fi

  printf '%s\n' ""
}

ensure_agent_dependency_runtime() {
  info "Checking agent runtime dependencies (Python + PATH parity)..."

  ensure_node_runtime_paths

  local python_cmd
  python_cmd="$(resolve_python_command_for_agents)"

  if [[ -z "${python_cmd}" ]]; then
    warn "Python runtime not found. Attempting automatic install..."
    local pm
    pm="$(detect_package_manager)"

    case "$pm" in
      apt)
        install_packages_auto "$pm" python3 python3-pip python3-venv || true
        ;;
      dnf|yum)
        install_packages_auto "$pm" python3 python3-pip || true
        ;;
      pacman)
        install_packages_auto "$pm" python python-pip || true
        ;;
      zypper)
        install_packages_auto "$pm" python311 python311-pip || install_packages_auto "$pm" python3 python3-pip || true
        ;;
      apk)
        install_packages_auto "$pm" python3 py3-pip || true
        ;;
      brew)
        install_packages_auto "$pm" python || true
        ;;
      *)
        warn "No supported package manager available for Python auto-install."
        ;;
    esac

    python_cmd="$(resolve_python_command_for_agents)"
  fi

  if [[ -n "${python_cmd}" ]]; then
    local python_version
    python_version="$("${python_cmd}" --version 2>/dev/null || true)"
    if [[ -n "${python_version}" ]]; then
      info "Python runtime ready: ${python_version}"
    fi

    if ! "${python_cmd}" -m pip --version >/dev/null 2>&1; then
      warn "pip missing for ${python_cmd}. Attempting ensurepip..."
      "${python_cmd}" -m ensurepip --upgrade >/dev/null 2>&1 || true
    fi

    if ! command -v pipx >/dev/null 2>&1; then
      info "pipx not found. Attempting user install for agent tooling..."
      "${python_cmd}" -m pip install --user -U pipx >/dev/null 2>&1 || true
    fi
  else
    warn "Python runtime still unavailable. CocoIndex auto-bootstrap may be skipped."
  fi

  ensure_pnpm_command || true

  export PATH="${HOME}/.opencode/bin:${HOME}/.local/bin:${HOME}/.local/pipx/bin:${HOME}/.local/share/uv/tools/bin:${HOME}/.bun/bin:${PATH}"
  hash -r 2>/dev/null || true
}

ensure_pnpm_command() {
  if command_is_usable_local_runtime pnpm; then
    info "pnpm already available."
    return 0
  fi

  info "pnpm not found. Bootstrapping pnpm via corepack/npm..."
  local bootstraped=false
  local npm_cmd=""
  local pnpm_cmd=""
  local corepack_cmd=""
  if command_is_usable_local_runtime corepack; then
    corepack_cmd="$(resolve_local_runtime_command_path corepack 2>/dev/null || true)"
    if [[ -n "${corepack_cmd}" ]]; then
      "${corepack_cmd}" enable >/tmp/ocs-corepack-enable.err 2>&1 || true
    fi
    if [[ -n "${corepack_cmd}" ]] && "${corepack_cmd}" prepare pnpm@10 --activate >/tmp/ocs-corepack-pnpm.err 2>&1; then
      bootstraped=true
    else
      warn "corepack pnpm preparation failed: $(cat /tmp/ocs-corepack-pnpm.err 2>/dev/null || true)"
    fi
  fi

  if [[ "${bootstraped}" != "true" ]] && command_is_usable_local_runtime npm; then
    npm_cmd="$(resolve_local_runtime_command_path npm 2>/dev/null || true)"
    info "Attempting npm install -g pnpm..."
    ensure_native_npm_user_prefix
    if [[ -n "${npm_cmd}" ]] && env NPM_CONFIG_PREFIX="${NPM_CONFIG_PREFIX}" npm_config_prefix="${npm_config_prefix}" "${npm_cmd}" install -g pnpm@10 >/tmp/ocs-pnpm-npm.err 2>&1; then
      local npm_prefix
      npm_prefix="$("${npm_cmd}" config get prefix 2>/dev/null || true)"
      if [[ -n "${npm_prefix}" && -d "${npm_prefix}/bin" ]]; then
        export PATH="${npm_prefix}/bin:${PATH}"
      fi
      ensure_node_runtime_paths
      hash -r 2>/dev/null || true
      bootstraped=true
    else
      warn "npm install -g pnpm failed: $(cat /tmp/ocs-pnpm-npm.err 2>/dev/null || true)"
    fi
  fi

  if command_is_usable_local_runtime pnpm; then
    pnpm_cmd="$(resolve_local_runtime_command_path pnpm 2>/dev/null || true)"
    if [[ -n "${pnpm_cmd}" ]]; then
      "${pnpm_cmd}" --version >/dev/null 2>&1 || true
    fi
    ensure_native_node_tool_shims
    ensure_shell_path_priority
    source_shell_path_priority
    success "pnpm ready for agent/tooling workflows."
    return 0
  fi

  warn "pnpm remains unavailable after auto-bootstrap attempts. Manual install may be required."
  return 1
}

ensure_system_command_links() {
  local target_dir="/usr/local/bin"
  local cmd source_path target_path current_target

  for cmd in ocs opencode; do
    source_path=""
    if [[ -x "${HOME}/.local/bin/${cmd}" ]]; then
      source_path="${HOME}/.local/bin/${cmd}"
    elif [[ -x "${HOME}/.bun/bin/${cmd}" ]]; then
      source_path="${HOME}/.bun/bin/${cmd}"
    fi

    [[ -n "${source_path}" ]] || continue
    target_path="${target_dir}/${cmd}"

    if [[ -e "${target_path}" && ! -L "${target_path}" ]]; then
      continue
    fi

    if [[ -L "${target_path}" ]]; then
      current_target="$(readlink "${target_path}" 2>/dev/null || true)"
      if [[ "${current_target}" == "${source_path}" ]]; then
        continue
      fi
    fi

    if [[ -w "${target_dir}" ]]; then
      ln -sfn "${source_path}" "${target_path}" || true
    elif run_with_privilege mkdir -p "${target_dir}" && run_with_privilege ln -sfn "${source_path}" "${target_path}"; then
      :
    else
      info "Cannot create ${target_path}. Continuing with shell profile PATH entries."
    fi
  done

  hash -r 2>/dev/null || true
}

resolve_supported_cocoindex_python() {
  local candidate

  for candidate in python3.13 python3.12 python3.11 python3 python; do
    command -v "${candidate}" >/dev/null 2>&1 || continue
    if "${candidate}" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)' >/dev/null 2>&1; then
      command -v "${candidate}"
      return 0
    fi
  done

  return 1
}

repair_recursive_cocoindex_shim() {
  local local_ccc="${HOME}/.local/bin/ccc"
  local system_ccc="/usr/local/bin/ccc"
  local current_target=""
  local python_cmd=""

  if [[ -L "${system_ccc}" ]]; then
    current_target="$(readlink "${system_ccc}" 2>/dev/null || true)"
    if [[ "${current_target}" == "${local_ccc}" ]]; then
      if [[ -w "$(dirname "${system_ccc}")" ]]; then
        rm -f "${system_ccc}" || true
      elif run_with_privilege rm -f "${system_ccc}"; then
        :
      else
        info "Cannot remove recursive ${system_ccc} system link automatically. Continuing with local shim repair."
      fi
    fi
  fi

  if [[ ! -f "${local_ccc}" ]]; then
    return 0
  fi

  if ! grep -Fq 'exec "/usr/local/bin/ccc" "$@"' "${local_ccc}" && \
     ! grep -Fq "exec \"${local_ccc}\" \"\$@\"" "${local_ccc}"; then
    return 0
  fi

  python_cmd="$(resolve_supported_cocoindex_python || true)"
  if [[ -z "${python_cmd}" ]]; then
    warn "Unable to repair recursive ccc shim automatically because Python 3.11+ is unavailable."
    return 1
  fi

  mkdir -p "${HOME}/.local/bin"
  cat > "${local_ccc}" <<EOF
#!/bin/sh
exec "${python_cmd}" -m cocoindex_code.cli "\$@"
EOF
  chmod +x "${local_ccc}"
  hash -r 2>/dev/null || true
  success "Repaired recursive local ccc shim to use ${python_cmd}."
}

is_lock_error() {
  local msg="$1"
  [[ "$msg" =~ EBUSY|EFAULT|EPERM|ENOENT|resource\ busy|being\ used\ by\ another\ process|Access\ is\ denied ]]
}

hash_file_sha256() {
  local file_path="$1"

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file_path" | awk '{print $1}'
    return 0
  fi

  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file_path" | awk '{print $1}'
    return 0
  fi

  return 1
}

compute_dependency_fingerprint() {
  local install_dir="$1"
  local files=(
    "package.json"
    "bun.lock"
    "bun.lockb"
    "bunfig.toml"
    "package-lock.json"
    "pnpm-lock.yaml"
    "yarn.lock"
  )
  local file
  local full_path
  local hash_value
  local parts=()

  for file in "${files[@]}"; do
    full_path="${install_dir}/${file}"
    if [[ -f "$full_path" ]]; then
      hash_value="$(hash_file_sha256 "$full_path" 2>/dev/null || true)"
      [[ -n "$hash_value" ]] || continue
      parts+=("${file}:${hash_value}")
    fi
  done

  if [[ ${#parts[@]} -eq 0 ]]; then
    return 1
  fi

  printf '%s\n' "${parts[@]}"
}

stop_windows_lock_holders() {
  if ! command -v powershell >/dev/null 2>&1; then
    return 0
  fi

  powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Process bun,node,opencode,biome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue" >/dev/null 2>&1 || true
}

install_dependencies_with_retry() {
  local install_dir="$1"
  local attempts=5
  local i
  local marker_dir="${install_dir}/.ocs-install-state"
  local marker_file="${marker_dir}/bun-install.fingerprint"
  local current_fingerprint=""

  current_fingerprint="$(compute_dependency_fingerprint "$install_dir" 2>/dev/null || true)"
  if [[ -n "$current_fingerprint" && -d "${install_dir}/node_modules" && -f "$marker_file" ]]; then
    local previous_fingerprint
    previous_fingerprint="$(cat "$marker_file" 2>/dev/null || true)"
    if [[ "$previous_fingerprint" == "$current_fingerprint" ]]; then
      info "Dependency fingerprint unchanged. Skipping bun install in ${install_dir}."
      return 0
    fi
  fi

  for ((i=1; i<=attempts; i++)); do
    start_progress_narration "install" "dependency-install" || true
    if bun install --frozen-lockfile >/dev/null 2>&1; then
      stop_progress_narration
      local new_fingerprint
      new_fingerprint="$(compute_dependency_fingerprint "$install_dir" 2>/dev/null || true)"
      if [[ -n "$new_fingerprint" ]]; then
        mkdir -p "$marker_dir"
        printf '%s' "$new_fingerprint" >"$marker_file"
      fi
      return 0
    fi
    stop_progress_narration

    start_progress_narration "install" "dependency-install" || true
    if bun install >/tmp/ocs-bun-install.err 2>&1; then
      stop_progress_narration
      local new_fingerprint
      new_fingerprint="$(compute_dependency_fingerprint "$install_dir" 2>/dev/null || true)"
      if [[ -n "$new_fingerprint" ]]; then
        mkdir -p "$marker_dir"
        printf '%s' "$new_fingerprint" >"$marker_file"
      fi
      return 0
    fi
    stop_progress_narration

    local err
    err="$(cat /tmp/ocs-bun-install.err 2>/dev/null || true)"

    if (( i < attempts )); then
      warn "bun install failed (attempt ${i}/${attempts}), retrying..."
      if is_lock_error "$err"; then
        stop_windows_lock_holders "$install_dir"
      fi
      sleep "$i"
      continue
    fi

    warn "$err"
    return 1
  done

  return 1
}

has_interactive_tty() {
  [[ -r /dev/tty && -w /dev/tty ]]
}

ensure_gh_cli_for_oauth() {
  if command -v gh >/dev/null 2>&1; then
    return 0
  fi

  if ! has_interactive_tty; then
    return 1
  fi

  local pm
  pm="$(detect_package_manager)"
  if [[ -z "$pm" ]]; then
    warn "Cannot auto-install gh: no supported package manager detected."
    return 1
  fi

  info "GitHub CLI (gh) not found. Attempting auto-install via ${pm} for OAuth login..."
  if install_packages_auto "$pm" gh; then
    success "GitHub CLI installed."
    return 0
  fi

  warn "Failed to auto-install gh."
  return 1
}

gh_supports_auth_token() {
  command -v gh >/dev/null 2>&1 || return 1
  gh auth token --help </dev/null >/dev/null 2>&1
}

upgrade_gh_cli_for_oauth() {
  command -v gh >/dev/null 2>&1 || return 1
  gh_supports_auth_token && return 0
  has_interactive_tty || return 1

  local pm
  pm="$(detect_package_manager)"
  if [[ -z "$pm" ]]; then
    warn "gh is installed but too old for 'gh auth token', and no supported package manager was detected for auto-upgrade."
    return 1
  fi

  info "GitHub CLI is installed but missing 'gh auth token'. Attempting auto-upgrade via ${pm}..."
  if install_packages_auto "$pm" gh && gh_supports_auth_token; then
    success "GitHub CLI upgraded with token support."
    return 0
  fi

  warn "gh auto-upgrade did not add 'gh auth token'. Continuing with existing authenticated gh session if available."
  return 1
}

get_gh_token_if_supported() {
  gh_supports_auth_token || return 1
  local token=""
  token="$(gh auth token </dev/null 2>/dev/null || true)"
  token="$(printf '%s' "$token" | tr -d '\r\n')"
  [[ -n "$token" ]] || return 1
  printf '%s' "$token"
}

print_gh_auth_terminal_guide() {
  warn "Run this command in terminal, then rerun installer:"
  warn "gh auth login"
  warn "Then choose: GitHub.com -> HTTPS -> Yes -> Login with a web browser"
  warn "If browser auto-open fails (WSL), open shown URL manually and finish login"
  warn "Optional hardening: gh auth refresh -h github.com -s repo"
  if ! command -v gh >/dev/null 2>&1; then
    warn "Install GitHub CLI first: https://cli.github.com/"
  fi
}

refresh_gh_repo_scope() {
  has_interactive_tty || return 1

  if gh auth login >/dev/null 2>&1; then
    gh config set -h github.com git_protocol https >/dev/null 2>&1 || true
    gh auth refresh -h github.com -s repo >/dev/null 2>&1 || true
    return 0
  fi

  if gh auth refresh -h github.com -s repo >/dev/null 2>&1; then
    gh config set -h github.com git_protocol https >/dev/null 2>&1 || true
    return 0
  fi

  gh auth login >/dev/null 2>&1 || return 1
  gh config set -h github.com git_protocol https >/dev/null 2>&1 || true
  gh auth refresh -h github.com -s repo >/dev/null 2>&1 || true
  return 0
}

# ─── Auth: resolve GitHub token ───────────────────────────────────────────────
resolve_token() {
  # Path 1: GITHUB_TOKEN env var
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    echo "  Auth: using GITHUB_TOKEN environment variable" >&2
    printf '%s' "${GITHUB_TOKEN}" | tr -d '\r\n'
    return 0
  fi

  # Path 2: stored token file
  if [[ -f "${TOKEN_FILE}" ]]; then
    local stored_token
    stored_token="$(cat "${TOKEN_FILE}")"
    if [[ -n "${stored_token}" ]]; then
      echo "  Auth: using stored token from ${TOKEN_FILE}" >&2
      printf '%s' "${stored_token}" | tr -d '\r\n'
      return 0
    fi
  fi

  # Path 3: OAuth via gh CLI
  if command -v gh >/dev/null 2>&1 || ensure_gh_cli_for_oauth; then
    upgrade_gh_cli_for_oauth >/dev/null 2>&1 || true
    if gh auth status </dev/null >/dev/null 2>&1; then
      GH_TOKEN="$(get_gh_token_if_supported 2>/dev/null || true)"
      if [[ -n "${GH_TOKEN}" ]]; then
        echo "  Auth: using gh CLI token" >&2
        printf '%s' "${GH_TOKEN}" | tr -d '\r\n'
        return 0
      fi
      echo "  Auth: using existing gh CLI session" >&2
      printf '%s' ""
      return 0
    elif has_interactive_tty; then
      warn "GitHub CLI (gh) is installed but not authenticated."
      info "Opening OAuth login in browser..."
      if gh auth login </dev/null; then
        gh config set -h github.com git_protocol https </dev/null >/dev/null 2>&1 || true
        GH_TOKEN="$(get_gh_token_if_supported 2>/dev/null || true)"
        if [[ -n "${GH_TOKEN}" ]]; then
          echo "  Auth: using gh CLI token" >&2
          printf '%s' "${GH_TOKEN}" | tr -d '\r\n'
          return 0
        fi
        if gh auth status </dev/null >/dev/null 2>&1; then
          echo "  Auth: using existing gh CLI session" >&2
          printf '%s' ""
          return 0
        fi
      else
        warn "gh OAuth login failed."
      fi
    fi
  fi

  if ! has_interactive_tty; then
    error "No GitHub token found in non-interactive session. Export GITHUB_TOKEN and rerun."
  fi

  print_gh_auth_terminal_guide
  error "No GitHub auth available. Complete gh login first, then rerun installer."
}

# ─── Verify repo access ───────────────────────────────────────────────────────
verify_access() {
  local token="$1"
  token="$(printf '%s' "$token" | tr -d '\r\n')"

  if command -v gh >/dev/null 2>&1; then
    if GH_TOKEN="$token" gh api "repos/${GITHUB_SOURCE_REPO}/branches/${GITHUB_SOURCE_BRANCH}" </dev/null >/dev/null 2>&1; then
      return 0
    fi

    if gh api "repos/${GITHUB_SOURCE_REPO}/branches/${GITHUB_SOURCE_BRANCH}" </dev/null >/dev/null 2>&1; then
      return 0
    fi
  fi

  local status_code
  status_code="$(curl -sS -o /dev/null -w "%{http_code}" \
    --connect-timeout 10 \
    --max-time 30 \
    -H "Authorization: token ${token}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${GITHUB_SOURCE_REPO}/branches/${GITHUB_SOURCE_BRANCH}")"

  if [[ "${status_code}" == "000" && -n "${token}" ]] && command -v gh >/dev/null 2>&1; then
    if GH_TOKEN="${token}" gh api "repos/${GITHUB_SOURCE_REPO}/branches/${GITHUB_SOURCE_BRANCH}" </dev/null >/dev/null 2>&1; then
      status_code="200"
    fi
  fi

  if [[ ("${status_code}" == "401" || "${status_code}" == "403" || "${status_code}" == "404") && -n "${token}" ]] && command -v gh >/dev/null 2>&1; then
    if GH_TOKEN="${token}" gh api "repos/${GITHUB_SOURCE_REPO}/branches/${GITHUB_SOURCE_BRANCH}" </dev/null >/dev/null 2>&1; then
      status_code="200"
    elif [[ "${status_code}" == "401" ]] && has_interactive_tty; then
      info "gh token may be missing repo scope. Running: gh auth refresh -h github.com -s repo"
      if gh auth refresh -h github.com -s repo </dev/null; then
        local refreshed_token
        refreshed_token="$(get_gh_token_if_supported 2>/dev/null || true)"
        refreshed_token="$(printf '%s' "$refreshed_token" | tr -d '\r\n')"
        if [[ -n "$refreshed_token" ]]; then
          token="$refreshed_token"
          status_code="$(curl -sS -o /dev/null -w "%{http_code}" \
            --connect-timeout 10 \
            --max-time 30 \
            -H "Authorization: token ${token}" \
            -H "Accept: application/vnd.github+json" \
            "https://api.github.com/repos/${GITHUB_SOURCE_REPO}/branches/${GITHUB_SOURCE_BRANCH}")"
          if [[ "${status_code}" != "200" ]] && GH_TOKEN="${token}" gh api "repos/${GITHUB_SOURCE_REPO}/branches/${GITHUB_SOURCE_BRANCH}" >/dev/null 2>&1; then
            status_code="200"
          fi
        elif gh api "repos/${GITHUB_SOURCE_REPO}/branches/${GITHUB_SOURCE_BRANCH}" </dev/null >/dev/null 2>&1; then
          status_code="200"
        fi
      fi
    fi
  fi

  if [[ "${status_code}" == "401" || "${status_code}" == "403" || "${status_code}" == "404" ]]; then
    warn "You do not have OCS release access yet (repo/branch: ${GITHUB_SOURCE_REPO}@${GITHUB_SOURCE_BRANCH}, HTTP ${status_code})."
    if command -v gh >/dev/null 2>&1; then
      warn "If you already have repo access, run: gh auth refresh -h github.com -s repo"
    fi
    warn "If you haven't purchased OCS yet, contact support at: ${WHATSAPP_ORDER_URL}"
    open_purchase_page
    return 1
  elif [[ "${status_code}" == "000" ]]; then
    error "Cannot reach GitHub API from this environment (HTTP 000). Check network/proxy/firewall, then rerun installer."
  elif [[ "${status_code}" != "200" ]]; then
    error "Unexpected response from GitHub API (HTTP ${status_code})."
  fi

  info "Repo branch access verified: ${GITHUB_SOURCE_REPO}@${GITHUB_SOURCE_BRANCH} (HTTP ${status_code})"
}

download_plugin_bundle() {
  local token="$1"
  local output="$2"
  token="$(printf '%s' "$token" | tr -d '\r\n')"

  fetch_assets_json_for_branch() {
    local token="$1"
    local branch="$2"
    local assets_api="https://api.github.com/repos/${GITHUB_SOURCE_REPO}/contents/assets?ref=${branch}"
    local branch_assets_json=""

    if command -v gh >/dev/null 2>&1; then
      branch_assets_json="$(gh api "repos/${GITHUB_SOURCE_REPO}/contents/assets?ref=${branch}" 2>/dev/null || true)"
      if [[ -z "$branch_assets_json" && -n "$token" ]]; then
        branch_assets_json="$(GH_TOKEN="$token" gh api "repos/${GITHUB_SOURCE_REPO}/contents/assets?ref=${branch}" 2>/dev/null || true)"
      fi
    fi

    if [[ -z "$branch_assets_json" ]]; then
      branch_assets_json="$(curl -fsSL \
        -H "Authorization: token ${token}" \
        -H "Accept: application/vnd.github+json" \
        "${assets_api}" 2>/dev/null || true)"
    fi

    printf '%s' "$branch_assets_json"
  }

  assets_json_has_bundle() {
    local assets_json="$1"
    local bundle_name="$2"
    printf '%s' "$assets_json" | grep -Eq "\"name\"[[:space:]]*:[[:space:]]*\"${bundle_name}\""
  }

  local resolved_branch="${GITHUB_SOURCE_BRANCH}"
  local assets_json
  assets_json="$(fetch_assets_json_for_branch "$token" "$resolved_branch")"

  [[ -n "$assets_json" ]] || error "Unable to read assets/ listing for ${GITHUB_SOURCE_REPO}@${resolved_branch}"

  local bundle_name
  if [[ -n "${REQUESTED_VERSION}" ]]; then
    bundle_name="opencode-config-suites-v${REQUESTED_VERSION}.tar.gz"
    info "Requested bundle asset: ${bundle_name}"
    info "Checking branch ${resolved_branch} for requested version..."
    if ! assets_json_has_bundle "$assets_json" "$bundle_name"; then
      info "Requested version v${REQUESTED_VERSION} not found on branch ${resolved_branch}."
      info "Checking fallback branch ${DEFAULT_RELEASE_BRANCH}..."
      local fallback_assets_json
      if [[ "$resolved_branch" == "$DEFAULT_RELEASE_BRANCH" ]]; then
        fallback_assets_json="$assets_json"
      else
        fallback_assets_json="$(fetch_assets_json_for_branch "$token" "$DEFAULT_RELEASE_BRANCH")"
      fi

      if [[ -n "$fallback_assets_json" ]] && assets_json_has_bundle "$fallback_assets_json" "$bundle_name"; then
        warn "Requested version ${REQUESTED_VERSION} not found in assets/ for ${GITHUB_SOURCE_REPO}@${resolved_branch}. Falling back to ${DEFAULT_RELEASE_BRANCH}."
        assets_json="$fallback_assets_json"
        resolved_branch="$DEFAULT_RELEASE_BRANCH"
      else
        error "Requested version ${REQUESTED_VERSION} not found in assets/ for ${GITHUB_SOURCE_REPO}@${resolved_branch}. Checked branches ${resolved_branch} and ${DEFAULT_RELEASE_BRANCH}, and the asset is missing on both."
      fi
    fi
  else
    bundle_name="$(printf '%s' "$assets_json" | grep -oE '"name"[[:space:]]*:[[:space:]]*"opencode-config-suites-v[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz"' | cut -d '"' -f4 | sort -V | tail -1)"
  fi
  [[ -n "$bundle_name" ]] || error "No plugin bundle found in assets/ for ${GITHUB_SOURCE_REPO}@${resolved_branch}"

  RESOLVED_SOURCE_BRANCH="$resolved_branch"
  info "Resolved bundle source branch: ${RESOLVED_SOURCE_BRANCH}"
  info "Resolved bundle asset: ${bundle_name}"

  local file_api="https://api.github.com/repos/${GITHUB_SOURCE_REPO}/contents/assets/${bundle_name}?ref=${RESOLVED_SOURCE_BRANCH}"
  if command -v gh >/dev/null 2>&1; then
    if gh api -H "Accept: application/vnd.github.raw" "repos/${GITHUB_SOURCE_REPO}/contents/assets/${bundle_name}?ref=${RESOLVED_SOURCE_BRANCH}" >"${output}" 2>/dev/null; then
      return 0
    fi
    if [[ -n "$token" ]] && GH_TOKEN="$token" gh api -H "Accept: application/vnd.github.raw" "repos/${GITHUB_SOURCE_REPO}/contents/assets/${bundle_name}?ref=${RESOLVED_SOURCE_BRANCH}" >"${output}" 2>/dev/null; then
      return 0
    fi
  fi

  curl -fsSL \
    -H "Authorization: token ${token}" \
    -H "Accept: application/vnd.github.raw" \
    -L "${file_api}" \
    -o "${output}"
}
# ─── Verify SHA256 ────────────────────────────────────────────────────────────
verify_sha256() {
  local sums_file="$1"
  local target_dir="$2"

  info "Verifying SHA256SUMS..."
  cd "${target_dir}"

  if command -v sha256sum &>/dev/null; then
    sha256sum --check "${sums_file}" --ignore-missing
  elif command -v shasum &>/dev/null; then
    shasum -a 256 --check "${sums_file}" --ignore-missing
  else
    warn "sha256sum/shasum not found — skipping checksum verification"
    return 0
  fi

  success "Checksum verification passed"
}

read_installed_plugin_version() {
  local plugin_dir="$1"
  local package_json="${plugin_dir}/package.json"

  [[ -f "${package_json}" ]] || return 0

  grep -o '"version": *"[^"]*"' "${package_json}" 2>/dev/null | head -1 | cut -d '"' -f4
}

installed_same_version_skip_is_trusted() {
  local requested_version="$1"
  local plugin_dir="$2"
  local config_root="$3"
  local provenance_file="${config_root}/BUILD_PROVENANCE.json"
  local installed_version=""
  local provenance_summary=""
  local provenance_version=""
  local provenance_git_tag=""
  local provenance_is_dirty=""

  installed_version="$(read_installed_plugin_version "${plugin_dir}")"
  if [[ -z "${installed_version}" ]]; then
    info "Identity unknown: unable to read installed plugin version from ${plugin_dir}/package.json."
    return 1
  fi

  if [[ "${installed_version}" != "${requested_version}" ]]; then
    info "Identity unknown: installed plugin version v${installed_version} does not match requested v${requested_version}."
    return 1
  fi

  if [[ ! -f "${provenance_file}" ]]; then
    info "Skip denied: missing installed provenance at ${provenance_file}; identity is unknown."
    return 1
  fi

  if ! provenance_summary="$(PROVENANCE_FILE="${provenance_file}" bun -e '
    const provenanceFile = process.env.PROVENANCE_FILE
    try {
      const data = JSON.parse(await Bun.file(provenanceFile).text())
      const version = typeof data.version === "string" ? data.version : ""
      const gitTag = typeof data?.source?.gitTag === "string" ? data.source.gitTag : ""
      const isDirty = data?.source?.isDirty === true ? "true" : data?.source?.isDirty === false ? "false" : ""
      process.stdout.write([version, gitTag, isDirty].join("\t"))
    } catch {
      process.exit(1)
    }
  ')"; then
    info "Skip denied: provenance file at ${provenance_file} is unreadable or malformed; identity is unknown."
    return 1
  fi

  IFS=$'\t' read -r provenance_version provenance_git_tag provenance_is_dirty <<< "${provenance_summary}"

  if [[ "${provenance_version}" != "${requested_version}" ]]; then
    info "Identity unknown: provenance version ${provenance_version:-<missing>} does not match requested v${requested_version}."
    return 1
  fi

  if [[ "${provenance_git_tag}" != "v${requested_version}" ]]; then
    info "Identity unknown: provenance gitTag ${provenance_git_tag:-<missing>} does not match expected v${requested_version}."
    return 1
  fi

  if [[ "${provenance_is_dirty}" != "false" ]]; then
    info "Identity unknown: provenance source.isDirty=${provenance_is_dirty:-<missing>} is not clean."
    return 1
  fi

  info "Trusted installed provenance accepted from ${provenance_file} (version v${requested_version}, tag v${requested_version}, clean tree)."
  return 0
}

# ─── Main ─────────────────────────────────────────────────────────────────────
# ─── Bun installation ───────────────────────────────────────────────────────────
install_bun() {
  info "Bun not found. Attempting auto-install..."
  if ! command -v curl &>/dev/null; then
    error "curl is required to install Bun. Please install curl first."
  fi
  export BUN_INSTALL="${HOME}/.bun"
  curl -fsSL https://bun.sh/install | bash

  if [[ -d "${HOME}/.bun" ]]; then
    export PATH="${HOME}/.bun/bin:${PATH}"
  fi
  if [[ -d "${HOME}/.local/bin" ]]; then
    export PATH="${HOME}/.local/bin:${PATH}"
  fi
  
  if ! command_is_usable_local_runtime bun; then
    error "Bun installation failed or not found in PATH. Please install manually at https://bun.sh"
  fi

  local bun_cmd
  bun_cmd="$(resolve_local_runtime_command_path bun)"
  success "Bun $(${bun_cmd} --version) installed successfully"
}

cleanup_runtime_plugins_dir() {
  local plugins_root="${CONFIG_ROOT}/plugins"
  local purge_plugins="${OCS_INSTALLER_PURGE_PLUGINS:-1}"

  if [[ "${purge_plugins}" != "1" ]]; then
    info "Skipping plugin directory purge because OCS_INSTALLER_PURGE_PLUGINS=${purge_plugins}"
    return 0
  fi

  if [[ -d "${plugins_root}" ]]; then
    warn "Removing existing plugin directory to avoid stale plugin manager conflicts: ${plugins_root}"
    rm -rf "${plugins_root}"
  fi

  mkdir -p "${plugins_root}"
  success "Plugin directory reset complete: ${plugins_root}"
}

main() {
  parse_cli_args "$@"
  resolve_release_branch_config

  echo ""
  echo "🔌 opencode-multi-auth — Plugin Installer"
  echo "────────────────────────────────────────"

  ensure_shell_dependencies

  # Bun version check
  if ! command_is_usable_local_runtime bun; then
    install_bun
  fi

  local bun_cmd
  bun_cmd="$(resolve_local_runtime_command_path bun)"
  local bun_version
  bun_version="$(${bun_cmd} --version)"
  local bun_major
  bun_major="$(echo "${bun_version}" | cut -d. -f1)"
  if [[ "${bun_major}" -lt 1 ]]; then
    error "Bun >= 1.0.0 required (found ${bun_version}). Install at https://bun.sh"
  fi
  info "Bun ${bun_version} detected"
  info "Installer source branch: ${GITHUB_SOURCE_BRANCH}"
  info "Fallback release branch: ${DEFAULT_RELEASE_BRANCH}"
  if [[ -n "${REQUESTED_VERSION}" ]]; then
    info "Requested version pin: v${REQUESTED_VERSION}"
  fi
  local root_dir="${PWD}"
  local force_local_source="${OCS_FORCE_LOCAL_SOURCE:-0}"
  local local_bundle_path="${OCS_LOCAL_BUNDLE_PATH:-}"
  local resolved_local_bundle=""
  local installed_version=""
  is_local_source=false
  if [[ "${force_local_source}" == "1" ]]; then
    if [[ -f "${root_dir}/plugins/opencode-multi-auth/package.json" && -f "${root_dir}/scripts/setup.js" && -f "${root_dir}/scripts/constants/profile-catalog.json" && -d "${root_dir}/configs" ]]; then
      is_local_source=true
      warn "OCS_FORCE_LOCAL_SOURCE=1 enabled. Using local workspace plugin source."
    else
      error "OCS_FORCE_LOCAL_SOURCE=1 set, but local source markers are missing in ${root_dir}."
    fi
  fi

  if [[ -n "${local_bundle_path}" ]]; then
    resolved_local_bundle="$(resolve_absolute_path_safe "${local_bundle_path}")"
    [[ -f "${resolved_local_bundle}" ]] || error "OCS_LOCAL_BUNDLE_PATH not found: ${local_bundle_path}"
  fi

  if [[ -z "${resolved_local_bundle}" && "${is_local_source}" != "true" && -n "${REQUESTED_VERSION}" ]]; then
    installed_version="$(read_installed_plugin_version "${PLUGIN_DIR}")"
    if [[ -n "${installed_version}" && "${installed_version}" == "${REQUESTED_VERSION}" ]]; then
      if installed_same_version_skip_is_trusted "${REQUESTED_VERSION}" "${PLUGIN_DIR}" "${CONFIG_ROOT}"; then
        info "Requested version v${REQUESTED_VERSION} is already installed at ${PLUGIN_DIR}."
        info "Trusted installed identity was detected, but the normal installer path will still purge and refresh plugin payloads so same-version patches land correctly."
      else
        info "Same-version installed payload found, but trusted identity was not established; continuing with the normal purge-and-refresh path."
      fi
    fi
  fi

  info "Resolved installer target root: ${CONFIG_ROOT}"
  info "Resolved installer plugin dir: ${PLUGIN_DIR}"
  cleanup_runtime_plugins_dir

  local token=""
  if [[ -n "${resolved_local_bundle}" ]]; then
    info "OCS_LOCAL_BUNDLE_PATH detected. Skipping GitHub auth and repo access checks."
  else
    echo ""
    info "Resolving GitHub auth..."
    token="$(resolve_token)"

    echo ""
    info "Verifying repo access..."
    if ! verify_access "${token}"; then
      warn "Access check failed with current token. Retrying with fresh authentication..."
      rm -f "${TOKEN_FILE}" || true
      token="$(resolve_token)"
      if ! verify_access "${token}"; then
        error "Installation stopped. Complete purchase/activation first, then rerun installer."
      fi
    fi
  fi

  echo ""
  local version="${installed_version}"
  info "Preparing plugin bundle source..."
  local tar_filename="plugin-bundle.tar.gz"
  local tar_path="${TMP_DIR}/${tar_filename}"

  if [[ -n "${resolved_local_bundle}" ]]; then
    info "Using local bundle: ${resolved_local_bundle}"
    cp "${resolved_local_bundle}" "${tar_path}"
  else
    echo ""
    if [[ -n "${REQUESTED_VERSION}" ]]; then
      info "Downloading plugin bundle v${REQUESTED_VERSION} from ${GITHUB_SOURCE_REPO}@${GITHUB_SOURCE_BRANCH}..."
    else
      info "Downloading plugin bundle from ${GITHUB_SOURCE_REPO}@${GITHUB_SOURCE_BRANCH}..."
    fi
    echo ""
    info "Downloading ${tar_filename}..."
    download_plugin_bundle "${token}" "${tar_path}"
  fi

  echo ""
  info "Extracting to ${PLUGIN_DIR}..."
  mkdir -p "${PLUGIN_DIR}"
  local extract_tmp="${TMP_DIR}/extract"
  mkdir -p "${extract_tmp}"
  tar -xzf "${tar_path}" -C "${extract_tmp}" --strip-components=1
  local plugin_source_dir="${extract_tmp}"
  [[ -f "${plugin_source_dir}/package.json" ]] || error "Invalid plugin bundle: package.json not found"
  cp -R "${plugin_source_dir}/." "${PLUGIN_DIR}/"
  sync_bundle_runtime_root "${plugin_source_dir}" "${CONFIG_ROOT}"

  version="$(grep -o '"version": *"[^"]*"' "${plugin_source_dir}/package.json" | head -1 | cut -d '"' -f4)"
  [[ -n "${version}" ]] || version="${GITHUB_SOURCE_BRANCH}"

  [[ -n "${version}" ]] || version="${GITHUB_SOURCE_BRANCH}"

  echo ""
  if [[ "${is_local_source}" == "true" ]]; then
    PLUGIN_DIR="${root_dir}/plugins/opencode-multi-auth"
  fi

  cd "${PLUGIN_DIR}"
  info "Installing dependencies..."
  install_dependencies_with_retry "${PLUGIN_DIR}" || error "Dependency installation failed after retries."

  echo ""
  success "opencode-multi-auth ${version} installed to ${PLUGIN_DIR} from ${RESOLVED_SOURCE_BRANCH}"
  echo ""
  info "Running setup script..."
  local setup_script
  setup_script="$(resolve_installer_setup_script "${is_local_source}" "${PLUGIN_DIR}" "${CONFIG_ROOT}")"

  # Ensure current installer shell can resolve user-installed binaries
  # (e.g. ccc in ~/.local/bin) before running headless setup.
  enable_legacy_shell_fallbacks
  ensure_posix_bootstrap_prerequisites
  ensure_agent_dependency_runtime
  source_shell_path_priority

  if [[ "${OCS_SKIP_AUTO_SETUP:-0}" == "1" ]]; then
    warn "Skipping auto setup because OCS_SKIP_AUTO_SETUP=1"
  else
    export OCS_SETUP_INSTALLER_MODE=1
    start_progress_narration "install" "setup-profile" || true
    if bun "${setup_script}" --headless --profile "${INSTALLER_DEFAULT_PROFILE}" --mode "${INSTALLER_DEFAULT_MODE}"; then
      stop_progress_narration
      success "Setup completed automatically (headless)."
    else
      stop_progress_narration
      warn "Headless setup failed. Falling back to interactive setup..."
      start_progress_narration "install" "setup-profile" || true
      if ! bun "${setup_script}"; then
        stop_progress_narration
        error "Setup script failed."
      fi
      stop_progress_narration
    fi
    unset OCS_SETUP_INSTALLER_MODE
  fi

  if [[ -d "${root_dir}" ]]; then
    cd "${root_dir}"
  else
    cd "${CONFIG_ROOT}"
  fi

  enable_legacy_shell_fallbacks
  ensure_posix_bootstrap_prerequisites
  ensure_agent_dependency_runtime
  source_shell_path_priority
  hash -r 2>/dev/null || true

  echo ""
  success "opencode-multi-auth ${version} (${RESOLVED_SOURCE_BRANCH}) installed and configured!"
  echo ""
  if [[ "${OCS_ENABLE_OCS_AUTO_INSTALL:-1}" == "1" ]]; then
    if ! ensure_ocs_command "${token}" "${root_dir}" "${is_local_source}" "${PLUGIN_DIR}"; then
      source_shell_path_priority
      if ocs_works; then
        info "ocs verification passed after sourcing the installer PATH snippet."
      else
        info "ocs command still unavailable after auto-install attempts."
        info "Manual fallback: clone private suite repo, then run bun install -g <repo-path>."
        info "If needed, ensure PATH includes ${HOME}/.bun/bin and open a new terminal."
      fi
    fi
else
  info "Skipping automatic ocs command installation because OCS_ENABLE_OCS_AUTO_INSTALL=0."
fi

ensure_system_command_links
repair_recursive_cocoindex_shim || true
source_shell_path_priority
hash -r 2>/dev/null || true

ensure_adjunct_runtime_ready

if opencode_works; then
  info "opencode verification passed."
else
  warn "opencode command not healthy. Attempting automatic repair..."
  if ensure_opencode_command; then
    info "opencode repair and verification passed."
  else
    warn "opencode command is still unavailable. Install Node.js or ensure bunx can run opencode-ai."
    info "Manual check: opencode --version"
  fi
fi

ensure_antigravity_oauth_integrity "${setup_script}"

  echo ""
  echo "   Next steps:"
  echo "   1. Add account / login: opencode auth login"
  echo "      - Default recommended path: OpenAI > Chatgpt browser"
  echo "   2. Create EXA API key: https://dashboard.exa.ai/api-keys"
  echo "   3. Setup Exa MCP: ocs exa setup --api-key <YOUR_EXA_API_KEY>"
  echo "   4. Verify Exa MCP: ocs exa check"
  echo "   5. Verify MCP status: opencode mcp list"
  echo "   6. Default runtime: opencode --port 78617"
  echo "   7. If you prefer web UI: opencode web --port 8089"
  echo ""
  echo "   Optional later:"
  echo "   - Change from the default ChatGPT/Codex profile: ocs setup:profile"
  echo "   - GitHub MCP: start from GitHub CLI install/auth docs https://cli.github.com/"
  echo "   - VS Code extension: OpenCode VSCode Extension by SST"
  echo ""
}

if [[ -z "${BASH_SOURCE[0]-}" || "${BASH_SOURCE[0]-}" == "$0" ]]; then
  main "$@"
fi
