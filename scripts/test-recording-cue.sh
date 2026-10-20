#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/.build"
swiftc "$ROOT/Sources/Vo1cy/RecordingCue.swift" "$ROOT/Tests/RecordingCueChecks.swift" -o "$ROOT/.build/recording-cue-checks"
"$ROOT/.build/recording-cue-checks"
