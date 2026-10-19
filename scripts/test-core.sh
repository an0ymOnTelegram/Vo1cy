#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/.build"
swiftc "$ROOT"/Sources/VoiceCore/*.swift "$ROOT/Tests/PortableChecks.swift" -o "$ROOT/.build/portable-checks"
"$ROOT/.build/portable-checks"
