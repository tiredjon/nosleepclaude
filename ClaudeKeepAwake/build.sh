#!/bin/bash
# Builds ClaudeKeepAwake.app from the Swift package.
#
# Why not `swift package generate-xcodeproj` or a hand-authored .xcodeproj:
# see context/DECISIONS.md ("SwiftPM package + build.sh assembling a real
# .app bundle"). SwiftPM's own executable output is a bare Mach-O, not a
# bundle — SMAppService (Launch at Login) and LSUIElement (menu-bar-only,
# no Dock icon) both need a real .app with an Info.plist, so this script
# assembles one after `swift build`.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="ClaudeKeepAwake"
CONFIGURATION="release"

echo "==> Building $APP_NAME ($CONFIGURATION)..."
swift build -c "$CONFIGURATION"

BIN_PATH="$(swift build -c "$CONFIGURATION" --show-bin-path)/$APP_NAME"
if [ ! -f "$BIN_PATH" ]; then
    echo "error: expected binary not found at $BIN_PATH" >&2
    exit 1
fi

APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"
echo "==> Assembling $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$SCRIPT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

echo "==> Ad-hoc code signing..."
xattr -cr "$APP_BUNDLE"
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> Done: $APP_BUNDLE"
echo ""
echo "To install: move $APP_NAME.app to /Applications, then launch it."
echo "Launch at Login registers the app at its CURRENT path — move it to"
echo "/Applications before enabling that setting, or re-enable it after moving."
