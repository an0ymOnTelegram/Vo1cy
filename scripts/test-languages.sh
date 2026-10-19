#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/.build"
swiftc -O "$ROOT"/Sources/VoiceCore/*.swift "$ROOT/Tests/LanguageChecks.swift" -o "$ROOT/.build/language-checks"
"$ROOT/.build/language-checks"
