#!/usr/bin/env bash
# install-plugin.sh — Install opencode-multi-auth plugin for OpenCode Config Suites
# Supports 3 auth paths: gh CLI → GITHUB_TOKEN env → interactive prompt
set -euo pipefail

# ─── Config ──────────────────────────────────────────────────────────────────
GITHUB_RELEASES_REPO="andyvandaric/opencode-config-suites-releases"
PLUGIN_DIR="./plugins/opencode-multi-auth"
TOKEN_FILE="${HOME}/.opencode-suites/.token"
TMP_DIR="$(mktemp -d /tmp/ocs-install-XXXXXX)"

# ─── Cleanup on exit ─────────────────────────────────────────────────────────
trap 'rm -rf "${TMP_DIR}"' EXIT

# ─── Helpers ─────────────────────────────────────────────────────────────────
info()    { echo "  $*"; }
success() { echo "✅ $*"; }
error()   { echo "❌ $*" >&2; exit 1; }
warn()    { echo "⚠️  $*" >&2; }

# ─── Auth: resolve GitHub token ───────────────────────────────────────────────
resolve_token() {
  # Path 1: gh CLI
  if command -v gh &>/dev/null; then
    if ! gh auth status &>/dev/null; then
      warn "GitHub CLI (gh) is installed but not authenticated."
      info "Logging in via GitHub CLI (browser flow)..."
      gh auth login --git-protocol https -w
    fi

    GH_TOKEN="$(gh auth token 2>/dev/null)"
    if [[ -n "${GH_TOKEN}" ]]; then
      echo "  Auth: using gh CLI token" >&2
      echo "${GH_TOKEN}"
      return 0
    fi
  else
    warn "GitHub CLI (gh) is not installed. It is highly recommended for managing access."
    warn "Please install it from https://cli.github.com/ or provide a token manually."
  fi
  if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
    GH_TOKEN="$(gh auth token 2>/dev/null)"
    if [[ -n "${GH_TOKEN}" ]]; then
      echo "  Auth: using gh CLI token" >&2
      echo "${GH_TOKEN}"
      return 0
    fi
  fi

  # Path 2: GITHUB_TOKEN env var
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    echo "  Auth: using GITHUB_TOKEN environment variable" >&2
    echo "${GITHUB_TOKEN}"
    return 0
  fi

  # Path 3: stored token file
  if [[ -f "${TOKEN_FILE}" ]]; then
    local stored_token
    stored_token="$(cat "${TOKEN_FILE}")"
    if [[ -n "${stored_token}" ]]; then
      echo "  Auth: using stored token from ${TOKEN_FILE}" >&2
      echo "${stored_token}"
      return 0
    fi
  fi

  # Path 3b: interactive prompt
  warn "No GitHub token found. Generate one at:"
  warn "https://github.com/settings/tokens/new?scopes=repo"
  echo ""
  read -rsp "GitHub Personal Access Token (repo scope): " token </dev/tty
  echo ""

  if [[ -z "${token}" ]]; then
    error "No token provided. Cannot continue."
  fi

  # Save for future use
  mkdir -p "$(dirname "${TOKEN_FILE}")"
  echo "${token}" > "${TOKEN_FILE}"
  chmod 600 "${TOKEN_FILE}"
  echo "  Token saved to ${TOKEN_FILE}" >&2
  echo "${token}"
}

# ─── Verify repo access ───────────────────────────────────────────────────────
verify_access() {
  local token="$1"
  local status_code
  status_code="$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: token ${token}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${GITHUB_RELEASES_REPO}/releases/latest")"

  if [[ "${status_code}" == "403" || "${status_code}" == "404" ]]; then
    error "Cannot access repo ${GITHUB_RELEASES_REPO} (HTTP ${status_code}). Check token scopes or repo access."
  elif [[ "${status_code}" != "200" ]]; then
    error "Unexpected response from GitHub API (HTTP ${status_code})."
  fi

  info "Repo access verified (HTTP ${status_code})"
}

# ─── Get latest release info ──────────────────────────────────────────────────
get_release_info() {
  local token="$1"
  local api_url="https://api.github.com/repos/${GITHUB_RELEASES_REPO}/releases/latest"

  if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
    gh api "repos/${GITHUB_RELEASES_REPO}/releases/latest" 2>/dev/null
  else
    curl -fsSL \
      -H "Authorization: token ${token}" \
      -H "Accept: application/vnd.github+json" \
      "${api_url}"
  fi
}

# ─── Download asset ───────────────────────────────────────────────────────────
download_asset() {
  local token="$1"
  local download_url="$2"
  local output="$3"

  if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
    gh release download \
      --repo "${GITHUB_RELEASES_REPO}" \
      --pattern "$(basename "${output}")" \
      --dir "${TMP_DIR}" 2>/dev/null || true
  fi

  if [[ ! -f "${output}" ]]; then
    curl -fsSL \
      -H "Authorization: token ${token}" \
      -H "Accept: application/octet-stream" \
      -L "${download_url}" \
      -o "${output}"
  fi
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
  curl -fsSL https://bun.sh/install | bash
  
  # Source bun environment for current session
  if [[ -f "${HOME}/.bashrc" ]]; then
    # shellcheck source=/dev/null
    source "${HOME}/.bashrc" || true
  fi
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
  echo ""
  echo "🔌 opencode-multi-auth — Plugin Installer"
  echo "────────────────────────────────────────"

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
# Check if we are running in the repo locally
is_local_source=false
if [[ -f "./plugins/opencode-multi-auth/package.json" || -f "./package.json" ]]; then
  is_local_source=true
fi

  echo ""
  info "Resolving GitHub auth..."
  local token
  token="$(resolve_token)"

  echo ""
  info "Verifying repo access..."
  verify_access "${token}"

  echo ""
  info "Fetching latest release..."
  local release_json
  release_json="$(get_release_info "${token}")"

  local version
  version="$(echo "${release_json}" | grep -o '"tag_name": *"[^"]*"' | head -1 | grep -o '"[^"]*"$' | tr -d '"')"
  info "Latest version: ${version}"

  # Find tar.gz asset URL
  local tar_url
  tar_url="$(echo "${release_json}" | grep -o '"browser_download_url": *"[^"]*\.tar\.gz"' | head -1 | grep -o '"https[^"]*"' | tr -d '"')"

  if [[ -z "${tar_url}" ]]; then
    error "No .tar.gz asset found in latest release."
  fi

  local tar_filename
  tar_filename="$(basename "${tar_url}")"
  local tar_path="${TMP_DIR}/${tar_filename}"

  echo ""
  info "Downloading ${tar_filename}..."
  download_asset "${token}" "${tar_url}" "${tar_path}"

  # Download SHA256SUMS
  local sums_url
  sums_url="$(echo "${release_json}" | grep -o '"browser_download_url": *"[^"]*SHA256SUMS[^"]*"' | head -1 | grep -o '"https[^"]*"' | tr -d '"' || true)"
  local sums_path="${TMP_DIR}/SHA256SUMS"

  if [[ -n "${sums_url}" ]]; then
    curl -fsSL \
      -H "Authorization: token ${token}" \
      -H "Accept: application/octet-stream" \
      -L "${sums_url}" \
      -o "${sums_path}"

    # Extract tar into tmp for verification
    local verify_dir="${TMP_DIR}/verify"
    mkdir -p "${verify_dir}"
    tar -xzf "${tar_path}" -C "${verify_dir}" --strip-components=1
    cp "${sums_path}" "${verify_dir}/SHA256SUMS"
    verify_sha256 "${verify_dir}/SHA256SUMS" "${verify_dir}"
  else
    warn "SHA256SUMS not found in release — skipping checksum verification"
  fi

  echo ""
  info "Extracting to ${PLUGIN_DIR}..."
  mkdir -p "${PLUGIN_DIR}"
  local extract_tmp="${TMP_DIR}/extract"
  mkdir -p "${extract_tmp}"
  tar -xzf "${tar_path}" -C "${extract_tmp}" --strip-components=1
  cp -R "${extract_tmp}/"* "${PLUGIN_DIR}/"

  echo ""
  info "Installing dependencies..."
  local root_dir="${PWD}"
  cd "${PLUGIN_DIR}"
  bun install --frozen-lockfile 2>/dev/null || bun install

  echo ""
  success "opencode-multi-auth ${version} installed to ${PLUGIN_DIR}"
  echo ""
  info "Running setup script..."
  local setup_script
  if [[ "${is_local_source}" == "true" ]]; then
    setup_script="${root_dir}/scripts/setup.js"
  else
    setup_script="${root_dir}/${PLUGIN_DIR}/scripts/setup.js"
  fi

  if [[ "${OCS_SKIP_AUTO_SETUP:-0}" == "1" ]]; then
    warn "Skipping auto setup because OCS_SKIP_AUTO_SETUP=1"
  else
    if bun "${setup_script}" --headless --profile codex-5.3-all --mode balanced; then
      success "Setup completed automatically (headless)."
    else
      warn "Headless setup failed. Falling back to interactive setup..."
      if ! bun "${setup_script}"; then
        error "Setup script failed."
      fi
    fi
  fi

  echo ""
  success "opencode-multi-auth ${version} installed and configured!"
  echo ""
  echo "   Next steps:"
  echo "   1. Verify runtime: opencode auth login"
  echo "   2. Start coding!"
  echo ""
}

main "$@"
