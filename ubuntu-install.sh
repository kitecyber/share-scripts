#!/bin/sh
set -e

WORK_DIR="$HOME/Downloads/kitecyber-install"
mkdir -p "$WORK_DIR"

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

# Find the extracted folder
EXTRACT_DIR=$(find "$WORK_DIR" -mindepth 1 -maxdepth 1 -type d | head -1)

if [ -z "$EXTRACT_DIR" ]; then
  echo "Error: No extracted folder found" >&2
  exit 1
fi

echo "Extracted to: $EXTRACT_DIR"

# Verify .deb file is present
DEB_FILE=$(find "$EXTRACT_DIR" -name "*.deb" -type f | head -1)

if [ -z "$DEB_FILE" ]; then
  echo "Error: No .deb file found in $EXTRACT_DIR" >&2
  exit 1
fi

echo "Found package: $(basename "$DEB_FILE")"

if [ ! -f "$EXTRACT_DIR/install.sh" ]; then
  echo "Error: install.sh not found in $EXTRACT_DIR" >&2
  exit 1
fi

chmod +x "$EXTRACT_DIR/install.sh"

echo "Running installer..."
cd "$EXTRACT_DIR"
sudo bash install.sh
