#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/vendor/silero-vad-v6.2-F32.gguf"
HASH=0d871a800c420fdd5d1b17a3aea4296d1c39608f0ff4a9295eb76457eb1c88e6
mkdir -p "$ROOT/vendor"
if [ ! -f "$DEST" ]; then
  curl --fail --location --retry 2 --proto '=https' --tlsv1.2 \
    'https://huggingface.co/handy-computer/silero-vad-v6.2-gguf/resolve/a9b2d61c20ae4ddf3644edb34969e8185a485448/silero-vad-v6.2-F32.gguf' \
    --output "$DEST.partial"
  printf '%s  %s\n' "$HASH" "$DEST.partial" | shasum -a 256 -c -
  mv "$DEST.partial" "$DEST"
fi
printf '%s  %s\n' "$HASH" "$DEST" | shasum -a 256 -c -
