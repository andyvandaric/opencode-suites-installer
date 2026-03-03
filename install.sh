#!/usr/bin/env bash
# OpenCode Configuration Suite — Linux / macOS Installer
#
# One-liner install:
#   curl -fsSL https://raw.githubusercontent.com/andyvandaric/opencode-config-suites/main/install.sh | bash
#
set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; GRAY='\033[0;90m'; NC='\033[0m'
step()  { echo -e "\n${CYAN}▶  $*${NC}"; }
ok()    { echo -e "   ${GREEN}✅ $*${NC}"; }
warn()  { echo -e "   ${YELLOW}⚠️  $*${NC}"; }
fail()  { echo -e "   ${RED}❌ $*${NC}"; exit 1; }
info()  { echo -e "   ${GRAY}ℹ️  $*${NC}"; }

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  OpenCode Configuration Suite — Installer          ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo ""

OS="$(uname -s)"
info "Detected OS: $OS"

# ─── Helper ───────────────────────────────────────────────────────────────────
cmd_exists() { command -v "$1" &>/dev/null; }

ensure_local_ocs_shim() {
  local shim_dir="${HOME}/.local/bin"
  local shim_path="${shim_dir}/ocs"
  mkdir -p "${shim_dir}"
cat > "${shim_path}" <<EOF
#!/usr/bin/env bash
bun "${REPO_DIR}/bin/ocs.cjs" "\$@"
EOF
  chmod +x "${shim_path}"
  ok "Created local ocs shim: ${shim_path}"
  if ! echo ":$PATH:" | grep -q ":${shim_dir}:"; then
    warn "${shim_dir} is not in PATH. Add this line to your shell profile:"
    echo "      export PATH=\"${shim_dir}:\$PATH\""
  fi
}

# ─── 0. Pre-clean: Remove conflicting opencode-antigravity-auth ───────────────
step "Pre-clean: Removing conflicting 'opencode-antigravity-auth' plugin..."
CONFLICT_PKG="opencode-antigravity-auth"
_removed=0

# npm global
if cmd_exists npm && npm list -g --depth=0 2>/dev/null | grep -q "${CONFLICT_PKG}"; then
    info "Removing ${CONFLICT_PKG} via npm (global)..."
    npm uninstall -g "${CONFLICT_PKG}" 2>/dev/null && _removed=1 || true
fi

# bun global
if cmd_exists bun && bun pm ls -g 2>/dev/null | grep -q "${CONFLICT_PKG}"; then
    info "Removing ${CONFLICT_PKG} via bun (global)..."
    bun remove -g "${CONFLICT_PKG}" 2>/dev/null && _removed=1 || true
fi

# pnpm global
if cmd_exists pnpm && pnpm list -g --depth=0 2>/dev/null | grep -q "${CONFLICT_PKG}"; then
    info "Removing ${CONFLICT_PKG} via pnpm (global)..."
    pnpm remove -g "${CONFLICT_PKG}" 2>/dev/null && _removed=1 || true
fi

# yarn global
if cmd_exists yarn && yarn global list 2>/dev/null | grep -q "${CONFLICT_PKG}"; then
    info "Removing ${CONFLICT_PKG} via yarn (global)..."
    yarn global remove "${CONFLICT_PKG}" 2>/dev/null && _removed=1 || true
fi

# Remove from opencode plugin cache directories
for PLUGIN_DIR in \
    "${HOME}/.local/share/opencode/plugins" \
    "${HOME}/.config/opencode/plugins" \
    "${XDG_DATA_HOME:-${HOME}/.local/share}/opencode/plugins"
do
    if [ -d "${PLUGIN_DIR}/${CONFLICT_PKG}" ]; then
        info "Removing cached plugin at ${PLUGIN_DIR}/${CONFLICT_PKG}..."
        rm -rf "${PLUGIN_DIR:?}/${CONFLICT_PKG}" && _removed=1 || true
    fi
    # Also check versioned subdirs e.g. opencode-antigravity-auth@1.5.1
    for VERSIONED_DIR in "${PLUGIN_DIR}/${CONFLICT_PKG}"@*; do
        if [ -d "${VERSIONED_DIR}" ]; then
            info "Removing cached plugin at ${VERSIONED_DIR}..."
            rm -rf "${VERSIONED_DIR}" && _removed=1 || true
        fi
    done
done

if [ "${_removed}" -eq 1 ]; then
    ok "Conflicting plugin '${CONFLICT_PKG}' removed."
else
    info "No conflicting '${CONFLICT_PKG}' installation found — skipping."
fi

# ─── 1. Check / Install Git ───────────────────────────────────────────────────
step "Checking Git..."
if cmd_exists git; then
    ok "Git already installed: $(git --version)"
else
    warn "Git not found. Installing..."
    case "$OS" in
        Linux)
            if cmd_exists apt-get; then
                sudo apt-get update -qq && sudo apt-get install -y git
            elif cmd_exists dnf; then
                sudo dnf install -y git
            elif cmd_exists pacman; then
                sudo pacman -S --noconfirm git
            else
                fail "Cannot install Git automatically. Please install it manually: https://git-scm.com"
            fi
            ;;
        Darwin)
            if cmd_exists brew; then
                brew install git
            else
                # Xcode CLT includes git
                xcode-select --install 2>/dev/null || true
                warn "If git is still missing after this, install Xcode Command Line Tools."
            fi
            ;;
        *) fail "Unsupported OS: $OS" ;;
    esac
    ok "Git installed."
fi

# ─── 2. Check / Install Bun ───────────────────────────────────────────────────
step "Checking Bun..."
if cmd_exists bun; then
    ok "Bun already installed: v$(bun --version)"
else
    warn "Bun not found. Installing..."
    curl -fsSL https://bun.sh/install | bash
    # Make bun available in this session
    export BUN_INSTALL="${HOME}/.bun"
    export PATH="${BUN_INSTALL}/bin:${PATH}"
    ok "Bun installed."
fi

# ─── 3. Check / Install GitHub CLI ───────────────────────────────────────────
step "Checking GitHub CLI (gh)..."
if cmd_exists gh; then
    ok "gh already installed: $(gh --version | head -1)"
else
    warn "gh not found. Installing..."
    case "$OS" in
        Linux)
            if cmd_exists apt-get; then
                curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
                    | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
                    | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
                sudo apt-get update -qq && sudo apt-get install -y gh
            elif cmd_exists dnf; then
                sudo dnf install -y gh
            elif cmd_exists pacman; then
                sudo pacman -S --noconfirm github-cli
            else
                warn "Cannot install gh automatically. Install manually: https://cli.github.com"
            fi
            ;;
        Darwin)
            if cmd_exists brew; then
                brew install gh
            else
                warn "Homebrew not found. Install gh manually: https://cli.github.com"
            fi
            ;;
    esac
    cmd_exists gh && ok "GitHub CLI installed." || warn "gh not installed — private repo cloning may fail."
fi

# ─── 4. Clone or update repo ──────────────────────────────────────────────────
step "Setting up OpenCode config repo..."

REPO_URL="https://github.com/andyvandaric/opencode-config-suites.git"
DEFAULT_REPO_DIR="${HOME}/Dev/personal/opencode-config-suites"

# Auto-detect: if running from inside the repo already, use that directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/scripts/setup.js" ] && [ -d "${SCRIPT_DIR}/.git" ]; then
    REPO_DIR="${SCRIPT_DIR}"
    info "Detected local repo at ${REPO_DIR} — using it directly (skipping clone)."
    ok "Using local repo: ${REPO_DIR}"
else
    REPO_DIR="${DEFAULT_REPO_DIR}"

    if [ -d "${REPO_DIR}/.git" ]; then
        info "Repo already exists at ${REPO_DIR} — pulling latest..."
        cd "${REPO_DIR}"
        git fetch origin
        git pull --ff-only origin main && ok "Repo updated." || warn "Pull failed (possibly diverged). Please resolve manually."
    else
        mkdir -p "$(dirname "${REPO_DIR}")"
        if cmd_exists gh; then
            info "Cloning via GitHub CLI (supports private repos)..."
            gh repo clone andyvandaric/opencode-config-suites "${REPO_DIR}"
        else
            info "Cloning via git..."
            git clone "${REPO_URL}" "${REPO_DIR}"
        fi
        ok "Repo cloned to ${REPO_DIR}"
    fi
fi

cd "${REPO_DIR}"

# ─── 5. Install dependencies ──────────────────────────────────────────────────
step "Installing project dependencies (bun install)..."
bun install
ok "Dependencies installed."

# ─── 6. Run setup profile ─────────────────────────────────────────────────────
step "Running setup profile (deploys config to ~/.config/opencode)..."
bun run setup:profile
ok "Profile deployed."

# ─── 7. Install OpenCode CLI ──────────────────────────────────────────────────
step "Checking OpenCode CLI..."
if cmd_exists opencode; then
    ok "OpenCode already installed: $(opencode --version 2>&1 || true)"
else
    info "Installing OpenCode CLI via bun..."
    bun install -g opencode-ai && ok "OpenCode CLI installed." \
        || warn "Could not install OpenCode CLI. Install manually: https://opencode.ai"
fi

# ─── 8. Ensure OCS global command ─────────────────────────────────────────────
step "Checking OCS command..."
if cmd_exists ocs; then
    ok "OCS already available: $(ocs --version 2>/dev/null || echo unknown)"
else
    info "Attempting global install for OCS..."
    if bun install -g @andyvandaric/opencode-config-suites >/dev/null 2>&1; then
        ok "Installed OCS globally from npm registry."
    else
        warn "Global install unavailable right now. Falling back to local shim."
        ensure_local_ocs_shim
    fi
fi

if cmd_exists ocs; then
    info "Verifying OCS commands..."
    ocs --version >/dev/null 2>&1 || warn "ocs --version failed"
    ocs --help >/dev/null 2>&1 || warn "ocs --help failed"
    ocs setup profile --help >/dev/null 2>&1 || warn "ocs setup profile --help failed"
    ocs prefs --dry-run </dev/null >/dev/null 2>&1 || warn "ocs prefs --dry-run failed"
fi

# ─── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅  Installation complete!                        ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${NC}Next steps:"
echo -e "  1. Configure profile globally:"
echo -e "     ${YELLOW}ocs setup profile${NC}"
echo -e "  2. Tune preferences wizard:"
echo -e "     ${YELLOW}ocs prefs${NC}"
echo -e "  3. Add your Antigravity/OpenAI account:"
echo -e "     ${YELLOW}opencode auth login${NC}"
echo -e "  4. Start OpenCode in any project folder:"
echo -e "     ${YELLOW}opencode${NC}"
echo ""
echo -e "  ${GRAY}To update later:"
echo -e "    cd ${REPO_DIR}"
echo -e "    git pull --ff-only origin main"
echo -e "    ocs setup profile${NC}"
echo ""
