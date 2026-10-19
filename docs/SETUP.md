# Setup and settings

Install one copy in `/Applications/Vo1cy.app`. Launching that app more than once reuses its existing GUI. CLI transcription jobs are separate headless processes.

## First launch

1. Allow microphone access in Setup. If denied, open macOS Privacy & Security → Microphone.
2. Download Parakeet Ultra directly in Setup or on the Model page. Downloads show progress, support cancellation, verify SHA-256 and size, and remove partial files on failure. Retry by choosing Download again. The model is not downloaded silently at launch.
3. Choose your recognition language. Automatic detection preserves the spoken language. English and German can be mixed in automatic mode.
4. Choose a shortcut. The default is Option–Command–Space, held while speaking. Toggle mode and standalone keys are available under General.
5. Allow Accessibility if you want text inserted into another application, or use a standalone modifier shortcut. You may turn automatic insertion off and copy text manually.
6. Finish setup after the model has successfully loaded and the required permissions are available.

The Model page manages Parakeet Ultra: download, reload, import, or delete it. Imported Ultra Q8 files must match the same pinned size and SHA-256 as downloads. Existing Ultra installations are reused when upgrading; unsupported selections are cleared without deleting old model files.

## Settings reference

| Page | Controls |
| --- | --- |
| General | Shortcut and hold/toggle mode; recognition language; allowed-language selection; microphone; output muting; sound enable/volume/import/reset; indicator enable/position/preview |
| Model | Download/cancel/retry; select/reload; import; delete; source/license/release information |
| Post-processing | Punctuation; sentence boundaries; spoken lists; fillers; restarts; common spellings; custom dictionary; phrase or whole-dictation scope; protection of quoted text, code, and URLs for phrase rules |
| Advanced | Keep model loaded; keep microphone active; CPU mode and Apply; automatic insertion; trailing space; insertion/clipboard delays; audio saving; history limit and retention; launch at login; microphone refresh |
| History | Copy; correct; save an optional reusable rule; export; delete; playback and retranscription if audio was saved |
| About | Version/build; release downloads or configured Sparkle updates; diagnostic export; Telegram creator/community links |

The app uses a dark purple appearance. History defaults to 100 entries and 30 days. Set maximum entries to 0 to disable history; retention days 0 disables the age limit. Audio saving is off by default. Turning it off does not erase existing recordings; delete their history entries or reduce retention to remove them.

## Troubleshooting

- **Fn opens emoji:** macOS Keyboard settings can assign the Globe key to Do Nothing. Vo1cy does not change that system preference automatically.
- **Permission appears enabled but is not recognized:** ensure only the current app is in Applications. Remove the old Accessibility entry, add the current app, and restart. Ad-hoc builds can require renewed permission after updates; stable Developer ID signing is needed for a distributed update identity.
- **No inserted text:** check History and any language warning, Accessibility, and the target text field. Increase insertion delay if the target app is slow. Vo1cy never presses Return or submits a form.
- **Unsupported output device:** turn output muting off in General, or use another output device. Muting is restored on stop/cancel and the next launch can recover a persisted session after a crash.
- **Slow first use:** model download, model loading, and Metal initialization are separate from warm inference. Keep the model loaded to avoid repeated initialization.
