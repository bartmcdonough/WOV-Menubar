#!/usr/bin/env bash
set -euo pipefail

APP_EXECUTABLE="WOVMenubar"
APP_DISPLAY_NAME="WOV Quick Notes"
BUNDLE_ID="com.walkonvalley.WOVMenubar"
DEFAULT_FEED_URL="https://portal.walkonvalley.com/appcast/wov-quick-notes.xml"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${WOV_VERSION:-}"
BUILD_NUMBER="${WOV_BUILD:-}"
MIN_SYSTEM_VERSION="${MIN_SYSTEM_VERSION:-14.0}"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-$DEFAULT_FEED_URL}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-}"
SPARKLE_PRIVATE_KEY_FILE="${SPARKLE_PRIVATE_KEY_FILE:-}"
SPARKLE_SIGN_UPDATE="${SPARKLE_SIGN_UPDATE:-}"
DEVELOPER_ID_APPLICATION="${DEVELOPER_ID_APPLICATION:-}"
NOTARYTOOL_PROFILE="${NOTARYTOOL_PROFILE:-wov-portal-notary}"
RELEASE_NOTES="${RELEASE_NOTES:-}"
AD_HOC_SIGN=0
SKIP_NOTARIZE=0

usage() {
  cat <<USAGE >&2
usage: $0 --version <semver> --build <number> [options]

Options:
  --version <semver>             CFBundleShortVersionString and release version
  --build <number>               CFBundleVersion and Sparkle machine version
  --min-macos <version>          Minimum macOS version (default: 14.0)
  --release-notes <text>         Short release notes for the Portal manifest
  --release-notes-file <path>    Read release notes from a text file
  --sparkle-public-ed-key <key>  Sparkle SUPublicEDKey value
  --sparkle-private-key <path>   Private EdDSA key file for sign_update
  --feed-url <url>               Sparkle appcast URL
  --ad-hoc                       Use ad-hoc code signing for local dry runs
  --no-notarize                  Skip notarytool and stapler

Release signing defaults come from:
  DEVELOPER_ID_APPLICATION, NOTARYTOOL_PROFILE, SPARKLE_PUBLIC_ED_KEY,
  SPARKLE_PRIVATE_KEY_FILE, SPARKLE_SIGN_UPDATE, WOV_VERSION, WOV_BUILD.
USAGE
}

clean_bundle_metadata() {
  local bundle_path="$1"

  xattr -cr "$bundle_path" 2>/dev/null || true
  find "$bundle_path" -depth -name "._*" -delete 2>/dev/null || true

  while IFS= read -r -d '' item; do
    xattr -c "$item" 2>/dev/null || true
    xattr -d com.apple.FinderInfo "$item" 2>/dev/null || true
    xattr -d com.apple.ResourceFork "$item" 2>/dev/null || true
    xattr -d com.apple.provenance "$item" 2>/dev/null || true
    xattr -d 'com.apple.fileprovider.fpfs#P' "$item" 2>/dev/null || true
  done < <(find "$bundle_path" -depth -print0)
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="${2:-}"
      shift 2
      ;;
    --build)
      BUILD_NUMBER="${2:-}"
      shift 2
      ;;
    --min-macos)
      MIN_SYSTEM_VERSION="${2:-}"
      shift 2
      ;;
    --release-notes)
      RELEASE_NOTES="${2:-}"
      shift 2
      ;;
    --release-notes-file)
      RELEASE_NOTES="$(cat "${2:-}")"
      shift 2
      ;;
    --sparkle-public-ed-key)
      SPARKLE_PUBLIC_ED_KEY="${2:-}"
      shift 2
      ;;
    --sparkle-private-key)
      SPARKLE_PRIVATE_KEY_FILE="${2:-}"
      shift 2
      ;;
    --feed-url)
      SPARKLE_FEED_URL="${2:-}"
      shift 2
      ;;
    --ad-hoc)
      AD_HOC_SIGN=1
      shift
      ;;
    --no-notarize)
      SKIP_NOTARIZE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

if [[ -z "$VERSION" || -z "$BUILD_NUMBER" ]]; then
  usage
  exit 2
fi

if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "BUILD_NUMBER must be an integer." >&2
  exit 2
fi

if [[ -z "$SPARKLE_PUBLIC_ED_KEY" ]]; then
  echo "SPARKLE_PUBLIC_ED_KEY is required for release builds." >&2
  exit 2
fi

if [[ "$AD_HOC_SIGN" -eq 0 && -z "$DEVELOPER_ID_APPLICATION" ]]; then
  echo "DEVELOPER_ID_APPLICATION is required unless --ad-hoc is used." >&2
  exit 2
fi

if [[ -z "$RELEASE_NOTES" ]]; then
  RELEASE_NOTES="WOV Quick Notes $VERSION"
fi

MODULE_CACHE="$ROOT_DIR/.build/module-cache-release"
RELEASE_DIR="$ROOT_DIR/dist/releases/$VERSION"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/wov-quick-notes-release.XXXXXX")"
STAGING_DIR="$WORK_DIR/staging"
APP_BUNDLE="$STAGING_DIR/$APP_DISPLAY_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_FRAMEWORKS="$APP_CONTENTS/Frameworks"
APP_BINARY="$APP_MACOS/$APP_EXECUTABLE"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ARCHIVE_ROOT="$WORK_DIR/archive-root"
DMG_PATH="$RELEASE_DIR/WOVQuickNotes-$VERSION.dmg"
ZIP_PATH="$RELEASE_DIR/WOVQuickNotes-$VERSION.zip"
MANIFEST_PLIST="$RELEASE_DIR/release-manifest.plist"
MANIFEST_JSON="$RELEASE_DIR/release-manifest.json"
APP_ICON_SOURCE="$ROOT_DIR/Sources/WOVMenubar/Resources/AppIcon.icns"

rm -rf "$MODULE_CACHE" "$RELEASE_DIR"
mkdir -p "$MODULE_CACHE" "$RELEASE_DIR" "$APP_MACOS" "$APP_RESOURCES" "$APP_FRAMEWORKS"
trap 'rm -rf "$WORK_DIR"' EXIT
export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE"
export COPYFILE_DISABLE=1

swift build \
  -c release \
  --scratch-path "$ROOT_DIR/.build" \
  -Xswiftc -module-cache-path \
  -Xswiftc "$MODULE_CACHE"

BUILD_BIN_PATH="$(swift build \
  -c release \
  --scratch-path "$ROOT_DIR/.build" \
  -Xswiftc -module-cache-path \
  -Xswiftc "$MODULE_CACHE" \
  --show-bin-path)"
BUILD_BINARY="$BUILD_BIN_PATH/$APP_EXECUTABLE"

cp -X "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

for resource_bundle in "$BUILD_BIN_PATH"/*.bundle; do
  if [[ -e "$resource_bundle" ]]; then
    ditto --norsrc "$resource_bundle" "$APP_RESOURCES/$(basename "$resource_bundle")"
    find "$resource_bundle" -maxdepth 1 -type f -exec cp -X {} "$APP_RESOURCES/" \;
  fi
done

if [[ -f "$APP_ICON_SOURCE" ]]; then
  cp -X "$APP_ICON_SOURCE" "$APP_RESOURCES/AppIcon.icns"
fi

SPARKLE_FRAMEWORK="$(find "$ROOT_DIR/.build" -path "*/Sparkle.framework" -type d | head -n 1 || true)"
if [[ -z "$SPARKLE_FRAMEWORK" ]]; then
  echo "Could not locate Sparkle.framework under .build." >&2
  exit 1
fi
ditto --norsrc "$SPARKLE_FRAMEWORK" "$APP_FRAMEWORKS/Sparkle.framework"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_EXECUTABLE</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>WOV Quick Notes records your voice to draft Portal Quick Notes.</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>SUFeedURL</key>
  <string>$SPARKLE_FEED_URL</string>
  <key>SUPublicEDKey</key>
  <string>$SPARKLE_PUBLIC_ED_KEY</string>
  <key>SUEnableAutomaticChecks</key>
  <true/>
</dict>
</plist>
PLIST

clean_bundle_metadata "$APP_BUNDLE"

if [[ "$AD_HOC_SIGN" -eq 1 ]]; then
  codesign --force --deep --options runtime --sign - "$APP_BUNDLE"
else
  codesign --force --deep --timestamp --options runtime --sign "$DEVELOPER_ID_APPLICATION" "$APP_BUNDLE"
fi

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

if [[ "$SKIP_NOTARIZE" -eq 0 && "$AD_HOC_SIGN" -eq 0 ]]; then
  NOTARY_ZIP="$RELEASE_DIR/notary-submit.zip"
  ditto -c -k --norsrc --keepParent "$APP_BUNDLE" "$NOTARY_ZIP"
  xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
  xcrun stapler staple "$APP_BUNDLE"
  rm -f "$NOTARY_ZIP"
fi

ditto -c -k --norsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

rm -rf "$ARCHIVE_ROOT"
mkdir -p "$ARCHIVE_ROOT"
ditto --norsrc "$APP_BUNDLE" "$ARCHIVE_ROOT/$APP_DISPLAY_NAME.app"
clean_bundle_metadata "$ARCHIVE_ROOT/$APP_DISPLAY_NAME.app"
ln -s /Applications "$ARCHIVE_ROOT/Applications"
hdiutil create -volname "$APP_DISPLAY_NAME" -srcfolder "$ARCHIVE_ROOT" -ov -format UDZO "$DMG_PATH"

if [[ "$AD_HOC_SIGN" -eq 0 ]]; then
  codesign --force --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$DMG_PATH"
fi

if [[ "$SKIP_NOTARIZE" -eq 0 && "$AD_HOC_SIGN" -eq 0 ]]; then
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
fi

if [[ -z "$SPARKLE_SIGN_UPDATE" ]]; then
  SPARKLE_SIGN_UPDATE="$(find "$ROOT_DIR/.build" -path "*/sign_update" -type f | head -n 1 || true)"
fi
if [[ -z "$SPARKLE_SIGN_UPDATE" ]]; then
  echo "Could not locate Sparkle sign_update. Set SPARKLE_SIGN_UPDATE explicitly." >&2
  exit 1
fi

SIGN_ARGS=("$ZIP_PATH")
if [[ -n "$SPARKLE_PRIVATE_KEY_FILE" ]]; then
  SIGN_ARGS+=("-f" "$SPARKLE_PRIVATE_KEY_FILE")
fi
SIGN_OUTPUT="$("$SPARKLE_SIGN_UPDATE" "${SIGN_ARGS[@]}")"
SPARKLE_ED_SIGNATURE="$(printf "%s\n" "$SIGN_OUTPUT" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')"
SPARKLE_LENGTH="$(printf "%s\n" "$SIGN_OUTPUT" | sed -n 's/.*length="\([^"]*\)".*/\1/p')"

if [[ -z "$SPARKLE_ED_SIGNATURE" || -z "$SPARKLE_LENGTH" ]]; then
  echo "Could not parse Sparkle signature output: $SIGN_OUTPUT" >&2
  exit 1
fi

sha256_for() {
  shasum -a 256 "$1" | awk '{print $1}'
}

size_for() {
  stat -f%z "$1"
}

DMG_SHA="$(sha256_for "$DMG_PATH")"
ZIP_SHA="$(sha256_for "$ZIP_PATH")"
DMG_SIZE="$(size_for "$DMG_PATH")"
ZIP_SIZE="$(size_for "$ZIP_PATH")"
RELEASED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

cat >"$MANIFEST_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
PLIST

/usr/libexec/PlistBuddy -c "Add :appName string $APP_DISPLAY_NAME" "$MANIFEST_PLIST"
/usr/libexec/PlistBuddy -c "Add :bundleId string $BUNDLE_ID" "$MANIFEST_PLIST"
/usr/libexec/PlistBuddy -c "Add :version string $VERSION" "$MANIFEST_PLIST"
/usr/libexec/PlistBuddy -c "Add :build string $BUILD_NUMBER" "$MANIFEST_PLIST"
/usr/libexec/PlistBuddy -c "Add :minMacOS string $MIN_SYSTEM_VERSION" "$MANIFEST_PLIST"
/usr/libexec/PlistBuddy -c "Add :channel string stable" "$MANIFEST_PLIST"
/usr/libexec/PlistBuddy -c "Add :releasedAt string $RELEASED_AT" "$MANIFEST_PLIST"
/usr/libexec/PlistBuddy -c "Add :releaseNotes string $RELEASE_NOTES" "$MANIFEST_PLIST"
/usr/libexec/PlistBuddy -c "Add :artifacts dict" "$MANIFEST_PLIST"
/usr/libexec/PlistBuddy -c "Add :artifacts:dmg dict" "$MANIFEST_PLIST"
/usr/libexec/PlistBuddy -c "Add :artifacts:dmg:fileName string $(basename "$DMG_PATH")" "$MANIFEST_PLIST"
/usr/libexec/PlistBuddy -c "Add :artifacts:dmg:size string $DMG_SIZE" "$MANIFEST_PLIST"
/usr/libexec/PlistBuddy -c "Add :artifacts:dmg:sha256 string $DMG_SHA" "$MANIFEST_PLIST"
/usr/libexec/PlistBuddy -c "Add :artifacts:sparkleZip dict" "$MANIFEST_PLIST"
/usr/libexec/PlistBuddy -c "Add :artifacts:sparkleZip:fileName string $(basename "$ZIP_PATH")" "$MANIFEST_PLIST"
/usr/libexec/PlistBuddy -c "Add :artifacts:sparkleZip:size string $ZIP_SIZE" "$MANIFEST_PLIST"
/usr/libexec/PlistBuddy -c "Add :artifacts:sparkleZip:sha256 string $ZIP_SHA" "$MANIFEST_PLIST"
/usr/libexec/PlistBuddy -c "Add :sparkle dict" "$MANIFEST_PLIST"
/usr/libexec/PlistBuddy -c "Add :sparkle:edSignature string $SPARKLE_ED_SIGNATURE" "$MANIFEST_PLIST"
/usr/libexec/PlistBuddy -c "Add :sparkle:length string $SPARKLE_LENGTH" "$MANIFEST_PLIST"

plutil -convert json -o "$MANIFEST_JSON" "$MANIFEST_PLIST"
rm -f "$MANIFEST_PLIST"

echo "Release artifacts:"
echo "  $DMG_PATH"
echo "  $ZIP_PATH"
echo "  $MANIFEST_JSON"
