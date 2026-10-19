#!/bin/bash
# Uses an isolated pasteboard and stubbed event posting; never types into apps.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/.build"
swiftc "$ROOT/Sources/Vo1cy/TextOutput.swift" "$ROOT/Tests/TextOutputChecks.swift" -o "$ROOT/.build/text-output-checks"
"$ROOT/.build/text-output-checks"
