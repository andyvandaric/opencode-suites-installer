#!/usr/bin/env bash
# restore.sh — restore OCS/OpenCode state from installer backups
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
DRY_RUN=0
BACKUP_DIR="${HOME}/.opencode-suites-uninstall-backups"
ARCHIVE_OVERRIDE=""

info()    { echo "  $*"; }
success() { echo "✅ $*"; }
warn()    { echo "⚠️  $*" >&2; }
error()   { echo "❌ $*" >&2; exit 1; }

get_file_mtime() {
  local file="$1"
  local epoch
  if epoch="$(stat -c %Y -- "${file}" 2>/dev/null)"; then
    printf '%s\n' "${epoch}"
    return 0
  fi
  if epoch="$(stat -f %m "${file}" 2>/dev/null)"; then
    printf '%s\n' "${epoch}"
    return 0
  fi
  printf '0\n'
}

show_usage() {
  cat <<'EOF'
Usage: restore.sh [options]

Options:
  --yes, -y               Skip confirmation prompts
  --backup-dir <path>     Directory where backup archives reside
  --archive <path>        Explicit archive to restore
  --dry-run               Print planned actions without extracting
  --help, -h              Show this help

Env alternatives:
  OCS_TARGET_HOME         Target HOME when running under sudo
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y)
      YES_MODE=1
      shift
      ;;
    --backup-dir)
      [[ $# -ge 2 ]] || error "Missing value for --backup-dir"
      BACKUP_DIR="$2"
      shift 2
      ;;
    --archive)
      [[ $# -ge 2 ]] || error "Missing value for --archive"
      ARCHIVE_OVERRIDE="$2"
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

find_latest_archive() {
  local candidates=()
  local pattern nullglob_was_set=0
  if shopt -q nullglob; then
    nullglob_was_set=1
  fi
  shopt -s nullglob
  for pattern in "${BACKUP_DIR}"/ocs-backup-*.tar.gz "${BACKUP_DIR}"/ocs-uninstall-backup-*.tar.gz; do
    if [[ -e "${pattern}" ]]; then
      candidates+=("${pattern}")
    fi
  done
  if (( nullglob_was_set == 0 )); then
    shopt -u nullglob
  fi

  if (( ${#candidates[@]} == 0 )); then
    return 0
  fi

  local latest=""
  local best_mtime=0
  local mtime
  for pattern in "${candidates[@]}"; do
    mtime="$(get_file_mtime "${pattern}")"
    if (( mtime > best_mtime )); then
      best_mtime=${mtime}
      latest="${pattern}"
    fi
  done

  printf '%s\n' "${latest}"
}

select_archive() {
  if [[ -n "${ARCHIVE_OVERRIDE}" ]]; then
    printf '%s\n' "${ARCHIVE_OVERRIDE}"
    return 0
  fi

  find_latest_archive
}

print_archive_preview() {
  local archive="$1"
  local limit=8
  local count=0
  info "Archive preview (first ${limit} entries):"
  while IFS= read -r entry && (( count < limit )); do
    info "- ${entry}"
    count=$((count + 1))
  done < <(tar -tzf "${archive}")
  if (( count == 0 )); then
    info "  (archive appears empty)"
  elif (( count == limit )); then
    info "  ... preview truncated after ${limit} entries"
  fi
}

validate_archive_entries() {
  local archive="$1"
  local entry
  while IFS= read -r entry; do
    if [[ "${entry}" == /* ]]; then
      error "Archive entry is absolute: ${entry}"
    fi
    case "${entry}" in
      ../*|*/../*|*/..|..)
        error "Archive entry contains directory traversal: ${entry}"
        ;;
    esac
  done < <(tar -tzf "${archive}")
}

confirm_restore() {
  local archive="$1"
  if (( YES_MODE == 1 )); then
    return 0
  fi

  cat <<EOF
This will restore OCS/OpenCode state from:
  ${archive}

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

main() {
  local archive
  archive="$(select_archive)"

  if [[ -z "${archive:-}" ]]; then
    error "No backup archives found in ${BACKUP_DIR}"
  fi

  if [[ ! -f "${archive}" ]]; then
    error "Archive not found: ${archive}"
  fi

  info "Selected archive: ${archive}"
  print_archive_preview "${archive}"
  validate_archive_entries "${archive}"
  confirm_restore "${archive}"

  run_cmd tar -xzf "${archive}" -C /
  if (( DRY_RUN == 1 )); then
    warn "Dry-run mode: no files were extracted."
  else
    success "Restored from ${archive}"
  fi

  info "Post-restore hints:"
  info "  - Run 'hash -r' and restart shells if needed"
  info "  - Verify ~/.config/opencode, ~/.opencode*, ~/.local/share/opencode exist"
}

main
