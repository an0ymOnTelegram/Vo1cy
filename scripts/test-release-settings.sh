#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/.build"
swiftc "$ROOT"/Sources/VoiceCore/*.swift "$ROOT/Tests/ReleaseSettingsChecks.swift" -o "$ROOT/.build/release-settings-checks"
"$ROOT/.build/release-settings-checks"
