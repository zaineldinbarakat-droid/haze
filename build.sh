#!/bin/bash
# Builds Haze and assembles a runnable Haze.app.
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/Haze.app"

echo "==> Building ($CONFIG)"
swift build -c "$CONFIG" --package-path "$ROOT"
BIN_DIR="$(swift build -c "$CONFIG" --package-path "$ROOT" --show-bin-path)"

echo "==> Assembling Haze.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Haze" "$APP/Contents/MacOS/Haze"
cp "$ROOT/Packaging/Haze-Info.plist" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(cat "$ROOT/VERSION")" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || echo 1)" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
cp "$ROOT/Packaging/Haze.icns" "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc signature pinned to the bundle identifier, so Open at Login keeps
# matching the app across rebuilds.
codesign --force --sign - --timestamp=none \
    --requirements '=designated => identifier "com.zaineldinbarakat.haze"' "$APP" >/dev/null 2>&1 || {
    echo "warning: ad-hoc signing failed; the app will still run" >&2
}
echo "Built: $APP"
echo
echo "Run:   open \"$APP\""
