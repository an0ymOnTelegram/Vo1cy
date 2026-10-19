#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/.build"
swiftc -O "$ROOT/Sources/Vo1cy/Models.swift" "$ROOT/Sources/Vo1cy/ReduxManifest.swift" "$ROOT/Sources/Vo1cy/ModelAssessment.swift" "$ROOT/Tests/ModelDownloadChecks.swift" -o "$ROOT/.build/model-checks"
"$ROOT/.build/model-checks"
