#!/usr/bin/env bash
# backup.sh — capture OCS/OpenCode state before clearing
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
OUTPUT_PATH=""

info()    { echo "  $*"; }
success() { echo "✅ $*"; }
warn()    { echo "⚠️  $*" >&2; }
error()   { echo "❌ $*" >&2; exit 1; }

show_usage() {
  cat <<'EOF'
Usage: backup.sh [options]

Options:
  --yes, -y               Skip confirmation prompts
  --backup-dir <path>     Directory to store archives (default: ~/.opencode-suites-uninstall-backups)
  --output <path>         Exact archive path (overrides --backup-dir)
  --dry-run               Print planned actions without touching disk
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
    --output)
      [[ $# -ge 2 ]] || error "Missing value for --output"
      OUTPUT_PATH="$2"
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

collect_sources() {
  local candidate
  for candidate in \
    "${HOME}/.config/opencode" \
    "${HOME}/.opencode" \
    "${HOME}/.opencode-suites" \
    "${HOME}/.cache/opencode" \
    "${HOME}/.local/share/opencode" \
  ; do
    if [[ -e "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
    fi
  done
}

confirm_proceed() {
  if (( YES_MODE == 1 )); then
    return 0
  fi

  echo "About to archive the following OCS/OpenCode directories:"
  echo "  HOME=${HOME}"
  echo
  echo "Sources:"
  for src in "$@"; do
    printf '  - %s\n' "${src/#${HOME}/~}"
  done
  echo
  cat <<'EOF'
Continue? [Y/n]
EOF

  local answer=""
  read -r answer || true
  case "${answer}" in
    y|Y|yes|YES|"")
      return 0
      ;;
    *)
      info "Cancelled."
      exit 0
      ;;
  esac
}

prepare_archive_path() {
  local dest_dir ts
  if [[ -n "${OUTPUT_PATH}" ]]; then
    dest_dir="$(dirname "${OUTPUT_PATH}")"
    run_cmd mkdir -p "${dest_dir}"
    printf '%s\n' "${OUTPUT_PATH}"
    return 0
  fi

  ts="$(date +%Y%m%d-%H%M%S)"
  run_cmd mkdir -p "${BACKUP_DIR}"
  printf '%s\n' "${BACKUP_DIR}/ocs-backup-${ts}.tar.gz"
}

main() {
  local sources=()
  local src=""
  while IFS= read -r src; do
    [[ -n "${src}" ]] && sources+=("${src}")
  done < <(collect_sources)

  if (( ${#sources[@]} == 0 )); then
    info "No OCS/OpenCode config/cache directories found to archive."
    return 0
  fi

  confirm_proceed "${sources[@]}"

  local archive
  archive="$(prepare_archive_path)"

  info "Archive destination: ${archive}"

  local rel_sources=()
  for src in "${sources[@]}"; do
    rel_sources+=("${src#/}")
  done

  run_cmd tar -C / -czf "${archive}" "${rel_sources[@]}"
  if (( DRY_RUN == 0 )); then
    success "Backup created: ${archive}"
  fi
}

main
