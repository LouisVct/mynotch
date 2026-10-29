#!/usr/bin/env bash
# Installs the latest MyNotch release from GitHub into /Applications and relaunches it.
# Needs the GitHub CLI (gh) signed in to an account that can read the repo.
set -euo pipefail

REPO="LouisVct/mynotch"
APP="/Applications/MyNotch.app"
tmp="$(mktemp -d)"
mount="$tmp/mnt"
cleanup() { hdiutil detach "$mount" -quiet 2>/dev/null || true; rm -rf "$tmp"; }
trap cleanup EXIT

echo "Downloading the latest release..."
gh release download -R "$REPO" -p MyNotch.dmg -D "$tmp" --clobber
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
