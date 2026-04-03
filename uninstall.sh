#!/usr/bin/env bash
set -euo pipefail

EXIT_OK=0
EXIT_FATAL=1
EXIT_ARG=2

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

MODE="safe"
YES_MODE=0
DRY_RUN=0
NO_BACKUP=0
FORCE_PURGE=0
WINDOWS_HOST_CLEANUP=0

BACKUP_DIR="${HOME}/.opencode-suites-uninstall-backups"
WINDOWS_HOME=""

STEP=0
TOTAL_STEPS=8

PRESERVE_BASENAMES=(
  "opencode.json"
  "openai-session-state.json"
)

PRESERVE_PATTERNS=(
  "openai-accounts*.json"
  "antigravity-accounts*.json"
)

PRESERVE_EXISTING=()

info()    { echo "  $*"; }
success() { echo "✅ $*"; }
warn()    { echo "⚠️  $*" >&2; }

fail_arg() {
  echo "❌ $*" >&2
  exit "${EXIT_ARG}"
}

fail_fatal() {
  echo "❌ $*" >&2
  exit "${EXIT_FATAL}"
}

show_usage() {
  cat <<'EOF'
Usage: uninstall.sh [options]

Options:
  --mode <safe|purge>       Uninstall mode (default: safe)
  --yes, -y                 Non-interactive confirmation
  --force-purge             Required with --yes --mode purge
  --dry-run                 Print actions without mutating filesystem
  --no-backup               Skip backup archive creation
  --backup-dir <path>       Backup output directory
  --windows-host-cleanup    (WSL only) also clean installer-owned Windows-host paths
  --windows-home <path>     Override Windows home path for host cleanup (WSL)
  --help, -h                Show this help

Exit codes:
  0 = success (including non-fatal warnings)
  1 = fatal execution error
  2 = invalid arguments / missing purge gate

Environment:
  OCS_TARGET_HOME           Home directory to clean when running via sudo
EOF
}

resolve_target_home() {
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

is_wsl() {
  [[ -f /proc/version ]] && grep -qiE 'microsoft|wsl' /proc/version
}

next_step() {
  STEP=$((STEP + 1))
  echo ""
  echo "[$STEP/$TOTAL_STEPS] $*"
}

run_cmd() {
  if (( DRY_RUN == 1 )); then
    info "[dry-run] $*"
    return 0
  fi
  "$@"
}

in_prefix() {
  local path="$1"
  local base="$2"
  [[ "$path" == "$base" || "$path" == "$base"/* ]]
}

validate_delete_target() {
  local path="$1"
  if in_prefix "$path" "$HOME"; then
    return 0
  fi

  if [[ -n "${WINDOWS_HOME}" ]] && in_prefix "$path" "$WINDOWS_HOME"; then
    return 0
  fi

  case "$path" in
    /usr/local/bin/ocs|/usr/local/bin/opencode)
      return 0
      ;;
  esac

  fail_fatal "Refusing to delete outside allowed prefixes: $path"
}

remove_path_if_exists() {
  local path="$1"
  [[ -e "$path" || -L "$path" ]] || return 0
  validate_delete_target "$path"
  info "REMOVE $path"
  run_cmd rm -rf "$path"
}

preserve_match() {
  local base="$1"
  local p

  for p in "${PRESERVE_BASENAMES[@]}"; do
    [[ "$base" == "$p" ]] && return 0
  done

  for p in "${PRESERVE_PATTERNS[@]}"; do
    [[ "$base" == $p ]] && return 0
  done

  return 1
}

capture_safe_preserve_targets() {
  local cfg_dir="${HOME}/.config/opencode"
  local p
  PRESERVE_EXISTING=()

  [[ -d "$cfg_dir" ]] || return 0

  for p in "${PRESERVE_BASENAMES[@]}"; do
    if [[ -e "$cfg_dir/$p" ]]; then
      PRESERVE_EXISTING+=("$cfg_dir/$p")
    fi
  done

  shopt -s nullglob
  for p in "$cfg_dir"/openai-accounts*.json "$cfg_dir"/antigravity-accounts*.json; do
    [[ -e "$p" ]] && PRESERVE_EXISTING+=("$p")
  done
  shopt -u nullglob
}

verify_safe_preserve_targets() {
  local missing=0
  local p

  (( DRY_RUN == 1 )) && return 0
  [[ "$MODE" == "safe" ]] || return 0

  for p in "${PRESERVE_EXISTING[@]}"; do
    if [[ ! -e "$p" ]]; then
      warn "Expected preserved file missing after safe uninstall: $p"
      missing=1
    fi
  done

  if (( missing == 1 )); then
    fail_fatal "Safe-mode preservation check failed"
  fi
}

create_backup() {
  (( NO_BACKUP == 0 )) || return 0

  local sources=()
  local ts archive

  [[ -e "${HOME}/.config/opencode" ]] && sources+=("${HOME}/.config/opencode")
  [[ -e "${HOME}/.opencode" ]] && sources+=("${HOME}/.opencode")
  [[ -e "${HOME}/.opencode-suites" ]] && sources+=("${HOME}/.opencode-suites")
  [[ -e "${HOME}/.cache/opencode" ]] && sources+=("${HOME}/.cache/opencode")
  [[ -e "${HOME}/.local/share/opencode" ]] && sources+=("${HOME}/.local/share/opencode")

  if (( ${#sources[@]} == 0 )); then
    info "No directories found for backup."
    return 0
  fi

  ts="$(date +%Y%m%d-%H%M%S)"
  archive="${BACKUP_DIR}/ocs-uninstall-backup-${ts}.tar.gz"

  info "Creating backup archive: ${archive}"
  run_cmd mkdir -p "${BACKUP_DIR}"
  if (( DRY_RUN == 1 )); then
    info "[dry-run] tar -czf ${archive} ..."
  else
    tar -czf "${archive}" "${sources[@]}" || fail_fatal "Backup creation failed"
    success "Backup created: ${archive}"
  fi
}

kill_related_processes() {
  if ! command -v pkill >/dev/null 2>&1; then
    warn "pkill not found; skip process cleanup"
    return 0
  fi

  local patterns=(
    "(^|/)opencode( |$)"
    "(^|/)ocs( |$)"
    "\.opencode/bin/opencode"
  )
  local p

  for p in "${patterns[@]}"; do
    if (( DRY_RUN == 1 )); then
      info "[dry-run] pkill -f ${p}"
    else
      pkill -f "$p" >/dev/null 2>&1 || true
    fi
  done
}

remove_system_link_if_installer_managed() {
  local link_path="$1"
  [[ -e "$link_path" || -L "$link_path" ]] || return 0

  if [[ ! -L "$link_path" ]]; then
    warn "Skip ${link_path} (not a symlink)"
    return 0
  fi

  local target
  target="$(readlink "$link_path" 2>/dev/null || true)"

  case "$target" in
    *"/.local/bin/"*|*"/.bun/bin/"*|*"/.opencode/bin/"*)
      info "REMOVE managed symlink ${link_path} -> ${target}"
      if (( DRY_RUN == 1 )); then
        info "[dry-run] rm -f ${link_path}"
      elif rm -f "$link_path" 2>/dev/null; then
        :
      elif command -v sudo >/dev/null 2>&1; then
        sudo rm -f "$link_path" >/dev/null 2>&1 || warn "Failed to remove ${link_path}"
      else
        warn "Failed to remove ${link_path} (sudo unavailable)"
      fi
      ;;
    *)
      warn "Skip ${link_path} (target not installer-managed: ${target})"
      ;;
  esac
}

uninstall_global_packages() {
  local pkg

  if command -v bun >/dev/null 2>&1; then
    for pkg in opencode-ai @opencode-ai/opencode; do
      if (( DRY_RUN == 1 )); then
        info "[dry-run] bun remove -g ${pkg}"
      else
        bun remove -g "${pkg}" >/dev/null 2>&1 || warn "bun remove -g ${pkg} failed (non-fatal)"
      fi
    done
  fi

  if command -v npm >/dev/null 2>&1; then
    for pkg in opencode-ai @opencode-ai/opencode; do
      if (( DRY_RUN == 1 )); then
        info "[dry-run] npm uninstall -g ${pkg}"
      else
        npm uninstall -g "${pkg}" >/dev/null 2>&1 || warn "npm uninstall -g ${pkg} failed (non-fatal)"
      fi
    done
  fi
}

cleanup_config_safe() {
  local cfg_dir="${HOME}/.config/opencode"
  local entry base

  [[ -d "$cfg_dir" ]] || return 0

  shopt -s dotglob nullglob
  for entry in "$cfg_dir"/*; do
    base="$(basename "$entry")"
    if preserve_match "$base"; then
      info "PRESERVE ${entry}"
      continue
    fi
    remove_path_if_exists "$entry"
  done
  shopt -u dotglob nullglob
}

cleanup_windows_host() {
  local w_home

  (( WINDOWS_HOST_CLEANUP == 1 )) || return 0

  if ! is_wsl; then
    warn "--windows-host-cleanup ignored: not running in WSL"
    return 0
  fi

  if [[ -n "${WINDOWS_HOME}" ]]; then
    w_home="${WINDOWS_HOME}"
  elif [[ -d "/mnt/c/Users/${USER:-}" ]]; then
    w_home="/mnt/c/Users/${USER}"
  else
    fail_fatal "Unable to resolve Windows home. Pass --windows-home <path>."
  fi

  if [[ "$w_home" != /mnt/[a-zA-Z]/Users/* ]]; then
    fail_fatal "Refusing Windows host cleanup outside /mnt/<drive>/Users/*: $w_home"
  fi

  WINDOWS_HOME="$w_home"
  info "Windows host cleanup target: ${WINDOWS_HOME}"

  if [[ "$MODE" == "purge" ]]; then
    remove_path_if_exists "${WINDOWS_HOME}/.opencode"
    remove_path_if_exists "${WINDOWS_HOME}/.opencode-suites"
    remove_path_if_exists "${WINDOWS_HOME}/AppData/Local/opencode"
    remove_path_if_exists "${WINDOWS_HOME}/AppData/Roaming/opencode"
  else
    remove_path_if_exists "${WINDOWS_HOME}/AppData/Local/opencode"
  fi
}

print_plan() {
  echo ""
  echo "Uninstall mode: ${MODE}"
  echo "Target HOME: ${HOME}"
  if (( DRY_RUN == 1 )); then
    echo "Dry-run: enabled"
  fi

  echo ""
  echo "Will remove:"
  echo "  - local shims/binaries and installer-managed symlinks"
  echo "  - global package links (best effort)"
  echo "  - ~/.opencode, ~/.opencode-suites, ~/.cache/opencode, ~/.local/share/opencode"
  if [[ "$MODE" == "safe" ]]; then
    echo "  - ~/.config/opencode/* except preserved account/API key artifacts"
  else
    echo "  - ~/.config/opencode (full purge)"
  fi
  if (( WINDOWS_HOST_CLEANUP == 1 )); then
    echo "  - WSL host-boundary cleanup is enabled"
  fi

  echo ""
  echo "Will preserve (safe mode):"
  echo "  - ~/.config/opencode/opencode.json"
  echo "  - ~/.config/opencode/openai-accounts*.json"
  echo "  - ~/.config/opencode/openai-session-state.json"
  echo "  - ~/.config/opencode/antigravity-accounts*.json"
}

confirm_uninstall() {
  print_plan

  if [[ "$MODE" == "purge" ]]; then
    if (( YES_MODE == 1 )); then
      (( FORCE_PURGE == 1 )) || fail_arg "--yes with --mode purge requires --force-purge"
      return 0
    fi

    echo ""
    echo "Purge mode requires destructive confirmation."
    echo "Type PURGE to continue:"
    local token=""
    read -r token || true
    [[ "$token" == "PURGE" ]] || {
      info "Cancelled."
      exit 0
    }
    return 0
  fi

  if (( YES_MODE == 1 )); then
    return 0
  fi

  echo ""
  echo "Proceed with SAFE uninstall? [y/N]"
  local answer=""
  read -r answer || true
  case "${answer}" in
    y|Y|yes|YES) ;;
    *)
      info "Cancelled."
      exit 0
      ;;
  esac
}

verify_cleanup() {
  local found=0

  if command -v ocs >/dev/null 2>&1; then
    warn "ocs still resolves to: $(command -v ocs)"
    found=1
  fi
  if command -v opencode >/dev/null 2>&1; then
    warn "opencode still resolves to: $(command -v opencode)"
    found=1
  fi

  if (( found == 0 )); then
    success "No ocs/opencode command found in current PATH."
  else
    warn "Some commands still resolve. Open a new shell or run: hash -r"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --mode)
        [[ $# -ge 2 ]] || fail_arg "Missing value for --mode"
        MODE="$2"
        shift 2
        ;;
      --yes|-y)
        YES_MODE=1
        shift
        ;;
      --force-purge)
        FORCE_PURGE=1
        shift
        ;;
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --no-backup)
        NO_BACKUP=1
        shift
        ;;
      --backup-dir)
        [[ $# -ge 2 ]] || fail_arg "Missing value for --backup-dir"
        BACKUP_DIR="$2"
        shift 2
        ;;
      --windows-host-cleanup)
        WINDOWS_HOST_CLEANUP=1
        shift
        ;;
      --windows-home)
        [[ $# -ge 2 ]] || fail_arg "Missing value for --windows-home"
        WINDOWS_HOME="$2"
        shift 2
        ;;
      --help|-h)
        show_usage
        exit "${EXIT_OK}"
        ;;
      *)
        fail_arg "Unknown option: $1 (use --help for usage)"
        ;;
    esac
  done

  case "$MODE" in
    safe|purge) ;;
    *) fail_arg "Invalid --mode value: $MODE (expected safe|purge)" ;;
  esac

  if [[ "$MODE" == "safe" && "$FORCE_PURGE" -eq 1 ]]; then
    fail_arg "--force-purge can only be used with --mode purge"
  fi
}

main() {
  parse_args "$@"

  TARGET_HOME="$(resolve_target_home)"
  if [[ -n "$TARGET_HOME" && "$TARGET_HOME" != "$HOME" ]]; then
    HOME="$TARGET_HOME"
    export HOME
  fi

  if (( WINDOWS_HOST_CLEANUP == 1 )); then
    TOTAL_STEPS=9
  fi

  if [[ "$MODE" == "safe" ]]; then
    capture_safe_preserve_targets
  fi

  confirm_uninstall

  next_step "Create backup"
  create_backup

  next_step "Stop related processes"
  kill_related_processes

  next_step "Remove local command shims"
  remove_path_if_exists "${HOME}/.local/bin/ocs"
  remove_path_if_exists "${HOME}/.local/bin/opencode"
  remove_path_if_exists "${HOME}/.bun/bin/ocs"
  remove_path_if_exists "${HOME}/.bun/bin/opencode"
  remove_path_if_exists "${HOME}/.opencode/bin/ocs"
  remove_path_if_exists "${HOME}/.opencode/bin/opencode"

  next_step "Remove installer-managed /usr/local/bin symlinks"
  remove_system_link_if_installer_managed "/usr/local/bin/ocs"
  remove_system_link_if_installer_managed "/usr/local/bin/opencode"

  next_step "Remove global packages (best effort)"
  uninstall_global_packages

  next_step "Remove runtime/cache directories"
  remove_path_if_exists "${HOME}/.opencode"
  remove_path_if_exists "${HOME}/.opencode-suites"
  remove_path_if_exists "${HOME}/.cache/opencode"
  remove_path_if_exists "${HOME}/.local/share/opencode"

  next_step "Apply config cleanup policy"
  if [[ "$MODE" == "purge" ]]; then
    remove_path_if_exists "${HOME}/.config/opencode"
  else
    cleanup_config_safe
  fi

  if (( WINDOWS_HOST_CLEANUP == 1 )); then
    next_step "Apply WSL Windows-host cleanup"
    cleanup_windows_host
  fi

  hash -r 2>/dev/null || true

  next_step "Verify command/path state"
  verify_safe_preserve_targets
  verify_cleanup

  success "Uninstall flow completed (mode=${MODE})."
  cat <<'EOF'

Next step (clean-room reinstall test):
  bash -lc 'curl -fsSL https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/staging/v2.1.14/install.sh | bash'
EOF

  exit "${EXIT_OK}"
}

main "$@"
