#!/bin/bash

set -e

echo "[*] Uninstalling KiteCyber..."

# Get currently logged-in GUI user
GUI_USER=$(stat -f%Su /dev/console)
USER_ID=$(id -u "$GUI_USER")

# Paths
LAUNCHAGENT_PLIST="/Library/LaunchAgents/com.kitecyber.clientagent.plist"
LAUNCHDAEMON_PLIST="/Library/LaunchDaemons/com.kitecyber.clientagent.plist"
APP_PATH="/Applications/clientagent.app"
KITECYBER_DIR="/usr/local/bin/kitecyber"
BOOTSTRAP_SCRIPT="$KITECYBER_DIR/bootstrap_agent.sh"
INFO_PLIST="$APP_PATH/Contents/Info.plist"

# Stop and remove LaunchAgent
if [ -f "$LAUNCHAGENT_PLIST" ]; then
    echo "[*] Stopping LaunchAgent..."
    sudo launchctl bootout gui/$USER_ID "$LAUNCHAGENT_PLIST" 2>/dev/null || true
    sudo launchctl remove com.kitecyber.clientagent 2>/dev/null || true
    sudo rm -f "$LAUNCHAGENT_PLIST"
fi

# Stop and remove LaunchDaemon
if [ -f "$LAUNCHDAEMON_PLIST" ]; then
    echo "[*] Stopping LaunchDaemon..."
    sudo launchctl bootout system "$LAUNCHDAEMON_PLIST" 2>/dev/null || true
    sudo launchctl remove com.kitecyber.bootstrap 2>/dev/null || true
    sudo rm -f "$LAUNCHDAEMON_PLIST"
fi

# Remove installed app
if [ -d "$APP_PATH" ]; then
    echo "[*] Removing application..."
    sudo rm -rf "$APP_PATH"
fi

# Remove custom files
if [ -d "$KITECYBER_DIR" ]; then
    echo "[*] Removing /usr/local/bin/kitecyber..."
    sudo rm -rf "$KITECYBER_DIR"
fi

if [ -d /Applications/clientagent.app.backup ]; then
    echo "[*] Removing application backup..."
    sudo rm -rf /Applications/clientagent.app.backup
fi

# Clean up logs if present
sudo rm -f /tmp/kitecyber-bootstrap.out
sudo rm -f /tmp/kitecyber-bootstrap.err

# if clientagent process is running, kill it, if its fails kills untill success
CLIENTAGENT_PID=$(pgrep -f "clientagent.app/Contents/MacOS/clientagent" || true)
if [ -n "$CLIENTAGENT_PID" ]; then
    echo "[*] Terminating clientagent process..."
    while kill -0 "$CLIENTAGENT_PID" 2>/dev/null; do
        sudo kill -9 "$CLIENTAGENT_PID" || true
        sleep 1
    done
# Added to kill the clientagent monitor process
sudo pkill -9 clientagent
fi

echo "[*] Cleaning up user data..."

USER_HOME=$(eval echo "~$GUI_USER")

rm -f "$USER_HOME/Library/Preferences/com.kitecyber.clientagent.plist"
# Added missing delete
rm -f "$USER_HOME/Library/Preferences/com.kitecyber.clientagent.kc-config.plist"
rm -rf "$USER_HOME/Library/Application Support/com.kitecyber.clientagent"
rm -rf "$USER_HOME/Library/Caches/com.kitecyber.clientagent"
rm -rf "$USER_HOME/Library/Saved Application State/com.kitecyber.clientagent.savedState"
rm -f "$USER_HOME/Library/LaunchAgents/com.kitecyber.clientagent.plist"

# Flush cached preferences
killall cfprefsd 2>/dev/null || true

# Optional: Remove package receipt
pkgutil --forget com.kitecyber.clientagent 2>/dev/null || true


echo "[✔] KiteCyber has been completely uninstalled."

