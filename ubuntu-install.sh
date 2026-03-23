#!/bin/bash
set -eu

# Require root or sudo
if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root or with sudo" >&2
  exit 1
fi

WORK_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT INT TERM

# Make sure lsb_release exists
if ! command -v lsb_release >/dev/null 2>&1; then
  echo "Error: lsb_release is required but not installed" >&2
  exit 1
fi

# detecting ubuntu 22.04, 24.04, 24.10 else exit
UBUNTU_VERSION="$(lsb_release -rs)"

if [[ "$UBUNTU_VERSION" == "22.04" ]]; then
  echo "Detected Ubuntu 22.04"
  PLATFORM="UBUNTU_22_NA"
elif [[ "$UBUNTU_VERSION" == "24.04" ]]; then
  echo "Detected Ubuntu 24.04"
  PLATFORM="UBUNTU_24_NA"
elif [[ "$UBUNTU_VERSION" == "24.10" ]]; then
  echo "Detected Ubuntu 24.10"
  PLATFORM="UBUNTU_24_10_NA"
else
  echo "Unsupported Ubuntu version: $UBUNTU_VERSION" >&2
  exit 1
fi

API_BASE="https://api-in.kitecyber.com"
CONSOLE_BASE="https://console-in.kitecyber.com"
API_URL="${API_BASE}/agent-download?p=${PLATFORM}&t=PRIVILEGED_INSTALL"
RESPONSE_JSON="$WORK_DIR/response.json"

echo "Detected platform is ${PLATFORM}"
echo "Fetching download metadata..."

echo "url: ${API_URL}..."

curl -fsSL "$API_URL" \
  -H "accept: application/json" \
  -H "origin: $CONSOLE_BASE" \
  -H "referer: $CONSOLE_BASE/" \
  -o "$RESPONSE_JSON"

# Parse JSON using jq if available, otherwise fall back to sed
if command -v jq >/dev/null 2>&1; then
  DOWNLOAD_URL="$(jq -r '.download_url // empty' "$RESPONSE_JSON")"
  FILE_NAME="$(jq -r '.file_name // empty' "$RESPONSE_JSON")"
else
  DOWNLOAD_URL="$(sed -n 's/.*"download_url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$RESPONSE_JSON" | head -n 1)"
  FILE_NAME="$(sed -n 's/.*"file_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$RESPONSE_JSON" | head -n 1)"
fi

if [ -z "$DOWNLOAD_URL" ] || [ -z "$FILE_NAME" ]; then
  echo "Error: Failed to get download URL or file name from API response" >&2
  echo "Response was:" >&2
  cat "$RESPONSE_JSON" >&2
  exit 1
fi

PKG_PATH="$WORK_DIR/$FILE_NAME"

echo "Downloading $FILE_NAME..."
curl -fL "$DOWNLOAD_URL" -o "$PKG_PATH"

echo "Installing package..."

case "$FILE_NAME" in
  *.tar.gz)
    EXTRACT_DIR="$WORK_DIR/extracted"
    rm -rf "$EXTRACT_DIR"
    mkdir -p "$EXTRACT_DIR"

    echo "Extracting archive..."
    tar -xzf "$PKG_PATH" -C "$EXTRACT_DIR"

    INSTALL_SCRIPT="$(find "$EXTRACT_DIR" -type f -name install.sh | head -n 1)"

    if [ -z "$INSTALL_SCRIPT" ]; then
      echo "Error: install.sh not found in archive" >&2
      exit 1
    fi

    chmod +x "$INSTALL_SCRIPT"
    echo "Running installer..."
    bash "$INSTALL_SCRIPT"
    ;;
  *.deb)
    echo "Installing .deb package..."
    if ! command -v dpkg >/dev/null 2>&1; then
      echo "Error: dpkg is not available on this system" >&2
      exit 1
    fi

    dpkg -i "$PKG_PATH" || apt-get -f install -y
    ;;
  *)
    echo "Error: Unsupported package type: $FILE_NAME" >&2
    exit 1
    ;;
esac

echo "Install completed successfully."