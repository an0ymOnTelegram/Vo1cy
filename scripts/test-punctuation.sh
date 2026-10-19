#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/.build"
swiftc -O "$ROOT"/Sources/VoiceCore/*.swift "$ROOT/Tests/PunctuationChecks.swift" -o "$ROOT/.build/punctuation-checks"
"$ROOT/.build/punctuation-checks"
