#!/bin/bash
# Requires a logged-in macOS desktop; never posts keystrokes to other apps.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGE="$(mktemp -d /tmp/vo1cy-shortcut-checks.XXXXXX)"
trap 'rm -rf "$STAGE"' EXIT
swiftc -emit-library -emit-module -module-name VoiceCore "$ROOT"/Sources/VoiceCore/*.swift -o "$STAGE/libVoiceCore.dylib" -emit-module-path "$STAGE/VoiceCore.swiftmodule"
swiftc -I "$STAGE" -L "$STAGE" -lVoiceCore -Xlinker -rpath -Xlinker "$STAGE" "$ROOT/Sources/Vo1cy/GlobalShortcut.swift" "$ROOT/Tests/ShortcutChecks.swift" -o "$STAGE/shortcut-checks"
"$STAGE/shortcut-checks"
APP="$STAGE/RecorderChecks.app"
mkdir -p "$APP/Contents/MacOS"
swiftc -I "$STAGE" -L "$STAGE" -lVoiceCore -Xlinker -rpath -Xlinker "$STAGE" "$ROOT/Sources/Vo1cy/ShortcutRecorder.swift" "$ROOT/Tests/RecorderChecks.swift" -o "$APP/Contents/MacOS/RecorderChecks"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>app.vo1cy.recorderchecks</string>
<key>CFBundleExecutable</key><string>RecorderChecks</string>
<key>CFBundleName</key><string>Vo1cy Recorder Checks</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
open -W -n "$APP" --args "$STAGE/recorder-result.txt"
cat "$STAGE/recorder-result.txt"
grep -q '^9 AppKit recorder checks passed$' "$STAGE/recorder-result.txt"
