# Privacy and local data

Speech recognition and text cleanup run locally. Vo1cy has no telemetry, account service, or transcription upload endpoint.

Model downloads contact Hugging Face (including its download/CDN endpoints). Links to model documentation, licenses, and GitHub open in the browser. A configured Sparkle channel contacts its update server; this preview has no automatic update channel.

User data is stored under `~/Library/Application Support/Vo1cy/`:

- `settings.json`: preferences, shortcut, model path, and custom dictionary.
- `history.json`: raw and processed text, model/language, timings, and optional audio references.
- `Audio/`: recordings, only when saving audio is enabled.
- `Models/`: downloaded/imported recognition models.
- `SoundEffects/`: optional locally imported recording sound.
- Lock and output-mute recovery files used for process coordination and restoring audio output.

History and settings exports are explicit actions. History export contains transcription text. Diagnostic export omits transcription text, audio, dictionary entries, and file paths, but includes app, operating-system, engine and timing information. Review any export before sharing it.

Deleting a history entry also deletes its associated saved recording. Retention pruning does the same. Microphone warm mode discards audio outside a recording, but keeps the hardware active. Switch it off to release the microphone between recordings.

Source archives and release packages must never include a user's data directory, audio samples, personal dictionaries, signing keys, or local development reports. See the release audit script and packaging instructions.
