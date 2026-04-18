#!/bin/sh
set -eu

EXIT_OK=0
EXIT_FATAL=1
EXIT_ARG=2

YES_MODE=0
DRY_RUN=0
STEP=0
TOTAL_STEPS=8

info() {
  printf '  %s\n' "$*"
}

success() {
  printf 'OK    %s\n' "$*"
}

warn() {
  printf 'WARN  %s\n' "$*" >&2
}

fail_arg() {
  printf 'ERROR %s\n' "$*" >&2
  exit "$EXIT_ARG"
}

fail_fatal() {
  printf 'ERROR %s\n' "$*" >&2
  exit "$EXIT_FATAL"
}

show_usage() {
  cat <<'EOF'
Usage: uninstall.sh [options]

Options:
  --yes, -y            Non-interactive confirmation
  --dry-run            Print actions without mutating filesystem
  --help, -h           Show this help

Environment:
  OCS_TARGET_HOME      Home directory to clean when running via sudo

Behavior:
  - Fully removes ~/.config/opencode and other OCS/OpenCode runtime data
  - No safe/partial mode
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --yes|-y)
        YES_MODE=1
        shift
        ;;
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --help|-h)
        show_usage
        exit "$EXIT_OK"
        ;;
      *)
        fail_arg "Unknown option: $1"
        ;;
    esac
  done
}

resolve_home() {
  if [ -n "${OCS_TARGET_HOME:-}" ]; then
    printf '%s\n' "$OCS_TARGET_HOME"
    return 0
  fi

  if [ -n "${HOME:-}" ]; then
    printf '%s\n' "$HOME"
    return 0
  fi

  if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    if command -v getent >/dev/null 2>&1; then
      sudo_home="$(getent passwd "$SUDO_USER" | cut -d: -f6 2>/dev/null || true)"
      if [ -n "$sudo_home" ]; then
        printf '%s\n' "$sudo_home"
        return 0
      fi
    fi
  fi

  if command -v getent >/dev/null 2>&1; then
    user_home="$(getent passwd "$(id -u)" | cut -d: -f6 2>/dev/null || true)"
    if [ -n "$user_home" ]; then
      printf '%s\n' "$user_home"
      return 0
    fi
  fi

  if eval "printf '%s' ~" >/dev/null 2>&1; then
    eval "printf '%s\n' ~"
    return 0
  fi

  if [ -n "${TMPDIR:-}" ]; then
    printf '%s\n' "$TMPDIR"
    return 0
  fi

  printf '%s\n' "/tmp"
}

next_step() {
  STEP=$((STEP + 1))
  printf '\n[%s/%s] %s\n' "$STEP" "$TOTAL_STEPS" "$*"
}

run_cmd() {
  if [ "$DRY_RUN" -eq 1 ]; then
    info "[dry-run] $*"
    return 0
  fi
  "$@"
}

remove_path_if_exists() {
  path="$1"
  if [ ! -e "$path" ] && [ ! -L "$path" ]; then
    return 0
  fi
  info "REMOVE $path"
  run_cmd rm -rf "$path"
}

cleanup_opencode_config() {
  config_dir="$HOME/.config/opencode"
  auth_dir="$config_dir/auth"

  if [ ! -e "$config_dir" ]; then
    return 0
  fi

  if [ ! -e "$auth_dir" ]; then
    remove_path_if_exists "$config_dir"
    return 0
  fi

  info "PRESERVE $auth_dir"
  for entry in "$config_dir"/* "$config_dir"/.[!.]* "$config_dir"/..?*; do
    if [ ! -e "$entry" ] && [ ! -L "$entry" ]; then
      continue
    fi
    if [ "$entry" = "$auth_dir" ]; then
      continue
    fi
    remove_path_if_exists "$entry"
  done
}

remove_system_link_if_installer_managed() {
  link_path="$1"
  if [ ! -e "$link_path" ] && [ ! -L "$link_path" ]; then
    return 0
  fi

  if [ ! -L "$link_path" ]; then
    warn "Skip $link_path (not a symlink)"
    return 0
  fi

  target="$(readlink "$link_path" 2>/dev/null || true)"
  case "$target" in
    *"/.local/bin/"*|*"/.bun/bin/"*|*"/.opencode/bin/"*)
      info "REMOVE managed symlink $link_path -> $target"
      if [ "$DRY_RUN" -eq 1 ]; then
        info "[dry-run] rm -f $link_path"
      elif rm -f "$link_path" 2>/dev/null; then
        :
      elif command -v sudo >/dev/null 2>&1; then
        sudo rm -f "$link_path" >/dev/null 2>&1 || warn "Failed to remove $link_path"
      else
        warn "Failed to remove $link_path"
      fi
      ;;
    *)
      warn "Skip $link_path (target not installer-managed: $target)"
      ;;
  esac
}

kill_related_processes() {
  if ! command -v pkill >/dev/null 2>&1; then
    warn "pkill not found; skip process cleanup"
    return 0
  fi

  for pattern in '(^|/)opencode( |$)' '(^|/)ocs( |$)' '\.opencode/bin/opencode'; do
    if [ "$DRY_RUN" -eq 1 ]; then
      info "[dry-run] pkill -f $pattern"
    else
      pkill -f "$pattern" >/dev/null 2>&1 || true
    fi
  done
}

uninstall_global_packages() {
  if command -v bun >/dev/null 2>&1; then
    for pkg in opencode-ai '@opencode-ai/opencode'; do
      if [ "$DRY_RUN" -eq 1 ]; then
        info "[dry-run] bun remove -g $pkg"
      else
        bun remove -g "$pkg" >/dev/null 2>&1 || warn "bun remove -g $pkg failed (non-fatal)"
      fi
    done
  fi

  if command -v npm >/dev/null 2>&1; then
    for pkg in opencode-ai '@opencode-ai/opencode'; do
      if [ "$DRY_RUN" -eq 1 ]; then
        info "[dry-run] npm uninstall -g $pkg"
      else
        npm uninstall -g "$pkg" >/dev/null 2>&1 || warn "npm uninstall -g $pkg failed (non-fatal)"
      fi
    done
  fi
}

print_plan() {
  printf '\nTarget HOME: %s\n' "$HOME"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'Dry-run: enabled\n'
  fi

  cat <<'EOF'

Will remove:
  - ~/.config/opencode except ~/.config/opencode/auth
  - ~/.opencode
  - ~/.opencode-suites
  - ~/.cache/opencode
  - ~/.local/share/opencode
  - local shims and installer-managed links
  - global package links (best effort)

Will preserve:
  - ~/.config/opencode/auth
EOF
}

confirm_uninstall() {
  print_plan

  if [ "$YES_MODE" -eq 1 ]; then
    return 0
  fi

  printf '\nThis removes ~/.config/opencode except the auth directory.\n'
  printf 'Continue? [y/N]\n'
  answer=""
  read -r answer || true
  case "$answer" in
    y|Y|yes|YES)
      ;;
    *)
      info "Cancelled."
      exit 0
      ;;
  esac
}

verify_cleanup() {
  found=0
  if command -v ocs >/dev/null 2>&1; then
    warn "ocs still resolves to: $(command -v ocs)"
    found=1
  fi
  if command -v opencode >/dev/null 2>&1; then
    warn "opencode still resolves to: $(command -v opencode)"
    found=1
  fi

  if [ "$found" -eq 0 ]; then
    success "No ocs/opencode command found in current PATH."
  else
    warn "Some commands still resolve. Open a new shell or run: hash -r"
  fi
}

parse_args "$@"
HOME="$(resolve_home)"
export HOME

next_step "Confirm uninstall plan"
confirm_uninstall

next_step "Stop related processes"
kill_related_processes

next_step "Remove local command shims"
remove_path_if_exists "$HOME/.local/bin/ocs"
remove_path_if_exists "$HOME/.local/bin/opencode"
remove_path_if_exists "$HOME/.bun/bin/ocs"
remove_path_if_exists "$HOME/.bun/bin/opencode"
remove_path_if_exists "$HOME/.opencode/bin/ocs"
remove_path_if_exists "$HOME/.opencode/bin/opencode"

next_step "Remove installer-managed /usr/local/bin symlinks"
remove_system_link_if_installer_managed "/usr/local/bin/ocs"
remove_system_link_if_installer_managed "/usr/local/bin/opencode"

next_step "Remove global packages (best effort)"
uninstall_global_packages

next_step "Remove runtime/cache directories"
remove_path_if_exists "$HOME/.opencode"
remove_path_if_exists "$HOME/.opencode-suites"
remove_path_if_exists "$HOME/.cache/opencode"
remove_path_if_exists "$HOME/.local/share/opencode"

next_step "Clean ~/.config/opencode (preserve auth)"
cleanup_opencode_config

hash -r 2>/dev/null || true

next_step "Verify command/path state"
verify_cleanup

success "Uninstall flow completed."
cat <<'EOF'

Next step (clean-room reinstall test):
  sh -c 'curl -fsSL https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/staging/v2.3.1/install.sh | sh'
EOF

exit "$EXIT_OK"
