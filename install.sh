#!/usr/bin/env bash
set -euo pipefail

GH_REPO="geodica/conflab-dist"
INSTALL_DIR="${CONFLAB_INSTALL_DIR:-/usr/local/bin}"
BINARY_NAME="conflab"

# --- Detect platform ---

detect_platform() {
  local os arch target

  os="$(uname -s)"
  arch="$(uname -m)"

  case "$os" in
    Darwin) os="apple-darwin" ;;
    Linux)  os="unknown-linux-gnu" ;;
    *)
      echo "Error: unsupported operating system: $os"
      exit 1
      ;;
  esac

  case "$arch" in
    arm64|aarch64) arch="aarch64" ;;
    x86_64)        arch="x86_64" ;;
    *)
      echo "Error: unsupported architecture: $arch"
      exit 1
      ;;
  esac

  target="${arch}-${os}"
  echo "$target"
}

# --- Main ---

TARGET=$(detect_platform)
DOWNLOAD_URL="https://github.com/${GH_REPO}/releases/latest/download/${BINARY_NAME}-${TARGET}"

echo "Conflab CLI Installer"
echo ""
echo "  Platform:  ${TARGET}"
echo "  Source:    ${DOWNLOAD_URL}"
echo "  Install:   ${INSTALL_DIR}/${BINARY_NAME}"
echo ""

# Download
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

echo "==> Downloading..."
if ! curl -fSL --progress-bar -o "$TMPFILE" "$DOWNLOAD_URL"; then
  echo ""
  echo "Error: download failed. Binary may not be available for ${TARGET} yet."
  echo "Check https://github.com/${GH_REPO}/releases for available platforms."
  exit 1
fi

chmod +x "$TMPFILE"

# Remove macOS quarantine if present
if [ "$(uname -s)" = "Darwin" ]; then
  xattr -d com.apple.quarantine "$TMPFILE" 2>/dev/null || true
fi

# Install
if [ -w "$INSTALL_DIR" ]; then
  mv "$TMPFILE" "${INSTALL_DIR}/${BINARY_NAME}"
else
  echo "==> Installing to ${INSTALL_DIR} (requires sudo)..."
  sudo mv "$TMPFILE" "${INSTALL_DIR}/${BINARY_NAME}"
fi

chmod +x "${INSTALL_DIR}/${BINARY_NAME}"

echo "==> Installed: ${INSTALL_DIR}/${BINARY_NAME}"
echo ""

# Verify
if command -v "$BINARY_NAME" >/dev/null 2>&1; then
  echo "==> Version:"
  "$BINARY_NAME" --version 2>/dev/null || true
  echo ""
  echo "Run 'conflab --help' to get started."
else
  echo "Warning: '${BINARY_NAME}' is not on your PATH."
  echo "Add ${INSTALL_DIR} to your PATH, or move the binary:"
  echo ""
  echo "  export PATH=\"${INSTALL_DIR}:\$PATH\""
fi
