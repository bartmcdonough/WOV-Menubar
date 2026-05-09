#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="WOVMenubar"
BUNDLE_ID="com.walkonvalley.WOVMenubar"
MIN_SYSTEM_VERSION="14.0"
APP_VERSION="${WOV_VERSION:-0.1}"
APP_BUILD="${WOV_BUILD:-1}"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-https://portal.walkonvalley.com/appcast/wov-quick-notes.xml}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${WOV_MENUBAR_RUN_DIR:-$HOME/Library/Application Support/WOVMenubar/Build}"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
MODULE_CACHE="$ROOT_DIR/.build/module-cache"

rm -rf "$MODULE_CACHE"
mkdir -p "$MODULE_CACHE"
export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE"

if [ -f "$ROOT_DIR/.env.local" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT_DIR/.env.local"
  set +a
fi

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

swift build \
  --scratch-path "$ROOT_DIR/.build" \
  -Xswiftc -module-cache-path \
  -Xswiftc "$MODULE_CACHE"

BUILD_BIN_PATH="$(swift build \
  --scratch-path "$ROOT_DIR/.build" \
  -Xswiftc -module-cache-path \
  -Xswiftc "$MODULE_CACHE" \
  --show-bin-path)"
BUILD_BINARY="$BUILD_BIN_PATH/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

FRAMEWORKS_DIR="$APP_CONTENTS/Frameworks"
SPARKLE_FRAMEWORK="$(find "$ROOT_DIR/.build" -path "*/Sparkle.framework" -type d | head -n 1 || true)"
if [ -n "$SPARKLE_FRAMEWORK" ]; then
  mkdir -p "$FRAMEWORKS_DIR"
  ditto "$SPARKLE_FRAMEWORK" "$FRAMEWORKS_DIR/Sparkle.framework"
fi

for resource_bundle in "$BUILD_BIN_PATH"/*.bundle; do
  if [ -e "$resource_bundle" ]; then
    cp -R "$resource_bundle" "$APP_RESOURCES/"
    find "$resource_bundle" -maxdepth 1 -type f -exec cp {} "$APP_RESOURCES/" \;
  fi
done

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>WOV Quick Notes</string>
  <key>CFBundleDisplayName</key>
  <string>WOV Quick Notes</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_BUILD</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>WOV Quick Notes records your voice to draft Portal Quick Notes.</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

if [ -n "$SPARKLE_PUBLIC_ED_KEY" ]; then
  /usr/libexec/PlistBuddy -c "Add :SUFeedURL string $SPARKLE_FEED_URL" "$INFO_PLIST"
  /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $SPARKLE_PUBLIC_ED_KEY" "$INFO_PLIST"
  /usr/libexec/PlistBuddy -c "Add :SUEnableAutomaticChecks bool true" "$INFO_PLIST"
fi

if command -v codesign >/dev/null 2>&1; then
  xattr -cr "$APP_BUNDLE" 2>/dev/null || true
  codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null
fi

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
