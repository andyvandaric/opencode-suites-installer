#!/usr/bin/env bash
# uninstall.sh — remove OCS/OpenCode local install artifacts
set -euo pipefail

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

TARGET_HOME="$(resolve_target_home)"
if [[ -n "${TARGET_HOME}" && "${TARGET_HOME}" != "${HOME}" ]]; then
  HOME="${TARGET_HOME}"
  export HOME
fi

YES_MODE=0
NO_BACKUP=0
DRY_RUN=0
BACKUP_DIR="${HOME}/.opencode-suites-uninstall-backups"

info()    { echo "  $*"; }
success() { echo "✅ $*"; }
warn()    { echo "⚠️  $*" >&2; }
error()   { echo "❌ $*" >&2; exit 1; }

show_usage() {
  cat <<'EOF'
Usage: uninstall.sh [--yes] [--no-backup] [--backup-dir <path>] [--dry-run]

Options:
  --yes, -y            Run non-interactive (skip confirmation)
  --no-backup          Skip backup archive creation
  --backup-dir <path>  Backup output directory
  --dry-run            Print actions without deleting anything
  --help, -h           Show this help

Env alternatives:
  OCS_TARGET_HOME      Home directory to clean (when script runs with sudo)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y)
      YES_MODE=1
      shift
      ;;
    --no-backup)
      NO_BACKUP=1
      shift
      ;;
    --backup-dir)
      [[ $# -ge 2 ]] || error "Missing value for --backup-dir"
      BACKUP_DIR="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
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

run_cmd() {
  if (( DRY_RUN == 1 )); then
    info "[dry-run] $*"
    return 0
  fi
  "$@"
}

remove_path_if_exists() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    info "Removing $path"
    run_cmd rm -rf "$path"
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
    info "No config/data directories found for backup."
    return 0
  fi

  ts="$(date +%Y%m%d-%H%M%S)"
  archive="${BACKUP_DIR}/ocs-uninstall-backup-${ts}.tar.gz"

  info "Creating backup archive: ${archive}"
  run_cmd mkdir -p "${BACKUP_DIR}"
  if (( DRY_RUN == 1 )); then
    info "[dry-run] tar -czf ${archive} ..."
  else
    tar -czf "${archive}" "${sources[@]}"
    success "Backup created: ${archive}"
  fi
}

kill_related_processes() {
  if ! command -v pkill >/dev/null 2>&1; then
    info "pkill not found, skipping process cleanup."
    return 0
  fi

  local patterns=(
    "opencode"
    "opencode-ai"
    "ocs setup"
    "\.opencode/bin/opencode"
  )

  for pattern in "${patterns[@]}"; do
    if (( DRY_RUN == 1 )); then
      info "[dry-run] pkill -f ${pattern}"
    else
      pkill -f "${pattern}" >/dev/null 2>&1 || true
    fi
  done
}

remove_system_link_if_installer_managed() {
  local link_path="$1"

  [[ -e "${link_path}" || -L "${link_path}" ]] || return 0

  if [[ ! -L "${link_path}" ]]; then
    warn "Skip ${link_path} (not a symlink)."
    return 0
  fi

  local target=""
  target="$(readlink "${link_path}" 2>/dev/null || true)"

  case "${target}" in
    *"/.local/bin/"*|*"/.bun/bin/"*|*"/.opencode/bin/"*)
      info "Removing managed symlink ${link_path} -> ${target}"
      if (( DRY_RUN == 1 )); then
        info "[dry-run] rm -f ${link_path}"
      elif rm -f "${link_path}" 2>/dev/null; then
        return 0
      elif command -v sudo >/dev/null 2>&1; then
        sudo rm -f "${link_path}" >/dev/null 2>&1 || warn "Failed to remove ${link_path}."
      else
        warn "Failed to remove ${link_path} (sudo unavailable)."
      fi
      ;;
    *)
      warn "Skip ${link_path} (target not recognized as installer-managed: ${target})."
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
        bun remove -g "${pkg}" >/dev/null 2>&1 || true
      fi
    done
  fi

  if command -v npm >/dev/null 2>&1; then
    for pkg in opencode-ai @opencode-ai/opencode; do
      if (( DRY_RUN == 1 )); then
        info "[dry-run] npm uninstall -g ${pkg}"
      else
        npm uninstall -g "${pkg}" >/dev/null 2>&1 || true
      fi
    done
  fi
}

confirm_uninstall() {
  if (( YES_MODE == 1 )); then
    return 0
  fi

  cat <<EOF
This will remove OCS/OpenCode local install artifacts from:
  HOME=${HOME}

Targets include:
  - ~/.config/opencode
  - ~/.opencode
  - ~/.opencode-suites
  - ~/.cache/opencode
  - ~/.local/share/opencode
  - local shims in ~/.local/bin, ~/.bun/bin, ~/.opencode/bin
  - managed symlinks in /usr/local/bin (if detected)

Continue? [y/N]
EOF

  local answer=""
  read -r answer || true
  case "${answer}" in
    y|Y|yes|YES)
      return 0
      ;;
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

main() {
  confirm_uninstall
  create_backup

  info "Stopping related processes"
  kill_related_processes

  info "Removing local command shims"
  remove_path_if_exists "${HOME}/.local/bin/ocs"
  remove_path_if_exists "${HOME}/.local/bin/opencode"
  remove_path_if_exists "${HOME}/.bun/bin/ocs"
  remove_path_if_exists "${HOME}/.bun/bin/opencode"
  remove_path_if_exists "${HOME}/.opencode/bin/ocs"
  remove_path_if_exists "${HOME}/.opencode/bin/opencode"

  info "Removing installer-managed /usr/local/bin symlinks if present"
  remove_system_link_if_installer_managed "/usr/local/bin/ocs"
  remove_system_link_if_installer_managed "/usr/local/bin/opencode"

  info "Removing global packages (best effort)"
  uninstall_global_packages

  info "Removing OCS/OpenCode config and cache directories"
  remove_path_if_exists "${HOME}/.config/opencode"
  remove_path_if_exists "${HOME}/.opencode"
  remove_path_if_exists "${HOME}/.opencode-suites"
  remove_path_if_exists "${HOME}/.cache/opencode"
  remove_path_if_exists "${HOME}/.local/share/opencode"

  hash -r 2>/dev/null || true

  success "Uninstall flow completed."
  verify_cleanup

  cat <<'EOF'

Next step (clean-room reinstall test):
  env -i HOME="$(mktemp -d /tmp/ocs-clean-XXXXXX)" USER="$(id -un)" PATH="/usr/bin:/bin" \
    bash -lc 'curl -fsSL https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/feat/buyer-setup-smoke/install.sh | bash -s -- --version 2.1.4 --branch feat/buyer-setup-smoke'
EOF
}

main "$@"
