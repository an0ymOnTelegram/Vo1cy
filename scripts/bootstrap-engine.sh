#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PIN=b61b7f936e4e728f8999a8c3e98c7112e700410e
SOURCE="${VO1CY_ENGINE_SOURCE:-$ROOT/.build/engine-source}"
if [ ! -d "$SOURCE/.git" ]; then
  mkdir -p "$(dirname "$SOURCE")"
  git clone https://github.com/handy-computer/transcribe.cpp.git "$SOURCE"
fi
if [ "$(git -C "$SOURCE" rev-parse HEAD)" != "$PIN" ]; then
  if [ -n "$(git -C "$SOURCE" status --porcelain)" ]; then
    echo "Engine source has local changes; refusing to switch revisions." >&2
    exit 1
  fi
  git -C "$SOURCE" fetch origin "$PIN"
  git -C "$SOURCE" checkout --detach "$PIN"
fi
cmake -S "$SOURCE" -B "$SOURCE/build-vo1cy" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
  -DCMAKE_C_FLAGS="-ffile-prefix-map=$SOURCE=/transcribe.cpp -fdebug-prefix-map=$SOURCE=/transcribe.cpp" \
  -DCMAKE_CXX_FLAGS="-ffile-prefix-map=$SOURCE=/transcribe.cpp -fdebug-prefix-map=$SOURCE=/transcribe.cpp" \
  -DTRANSCRIBE_BUILD_SHARED=ON -DTRANSCRIBE_BUILD_TESTS=OFF \
  -DTRANSCRIBE_BUILD_EXAMPLES=OFF -DTRANSCRIBE_BUILD_TOOLS=OFF \
  -DGGML_METAL_EMBED_LIBRARY=ON -DTRANSCRIBE_USE_OPENMP=OFF
cmake --build "$SOURCE/build-vo1cy" --target transcribe --parallel "${BUILD_JOBS:-4}"
cmake --install "$SOURCE/build-vo1cy" --prefix "$ROOT/vendor"
mkdir -p "$ROOT/vendor/licenses"
cp "$SOURCE/LICENSE" "$ROOT/vendor/licenses/transcribe-MIT.txt"
cp "$SOURCE/ggml/LICENSE" "$ROOT/vendor/licenses/ggml-MIT.txt"
cp "$SOURCE/src/third_party/miniz/LICENSE" "$ROOT/vendor/licenses/miniz.txt"
cp "$SOURCE/src/third_party/silero_vad/LICENSE" "$ROOT/vendor/licenses/silero.txt"
cp "$SOURCE/THIRD-PARTY-LICENSES.md" "$ROOT/vendor/licenses/transcribe-third-party.md"
printf '%s\n' "$PIN" > "$ROOT/vendor/engine-revision.txt"
"$ROOT/scripts/fetch-vad.sh"
