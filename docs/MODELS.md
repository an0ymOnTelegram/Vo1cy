# Model catalog

Catalog reviewed 2026-10-19. Release dates refer to the upstream model, not its converted package. Sizes are approximate decimal download sizes, not RAM estimates. Recognition accuracy depends on speech, language, microphone, noise, and conversion.

| Model | Download | Recognition | Upstream release | Weight license |
| --- | --- | --- | --- | --- |
| Parakeet Ultra Q8 | 740 MB | 25 languages; result after recording | 2026-09-22 | CC BY 4.0 |
| Nemotron 3.5 Streaming Q8 | 751 MB | 32 language/locale entries; live text | 2026-06-04 | OpenMDW-1.1 |
| Parakeet Redux Core ML | 220 MB | 25 languages; result after recording; macOS 15+ | 2026-09-22 | CC BY 4.0 |
| Orukeet Q8 | 740 MB | 25 languages; result after recording | 2026-09-11 | CC BY-SA 4.0 |
| Canary 180M Flash Q8 | 218 MB | English, German, French, Spanish; fixed language | March 2025; exact day unconfirmed | CC BY 4.0 |

Start with Ultra for multilingual quality, Nemotron for streaming, or Redux to reduce download/storage size. These are recommendations, not a claim that one model always wins. The app links the relevant upstream release and benchmark sources. Provider benchmark figures exclude recording, pasting, and first-load costs; Redux encoder-only figures must not be compared as complete transcription times.

The app verifies catalog downloads against pinned SHA-256 hashes and byte counts. Redux is a multi-file package installed only after all required files verify. Cancellation and failed validation remove staged files. Model files remain local and are not bundled in GitHub source or app downloads. The small Silero voice-activity model is bundled separately under MIT.

Allowing selected languages is an output check, not a strict decoder whitelist. English and German may be mixed when using an automatic multilingual model. Some backends do not emit a detected-language identifier, so script checks alone cannot reliably distinguish languages that share an alphabet. Short words can be missed or misrecognized by any model.

Sources and exact pinned conversions: [Models.swift](../Sources/Vo1cy/Models.swift), [Redux manifest](../Sources/Vo1cy/ReduxManifest.swift), [release/benchmark sources](../Sources/Vo1cy/ModelAssessment.swift), and [third-party notices](../THIRD_PARTY_NOTICES.md).
