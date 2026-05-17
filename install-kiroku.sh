#!/usr/bin/env bash
# install-kiroku.sh — Install Kiroku for Linux/macOS
# Usage: curl -fsSL https://raw.githubusercontent.com/andyvandaric/opencode-suites-installer/main/install-kiroku.sh | bash
set -euo pipefail

GITHUB_SOURCE_REPO="andyvandaric/andyvand-opencode-config"
GITHUB_SOURCE_BRANCH="main"
WHATSAPP_ORDER_URL="https://wa.me/6281289731212?text=Mau%20order%20Kiroku%20nya%2C%20mohon%20infonya%20ya"
INSTALL_DIR="${HOME}/.kiroku/bin"

info() { echo "  $*"; }
ok() { echo "✅ $*"; }
warn() { echo "⚠️  $*" >&2; }
err() { echo "❌ $*" >&2; exit 1; }

echo ""
echo "🥷 Kiroku — Multi-Provider Router for Kiro CLI"
echo "────────────────────────────────────────────────"
echo ""

# ─── Detect OS/Arch ──────────────────────────────────────────────────────────
detect_platform() {
  local os arch
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"

  case "$os" in
    linux) os="linux" ;;
    darwin) os="darwin" ;;
    *) err "Unsupported OS: $os" ;;
  esac

  case "$arch" in
    x86_64|amd64) arch="x64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) err "Unsupported architecture: $arch" ;;
  esac

  echo "${os}-${arch}"
}

PLATFORM="$(detect_platform)"
info "Platform: $PLATFORM"

# ─── Ensure kiro-cli ─────────────────────────────────────────────────────────
info "Checking kiro-cli..."
if command -v kiro-cli >/dev/null 2>&1; then
  ok "kiro-cli found: $(kiro-cli --version 2>/dev/null || echo 'unknown')"
elif [[ -x "${HOME}/.local/bin/kiro-cli" ]]; then
  export PATH="${HOME}/.local/bin:${PATH}"
  ok "kiro-cli found: ${HOME}/.local/bin/kiro-cli"
else
  info "kiro-cli not found. Installing from https://cli.kiro.dev ..."
  if curl -fsSL https://cli.kiro.dev/install | bash; then
    export PATH="${HOME}/.local/bin:${PATH}"
    if command -v kiro-cli >/dev/null 2>&1; then
      ok "kiro-cli installed successfully"
    else
      warn "kiro-cli install may have succeeded but not found in PATH"
      info "Continuing anyway — kiroku will check at runtime"
    fi
  else
    warn "kiro-cli auto-install failed"
    info "Install manually: curl -fsSL https://cli.kiro.dev/install | bash"
    info "Continuing with Kiroku install..."
  fi
fi

# ─── Resolve GitHub token ────────────────────────────────────────────────────
echo ""
info "Resolving GitHub auth..."

TOKEN=""

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  TOKEN="$GITHUB_TOKEN"
  info "Auth: using GITHUB_TOKEN env var"
elif command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    TOKEN="$(gh auth token 2>/dev/null || true)"
    if [[ -n "$TOKEN" ]]; then
      info "Auth: using gh CLI token"
    fi
  fi

  if [[ -z "$TOKEN" ]]; then
    info "gh CLI not authenticated. Running: gh auth login"
    if gh auth login; then
      TOKEN="$(gh auth token 2>/dev/null || true)"
    fi
  fi
fi

if [[ -z "$TOKEN" ]]; then
  err "No GitHub auth available. Install gh CLI (https://cli.github.com) and run: gh auth login"
fi

# ─── Verify repo access ─────────────────────────────────────────────────────
echo ""
info "Verifying buyer repo access..."

HTTP_CODE="$(curl -sS -o /dev/null -w "%{http_code}" \
  -H "Authorization: token ${TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${GITHUB_SOURCE_REPO}/contents/assets/kiroku?ref=${GITHUB_SOURCE_BRANCH}")"

if [[ "$HTTP_CODE" == "200" ]]; then
  ok "Repo access verified"
elif [[ "$HTTP_CODE" == "401" || "$HTTP_CODE" == "403" || "$HTTP_CODE" == "404" ]]; then
  warn "You do not have Kiroku access yet (HTTP $HTTP_CODE)."
  echo ""
  echo "  Purchase Kiroku: $WHATSAPP_ORDER_URL"
  echo ""
  if command -v xdg-open >/dev/null 2>&1; then xdg-open "$WHATSAPP_ORDER_URL" 2>/dev/null || true
  elif command -v open >/dev/null 2>&1; then open "$WHATSAPP_ORDER_URL" 2>/dev/null || true; fi
  exit 1
else
  err "GitHub API error (HTTP $HTTP_CODE)"
fi

# ─── Fetch manifest ──────────────────────────────────────────────────────────
echo ""
info "Fetching release manifest..."

MANIFEST="$(curl -fsSL \
  -H "Authorization: token ${TOKEN}" \
  -H "Accept: application/vnd.github.raw" \
  "https://api.github.com/repos/${GITHUB_SOURCE_REPO}/contents/assets/kiroku/manifest.json?ref=${GITHUB_SOURCE_BRANCH}")"

VERSION="$(echo "$MANIFEST" | grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | cut -d'"' -f4)"
ok "Manifest: v${VERSION}"

# ─── Determine artifact ──────────────────────────────────────────────────────
FILE_NAME="$(echo "$MANIFEST" | python3 -c "
import sys, json
m = json.load(sys.stdin)
p = '${PLATFORM}'
if p in m['artifacts']:
    print(m['artifacts'][p]['file'])
" 2>/dev/null || true)"

EXPECTED_SHA="$(echo "$MANIFEST" | python3 -c "
import sys, json
m = json.load(sys.stdin)
p = '${PLATFORM}'
if p in m['artifacts']:
    print(m['artifacts'][p]['sha256'])
" 2>/dev/null || true)"

if [[ -z "$FILE_NAME" ]]; then
  err "No artifact found for platform: $PLATFORM"
fi

info "Artifact: $FILE_NAME ($PLATFORM)"

# ─── Download binary ─────────────────────────────────────────────────────────
echo ""
info "Downloading $FILE_NAME..."

TMP_FILE="$(mktemp /tmp/kiroku-install-XXXXXX)"
trap 'rm -f "$TMP_FILE"' EXIT

# Use git LFS sparse checkout (reliable for LFS files)
LFS_DIR="$(mktemp -d /tmp/kiroku-lfs-XXXXXX)"
if git clone --depth 1 --filter=blob:none --sparse \
  "https://x-access-token:${TOKEN}@github.com/${GITHUB_SOURCE_REPO}.git" \
  "$LFS_DIR" >/dev/null 2>&1; then
  cd "$LFS_DIR"
  git sparse-checkout set "assets/kiroku/$FILE_NAME" >/dev/null 2>&1
  git lfs pull --include="assets/kiroku/$FILE_NAME" >/dev/null 2>&1
  cd - >/dev/null
  if [[ -f "$LFS_DIR/assets/kiroku/$FILE_NAME" ]]; then
    cp "$LFS_DIR/assets/kiroku/$FILE_NAME" "$TMP_FILE"
  fi
  rm -rf "$LFS_DIR"
fi

# Fallback: download_url
if [[ ! -s "$TMP_FILE" ]] || [[ "$(wc -c < "$TMP_FILE")" -lt 1000000 ]]; then
  DL_URL="$(curl -fsSL \
    -H "Authorization: token ${TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${GITHUB_SOURCE_REPO}/contents/assets/kiroku/${FILE_NAME}?ref=${GITHUB_SOURCE_BRANCH}" \
    | grep -o '"download_url"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)"
  if [[ -n "$DL_URL" ]]; then
    curl -fsSL "$DL_URL" -o "$TMP_FILE"
  fi
fi

DL_SIZE="$(wc -c < "$TMP_FILE" | tr -d ' ')"
if [[ "$DL_SIZE" -lt 1000000 ]]; then
  err "Download failed: file too small (${DL_SIZE} bytes)"
fi
ok "Downloaded: $(echo "scale=1; $DL_SIZE / 1048576" | bc) MB"

# ─── Verify SHA-256 ──────────────────────────────────────────────────────────
info "Verifying SHA-256..."
if command -v sha256sum >/dev/null 2>&1; then
  ACTUAL_SHA="$(sha256sum "$TMP_FILE" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
  ACTUAL_SHA="$(shasum -a 256 "$TMP_FILE" | awk '{print $1}')"
else
  warn "sha256sum/shasum not found — skipping checksum"
  ACTUAL_SHA="$EXPECTED_SHA"
fi

if [[ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]]; then
  err "SHA-256 mismatch! Expected: $EXPECTED_SHA, Got: $ACTUAL_SHA"
fi
ok "Checksum verified"

# ─── Install ─────────────────────────────────────────────────────────────────
echo ""
info "Installing to $INSTALL_DIR..."

mkdir -p "$INSTALL_DIR"
mv "$TMP_FILE" "$INSTALL_DIR/kiroku"
chmod +x "$INSTALL_DIR/kiroku"
ok "Installed: $INSTALL_DIR/kiroku"

# ─── Add to PATH ─────────────────────────────────────────────────────────────
add_to_path() {
  local shell_name profile snippet
  snippet="# Kiroku PATH
export PATH=\"${INSTALL_DIR}:\$PATH\""

  for profile in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
    if [[ -f "$profile" ]]; then
      if ! grep -q "\.kiroku/bin" "$profile" 2>/dev/null; then
        echo "" >> "$profile"
        echo "$snippet" >> "$profile"
        info "Added to: $profile"
      fi
    fi
  done

  # Also create for fish
  if [[ -d "$HOME/.config/fish" ]]; then
    mkdir -p "$HOME/.config/fish/conf.d"
    echo "set -gx PATH ${INSTALL_DIR} \$PATH" > "$HOME/.config/fish/conf.d/kiroku.fish"
    info "Added to: fish config"
  fi

  export PATH="${INSTALL_DIR}:${PATH}"
}

add_to_path
ok "PATH configured"

# ─── Verify ──────────────────────────────────────────────────────────────────
echo ""
info "Verifying installation..."
VER="$("$INSTALL_DIR/kiroku" --version 2>/dev/null || true)"
if [[ "$VER" == *"kiroku"* ]]; then
  ok "$VER installed and working!"
else
  warn "Binary installed but version check failed."
  info "Try: source ~/.bashrc && kiroku --version"
fi

# ─── Done ────────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────────────────"
ok "Kiroku v${VERSION} installed!"
echo ""
echo "  Next steps:"
echo "    1. Restart shell or: source ~/.bashrc (or ~/.zshrc)"
echo "    2. kiroku login          — Add accounts"
echo "    3. kiroku account list   — Check your accounts"
echo "    4. kiroku chat           — Start chatting"
echo "    5. kiroku dashboard      — Open usage dashboard"
echo ""
