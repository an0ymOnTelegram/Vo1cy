#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if [ ! -f vendor/lib/libtranscribe.dylib ]; then scripts/bootstrap-engine.sh; fi
scripts/fetch-vad.sh
swift build -c release -Xswiftc -file-prefix-map -Xswiftc "$ROOT=/Vo1cy" -Xswiftc -debug-prefix-map -Xswiftc "$ROOT=/Vo1cy"
BIN="$(swift build -c release --show-bin-path)"
APP="${VO1CY_APP_OUTPUT:-$ROOT/dist/Vo1cy.app}"
if [ -L "$APP" ]; then echo 'Refusing to replace a symlinked app bundle' >&2; exit 1; fi
if [ -d "$APP" ]; then chmod -R u+w "$APP"; rm -rf "$APP"; fi
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks" "$APP/Contents/Resources/Licenses"
cp "$BIN/Vo1cy" "$APP/Contents/MacOS/Vo1cy"
strip -S "$APP/Contents/MacOS/Vo1cy"
cp -R vendor/lib/*.dylib "$APP/Contents/Frameworks/"
SPARKLE="$(find .build/artifacts -path '*/macos-arm64_x86_64/Sparkle.framework' -type d -maxdepth 8 -print -quit)"
if [ -z "$SPARKLE" ]; then echo 'Sparkle framework missing' >&2; exit 1; fi
ditto --norsrc --noextattr "$SPARKLE" "$APP/Contents/Frameworks/Sparkle.framework"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp vendor/silero-vad-v6.2-F32.gguf "$APP/Contents/Resources/"
# SwiftPM resources must travel with the app, never reference a build checkout.
for resource in "$BIN/"*.bundle; do
  if [ -d "$resource" ]; then ditto --norsrc --noextattr "$resource" "$APP/Contents/Resources/$(basename "$resource")"; fi
done
if [ -d vendor/licenses ]; then ditto vendor/licenses "$APP/Contents/Resources/Licenses"; fi
cp LICENSE "$APP/Contents/Resources/Licenses/Vo1cy-MIT.txt"
cp ThirdParty/Handy-LICENSE.txt "$APP/Contents/Resources/Licenses/Handy-MIT.txt"
cp THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/Licenses/"
if [ -f .build/checkouts/Sparkle/LICENSE ]; then cp .build/checkouts/Sparkle/LICENSE "$APP/Contents/Resources/Licenses/Sparkle.txt"; fi
if [ -n "${VO1CY_VERSION:-}" ]; then /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VO1CY_VERSION" "$APP/Contents/Info.plist"; fi
if [ -n "${VO1CY_BUILD:-}" ]; then /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VO1CY_BUILD" "$APP/Contents/Info.plist"; fi
if [ -n "${VO1CY_FEED_URL:-}" ] && [ -n "${VO1CY_UPDATE_PUBLIC_KEY:-}" ]; then
  /usr/libexec/PlistBuddy -c "Add :SUFeedURL string $VO1CY_FEED_URL" "$APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $VO1CY_UPDATE_PUBLIC_KEY" "$APP/Contents/Info.plist"
fi
for library in "$APP/Contents/Frameworks/"*.dylib; do
  if [ ! -L "$library" ]; then
    if ! otool -l "$library" | grep -q 'path @loader_path '; then install_name_tool -add_rpath '@loader_path' "$library"; fi
  fi
done
# Ad-hoc signatures are for local development only. The release script replaces them.
chmod -R u+w "$APP"
xattr -dr com.apple.FinderInfo "$APP" 2>/dev/null || true
xattr -dr com.apple.ResourceFork "$APP" 2>/dev/null || true
codesign --force --deep --preserve-metadata=entitlements --sign - "$APP"
if [ "${VO1CY_LOCAL_SIGN:-0}" = 1 ]; then
  python3 "$ROOT/scripts/sign-local.py" "$APP"
fi
codesign --verify --deep --strict "$APP"
echo "$APP"
