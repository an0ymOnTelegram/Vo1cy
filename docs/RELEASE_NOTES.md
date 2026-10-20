# Vo1cy 0.1.0 preview 4 · build 25

Preserve existing local start sounds, with the microphone privacy fixes from preview 3.

- Previously saved local start sounds are used again. Missing, invalid, or overly long start sounds fall back to the built-in cue.
- Custom sound files remain local and are not included in release packages.
- The microphone is active only during an explicit recording. Stop, cancel, and error paths release the input engine completely.
- Previous keep-microphone-active settings are disabled on upgrade. The speech model may still stay loaded for fast recognition without opening the microphone.
- A short start cue confirms recording, followed by optional output muting. Capture starts immediately so the cue does not delay the first words.
- The stop sound plays after output is restored. Rapid release, cancellation, and a subsequent recording cannot trigger a delayed mute from an older recording.
- Existing shortcuts, language settings, dictionary, history, sound volume, and custom stop sound are preserved.

Requires Apple Silicon and macOS 14 or later. Parakeet Ultra is downloaded during setup and runs locally.

**Signing:** this preview is ad-hoc signed and not notarized by Apple. Updates are downloaded manually from GitHub Releases. A signed automatic update channel is not configured.

See [Setup](https://github.com/an0ymOnTelegram/Vo1cy/blob/codex/public-release/docs/SETUP.md), [Privacy](https://github.com/an0ymOnTelegram/Vo1cy/blob/codex/public-release/docs/PRIVACY.md), and [Model details](https://github.com/an0ymOnTelegram/Vo1cy/blob/codex/public-release/docs/MODELS.md).
