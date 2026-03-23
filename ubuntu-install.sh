#!/bin/sh
set -e

WORK_DIR=$(mktemp -d)

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

# Detect Ubuntu version
if [ ! -f /etc/os-release ]; then
  echo "Error: Cannot detect OS version (/etc/os-release not found)" >&2
  exit 1
fi

. /etc/os-release

if [ "$ID" != "ubuntu" ]; then
  echo "Error: This script only supports Ubuntu. Detected: $ID" >&2
  exit 1
fi

MAJOR=$(echo "$VERSION_ID" | cut -d. -f1)
MINOR=$(echo "$VERSION_ID" | cut -d. -f2)

if [ "$MAJOR" -eq 24 ] && [ "$MINOR" -eq 10 ]; then
  PLATFORM="UBUNTU_24_10_NA"
elif [ "$MAJOR" -eq 24 ] && [ "$MINOR" -eq 4 ]; then
  PLATFORM="UBUNTU_24_NA"
elif [ "$MAJOR" -eq 22 ]; then
  PLATFORM="UBUNTU_22_NA"
else
  echo "Error: Unsupported Ubuntu version: $VERSION_ID (supported: 22.04, 24.04, 24.10)" >&2
  exit 1
fi

API_URL="https://api-in.kitecyber.com/agent-download?p=${PLATFORM}&t=PRIVILEGED_INSTALL"

echo "Detected Ubuntu $VERSION_ID (using $PLATFORM)"
echo "Fetching download URL..."
curl -fsSL "$API_URL" -o "$WORK_DIR/response.json"

DOWNLOAD_URL=$(sed -n 's/.*"download_url":"\([^"]*\)".*/\1/p' "$WORK_DIR/response.json")
FILE_NAME=$(sed -n 's/.*"file_name":"\([^"]*\)".*/\1/p' "$WORK_DIR/response.json")

if [ -z "$DOWNLOAD_URL" ]; then
  echo "Error: Failed to get download URL" >&2
  exit 1
fi

echo "Downloading $FILE_NAME..."
curl -fsSL "$DOWNLOAD_URL" -o "$WORK_DIR/$FILE_NAME"

echo "Extracting..."
tar -xzf "$WORK_DIR/$FILE_NAME" -C "$WORK_DIR"

INSTALL_SCRIPT=$(find "$WORK_DIR" -name "install.sh" -type f | head -1)

if [ -z "$INSTALL_SCRIPT" ]; then
  echo "Error: install.sh not found in archive" >&2
  exit 1
fi

chmod +x "$INSTALL_SCRIPT"

echo "Running installer (requires sudo)..."
sudo "$INSTALL_SCRIPT"
