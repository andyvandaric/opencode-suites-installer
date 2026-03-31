#!/usr/bin/env bash
# install.sh — Install opencode-multi-auth plugin for OpenCode Config Suites
# Supports 3 auth paths: gh CLI → GITHUB_TOKEN env → interactive prompt
set -euo pipefail

# Recover HOME when missing (can happen in some pipe-to-bash shells).
if [[ -z "${HOME:-}" ]]; then
  HOME="$(getent passwd "$(id -u)" | cut -d: -f6 2>/dev/null || true)"
  if [[ -z "${HOME:-}" ]]; then
    HOME="$(cd ~ 2>/dev/null && pwd || true)"
  fi
  if [[ -z "${HOME:-}" ]]; then
    HOME="/tmp"
  fi
  export HOME
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

  printf '%s\n' "${HOME:-/tmp}"
}

TARGET_HOME="$(resolve_target_home_early)"
if [[ -n "${TARGET_HOME}" && "${TARGET_HOME}" != "${HOME}" ]]; then
  HOME="${TARGET_HOME}"
  export HOME
fi

# ─── Config ──────────────────────────────────────────────────────────────────
GITHUB_SOURCE_REPO="andyvandaric/andyvand-opencode-config"
INSTALLER_SOURCE_BRANCH_HINT="staging/v2.1.13"
GITHUB_SOURCE_BRANCH="${OCS_RELEASE_BRANCH:-}"
DEFAULT_RELEASE_BRANCH="${OCS_FALLBACK_RELEASE_BRANCH:-}"
INSTALLER_DEFAULT_PROFILE="codex-5.3-hybrid"
INSTALLER_DEFAULT_MODE="performance"
WHATSAPP_ORDER_URL="https://wa.me/6281289731212?text=Mau%20order%20OCS%20nya%2C%20mohon%20infonya%20ya"
PLUGIN_DIR="${HOME}/.config/opencode/plugins/opencode-multi-auth"
TOKEN_FILE="${HOME}/.opencode-suites/.token"
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

show_usage() {
  cat <<'EOF'
Usage: install.sh [--version <x.y.z>] [--branch <name>] [--help]

Options:
  --version, -v   Install specific bundle version (example: 2.0.15)
  --branch        Override source branch (default: inferred from installer URL, fallback: staging/v2.1.13)
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
  local tail="${cmdline#*${marker}}"
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

install_packages_auto() {
  local pm="$1"
  shift
  local pkgs=("$@")
  local dep_retries="${OCS_DEP_INSTALL_RETRIES:-2}"

  case "$pm" in
    apt)
      run_with_retries "$dep_retries" run_with_privilege env DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::Retries=3 update && run_with_retries "$dep_retries" run_with_privilege env DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::Retries=3 install -y "${pkgs[@]}"
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

  if ! command -v bun >/dev/null 2>&1; then
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
    error "Cannot auto-install dependencies (${missing[*]}): no supported package manager detected"
  fi

  info "Attempting to auto-install dependencies via ${pm}..."
  info "Installing: ${missing[*]}"
  if ! install_packages_auto "$pm" "${missing[@]}"; then
    error "Auto-install failed for dependencies (${missing[*]}). Please install them manually and rerun."
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
  ocs --help >/dev/null 2>&1 || return 1
  return 0
}

resolve_primary_shell_profile() {
  local shell_name="${SHELL##*/}"
  local candidate

  case "${shell_name}" in
    zsh)
      for candidate in "${HOME}/.zprofile" "${HOME}/.zshrc"; do
        if [[ -f "${candidate}" ]]; then
          printf '%s\n' "${candidate}"
          return 0
        fi
      done
      printf '%s\n' "${HOME}/.zprofile"
      ;;
    bash)
      for candidate in "${HOME}/.bash_profile" "${HOME}/.profile" "${HOME}/.bashrc"; do
        if [[ -f "${candidate}" ]]; then
          printf '%s\n' "${candidate}"
          return 0
        fi
      done
      printf '%s\n' "${HOME}/.profile"
      ;;
    fish)
      printf '%s\n' ""
      ;;
    *)
      for candidate in "${HOME}/.profile" "${HOME}/.bash_profile" "${HOME}/.zprofile"; do
        if [[ -f "${candidate}" ]]; then
          printf '%s\n' "${candidate}"
          return 0
        fi
      done
      printf '%s\n' "${HOME}/.profile"
      ;;
  esac
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

ensure_antigravity_oauth_integrity() {
  local setup_script="$1"
  local config_dir="${HOME}/.config/opencode"
  local runtime_opencode="${config_dir}/opencode.json"
  local runtime_antigravity="${config_dir}/antigravity.json"
  local template_antigravity="${PLUGIN_DIR}/backups/antigravity.json.template"
  local needs_repair=0

  mkdir -p "${config_dir}" 2>/dev/null || true

  if [[ ! -f "${runtime_antigravity}" && -f "${template_antigravity}" ]]; then
    cp "${template_antigravity}" "${runtime_antigravity}"
    needs_repair=1
  fi

  if [[ -f "${runtime_opencode}" ]] && grep -Eq 'file:///.*dist/index\.js|plugins/.*/dist/index\.js' "${runtime_opencode}"; then
    needs_repair=1
  fi

  if (( needs_repair )); then
    info "Repairing final Antigravity OAuth visibility before installer exit..."
    export OCS_SETUP_INSTALLER_MODE=1
    bun "${setup_script}" --headless --profile "${INSTALLER_DEFAULT_PROFILE}" --mode "${INSTALLER_DEFAULT_MODE}" >/dev/null 2>&1 || true
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
  command -v opencode >/dev/null 2>&1 || return 1

  if command -v timeout >/dev/null 2>&1; then
    timeout 8 opencode --version >/dev/null 2>&1 || timeout 8 opencode --help >/dev/null 2>&1 || return 1
    return 0
  fi

  return 0
}

install_opencode_shim() {
  local bun_bin="${HOME}/.bun/bin"
  local local_bin="${HOME}/.local/bin"
  local bunx_exec="${HOME}/.bun/bin/bunx"
  mkdir -p "$bun_bin" "$local_bin"

cat > "${bun_bin}/opencode" <<EOF
#!/usr/bin/env bash
if [[ -x "$bunx_exec" ]]; then
  exec "$bunx_exec" --bun opencode-ai "\$@"
fi
exec bunx --bun opencode-ai "\$@"
EOF
  chmod +x "${bun_bin}/opencode"

cat > "${local_bin}/opencode" <<EOF
#!/usr/bin/env bash
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
  command -v bun >/dev/null 2>&1 || return 1

  info "Installing opencode-ai via bun global package..."
  if ! bun add -g opencode-ai@latest >/tmp/ocs-opencode-bun-global.log 2>&1; then
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

  warn "opencode command not healthy. Trying official installer..."
  if install_opencode_official && opencode_works; then
    return 0
  fi

  warn "official installer did not recover opencode. Trying bun global install..."
  if install_opencode_bun_global && opencode_works; then
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
  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    return 0
  fi

  local pm
  pm="$(detect_package_manager)"
  [[ -n "$pm" ]] || return 1

  info "Attempting to auto-install Node.js runtime via ${pm}..."
  case "$pm" in
    apt)
      install_packages_auto "$pm" nodejs npm || return 1
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

  command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1
}

install_opencode_npm_global() {
  command -v npm >/dev/null 2>&1 || return 1

  info "Installing opencode-ai globally via npm..."
  if ! npm install -g opencode-ai@latest >/tmp/ocs-opencode-npm.err 2>&1; then
    warn "$(cat /tmp/ocs-opencode-npm.err 2>/dev/null || true)"
    return 1
  fi

  local npm_prefix
  npm_prefix="$(npm config get prefix 2>/dev/null || true)"
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

  for ((i=1; i<=attempts; i++)); do
    if bun install -g "$source_path" >/tmp/ocs-bun-global.err 2>&1; then
      return 0
    fi

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

  if command -v npm >/dev/null 2>&1; then
    warn "bun global install failed, trying npm global install..."
    if npm install -g "$source_path" >/tmp/ocs-npm-global.err 2>&1; then
      if [[ -d "${HOME}/.bun/bin" ]]; then
        export PATH="${HOME}/.bun/bin:${PATH}"
      fi
      ocs_works && return 0
    else
      warn "$(cat /tmp/ocs-npm-global.err 2>/dev/null || true)"
    fi
  fi

  if command -v pnpm >/dev/null 2>&1; then
    warn "npm fallback unavailable/failed, trying pnpm global install..."
    if pnpm add -g "$source_path" >/tmp/ocs-pnpm-global.err 2>&1; then
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
  local ocs_js="${plugin_path}/bin/ocs.cjs"
  if [[ ! -f "$ocs_js" ]]; then
    ocs_js="${plugin_path}/bin/ocs.js"
  fi
  [[ -f "$ocs_js" ]] || return 1

  local bun_bin="${HOME}/.bun/bin"
  local local_bin="${HOME}/.local/bin"
  local bun_exec="${HOME}/.bun/bin/bun"
  mkdir -p "$bun_bin" "$local_bin"

cat > "${bun_bin}/ocs" <<EOF
#!/usr/bin/env bash
if [[ -x "$bun_exec" ]]; then
  exec "$bun_exec" "$ocs_js" "\$@"
fi
exec bun "$ocs_js" "\$@"
EOF
  chmod +x "${bun_bin}/ocs"

cat > "${local_bin}/ocs" <<EOF
#!/usr/bin/env bash
if [[ -x "$bun_exec" ]]; then
  exec "$bun_exec" "$ocs_js" "\$@"
fi
exec bun "$ocs_js" "\$@"
EOF
  chmod +x "${local_bin}/ocs"

  export PATH="${bun_bin}:${local_bin}:${PATH}"
  hash -r 2>/dev/null || true

  ocs_works
}

install_ocs_shim_from_opencode() {
  local shim_cmd='bunx --bun opencode-ai "\$@"'
  local bunx_exec="${HOME}/.bun/bin/bunx"
  if [[ -x "$bunx_exec" ]]; then
    shim_cmd="\"$bunx_exec\" --bun opencode-ai \"\$@\""
  fi
  if command -v opencode >/dev/null 2>&1; then
    shim_cmd='opencode "\$@"'
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

  if ocs_works; then
    info "ocs verification passed."
    return 0
  fi

  if install_ocs_shim_from_bundle "$plugin_dir"; then
    success "ocs shim install and verification passed."
    return 0
  fi

  if install_ocs_shim_from_opencode; then
    success "ocs shim via opencode install and verification passed."
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
  local export_line='export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$HOME/.bun/bin:$PATH"'
  local source_line='[ -f "$HOME/.config/opencode/shell/ocs-path.sh" ] && . "$HOME/.config/opencode/shell/ocs-path.sh"'
  local snippet_dir="${HOME}/.config/opencode/shell"
  local snippet_path="${snippet_dir}/ocs-path.sh"
  local profile
  local shell_name="${SHELL##*/}"

  export PATH="${HOME}/.opencode/bin:${HOME}/.local/bin:${HOME}/.bun/bin:${PATH}"
  hash -r 2>/dev/null || true

  mkdir -p "${snippet_dir}" 2>/dev/null || true
  if ! ensure_text_file_exists_if_writable "${snippet_path}"; then
    warn "Cannot persist shell PATH snippet at ${snippet_path}. Keep using current-session PATH export only."
  else
    printf '# OCS installer path\n%s\n' "${export_line}" > "${snippet_path}"
  fi

  profile="$(resolve_primary_shell_profile)"
  if [[ -n "${profile}" ]]; then
    if ensure_text_file_exists_if_writable "${profile}"; then
      if ! grep -Fq "${source_line}" "${profile}"; then
        printf '\n# OCS installer path\n%s\n' "${source_line}" >> "${profile}"
      fi
    else
      warn "Cannot write to shell profile ${profile}. Current-session PATH is active, but persistence was skipped."
    fi
  fi

  local fish_cfg="${HOME}/.config/fish/config.fish"
  local fish_line='fish_add_path -m $HOME/.opencode/bin $HOME/.local/bin $HOME/.bun/bin'
  if [[ "${shell_name}" == "fish" || -f "$fish_cfg" ]]; then
    mkdir -p "$(dirname "$fish_cfg")" 2>/dev/null || true
    if ensure_text_file_exists_if_writable "$fish_cfg"; then
      if ! grep -Fq "$fish_line" "$fish_cfg"; then
        printf '\n# OCS installer path\n%s\n' "$fish_line" >> "$fish_cfg"
      fi
    else
      warn "Cannot write to fish config at ${fish_cfg}."
    fi
  fi
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
      warn "Cannot create ${target_path}. Keep using shell profile PATH entries."
    fi
  done

  hash -r 2>/dev/null || true
}

is_lock_error() {
  local msg="$1"
  [[ "$msg" =~ EBUSY|EFAULT|EPERM|ENOENT|resource\ busy|being\ used\ by\ another\ process|Access\ is\ denied ]]
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

  for ((i=1; i<=attempts; i++)); do
    if bun install --frozen-lockfile >/dev/null 2>&1; then
      return 0
    fi

    if bun install >/tmp/ocs-bun-install.err 2>&1; then
      return 0
    fi

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
    if gh auth status >/dev/null 2>&1; then
      GH_TOKEN="$(gh auth token 2>/dev/null)"
      if [[ -n "${GH_TOKEN}" ]]; then
        echo "  Auth: using gh CLI token" >&2
        printf '%s' "${GH_TOKEN}" | tr -d '\r\n'
        return 0
      fi
    elif has_interactive_tty; then
      warn "GitHub CLI (gh) is installed but not authenticated."
      info "Opening OAuth login in browser..."
      if gh auth login; then
        gh config set -h github.com git_protocol https >/dev/null 2>&1 || true
        GH_TOKEN="$(gh auth token 2>/dev/null)"
        if [[ -n "${GH_TOKEN}" ]]; then
          echo "  Auth: using gh CLI token" >&2
          printf '%s' "${GH_TOKEN}" | tr -d '\r\n'
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
    if GH_TOKEN="$token" gh api "repos/${GITHUB_SOURCE_REPO}/branches/${GITHUB_SOURCE_BRANCH}" >/dev/null 2>&1; then
      return 0
    fi

    if gh api "repos/${GITHUB_SOURCE_REPO}/branches/${GITHUB_SOURCE_BRANCH}" >/dev/null 2>&1; then
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
    if GH_TOKEN="${token}" gh api "repos/${GITHUB_SOURCE_REPO}/branches/${GITHUB_SOURCE_BRANCH}" >/dev/null 2>&1; then
      status_code="200"
    fi
  fi

  if [[ ("${status_code}" == "401" || "${status_code}" == "403" || "${status_code}" == "404") && -n "${token}" ]] && command -v gh >/dev/null 2>&1; then
    if GH_TOKEN="${token}" gh api "repos/${GITHUB_SOURCE_REPO}/branches/${GITHUB_SOURCE_BRANCH}" >/dev/null 2>&1; then
      status_code="200"
    elif [[ "${status_code}" == "401" ]] && has_interactive_tty; then
      info "gh token may be missing repo scope. Running: gh auth refresh -h github.com -s repo"
      if gh auth refresh -h github.com -s repo; then
        local refreshed_token
        refreshed_token="$(gh auth token 2>/dev/null || true)"
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
  
  if ! command -v bun &>/dev/null; then
    error "Bun installation failed or not found in PATH. Please install manually at https://bun.sh"
  fi
  success "Bun $(bun --version) installed successfully"
}

main() {
  parse_cli_args "$@"
  resolve_release_branch_config

  echo ""
  echo "🔌 opencode-multi-auth — Plugin Installer"
  echo "────────────────────────────────────────"

  ensure_shell_dependencies

  # Bun version check
  if ! command -v bun &>/dev/null; then
    install_bun
  fi

  local bun_version
  bun_version="$(bun --version)"
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
  cp -R "${plugin_source_dir}/"* "${PLUGIN_DIR}/"

  local version
  version="$(grep -o '"version": *"[^"]*"' "${plugin_source_dir}/package.json" | head -1 | cut -d '"' -f4)"
  [[ -n "${version}" ]] || version="${GITHUB_SOURCE_BRANCH}"

  echo ""
  info "Installing dependencies..."
  if [[ "${is_local_source}" == "true" ]]; then
    PLUGIN_DIR="${root_dir}/plugins/opencode-multi-auth"
  fi

  cd "${PLUGIN_DIR}"
  install_dependencies_with_retry "${PLUGIN_DIR}" || error "Dependency installation failed after retries."

  echo ""
  success "opencode-multi-auth ${version} installed to ${PLUGIN_DIR} from ${RESOLVED_SOURCE_BRANCH}"
  echo ""
  info "Running setup script..."
  local setup_script
  if [[ "${is_local_source}" == "true" ]]; then
    setup_script="${root_dir}/scripts/setup.js"
  else
    setup_script="${PLUGIN_DIR}/scripts/setup.js"
  fi

  if [[ "${OCS_SKIP_AUTO_SETUP:-0}" == "1" ]]; then
    warn "Skipping auto setup because OCS_SKIP_AUTO_SETUP=1"
  else
    export OCS_SETUP_INSTALLER_MODE=1
    if bun "${setup_script}" --headless --profile "${INSTALLER_DEFAULT_PROFILE}" --mode "${INSTALLER_DEFAULT_MODE}"; then
      success "Setup completed automatically (headless)."
    else
      warn "Headless setup failed. Falling back to interactive setup..."
      if ! bun "${setup_script}"; then
        error "Setup script failed."
      fi
    fi
    unset OCS_SETUP_INSTALLER_MODE
  fi

  echo ""
  success "opencode-multi-auth ${version} (${RESOLVED_SOURCE_BRANCH}) installed and configured!"
  echo ""
  if [[ "${OCS_ENABLE_OCS_AUTO_INSTALL:-1}" == "1" ]]; then
    if ! ensure_ocs_command "${token}" "${root_dir}" "${is_local_source}" "${PLUGIN_DIR}"; then
      info "ocs command still unavailable after auto-install attempts."
      info "Manual fallback: clone private suite repo, then run bun install -g <repo-path>."
      info "If needed, ensure PATH includes ${HOME}/.bun/bin and open a new terminal."
    fi
else
  info "Skipping automatic ocs command installation because OCS_ENABLE_OCS_AUTO_INSTALL=0."
fi

ensure_shell_path_priority
ensure_system_command_links

if opencode_works; then
  info "opencode verification passed."
elif install_opencode_shim && opencode_works; then
  info "opencode shim installed and verification passed."
elif [[ "${OCS_ENABLE_OPENCODE_AUTO_RECOVERY:-0}" == "1" ]]; then
  warn "opencode command not healthy. Auto-recovery enabled; attempting repair..."
  if ! ensure_opencode_command; then
    warn "opencode command is still unavailable. Install Node.js or ensure bunx can run opencode-ai."
  fi
else
  warn "opencode command check failed. Skipping heavy auto-recovery to avoid long waits."
  info "Manual check: opencode --version"
  info "To force auto-recovery on rerun: OCS_ENABLE_OPENCODE_AUTO_RECOVERY=1"
fi

ensure_antigravity_oauth_integrity "${setup_script}"

  echo ""
  echo "   Next steps:"
  echo "   1. Configure profile: ocs setup:profile"
  echo "   2. Create EXA API key: https://dashboard.exa.ai/api-keys"
  echo "   3. Setup Exa MCP: ocs exa setup --api-key <YOUR_EXA_API_KEY>"
  echo "   4. Verify Exa MCP: ocs exa check"
  echo "   5. Keep GitHub MCP green: gh auth login"
  echo "      Then export token: export GITHUB_PERSONAL_ACCESS_TOKEN=\"\$(gh auth token)\""
  echo "   6. Verify MCP status: opencode mcp list"
  echo "   7. Configure preferences: ocs prefs"
  echo "   8. Verify runtime: opencode auth login"
  echo "   9. Start coding!"
  echo ""
}

main "$@"
