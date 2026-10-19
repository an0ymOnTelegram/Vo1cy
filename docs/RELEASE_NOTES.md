# Vo1cy 0.1.0 preview 2 · build 23

A focused local dictation app for Apple Silicon, powered by Parakeet Ultra.

- One speech-recognition model throughout setup, downloads, and settings: Parakeet Ultra Q8, with 25 languages including English and German.
- Discreet Telegram creator and community links in the sidebar and About page.
- Existing Ultra downloads are reused. Unsupported selections are migrated without deleting settings, history, dictionaries, or model files.
- Downloads and local imports use the same pinned size and SHA-256 verification.
- Removed the unused Redux engine and FluidAudio package dependency.
- Native English interface, dark purple appearance, configurable shortcuts, microphone bubble, output muting, and local text cleanup.

Requires Apple Silicon and macOS 14 or later. Download the speech model during setup. Audio stays on the Mac; opening Telegram links is optional.

**Signing:** this preview is ad-hoc signed and not notarized by Apple. Updates are downloaded manually from GitHub Releases. A signed automatic update channel is not configured.

See [Setup](https://github.com/an0ymOnTelegram/Vo1cy/blob/codex/public-release/docs/SETUP.md), [Privacy](https://github.com/an0ymOnTelegram/Vo1cy/blob/codex/public-release/docs/PRIVACY.md), and [Model details](https://github.com/an0ymOnTelegram/Vo1cy/blob/codex/public-release/docs/MODELS.md). Recognition and punctuation remain imperfect; performance depends on the Mac and recording conditions.
