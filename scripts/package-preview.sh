#!/bin/bash
# Create a clearly labeled ad-hoc-signed preview; never upload local signing material.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VO1CY_VERSION:-0.1.0}"
ARCH="$(uname -m)"
if [ "$ARCH" != arm64 ]; then echo 'Preview packaging currently supports Apple Silicon only.' >&2; exit 1; fi
STAGE="$(mktemp -d /tmp/vo1cy-preview.XXXXXX)"
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/Vo1cy.app"
if [ -n "${VO1CY_PREBUILT_APP:-}" ]; then
  ditto --norsrc --noextattr "$VO1CY_PREBUILT_APP" "$APP"
else
  VO1CY_LOCAL_SIGN=0 VO1CY_APP_OUTPUT="$APP" "$ROOT/scripts/build-app.sh"
fi
BUNDLE_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
if [ "$BUNDLE_VERSION" != "$VERSION" ]; then echo 'Bundle and package versions do not match.' >&2; exit 1; fi
/usr/libexec/PlistBuddy -c 'Delete :SUFeedURL' "$APP/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c 'Delete :SUPublicEDKey' "$APP/Contents/Info.plist" 2>/dev/null || true
# Replace any development identity; verify the package after copying and signing.
codesign --force --deep --preserve-metadata=entitlements --sign - "$APP"
codesign --verify --deep --strict "$APP"
python3 "$ROOT/scripts/audit-release.py" --app "$APP"
mkdir -p "$ROOT/dist"
NAME="Vo1cy-$VERSION-preview-$ARCH"
ditto --norsrc --noextattr -c -k --keepParent "$APP" "$ROOT/dist/$NAME.zip"
mkdir "$STAGE/disk"
ditto --norsrc --noextattr "$APP" "$STAGE/disk/Vo1cy.app"
ln -s /Applications "$STAGE/disk/Applications"
printf '%s\n' 'Vo1cy preview: Apple Silicon, macOS 14+. Drag Vo1cy to Applications.' 'This preview is ad-hoc signed and is not notarized by Apple.' 'Setup and release information: https://github.com/an0ymOnTelegram/Vo1cy' > "$STAGE/disk/READ ME.txt"
hdiutil create -volname Vo1cy -srcfolder "$STAGE/disk" -ov -format UDZO "$ROOT/dist/$NAME.dmg"
(cd "$ROOT/dist" && shasum -a 256 "$NAME.zip" "$NAME.dmg" > SHA256SUMS)
echo "Preview ZIP, DMG, and SHA256SUMS created in dist. Nothing was uploaded."
