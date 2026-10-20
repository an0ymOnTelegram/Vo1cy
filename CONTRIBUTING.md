# Contributing

Use Apple Silicon, macOS 14 or newer, Swift 6.2 or newer, CMake, and Git. Keep application code native and avoid extra inference work in the recording path.

Run these portable checks before submitting a change:

```sh
./scripts/test-core.sh
./scripts/test-languages.sh
./scripts/test-cleanup.sh
./scripts/test-formatting.sh
./scripts/test-punctuation.sh
./scripts/test-instance.sh
./scripts/test-models.sh
./scripts/test-output-mute.sh
./scripts/test-recording-cue.sh
./scripts/test-release-settings.sh
python3 scripts/audit-release.py
```

`swift test` additionally runs the XCTest suite with full Xcode selected after the native runtime is bootstrapped. Hardware-specific shortcut, microphone, and text-insertion checks require macOS permissions and must be run intentionally; they are not safe headless CI assumptions.

Use synthetic, neutral fixtures. Never commit real dictations, personal dictionaries, audio, local file paths, signing material, or private exports. Keep tests for literal protection, mixed languages, cancellation, failed downloads, and single-instance behavior. Do not claim recognition-quality improvements from text-rule tests alone.

Dependencies and model licenses must remain attributed. The Ultra model uses an immutable revision, byte count, SHA-256 hash, language capabilities, license links, and honest resource guidance. Keep model downloads separate from releases.

Pull requests should explain the user-visible change and relevant validation. Report security issues privately through GitHub's security reporting feature when available; never include credentials or personal recordings in a public issue.
