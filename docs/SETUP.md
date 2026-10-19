# Setup and settings

Install one copy in `/Applications/Vo1cy.app`. Launching that app more than once reuses its existing GUI. CLI transcription jobs are separate headless processes.

## First launch

1. Allow microphone access in Setup. If denied, open macOS Privacy & Security → Microphone.
2. Download the recommended model directly in Setup, or use Browse models to choose another. Downloads show progress, support cancellation, verify SHA-256 and size, and remove partial files on failure. Retry by choosing Download again. Models are not downloaded silently at launch.
3. Choose your recognition language. Automatic detection preserves the spoken language. A fixed-language model falls back to a supported system language, or English, if necessary.
4. Choose a shortcut. The default is Option–Command–Space, held while speaking. Toggle mode and standalone keys are available under General.
5. Allow Accessibility if you want text inserted into another application, or use a standalone modifier shortcut. You may turn automatic insertion off and copy text manually.
6. Finish setup after the model has successfully loaded and the required permissions are available.

On the Models page, downloading an additional model does not replace your current selection. Choose **Use model** to switch. Model files can also be imported from a local GGUF; imported files are not authenticated against the catalog hashes.

## Settings reference

| Page | Controls |
| --- | --- |
| General | Shortcut and hold/toggle mode; recognition language; allowed-language selection; translation when supported; microphone; output muting; sound enable/volume/import/reset; indicator enable/position/preview |
| Models | Download/cancel/retry; select/reload; import; delete; source/license/release information |
| Post-processing | Punctuation; sentence boundaries; spoken lists; fillers; restarts; common spellings; custom dictionary; phrase or whole-dictation scope; protection of quoted text, code, and URLs for phrase rules |
| Advanced | Keep model loaded; keep microphone active; CPU mode and Apply; automatic insertion; trailing space; insertion/clipboard delays; audio saving; history limit and retention; launch at login; microphone refresh |
| History | Copy; correct; save an optional reusable rule; export; delete; playback and retranscription if audio was saved |
| About | Version/build; release downloads or configured Sparkle updates; diagnostic export |

The app uses a dark purple appearance. History defaults to 100 entries and 30 days. Set maximum entries to 0 to disable history; retention days 0 disables the age limit. Audio saving is off by default. Turning it off does not erase existing recordings; delete their history entries or reduce retention to remove them.

## Troubleshooting

- **Fn opens emoji:** macOS Keyboard settings can assign the Globe key to Do Nothing. Vo1cy does not change that system preference automatically.
- **Permission appears enabled but is not recognized:** ensure only the current app is in Applications. Remove the old Accessibility entry, add the current app, and restart. Ad-hoc builds can require renewed permission after updates; stable Developer ID signing is needed for a distributed update identity.
- **No inserted text:** check History and any language warning, Accessibility, and the target text field. Increase insertion delay if the target app is slow. Vo1cy never presses Return or submits a form.
- **Unsupported output device:** turn output muting off in General, or use another output device. Muting is restored on stop/cancel and the next launch can recover a persisted session after a crash.
- **Slow first use:** model download, model loading, and Core ML compilation are separate from warm inference. Keep the model loaded to avoid repeated initialization.
