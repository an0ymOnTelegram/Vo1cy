# Parakeet Ultra

Vo1cy uses one speech-recognition model: **Parakeet Ultra Q8**, by Moondream, based on NVIDIA Parakeet TDT 0.6B v3. It recognizes 25 languages, including English and German, and produces text after recording ends. There is no model-choice step.

| Property | Value |
| --- | --- |
| Download | 740 MB (740,363,168 bytes); separate from the app |
| Runtime | transcribe.cpp · Metal; optional CPU troubleshooting mode |
| Platform | Apple Silicon · macOS 14+ |
| Upstream release | 2026-09-22 |
| Weight license | CC BY 4.0 |
| Information reviewed | 2026-10-20 |

Ultra is a strong multilingual option, not a guarantee of the best result for every voice. [Manufacturer benchmarks](https://huggingface.co/moondream/parakeet-ultra) report improvements over the original Parakeet v3 in multilingual speech and background noise. Those tests use Photon on NVIDIA GPUs, not Vo1cy's quantized Mac runtime. Short words can still be missed or misrecognized.

[Runtime-provider measurements](https://github.com/handy-computer/transcribe.cpp/blob/b61b7f936e4e728f8999a8c3e98c7112e700410e/docs/models/parakeet-ultra.md) report 53 ms for 11 seconds of English audio on M4 Max / Metal / Q8, averaged over three warm runs. This excludes model loading, recording, and text insertion. Download size is not RAM usage.

Downloads and local imports must match the pinned byte count and SHA-256. Imports are installed under the canonical Ultra filename. Failed validation never replaces an installed model. No ASR weights are included in the source or app bundle; the small Silero voice-activity filter is bundled separately under MIT.

When upgrading, an existing Ultra installation is reused. A previously selected unsupported model is deselected; setup points to Ultra if it is not already installed. Old model files are not automatically deleted from disk. Settings, history, and dictionary entries remain local and are preserved.

Allowed languages are an output check, not a strict decoder whitelist. English and German may be mixed in automatic mode. Language tags and script checks cannot identify every error, especially between languages sharing an alphabet.

Exact revision and checksum: [Models.swift](../Sources/Vo1cy/Models.swift). See [model guidance](../Sources/Vo1cy/ModelAssessment.swift) and [third-party notices](../THIRD_PARTY_NOTICES.md).
