#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/.build"
swiftc -O "$ROOT"/Sources/VoiceCore/*.swift "$ROOT/Tests/FormattingChecks.swift" -o "$ROOT/.build/formatting-checks"
"$ROOT/.build/formatting-checks"
