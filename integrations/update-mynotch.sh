#!/usr/bin/env bash
# Installs the latest MyNotch release into /Applications and relaunches it.
# Works from anywhere, no GitHub account needed (the repository is public):
#   curl -fsSL https://raw.githubusercontent.com/LouisVct/mynotch/main/integrations/update-mynotch.sh | bash
set -euo pipefail

URL="https://github.com/LouisVct/mynotch/releases/latest/download/MyNotch.dmg"
APP="/Applications/MyNotch.app"
tmp="$(mktemp -d)"
mount="$tmp/mnt"
cleanup() { hdiutil detach "$mount" -quiet 2>/dev/null || true; rm -rf "$tmp"; }
trap cleanup EXIT

echo "Downloading the latest release..."
curl -fL --progress-bar -o "$tmp/MyNotch.dmg" "$URL"
hdiutil attach -nobrowse -readonly -mountpoint "$mount" "$tmp/MyNotch.dmg" -quiet

echo "Quitting MyNotch..."
osascript -e 'tell application "MyNotch" to quit' >/dev/null 2>&1 || true
sleep 1
pkill -x MyNotch 2>/dev/null || true

echo "Installing..."
rm -rf "$APP"
cp -R "$mount/MyNotch.app" /Applications/
xattr -cr "$APP"

open "$APP"
echo "Done."
