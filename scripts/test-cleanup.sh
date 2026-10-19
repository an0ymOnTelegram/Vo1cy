#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/.build"
swiftc -O "$ROOT"/Sources/VoiceCore/*.swift "$ROOT/Tests/CleanupChecks.swift" -o "$ROOT/.build/cleanup-checks"
"$ROOT/.build/cleanup-checks"
