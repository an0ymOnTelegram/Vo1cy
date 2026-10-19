#!/bin/bash
# Install one current development build; remove staging/backup copies on success.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET=/Applications/Vo1cy.app
STAGE="$(mktemp -d /tmp/vo1cy-install.XXXXXX)"
INSTALL_STARTED=0
COMMITTED=0
cleanup() {
  local result=$?
  if [ "$INSTALL_STARTED" = 1 ] && [ "$COMMITTED" = 0 ]; then
    rm -rf "$TARGET"
    if [ -d "$STAGE/previous.app" ]; then
      if ! mv "$STAGE/previous.app" "$TARGET"; then
        echo "Restore failed; previous app retained at $STAGE/previous.app" >&2
        return 1
      fi
    fi
  fi
  rm -rf "$STAGE"
  return "$result"
}
trap cleanup EXIT
if [ -L "$TARGET" ]; then echo 'Refusing a symlinked installation' >&2; exit 1; fi
if [ -e "$TARGET" ]; then
  IDENTIFIER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$TARGET/Contents/Info.plist")"
  if [ "$IDENTIFIER" != app.vo1cy.mac ]; then echo 'Unexpected app at destination' >&2; exit 1; fi
fi
if [ -n "${VO1CY_PREBUILT_APP:-}" ]; then
  codesign --verify --deep --strict "$VO1CY_PREBUILT_APP"
  ditto --norsrc --noextattr "$VO1CY_PREBUILT_APP" "$STAGE/Vo1cy.app"
  python3 "$ROOT/scripts/sign-local.py" "$STAGE/Vo1cy.app"
else
  VO1CY_LOCAL_SIGN=1 VO1CY_APP_OUTPUT="$STAGE/Vo1cy.app" "$ROOT/scripts/build-app.sh"
fi
codesign --verify --deep --strict "$STAGE/Vo1cy.app"
if [ -d "$TARGET" ]; then
  PREVIOUS_REQUIREMENT="$(codesign -d -r- "$TARGET" 2>&1 | sed -n 's/^designated => //p')"
  if [ -n "$PREVIOUS_REQUIREMENT" ]; then
    # Never silently replace a stable identity and invalidate its permissions.
    codesign --verify --strict -R "=$PREVIOUS_REQUIREMENT" "$STAGE/Vo1cy.app"
  fi
fi
mkdir -p "$ROOT/dist"
ditto --norsrc --noextattr -c -k --keepParent "$STAGE/Vo1cy.app" "$STAGE/Vo1cy-0.1.0-development-arm64.zip"
ditto -x -k "$STAGE/Vo1cy-0.1.0-development-arm64.zip" "$STAGE/verify"
codesign --verify --deep --strict "$STAGE/verify/Vo1cy.app"
if pgrep -f '^/Applications/Vo1cy.app/Contents/MacOS/Vo1cy($| )' >/dev/null; then
  osascript -e 'tell application id "app.vo1cy.mac" to quit'
  for attempt in {1..50}; do
    if ! pgrep -f '^/Applications/Vo1cy.app/Contents/MacOS/Vo1cy($| )' >/dev/null; then break; fi
    sleep 0.1
  done
  if pgrep -f '^/Applications/Vo1cy.app/Contents/MacOS/Vo1cy($| )' >/dev/null; then
    echo 'Vo1cy is still running; installation cancelled.' >&2; exit 1
  fi
fi
if [ -d "$TARGET" ]; then mv "$TARGET" "$STAGE/previous.app"; fi
INSTALL_STARTED=1
ditto --norsrc --noextattr "$STAGE/Vo1cy.app" "$TARGET"
codesign --verify --deep --strict "$TARGET"
mv "$STAGE/Vo1cy-0.1.0-development-arm64.zip" "$ROOT/dist/Vo1cy-0.1.0-development-arm64.zip"
COMMITTED=1
# These are superseded packaging copies, never models, source or user data.
rm -rf "$ROOT/dist/Vo1cy.app" "$ROOT/.build/package/Vo1cy.app"
if [ "${VO1CY_RESET_ACCESSIBILITY:-0}" = 1 ]; then
  tccutil reset Accessibility app.vo1cy.mac
fi
open "$TARGET"
if [ "${VO1CY_RESET_ACCESSIBILITY:-0}" = 1 ]; then
  open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility'
fi
echo 'Installed /Applications/Vo1cy.app; temporary and previous bundles removed on exit.'
