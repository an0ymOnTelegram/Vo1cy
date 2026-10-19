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
NVIDIA Canary 180M Flash and NVIDIA Nemotron 3.5 ASR Streaming 0.6B are converted
and quantized to GGUF by handy-computer. Original weights: NVIDIA; GGUF conversion:
handy-computer. Model cards and license/derivation notices:

- https://huggingface.co/handy-computer/canary-180m-flash-gguf
- https://huggingface.co/handy-computer/nemotron-3.5-asr-streaming-0.6b-gguf

The app links to model license information before download. Imported models remain
subject to their own licenses. Vo1cy does not grant rights to third-party weights.

## Additional models and runtime

- FluidAudio 0.17.5, FluidInference contributors, Apache-2.0. Pinned by SwiftPM
  (revision 0b1f46289fe27d95b5e66ad8be46e64f5ee02ae7). Used for Redux inference.
  https://github.com/FluidInference/FluidAudio
  The optional NemoTextProcessing trait is disabled. Library and bundled
  third-party license files are copied into Resources/Licenses.
- Parakeet Ultra and Parakeet Redux: Moondream, derived from NVIDIA
  Parakeet TDT 0.6B v3; CC BY 4.0. Ultra GGUF conversion/quantization by
  handy-computer; Redux Core ML conversion by FluidInference. Vo1cy does not
  modify these pinned converted weights.
  https://huggingface.co/moondream/parakeet-ultra
  https://huggingface.co/moondream/parakeet-redux
  https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3
  https://huggingface.co/handy-computer/parakeet-ultra-gguf
  https://huggingface.co/FluidInference/parakeet-redux-coreml
  License: https://creativecommons.org/licenses/by/4.0/
- Orukeet: Oruk AI, derived from NVIDIA Parakeet TDT 0.6B v3;
  CC BY-SA 4.0. GGUF conversion/quantization by handy-computer. Vo1cy does
  not modify the converted weights. Adaptations of the weights retain the
  ShareAlike license.
  https://huggingface.co/oruk/orukeet
  https://huggingface.co/handy-computer/orukeet-gguf
  License: https://creativecommons.org/licenses/by-sa/4.0/

These ASR model licenses apply to separately downloaded weights. No ASR weights,
user audio, or transcripts are included in the app archive or source. Only the
small Silero VAD model is bundled with the app.

Nemotron 3.5 weights use the NVIDIA Open Model Distribution Agreement (OpenMDW-1.1).
Canary weights use CC BY 4.0. Always review the model card linked in the app before
downloading, modifying, or redistributing weights.
