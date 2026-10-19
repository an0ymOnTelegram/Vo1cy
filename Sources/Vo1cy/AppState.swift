import SwiftUI
import AVFoundation
import ServiceManagement
import VoiceCore

@MainActor
final class AppState: ObservableObject {
    enum Phase: String { case idle = "Ready", loading = "Loading model", listening = "Recording", processing = "Transcription", inserting = "Inserting" }
    @Published var preferences: Preferences
    @Published var history: [HistoryEntry]
    @Published var phase = Phase.idle
    @Published var status = "Local speech recognition on your Mac."
    @Published var partial = ""
    @Published var level: Float = 0
    @Published var seconds = 0.0
    @Published var capabilities: ModelCapabilities?
    @Published var downloadID: String?
    @Published var downloadProgress = 0.0
    @Published var microphoneAllowed = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    @Published var accessibilityAllowed = TextOutput.trusted
    @Published var installedModels: [URL] = []
    @Published var devices = InputDevice.available()
    @Published var lastLoadMS = 0.0
    @Published var lastFinishMS = 0.0
    @Published var startAtLogin = SMAppService.mainApp.status == .enabled
    @Published var shortcutError: String?
    let updater = UpdateService()
    let root: URL
    private let interactionSounds: InteractionSounds
    private let outputMute: SystemOutputMute
    private let engine = NativeEngine()
    private let capture = AudioCapture()
    private let shortcut = GlobalShortcut()
    private let output = TextOutput()
    private let overlay = RecordingOverlay()
    private var generation = RunGeneration()
    private var flag = AbortFlag()
    private var samples: [Float] = []
    private var target: NSRunningApplication?
    private var runSettings = Preferences()
    private var stream = false
    private var stopRequested = false
    private var captureActive = false
    private var decoderReady = false
    private var captureInbox = CaptureInbox()
    private var pendingChunks = 0
    private var lastBuffer = Date()
    private var watchdog: Timer?
    private var downloader: ModelDownload?
    private var downloadGeneration = UUID()
    private var escapeLocal: Any?
    private var escapeGlobal: Any?
    private var player: AVAudioPlayer?
    private var registeredShortcut = ""
    private var editingShortcut = false
    private var validatedModelPath: String?
    private var shortcutHeld = false
    var busy: Bool { phase != .idle }
    var shortcutNeedsAccessibility: Bool { ShortcutKeys.modifier(preferences.shortcutCode) != nil }
    var setupReady: Bool {
        SetupPolicy.ready(microphone: microphoneAllowed, accessibility: accessibilityAllowed,
            automaticInsertion: preferences.pasteAutomatically, modifierShortcut: shortcutNeedsAccessibility,
            modelPath: preferences.modelPath, validatedModelPath: validatedModelPath)
    }
    var modelDirectory: URL { root.appendingPathComponent("Models", isDirectory: true) }
    var audioDirectory: URL { root.appendingPathComponent("Audio", isDirectory: true) }

    init() {
        root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Vo1cy", isDirectory: true)
        interactionSounds = InteractionSounds(root: root)
        outputMute = SystemOutputMute(root: root)
        preferences = (try? Persistence.load(Preferences.self, from: root.appendingPathComponent("settings.json"))) ?? Preferences()
        history = (try? Persistence.load([HistoryEntry].self, from: root.appendingPathComponent("history.json"))) ?? []
        interactionSounds.configure(enabled: preferences.playSounds, volume: preferences.soundVolume ?? 1)
        overlay.position = OverlayPosition(savedValue: preferences.overlayPosition)
        outputMute.onFailure = { [weak self] error in
            guard let self else { return }
            self.fail(error, token: self.generation.value)
        }
        capture.onDeviceChange = { [weak self] in
            guard let self else { return }
            self.cancel(); self.capture.shutdown(); self.devices = InputDevice.available()
            self.status = "The audio input changed. Check the microphone and record again."
        }
        shortcut.pressed = { [weak self] in self?.hotkeyDown() }
        shortcut.released = { [weak self] in self?.hotkeyUp() }
        shortcut.interrupted = { [weak self] in
            self?.shortcutHeld = false
            self?.cancel()
        }
        refreshModels()
        let previousModel = preferences.modelPath
        preferences.modelPath = CatalogModel.preferredPath(previous: previousModel, installed: installedModels)
        preferences.translate = false
        if previousModel != preferences.modelPath && preferences.modelPath.isEmpty {
            status = "Download Parakeet Ultra to continue. Your settings and history are preserved."
        }
        savePreferences()
        escapeLocal = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53, self?.busy == true { self?.cancel(); return nil }; return event
        }
        escapeGlobal = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.cancel() }
        }
        if !preferences.modelPath.isEmpty {
            Task { await prepareModel() }
        }
    }

    func savePreferences() {
        do { try Persistence.save(preferences, to: root.appendingPathComponent("settings.json")) }
        catch { status = "Could not save settings: \(error.localizedDescription)" }
        configureShortcut(); pruneHistory()
        interactionSounds.configure(enabled: preferences.playSounds, volume: preferences.soundVolume ?? 1)
        overlay.position = OverlayPosition(savedValue: preferences.overlayPosition)
        if !preferences.warmMicrophone && !busy { capture.shutdown() }
    }

    private func configureShortcut() {
        guard preferences.onboardingComplete, !editingShortcut else { return }
        let key = "\(preferences.shortcutCode):\(preferences.shortcutModifiers)"
        guard registeredShortcut != key else { return }
        do {
            try shortcut.register(key: preferences.shortcutCode, modifiers: preferences.shortcutModifiers)
            registeredShortcut = key
            shortcutError = nil
        } catch { registeredShortcut = ""; shortcutError = error.localizedDescription; status = error.localizedDescription }
    }

    func importSound(_ url: URL) {
        do { try interactionSounds.importStopSound(url); status = "Custom recording sound saved." }
        catch { status = error.localizedDescription }
    }

    func resetSound() {
        do { try interactionSounds.reset(); status = "Built-in recording sound restored." }
        catch { status = error.localizedDescription }
    }

    func previewSound() { interactionSounds.stop() }

    func previewOverlay() {
        guard !busy else { return }
        overlay.position = OverlayPosition(savedValue: preferences.overlayPosition)
        overlay.preview()
    }

    func editShortcut(_ editing: Bool) {
        editingShortcut = editing
        if editing { shortcut.unregister(); registeredShortcut = ""; shortcutHeld = false }
        else { configureShortcut() }
    }

    func refreshPermissions() {
        refreshPermissionStatus()
        devices = InputDevice.available()
    }
    func refreshPermissionStatus() {
        microphoneAllowed = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        let trusted = TextOutput.trusted
        let changed = accessibilityAllowed != trusted
        accessibilityAllowed = trusted
        if changed, ShortcutKeys.modifier(preferences.shortcutCode) != nil {
            shortcut.unregister(); registeredShortcut = ""; shortcutHeld = false
            if !trusted { cancel() }
        }
        if registeredShortcut.isEmpty { configureShortcut() }
    }
    func askMicrophone() async {
        _ = await AVCaptureDevice.requestAccess(for: .audio); refreshPermissions()
        if !microphoneAllowed { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!) }
    }
    func completeSetup() {
        refreshPermissions()
        guard setupReady else { status = "Check microphone access, the selected model, and shortcut permissions."; return }
        preferences.onboardingComplete = true; savePreferences()
        Task { await prepareModel() }
    }

    func prepareModel() async {
        guard !busy else { return }
        validatedModelPath = nil
        phase = .loading; let token = generation.next()
        do {
            let start = DispatchTime.now()
            let caps = try await engine.load(path: preferences.modelPath, cpu: preferences.useCPU)
            guard generation.accepts(token) else { return }
            capabilities = caps
            validatedModelPath = preferences.modelPath
            lastLoadMS = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1e6
            preferences.language = SetupPolicy.recognitionLanguage(current: preferences.language,
                supported: caps.languages, automatic: caps.autoLanguage, preferred: Locale.preferredLanguages.first ?? "en")
            if !caps.translation { preferences.translate = false }
            status = "Ready · \(caps.backend) · \(caps.streaming ? "Streaming" : "Recognition after recording")"
            if preferences.warmMicrophone && microphoneAllowed && preferences.onboardingComplete { try capture.prepare(device: preferences.deviceID) }
            phase = .idle; savePreferences()
            if !preferences.keepModelLoaded { await engine.unload() }
        } catch { if generation.accepts(token) { phase = .idle; status = error.localizedDescription } }
    }

    private func hotkeyDown() {
        shortcutHeld = true
        if preferences.shortcutMode == "toggle" { toggleRecording() }
        else if !busy { Task { if shortcutHeld { await begin() } } }
    }
    private func hotkeyUp() {
        shortcutHeld = false
        guard preferences.shortcutMode == "hold" else { return }
        if captureActive { stop() }
    }
    func toggleRecording() {
        if captureActive { stop() }
        else if !busy { Task { await begin() } }
    }

    func begin() async {
        guard !busy else { return }
        refreshPermissionStatus()
        guard microphoneAllowed else { status = "Allow microphone access in Setup first."; return }
        target = NSWorkspace.shared.frontmostApplication
        let token = generation.next(); flag = AbortFlag(); let activeFlag = flag
        runSettings = preferences; stopRequested = false; decoderReady = false
        samples = []; partial = ""; seconds = 0; pendingChunks = 0
        let inbox = CaptureInbox(); captureInbox = inbox
        phase = .loading
        do {
            // Silence output before opening capture, without waiting for a cue.
            if runSettings.muteOutput ?? true { try outputMute.begin() }
            player?.stop()
            interactionSounds.silence()
            // Capture immediately; decoder startup must not erase the first words.
            captureActive = true; lastBuffer = Date()
            try capture.start(device: runSettings.deviceID) { [weak self] chunk in
                guard inbox.append(chunk) else { return }
                DispatchQueue.main.async { self?.drainCapture(token: token, flag: activeFlag) }
            }
            if preferences.showOverlay { overlay.startRecording() }
            watchdog = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.captureActive else { return }
                    if Date().timeIntervalSince(self.lastBuffer) > 3 {
                        self.fail(EngineFailure(message: "The microphone is not providing audio. Check the input device."), token: token)
                    }
                }
            }
            let caps = try await engine.load(path: runSettings.modelPath, cpu: runSettings.useCPU)
            guard generation.accepts(token) else { return }
            capabilities = caps
            validatedModelPath = preferences.modelPath; stream = caps.streaming
            if stream { try await engine.beginStream(language: LanguagePolicy.recognitionLanguage(requested: runSettings.language, selection: runSettings.allowedLanguages), translate: runSettings.translate, flag: activeFlag) }
            else { try await engine.beginVoiceGate(flag: activeFlag) }
            guard generation.accepts(token) else { return }
            guard Double(samples.count) <= caps.maxSeconds * 16000 else {
                throw EngineFailure(message: "The recording exceeds this model's duration limit.")
            }
            decoderReady = true
            if !samples.isEmpty { feedCaptured(samples, token: token, flag: activeFlag) }
            if stopRequested { finishRecording() }
            else {
                phase = .listening
            }
        } catch { fail(error, token: token) }
    }

    private func drainCapture(token: UInt64, flag: AbortFlag) {
        guard generation.accepts(token), captureActive else { return }
        for chunk in captureInbox.drain() { accept(chunk, token: token, flag: flag) }
    }

    private func accept(_ chunk: [Float], token: UInt64, flag: AbortFlag, checkLimit: Bool = true) {
        guard captureActive, generation.accepts(token), !flag.isCancelled else { return }
        lastBuffer = Date()
        let limit = min(600, capabilities?.maxSeconds ?? 30)
        let available = max(0, Int(limit * 16000) - samples.count)
        let accepted = Array(chunk.prefix(available))
        samples.append(contentsOf: accepted); seconds = Double(samples.count) / 16000
        if !accepted.isEmpty { level = min(1, sqrt(accepted.reduce(0) { $0 + $1 * $1 } / Float(accepted.count)) * 8) }
        if preferences.showOverlay { overlay.updateLevel(level) }
        if decoderReady && !accepted.isEmpty { feedCaptured(accepted, token: token, flag: flag) }
        if checkLimit && samples.count >= Int(limit * 16000) { stop() }
    }

    private func feedCaptured(_ accepted: [Float], token: UInt64, flag: AbortFlag) {
        // Bound work queued behind a slow decoder; never silently drop speech.
        guard pendingChunks < 40 else {
            fail(EngineFailure(message: "Recognition cannot keep up. Use a shorter recording or a different model."), token: token)
            return
        }
        pendingChunks += 1
        let completion: (Result<String, Error>) -> Void = { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.generation.accepts(token) else { return }
                self.pendingChunks = max(0, self.pendingChunks - 1)
                switch result {
                case .success(let text):
                    guard self.stream, self.phase == .listening else { return }
                    self.partial = text
                case .failure(let error): self.fail(error, token: token)
                }
            }
        }
        if stream { engine.feed(accepted, flag: flag, completion: completion) }
        else { engine.feedVoiceGate(accepted, flag: flag, completion: completion) }
    }

    func stop() {
        guard captureActive else { return }
        capture.stop(warm: runSettings.warmMicrophone)
        // The producer has stopped, including its in-flight callback. Drain before
        // changing phase; queued main-thread notifications cannot lose final audio.
        for chunk in captureInbox.finish() { accept(chunk, token: generation.value, flag: flag, checkLimit: false) }
        guard captureActive else { return } // A feed failure may have cancelled.
        captureActive = false; stopRequested = true
        watchdog?.invalidate(); watchdog = nil
        outputMute.restore()
        interactionSounds.stop()
        phase = .processing; level = 0
        if preferences.showOverlay { overlay.processing() }
        if decoderReady { finishRecording() }
    }

    private func finishRecording() {
        guard decoderReady, !captureActive, stopRequested else { return }
        let token = generation.value; let activeFlag = flag; let audio = samples; let isStream = stream
        let finishStart = DispatchTime.now()
        Task {
            do {
                guard audio.count >= 1600 else { throw EngineFailure(message: "The recording is too short.") }
                let energy = audio.reduce(0.0) { $0 + Double($1 * $1) } / Double(audio.count)
                guard energy > 0.0000001 else { throw EngineFailure(message: "No audible signal detected.") }
                let result = try await (isStream ? engine.finishStream(flag: activeFlag) : engine.run(samples: audio, language: LanguagePolicy.recognitionLanguage(requested: runSettings.language, selection: runSettings.allowedLanguages), translate: runSettings.translate, flag: activeFlag, voiceCheckedDuringCapture: true))
                guard generation.accepts(token) else { return }
                lastFinishMS = Double(DispatchTime.now().uptimeNanoseconds - finishStart.uptimeNanoseconds) / 1e6
                await acceptResult(result, audio: audio, token: token, paste: true)
            } catch { fail(error, token: token) }
        }
    }

    private func acceptResult(_ result: Recognition, audio: [Float], token: UInt64, paste: Bool) async {
        guard generation.accepts(token) else { return }
        let language = result.language.isEmpty ? runSettings.language : result.language
        let languageWarning = LanguagePolicy.warning(text: result.text, raw: result.raw, detected: result.language, requested: runSettings.language, selection: runSettings.allowedLanguages)
        let formattingLanguage = TextRules.formattingLanguage(requested: runSettings.language, detected: result.language)
        let text = languageWarning != nil ? result.text : TextRules.apply(result.text, language: formattingLanguage, fillers: runSettings.removeFillers, dictionary: runSettings.dictionary, punctuation: runSettings.cleanPunctuation ?? true, sentences: runSettings.formatSentences ?? true, lists: runSettings.formatLists ?? true, restarts: runSettings.cleanRestarts ?? true, spellings: runSettings.normalizeSpellings ?? true)
        guard !text.isEmpty else { fail(EngineFailure(message: "No speech detected."), token: token); return }
        var entry = HistoryEntry(text: text, raw: result.raw, model: URL(fileURLWithPath: runSettings.modelPath).lastPathComponent, language: language, duration: Double(audio.count) / 16000, computeMS: result.milliseconds)
        entry.languageWarning = languageWarning
        if runSettings.saveAudio {
            do {
                try FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
                let name = entry.id.uuidString + ".wav"
                try AudioCapture.writeWAV(audio, to: audioDirectory.appendingPathComponent(name)); entry.audioFile = name
            } catch { status = "Text was recognized, but the audio could not be saved." }
        }
        history.insert(entry, at: 0); pruneHistory(); partial = text; samples = []
        overlay.hide(); status = "Text saved to history"
        if let languageWarning {
            status = "Not inserted — " + languageWarning + " Review the result in History or dictate again."
            if preferences.showOverlay { overlay.notice(status) }
        }
        if LanguagePolicy.shouldPaste(automatically: runSettings.pasteAutomatically, requested: paste, warning: languageWarning) {
            phase = .inserting
            let message = await output.deliver(text + (runSettings.trailingSpace ? " " : ""), to: target,
                beforeMS: runSettings.pasteDelayMS, restoreMS: runSettings.restoreDelayMS,
                valid: { [weak self] in self?.generation.accepts(token) == true })
            if generation.accepts(token) {
                status = message
                if preferences.showOverlay && !message.hasPrefix("Paste requested") { overlay.notice(message) }
            }
        }
        guard generation.accepts(token) else { return }
        if !runSettings.keepModelLoaded { await engine.unload() }
        guard generation.accepts(token) else { return }
        phase = .idle
    }

    func cancel() {
        outputMute.restore()
        guard busy else { return }
        generation.next(); flag.cancel(); capture.stop(warm: preferences.warmMicrophone)
        _ = captureInbox.finish(); captureActive = false; decoderReady = false
        watchdog?.invalidate(); watchdog = nil; samples = []; pendingChunks = 0; level = 0
        overlay.hide(); phase = .idle; status = "Cancelled — no further text will be inserted."
    }
    private func fail(_ error: Error, token: UInt64) {
        guard generation.accepts(token) else { return }
        cancel(); status = error is CancellationError ? "Cancelled" : error.localizedDescription
        if preferences.showOverlay { overlay.notice(status) }
    }

    func importAudio(_ url: URL) {
        guard !busy else { return }
        let token = generation.next(); flag = AbortFlag(); let activeFlag = flag
        runSettings = preferences; phase = .loading; partial = ""
        Task {
            do {
                let caps = try await engine.load(path: runSettings.modelPath, cpu: runSettings.useCPU)
                guard generation.accepts(token) else { return }; capabilities = caps; phase = .processing
                let audio = try await Task.detached { try AudioCapture.readFile(url, maxSeconds: min(600, caps.maxSeconds)) }.value
                let result = try await engine.run(samples: audio, language: LanguagePolicy.recognitionLanguage(requested: runSettings.language, selection: runSettings.allowedLanguages), translate: runSettings.translate, flag: activeFlag)
                await acceptResult(result, audio: audio, token: token, paste: false)
            } catch { fail(error, token: token) }
        }
    }

    func refreshModels() {
        installedModels = ((try? FileManager.default.contentsOfDirectory(at: modelDirectory, includingPropertiesForKeys: [.isRegularFileKey])) ?? [])
            .filter { $0.lastPathComponent == CatalogModel.ultra.filename && (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
    }
    func download(_ model: CatalogModel) {
        guard downloadID == nil, model.id == CatalogModel.ultra.id else { return }
        let token = UUID(); downloadGeneration = token; downloadID = model.id; downloadProgress = 0
        downloader = ModelDownload(model: model, destination: modelDirectory.appendingPathComponent(model.filename), progress: { [weak self] fraction in
            DispatchQueue.main.async { if self?.downloadGeneration == token { self?.downloadProgress = fraction } }
        }, completion: { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.downloadGeneration == token else { return }
                self.downloadID = nil; self.downloader = nil; self.refreshModels()
                switch result {
                case .success(let url): self.status = "Model downloaded and verified with SHA-256."; if !self.busy && self.preferences.modelPath.isEmpty { self.selectModel(url) }
                case .failure(let error): self.status = "Download stopped: \(error.localizedDescription)"
                }
            }
        }); downloader?.start()
    }
    func cancelDownload() { downloader?.cancel() }
    func selectModel(_ url: URL) {
        guard !busy, url.lastPathComponent == CatalogModel.ultra.filename else { return }; preferences.modelPath = url.path; capabilities = nil; savePreferences()
        Task { await prepareModel() }
    }
    func importModel(_ url: URL) {
        guard !busy else { return }
        validatedModelPath = nil
        phase = .loading; let token = generation.next()
        let destination = modelDirectory.appendingPathComponent(CatalogModel.ultra.filename)
        Task {
            do {
                try await Task.detached {
                    try CatalogModel.ultra.validateFile(url)
                    if url.standardizedFileURL == destination.standardizedFileURL { return }
                    try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try FileManager.default.copyItem(at: url, to: destination)
                }.value
                refreshModels()
                guard generation.accepts(token) else { return }
                phase = .idle; selectModel(destination)
            } catch { if generation.accepts(token) { phase = .idle; status = error.localizedDescription } }
        }
    }
    func deleteModel(_ url: URL) async {
        guard !busy, url.deletingLastPathComponent().standardizedFileURL == modelDirectory.standardizedFileURL else { return }
        phase = .loading
        await engine.unload()
        do {
            try FileManager.default.removeItem(at: url)
            if preferences.modelPath == url.path { preferences.modelPath = ""; capabilities = nil }
            refreshModels(); savePreferences()
        } catch { status = error.localizedDescription }
        phase = .idle
    }

    private func audioURL(_ entry: HistoryEntry) -> URL? {
        guard let name = entry.audioFile, name == URL(fileURLWithPath: name).lastPathComponent, name.hasSuffix(".wav") else { return nil }
        return audioDirectory.appendingPathComponent(name)
    }
    private func pruneHistory() {
        let retained = Retention.retained(history, limit: preferences.historyLimit, days: preferences.retentionDays)
        let ids = Set(retained.map(\.id))
        for entry in history where !ids.contains(entry.id) { if let url = audioURL(entry) { try? FileManager.default.removeItem(at: url) } }
        history = retained
        do { try Persistence.save(history, to: root.appendingPathComponent("history.json")) }
        catch { status = "Could not save history: \(error.localizedDescription)" }
    }
    func deleteHistory(_ entry: HistoryEntry) {
        if let url = audioURL(entry) { try? FileManager.default.removeItem(at: url) }
        history.removeAll { $0.id == entry.id }; pruneHistory()
    }
    func correct(_ entry: HistoryEntry, text: String, rule: Replacement?) throws {
        guard !busy, let index = history.firstIndex(where: { $0.id == entry.id }) else {
            throw EngineFailure(message: "This entry is no longer available or a recording is in progress.")
        }
        let corrected = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !corrected.isEmpty else { throw EngineFailure(message: "Enter the corrected text.") }
        var updated = history
        updated[index].text = corrected // Raw recognition and recording remain unchanged.
        try Persistence.save(updated, to: root.appendingPathComponent("history.json"))
        history = updated
        if partial == entry.text { partial = corrected }
        if let rule {
            var settings = preferences
            settings.dictionary = CorrectionRules.saving(rule, in: settings.dictionary)
            do { try Persistence.save(settings, to: root.appendingPathComponent("settings.json")) }
            catch { throw EngineFailure(message: "Text was corrected, but the rule could not be saved: \(error.localizedDescription)") }
            preferences = settings
        }
        status = rule == nil ? "Dictation corrected." : "Dictation corrected. The saved rule applies to future dictations."
    }
    func play(_ entry: HistoryEntry) {
        guard let url = audioURL(entry) else { return }
        do { player = try AVAudioPlayer(contentsOf: url); player?.play() } catch { status = error.localizedDescription }
    }
    func retry(_ entry: HistoryEntry) { if let url = audioURL(entry) { importAudio(url) } }
    func exportHistory(to url: URL) {
        do { try Persistence.save(history, to: url); status = "History exported." } catch { status = error.localizedDescription }
    }
    func exportDiagnostics(to url: URL) {
        let values: [String: String] = ["app": "Vo1cy", "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development",
            "os": ProcessInfo.processInfo.operatingSystemVersionString, "backend": capabilities?.backend ?? "none", "streaming": String(capabilities?.streaming ?? false),
            "modelLoadMS": String(lastLoadMS), "stopToResultMS": String(lastFinishMS), "language": preferences.language]
        do { try Persistence.save(values, to: url); status = "Diagnostics exported without transcripts, audio, or personal paths." } catch { status = error.localizedDescription }
    }
    func setLogin(_ enabled: Bool) {
        do { if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; startAtLogin = SMAppService.mainApp.status == .enabled }
        catch { startAtLogin = SMAppService.mainApp.status == .enabled; status = error.localizedDescription }
    }
    func shutdown() { flag.cancel(); capture.shutdown(); outputMute.shutdown(); shortcut.unregister(); downloader?.cancel(); engine.shutdown() }
}
