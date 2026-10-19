#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${DEVELOPER_ID:?Set your Developer ID Application identity}"
: "${NOTARY_PROFILE:?Set an existing notarytool Keychain profile}"
: "${VO1CY_VERSION:?Set release version}"
: "${VO1CY_BUILD:?Set increasing build number}"
: "${VO1CY_FEED_URL:?Set public HTTPS appcast URL}"
: "${VO1CY_UPDATE_PUBLIC_KEY:?Set Sparkle Ed25519 public key}"
"$ROOT/scripts/build-app.sh"
APP="${VO1CY_APP_OUTPUT:-$ROOT/dist/Vo1cy.app}"
# Sign leaf Mach-O files, then nested bundles from the inside out.
python3 "$ROOT/scripts/sign-bundle.py" "$APP" "$DEVELOPER_ID"
codesign --verify --deep --strict --verbose=2 "$APP"
python3 "$ROOT/scripts/audit-release.py" --app "$APP"
ZIP="$ROOT/dist/Vo1cy-$VO1CY_VERSION-$(uname -m).zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/Vo1cy.app"
ln -s /Applications "$STAGE/Applications"
DMG="$ROOT/dist/Vo1cy-$VO1CY_VERSION-$(uname -m).dmg"
hdiutil create -volname Vo1cy -srcfolder "$STAGE" -ov -format UDZO "$DMG"
codesign --sign "$DEVELOPER_ID" --timestamp "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
echo 'Artifacts prepared. Use Sparkle generate_appcast with your private signing key, then upload ZIP, DMG and appcast.xml together to GitHub Releases.'
echo 'No upload has been performed by this script.'
