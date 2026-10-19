# Third-party software and model attribution

Vo1cy is a native SwiftUI/AppKit application inspired by the workflow of
[Handy](https://github.com/cjpais/Handy). Handy is MIT licensed, copyright
(c) 2025 CJ Pais. Its notice is preserved in `ThirdParty/Handy-LICENSE.txt`.
This repository contains no Tauri/Rust/React application
sources from Handy. The transcribe.cpp inference runtime is reused explicitly.
The license for Vo1cy's own code does not replace dependency or model licenses.

- transcribe.cpp, handy-computer contributors, MIT. Pinned revision:
  b61b7f936e4e728f8999a8c3e98c7112e700410e.
  https://github.com/handy-computer/transcribe.cpp
- GGML, Georgi Gerganov and contributors, MIT (vendored by transcribe.cpp).
  https://github.com/ggml-org/ggml
- miniz and Silero-related code are included by the runtime; full notices are
  copied into the app's Resources/Licenses by the bootstrap and build scripts.
- Silero VAD v6.2, Silero Team, MIT, GGUF conversion by handy-computer, is
  bundled as a 1.24 MB voice-activity filter. Revision and SHA-256 are pinned
  in scripts/fetch-vad.sh. https://huggingface.co/handy-computer/silero-vad-v6.2-gguf
- Sparkle 2.10.0, Sparkle project contributors, MIT with additional bundled notices.
  https://github.com/sparkle-project/Sparkle

Model weights are downloaded separately and are not included in the source
repository or app bundle. Catalog hashes and exact revisions are in Models.swift.
Parakeet Ultra is provided by Moondream, derived from NVIDIA Parakeet TDT
0.6B v3, under CC BY 4.0. The GGUF conversion and Q8 quantization are by
handy-computer. Vo1cy does not modify the pinned converted weights.

- Original model: https://huggingface.co/moondream/parakeet-ultra
- Base model: https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3
- Converted weights: https://huggingface.co/handy-computer/parakeet-ultra-gguf
- License: https://creativecommons.org/licenses/by/4.0/

The app links model license information before download. These licenses apply
to the separately downloaded weights; Vo1cy's MIT license does not replace them.
Only the small Silero VAD model is bundled with the app. User audio, personal
history, and user dictionaries are never included in release packages.

The underlying transcribe.cpp runtime may contain support for other architectures;
its full third-party notices remain bundled even though Vo1cy exposes only Ultra.
