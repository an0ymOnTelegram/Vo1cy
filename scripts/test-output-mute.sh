#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/.build"
swiftc -O "$ROOT/Sources/Vo1cy/OutputMuteSession.swift" "$ROOT/Tests/OutputMuteChecks.swift" -o "$ROOT/.build/output-mute-checks"
"$ROOT/.build/output-mute-checks"
swiftc -O "$ROOT/Sources/Vo1cy/OutputMuteSession.swift" "$ROOT/Sources/Vo1cy/SystemOutputMute.swift" "$ROOT/Tests/CoreAudioMuteSmoke.swift" -o "$ROOT/.build/coreaudio-mute-smoke"
# Explicit hardware check: .build/coreaudio-mute-smoke --live
