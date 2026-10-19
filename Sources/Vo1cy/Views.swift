import SwiftUI
import UniformTypeIdentifiers
import VoiceCore

final class NavigationSelection: ObservableObject {
    @Published var section = "General"
    @Published var correction: HistoryEntry?
}

struct MainView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var navigation = NavigationSelection()
    private let sections = ["General", "Dictation", "History", "Model", "Post-processing", "Advanced"]
    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Vo1cyStyle.border).frame(width: 1)
            VStack(alignment: .leading, spacing: 0) {
                header
                Rectangle().fill(Vo1cyStyle.border).frame(height: 1)
                ScrollView {
                    page.padding(20).frame(maxWidth: 850, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }.defaultScrollAnchor(.top).id(navigation.section)
                footer
            }.background(Vo1cyStyle.background)
        }
        .frame(minWidth: 760, minHeight: 540)
        .font(.system(size: 13))
        .foregroundStyle(.white.opacity(0.92))
        .buttonStyle(CompactButtonStyle())
        .controlSize(.small)
        .tint(Vo1cyStyle.accent)
        .preferredColorScheme(.dark)
        .background(CompactWindow())
        .onAppear { if !state.preferences.onboardingComplete || state.preferences.modelPath.isEmpty { navigation.section = "Setup" } }
        .onChange(of: state.preferences) { _, _ in state.savePreferences() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in state.refreshPermissions() }
        .sheet(item: $navigation.correction) { entry in
            HistoryCorrectionView(text: entry.text) { text, rule in
                try state.correct(entry, text: text, rule: rule)
            }
            .onAppear { state.editShortcut(true) }
            .onDisappear { state.editShortcut(false) }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "waveform").font(.system(size: 23, weight: .medium)).foregroundStyle(Vo1cyStyle.accent)
                Text("Vo1cy").font(.system(size: 25, weight: .bold, design: .rounded)).tracking(-1)
            }.padding(.horizontal, 17).padding(.top, 20).padding(.bottom, 24)
            VStack(spacing: 4) { ForEach(sections, id: \.self) { navigationButton($0) } }.padding(.horizontal, 9)
            Spacer(minLength: 20)
            VStack(spacing: 4) { navigationButton("Setup"); navigationButton("About Vo1cy") }.padding(.horizontal, 9)
            Rectangle().fill(Vo1cyStyle.border).frame(height: 1).padding(.horizontal, 16).padding(.vertical, 14)
            VStack(alignment: .leading, spacing: 5) {
                Label("Local on your Mac", systemImage: "lock.shield").font(.system(size: 10, weight: .medium))
                Text("v\(AppVersion.display) · Preview").font(.system(size: 10)).foregroundStyle(Vo1cyStyle.muted)
                CommunityLinks().padding(.top, 8)
            }.padding(.horizontal, 16).padding(.bottom, 17)
        }.frame(width: 166).background(Vo1cyStyle.sidebar)
    }

    private func navigationButton(_ section: String) -> some View {
        let selected = navigation.section == section
        return Button { navigation.section = section } label: {
            HStack(spacing: 9) {
                Image(systemName: icon(section)).font(.system(size: 14)).frame(width: 18)
                Text(section).font(.system(size: 12, weight: selected ? .semibold : .medium))
                    .lineLimit(1).minimumScaleFactor(0.85)
                Spacer(minLength: 0)
                if section == "Setup", !state.preferences.onboardingComplete {
                    Circle().fill(Vo1cyStyle.accent).frame(width: 5, height: 5)
                }
            }.foregroundStyle(selected ? Vo1cyStyle.accent : Vo1cyStyle.muted)
                .padding(.horizontal, 10).frame(height: 35)
                .background(selected ? Vo1cyStyle.accent.opacity(0.13) : .clear, in: RoundedRectangle(cornerRadius: 7))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(section).accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(navigation.section).font(.system(size: 21, weight: .semibold))
                Text(subtitle).font(.system(size: 11)).foregroundStyle(Vo1cyStyle.muted)
            }
            Spacer(minLength: 10)
            HStack(spacing: 5) {
                Circle().fill(state.busy ? Vo1cyStyle.accent : .green.opacity(0.8)).frame(width: 5, height: 5)
                Text(state.phase.rawValue).font(.system(size: 10, weight: .medium)).lineLimit(1)
            }.padding(.horizontal, 9).padding(.vertical, 6).background(Vo1cyStyle.surface, in: Capsule())
        }.padding(.horizontal, 22).padding(.vertical, 14)
    }
    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Vo1cyStyle.border).frame(height: 1)
            HStack(spacing: 7) {
                Image(systemName: state.busy ? "waveform" : "info.circle").foregroundStyle(Vo1cyStyle.accent)
                Text(state.status).lineLimit(2).textSelection(.enabled).help(state.status)
                Spacer(minLength: 0)
            }.font(.system(size: 10)).foregroundStyle(Vo1cyStyle.muted).padding(.horizontal, 18).padding(.vertical, 10)
        }
    }
    private var subtitle: String {
        switch navigation.section {
        case "General": return "Keyboard shortcut, model, and language."
        case "Dictation": return "Speak and turn your voice into text."
        case "Model": return "Speech recognition directly on your Mac."
        case "History": return "Recent transcriptions in one place."
        case "Post-processing": return "Custom corrections and optional text cleanup."
        case "Advanced": return "Performance, text delivery, and storage."
        case "Setup": return "Get started in a few steps."
        default: return "Local speech recognition for macOS."
        }
    }
    @ViewBuilder private var page: some View {
        switch navigation.section {
        case "Setup": setup
        case "Model": models
        case "History": history
        case "Post-processing": dictionary
        case "Advanced": advanced
        case "About Vo1cy": about
        case "Dictation": dictation
        default: general
        }
    }

    private var general: some View {
        VStack(alignment: .leading, spacing: 19) {
            SettingsCard("Keyboard shortcut") {
                SettingRow("Dictation", detail: "A single key or combination, including in other apps.") {
                    ShortcutRecorder(label: shortcutDisplayLabel, onEditing: state.editShortcut) { code, modifiers, label in
                        state.preferences.shortcutCode = code; state.preferences.shortcutModifiers = modifiers; state.preferences.shortcutLabel = label
                    }.frame(width: 200, height: 27)
                }
                CardDivider()
                SettingRow("Choose a single key", detail: "Left and right modifiers can be assigned separately.") {
                    Menu("Choose key") {
                        Button("F8") { chooseShortcut(100, "F8") }
                        ForEach(ShortcutKeys.modifiers, id: \.code) { key in
                            Button(key.label) { chooseShortcut(key.code, key.label) }
                        }
                    }.frame(width: 170)
                }
                CardDivider()
                SettingRow("Recording mode") {
                    Picker("Recording mode", selection: $state.preferences.shortcutMode) {
                        Text("Hold to record").tag("hold"); Text("Toggle").tag("toggle")
                    }.labelsHidden().frame(width: 170)
                }
                CardDivider()
                SettingRow("Cancel recording") { Text("esc").font(.system(size: 11, design: .monospaced)).foregroundStyle(Vo1cyStyle.muted).padding(5).background(Vo1cyStyle.raised, in: RoundedRectangle(cornerRadius: 4)) }
            }.disabled(state.busy)
            if let error = state.shortcutError {
                Label(error, systemImage: "exclamationmark.triangle").font(.system(size: 11)).foregroundStyle(.orange)
            }
            if state.preferences.shortcutModifiers == 0 {
                Text("The selected key is reserved globally for Vo1cy. Function keys must send standard key events instead of media controls.")
                    .font(.system(size: 11)).foregroundStyle(Vo1cyStyle.muted)
            }
            if state.preferences.shortcutCode == 63 {
                Text("If Fn also opens emoji or switches input languages, set the Globe key action to Do Nothing in macOS Keyboard settings.")
                    .font(.system(size: 11)).foregroundStyle(Vo1cyStyle.muted)
            }
            SettingsCard("Speech recognition") {
                SettingRow(modelTitle, detail: state.capabilities.map { $0.streaming ? "Live text while speaking" : "Text after recording" } ?? "Selected model") {
                    Button("Manage model") { navigation.section = "Model" }
                }
                CardDivider()
                SettingRow("Recognition language", detail: "A fixed language or automatic detection.") { languagePicker }
                if state.preferences.language == "auto" {
                    CardDivider()
                    SettingRow("Allowed languages", detail: "Results flagged as another language are kept in History instead of being inserted automatically.") { allowedLanguagesMenu }
                    Text("The check uses language tags and writing systems. It cannot detect every language error or strictly restrict the model's decoder.")
                        .font(.system(size: 10)).foregroundStyle(Vo1cyStyle.muted).padding(.horizontal, 14).padding(.bottom, 10)
                }
                if state.capabilities?.translation == true || state.preferences.translate {
                    CardDivider()
                    SettingToggle(title: "Translate to English", detail: "When off, the original spoken language is retained.", isOn: $state.preferences.translate)
                        .disabled(state.capabilities?.translation != true)
                }
            }.disabled(state.busy)
            SettingsCard("Audio") {
                SettingRow("Microphone") { microphonePicker }
                CardDivider()
                SettingToggle(title: "Mute output while recording", detail: "Restore the previous output state when recording ends or is cancelled.", isOn: Binding(get: { state.preferences.muteOutput ?? true }, set: { state.preferences.muteOutput = $0 }))
                CardDivider()
                SettingToggle(title: "Sound effects", detail: "Play a stop sound after recording. Output muting is configured separately.", isOn: $state.preferences.playSounds)
                CardDivider()
                SettingRow("Sound volume", detail: "Relative to your current system volume.") {
                    Slider(value: Binding(get: { state.preferences.soundVolume ?? 1 }, set: { state.preferences.soundVolume = $0 }), in: 0...1).frame(width: 120)
                    Text("\(Int((state.preferences.soundVolume ?? 1) * 100))%").monospacedDigit().frame(width: 36)
                }.disabled(!state.preferences.playSounds)
                CardDivider()
                SettingRow("Recording sound", detail: "Use a local audio file up to 2 seconds long. It stays on this Mac.") {
                    Button("Choose …") { pickSound() }
                    Button("Reset") { state.resetSound() }
                    Button("Preview") { state.previewSound() }.disabled(!state.preferences.playSounds)
                }
                CardDivider()
                SettingToggle(title: "Recording indicator", detail: "A compact bubble showing the microphone level.", isOn: $state.preferences.showOverlay)
                CardDivider()
                SettingRow("Indicator position", detail: "Bottom center sits above the Dock. Other positions align with the screen edge.") {
                    VStack(alignment: .trailing, spacing: 6) {
                        Picker("Indicator position", selection: Binding(get: {
                            OverlayPosition(savedValue: state.preferences.overlayPosition).rawValue
                        }, set: { state.preferences.overlayPosition = $0 })) {
                            ForEach(OverlayPosition.allCases, id: \.rawValue) { position in
                                Text(position.title).tag(position.rawValue)
                            }
                        }.labelsHidden().frame(width: 170)
                        Button("Preview") { state.previewOverlay() }
                    }
                }.disabled(!state.preferences.showOverlay)
            }.disabled(state.busy)
        }
    }

    private var dictation: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard("") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(state.preferences.shortcutLabel).font(.system(size: 22, weight: .semibold, design: .rounded))
                            Text(state.preferences.shortcutMode == "hold" ? "Hold to dictate" : "Press to start and stop").foregroundStyle(Vo1cyStyle.muted).font(.system(size: 11))
                        }
                        Spacer()
                        Image(systemName: "waveform").font(.system(size: 32, weight: .light)).foregroundStyle(Vo1cyStyle.accent)
                    }
                    HStack {
                        Button(state.phase == .listening ? "Stop recording" : "Start recording", systemImage: state.phase == .listening ? "stop.fill" : "mic.fill") { state.toggleRecording() }
                            .buttonStyle(CompactButtonStyle(prominent: true)).disabled(state.busy && state.phase != .listening)
                        if state.busy { Button("Cancel") { state.cancel() } }
                        Spacer()
                        Text(String(format: "%.1f s", state.seconds)).monospacedDigit().foregroundStyle(Vo1cyStyle.muted)
                    }
                    ProgressView(value: Double(state.level)).tint(Vo1cyStyle.accent)
                }.padding(16)
            }
            SettingsCard("Transcription") {
                VStack(alignment: .leading, spacing: 14) {
                    Text(state.partial.isEmpty ? "Recognized text appears here …" : state.partial)
                        .foregroundStyle(state.partial.isEmpty ? Vo1cyStyle.muted : .white.opacity(0.92))
                        .textSelection(.enabled).frame(maxWidth: .infinity, minHeight: 125, alignment: .topLeading)
                    HStack {
                        Button("Copy", systemImage: "doc.on.doc") { TextOutput.copy(state.partial) }.disabled(state.partial.isEmpty)
                        Spacer()
                        Button("Open audio file …", systemImage: "waveform.badge.plus") { pickAudio() }.disabled(state.busy)
                    }
                }.padding(14)
            }
            HStack { languagePicker; Spacer(); Text(modelTitle).lineLimit(1).font(.system(size: 10)).foregroundStyle(Vo1cyStyle.muted) }.disabled(state.busy)
            Text("Use the keyboard shortcut to insert text into another app. Copy text directly from this page.").font(.system(size: 11)).foregroundStyle(Vo1cyStyle.muted)
            if state.preferences.translate { Label("Translation to English is enabled.", systemImage: "globe").foregroundStyle(.orange).font(.caption) }
        }
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard("") {
                HStack(spacing: 13) {
                    Image(systemName: "waveform.circle.fill").font(.system(size: 36)).foregroundStyle(Vo1cyStyle.accent)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Your voice. Your Mac.").font(.system(size: 16, weight: .semibold))
                        Text("Audio is processed locally. Transcription preserves the spoken language unless translation is enabled.").font(.system(size: 11)).foregroundStyle(Vo1cyStyle.muted)
                    }
                }.padding(15)
            }
            SettingsCard("01 · Permissions") {
                SettingRow("Microphone", detail: "Required to record your voice.") {
                    Button(state.microphoneAllowed ? "Allowed ✓" : "Allow access") { Task { await state.askMicrophone() } }.disabled(state.microphoneAllowed)
                }
                CardDivider()
                SettingRow("Accessibility", detail: "Required for direct text insertion and standalone modifier shortcuts.") {
                    Button(state.accessibilityAllowed ? "Allowed ✓" : "Open settings") { TextOutput.requestAccess() }.disabled(state.accessibilityAllowed)
                }
            }
            if !state.accessibilityAllowed {
                Text("Already allowed but not recognized? Remove the old Vo1cy entry in macOS Accessibility settings, add the app from Applications again, then restart Vo1cy.")
                    .font(.system(size: 11)).foregroundStyle(Vo1cyStyle.muted)
            }
            SettingsCard("02 · Model") {
                SettingRow(modelTitle, detail: "Parakeet Ultra · local multilingual speech recognition.") {
                    Button("Set up model") { navigation.section = "Model" }
                }
            }
            if state.preferences.modelPath.isEmpty, let model = CatalogModel.all.first(where: { $0.id == ModelAssessment.recommendedID }) {
                CatalogModelCard(model: model)
            }
            SettingsCard("03 · Ready to record") {
                SettingRow("Recognition language") { languagePicker }
                CardDivider()
                SettingRow("Keyboard shortcut") {
                    ShortcutRecorder(label: shortcutDisplayLabel, onEditing: state.editShortcut) { code, modifiers, label in
                        state.preferences.shortcutCode = code; state.preferences.shortcutModifiers = modifiers; state.preferences.shortcutLabel = label
                    }.frame(width: 200, height: 27)
                }
                CardDivider()
                SettingToggle(title: "Insert automatically", detail: "Requires Accessibility permission. Turn off to copy results manually.", isOn: $state.preferences.pasteAutomatically)
                CardDivider()
                SettingToggle(title: "Keep model loaded", detail: "Avoid reloading the model before each recording.", isOn: $state.preferences.keepModelLoaded)
                CardDivider()
                SettingToggle(title: "Keep microphone active", detail: "Faster startup. Audio outside a recording is discarded; the macOS microphone indicator stays visible.", isOn: $state.preferences.warmMicrophone)
            }.disabled(state.busy)
            HStack {
                Button("Check permissions") { state.refreshPermissions() }
                Spacer()
                Button(state.preferences.onboardingComplete ? "Go to overview" : "Finish setup", systemImage: "arrow.right") {
                    state.completeSetup(); if state.preferences.onboardingComplete { navigation.section = "General" }
                }.buttonStyle(CompactButtonStyle(prominent: true)).disabled(state.busy || !state.setupReady)
            }
            if !state.preferences.onboardingComplete {
                Text(state.setupReady ? "Finish setup activates the selected keyboard shortcut." : "Download and load a model, grant the required permissions, then finish setup.")
                    .font(.system(size: 11)).foregroundStyle(Vo1cyStyle.muted)
            }
        }.task {
            // Check only while setup is visible and active; avoid audio-device scans.
            while !Task.isCancelled {
                if scenePhase == .active { state.refreshPermissionStatus() }
                do { try await Task.sleep(nanoseconds: 2_000_000_000) }
                catch { break }
            }
        }
    }

    private var models: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard("Speech recognition") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Powered by Parakeet Ultra").font(.system(size: 14, weight: .semibold))
                    Text("25 languages, including English and German. Speak naturally; text appears when recording ends.")
                    Text("Runs locally after a one-time download. No account or subscription.")
                        .foregroundStyle(Vo1cyStyle.muted)
                    Text("Reviewed: \(ModelAssessment.reviewedOn) · Model information ships with app updates.")
                        .font(.system(size: 10)).foregroundStyle(Vo1cyStyle.muted)
                }.font(.system(size: 12)).padding(14)
            }
            ForEach(CatalogModel.all) { model in
                CatalogModelCard(model: model)
            }
            SettingsCard("Local model") {
                if state.installedModels.isEmpty {
                    Text("Parakeet Ultra is not downloaded yet.").foregroundStyle(Vo1cyStyle.muted).padding(14)
                }
                ForEach(state.installedModels, id: \.path) { url in
                    HStack(spacing: 9) {
                        Image(systemName: state.preferences.modelPath == url.path ? "checkmark.circle.fill" : "shippingbox").foregroundStyle(Vo1cyStyle.accent)
                        Text(modelName(url)).font(.system(size: 12)).lineLimit(2).help(url.lastPathComponent)
                        Spacer()
                        Button("Load") { state.selectModel(url) }.disabled(CatalogModel.all.first { $0.filename == url.lastPathComponent }?.available == false)
                        Button { confirmDeleteModel(url) } label: { Image(systemName: "trash") }.help("Delete model").accessibilityLabel("Delete \(modelName(url))")
                    }.padding(12).disabled(state.busy)
                }
                CardDivider()
                SettingRow("Import Parakeet Ultra", detail: "Use an existing Ultra Q8 GGUF file. Its size and SHA-256 must match the verified download.") { Button("Import …") { pickModel() }.disabled(state.busy) }
            }
            Text("Downloads and imports are verified against a pinned SHA-256 checksum.").font(.system(size: 10)).foregroundStyle(Vo1cyStyle.muted)
            if let caps = state.capabilities {
                DisclosureGroup("Model information") {
                    Text("\(caps.backend) · up to \(Int(min(600, caps.maxSeconds))) s per recording\nLanguages: \(caps.languages.joined(separator: ", "))").font(.system(size: 11)).foregroundStyle(Vo1cyStyle.muted).padding(.top, 8)
                }
            }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("\(state.history.count) entries").font(.system(size: 12)).foregroundStyle(Vo1cyStyle.muted)
                Spacer()
                Button("Export …", systemImage: "square.and.arrow.up") { savePanel(name: "Vo1cy-History.json") { state.exportHistory(to: $0) } }.disabled(state.history.isEmpty)
            }
            if state.history.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath").font(.system(size: 34, weight: .light)).foregroundStyle(Vo1cyStyle.accent)
                    Text("No transcriptions yet").font(.system(size: 16, weight: .semibold))
                    Text("Transcriptions appear here.\nStart with your shortcut or the Dictation page.")
                        .font(.system(size: 12)).foregroundStyle(Vo1cyStyle.muted).multilineTextAlignment(.center)
                    Button("Open Dictation") { navigation.section = "Dictation" }
                }.frame(maxWidth: .infinity).padding(.vertical, 70)
            }
            ForEach(state.history) { entry in
                SettingsCard("") {
                    VStack(alignment: .leading, spacing: 11) {
                        HStack {
                            Text(entry.date, style: .date); Text(entry.date, style: .time); Spacer()
                            Text(String(format: "%.1f s · %.0f ms", entry.duration, entry.computeMS))
                        }.font(.system(size: 10)).foregroundStyle(Vo1cyStyle.muted)
                        if let warning = entry.languageWarning ?? LanguagePolicy.warning(text: entry.text, raw: entry.raw, detected: entry.language, requested: state.preferences.language, selection: state.preferences.allowedLanguages) {
                            Label((entry.languageWarning == nil ? "Language check: " : "Not inserted automatically: ") + warning, systemImage: "exclamationmark.triangle")
                                .font(.system(size: 11)).foregroundStyle(.orange)
                        }
                        Text(entry.text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        HStack {
                            Button("Copy", systemImage: "doc.on.doc") { TextOutput.copy(entry.text) }
                            Button("Correct", systemImage: "pencil") { navigation.correction = entry }.disabled(state.busy)
                            if entry.audioFile != nil {
                                Button { state.play(entry) } label: { Image(systemName: "play.fill") }.help("Play audio").accessibilityLabel("Play recording")
                                Button { state.retry(entry) } label: { Image(systemName: "arrow.clockwise") }.disabled(state.busy).help("Transcribe again").accessibilityLabel("Transcribe again")
                            }
                            Spacer()
                            Button { state.deleteHistory(entry) } label: { Image(systemName: "trash") }.help("Delete entry").accessibilityLabel("Delete entry")
                        }
                        DisclosureGroup("Original text and model") {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(entry.raw).textSelection(.enabled)
                                Text("\(entry.model) · \(entry.language)").font(.system(size: 10)).foregroundStyle(Vo1cyStyle.muted)
                            }.padding(.top, 7)
                        }.font(.system(size: 11)).foregroundStyle(Vo1cyStyle.muted)
                    }.padding(14)
                }
            }
        }
    }

    private var dictionary: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard("Text cleanup") {
                SettingToggle(title: "Clean punctuation", detail: "Clean repeated punctuation, spacing, and selected German comma patterns. No rewriting.", isOn: Binding(get: { state.preferences.cleanPunctuation ?? true }, set: { state.preferences.cleanPunctuation = $0 }))
                CardDivider()
                SettingToggle(title: "Add sentence punctuation", detail: "Recognize common question patterns and sentence boundaries. No rewriting.", isOn: Binding(get: { state.preferences.formatSentences ?? true }, set: { state.preferences.formatSentences = $0 }))
                CardDivider()
                SettingToggle(title: "Spoken lists", detail: "Say firstly … secondly … or the following items: … for bullet lists. Also supported: new bullet, new paragraph, and end of list.", isOn: Binding(get: { state.preferences.formatLists ?? true }, set: { state.preferences.formatLists = $0 }))
                CardDivider()
                SettingToggle(title: "Remove fillers", detail: "Remove common English and German fillers. In automatic mode, German uses of the word um are retained.", isOn: $state.preferences.removeFillers)
                CardDivider()
                SettingToggle(title: "Clean short restarts", detail: "Remove short repeated phrases separated by a filler. Emphasis and repeated numbers are preserved.", isOn: Binding(get: { state.preferences.cleanRestarts ?? true }, set: { state.preferences.cleanRestarts = $0 }))
                CardDivider()
                SettingToggle(title: "Normalize common spellings", detail: "Join common letter sequences and spellings. Add specialized vocabulary to the custom dictionary.", isOn: Binding(get: { state.preferences.normalizeSpellings ?? true }, set: { state.preferences.normalizeSpellings = $0 }))
            }
            SettingsCard("Custom dictionary") {
                VStack(alignment: .leading, spacing: 13) {
                    Text("Corrections saved from History appear here. Rules apply to words within text or an entire dictation.").font(.system(size: 12)).foregroundStyle(Vo1cyStyle.muted)
                    if state.preferences.dictionary.isEmpty {
                        Label("No replacements yet", systemImage: "character.book.closed").foregroundStyle(Vo1cyStyle.muted).padding(.vertical, 16).frame(maxWidth: .infinity)
                    }
                    ForEach($state.preferences.dictionary) { $pair in
                        VStack(alignment: .leading, spacing: 7) {
                          HStack(spacing: 9) {
                            TextField("Recognized", text: $pair.heard).textFieldStyle(.roundedBorder)
                            Image(systemName: "arrow.right").foregroundStyle(Vo1cyStyle.accent)
                            TextField("Replace with", text: $pair.written).textFieldStyle(.roundedBorder)
                            Button { state.preferences.dictionary.removeAll { $0.id == pair.id } } label: { Image(systemName: "minus") }.accessibilityLabel("Remove replacement")
                          }
                          Picker("Scope", selection: Binding(get: { pair.wholeUtterance == true }, set: { pair.wholeUtterance = $0 })) {
                              Text("Words within text").tag(false); Text("Entire dictation").tag(true)
                          }.frame(width: 260)
                          Toggle("Protect quoted text, code, and URLs", isOn: Binding(get: { pair.protectLiterals == true }, set: { pair.protectLiterals = $0 }))
                              .disabled(pair.wholeUtterance == true)
                        }
                    }
                    Button("Add replacement", systemImage: "plus") { state.preferences.dictionary.append(Replacement(heard: "", written: "")) }
                }.padding(14)
            }
            Label("Rules run locally. Numbers are not automatically rewritten by text cleanup.", systemImage: "lock.shield")
                .font(.system(size: 11)).foregroundStyle(Vo1cyStyle.muted)
        }.disabled(state.busy)
    }

    private var advanced: some View {
        VStack(alignment: .leading, spacing: 19) {
            SettingsCard("Performance") {
                SettingToggle(title: "Keep model loaded", detail: "Faster startup, with ongoing memory use.", isOn: $state.preferences.keepModelLoaded)
                CardDivider()
                SettingToggle(title: "Keep microphone active", detail: "Avoid microphone startup delay. The macOS microphone indicator remains visible.", isOn: $state.preferences.warmMicrophone)
                CardDivider()
                SettingToggle(title: "Use CPU only", detail: "For troubleshooting. The default backend uses Metal GPU acceleration.", isOn: $state.preferences.useCPU)
                CardDivider()
                SettingRow("Reload model", detail: "Apply performance settings to the selected model.") {
                    Button("Apply") { Task { await state.prepareModel() } }.disabled(state.preferences.modelPath.isEmpty)
                }
            }
            SettingsCard("Text delivery") {
                SettingToggle(title: "Insert automatically", detail: "Insert text into the app active when recording starts.", isOn: $state.preferences.pasteAutomatically)
                CardDivider()
                SettingToggle(title: "Append a space", isOn: $state.preferences.trailingSpace)
                CardDivider()
                SettingRow("Delay before insertion") {
                    Stepper("\(state.preferences.pasteDelayMS) ms", value: $state.preferences.pasteDelayMS, in: 30...1000, step: 10).fixedSize()
                }
                CardDivider()
                SettingRow("Restore clipboard", detail: "Delay after insertion before restoring clipboard contents.") {
                    Stepper("\(state.preferences.restoreDelayMS) ms", value: $state.preferences.restoreDelayMS, in: 150...2000, step: 50).fixedSize()
                }
                Text("Vo1cy does not press Return or submit forms.").font(.system(size: 10)).foregroundStyle(Vo1cyStyle.muted).padding(.horizontal, 13).padding(.bottom, 11)
            }
            SettingsCard("History") {
                SettingToggle(title: "Save recordings", detail: "Keep audio for playback and retranscription.", isOn: $state.preferences.saveAudio)
                CardDivider()
                SettingRow("Maximum entries", detail: "Set to 0 to disable history.") {
                    Stepper("\(state.preferences.historyLimit)", value: $state.preferences.historyLimit, in: 0...1000, step: 10).fixedSize()
                }
                CardDivider()
                SettingRow("Retention", detail: "0 means no age limit.") {
                    Stepper("\(state.preferences.retentionDays) days", value: $state.preferences.retentionDays, in: 0...365).fixedSize()
                }
            }
            SettingsCard("App") {
                SettingRow("Appearance") { AccentBadge(text: "Dark · Purple") }
                CardDivider()
                SettingToggle(title: "Launch at login", isOn: Binding(get: { state.startAtLogin }, set: { state.setLogin($0) }))
                CardDivider()
                SettingRow("Audio inputs", detail: "Refresh connected microphones.") { Button("Refresh") { state.refreshPermissions() } }
            }
        }.disabled(state.busy)
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 19) {
            SettingsCard("") {
                HStack(spacing: 16) {
                    Image(systemName: "waveform").font(.system(size: 35, weight: .light)).foregroundStyle(Vo1cyStyle.accent)
                        .frame(width: 64, height: 64).background(Vo1cyStyle.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Vo1cy").font(.system(size: 26, weight: .bold, design: .rounded))
                        Text("Turn speech into text. Locally on your Mac.").font(.system(size: 12)).foregroundStyle(Vo1cyStyle.muted)
                        AccentBadge(text: "\(AppVersion.display) · Preview release")
                    }
                }.padding(18)
            }
            SettingsCard("Updates") {
                SettingRow("Software updates", detail: state.updater.configured ? "A signed update channel is configured." : "A signed automatic update channel is not configured for this build.") {
                    Button(state.updater.configured ? "Check now" : "View releases ↗") { state.updater.check() }
                }
                CardDivider()
                SettingRow("Project on GitHub", detail: "Source code, releases, and contribution information.") {
                    Link("Open GitHub ↗", destination: URL(string: "https://github.com/an0ymOnTelegram/Vo1cy")!).foregroundStyle(Vo1cyStyle.accent)
                }
            }
            SettingsCard("Community") {
                SettingRow("Made by @an0ym", detail: "Connect on Telegram or join the community.") {
                    CommunityLinks()
                }
            }
            SettingsCard("Diagnostics") {
                SettingRow("Export diagnostics", detail: "Technical information without transcription text.") {
                    Button("Export …") { savePanel(name: "Vo1cy-Diagnostics.json") { state.exportDiagnostics(to: $0) } }
                }
                CardDivider()
                SettingRow("Last model load") { Text(String(format: "%.0f ms", state.lastLoadMS)).monospacedDigit().foregroundStyle(Vo1cyStyle.muted) }
                CardDivider()
                SettingRow("Recording end to result") { Text(String(format: "%.0f ms", state.lastFinishMS)).monospacedDigit().foregroundStyle(Vo1cyStyle.muted) }
            }
            Text("Native macOS app · SwiftUI · Metal · transcribe.cpp · Sparkle\nSee release notes for signing and notarization status.").font(.system(size: 10)).foregroundStyle(Vo1cyStyle.muted)
        }
    }

    private var languagePicker: some View {
        Picker("Recognition language", selection: $state.preferences.language) {
            ForEach(Array(Set((state.capabilities?.languages ?? ["en", "de"]).map(LanguagePolicy.base) + (state.preferences.language == "auto" ? [] : [state.preferences.language]))).sorted(), id: \.self) { code in
                Text(Locale(identifier: "en").localizedString(forLanguageCode: code) ?? code).tag(code)
            }
            if state.capabilities?.autoLanguage != false { Text("Multilingual (automatic)").tag("auto") }
        }.labelsHidden().frame(width: 225).accessibilityLabel("Recognition language")
    }
    private var allowedLanguagesMenu: some View {
        let selected = LanguagePolicy.allowed(requested: "auto", selection: state.preferences.allowedLanguages)
        let available = Array(Set((state.capabilities?.languages ?? ["de", "en"]).map(LanguagePolicy.base) + selected)).sorted()
        return Menu {
            Button("German + English") { state.preferences.allowedLanguages = ["de", "en"] }
            Button("Allow all model languages") { state.preferences.allowedLanguages = [] }
            Divider()
            ForEach(available, id: \.self) { code in
                Toggle(Locale(identifier: "en").localizedString(forLanguageCode: code) ?? code, isOn: Binding(
                    get: { selected.isEmpty || selected.contains(code) },
                    set: { enabled in
                        var updated = selected.isEmpty ? available : selected
                        if enabled { updated.append(code) } else { updated.removeAll { $0 == code } }
                        if !updated.isEmpty { state.preferences.allowedLanguages = Array(Set(updated)).sorted() }
                    }
                )).disabled((selected.count == 1 && selected.contains(code)) || (selected.isEmpty && available.count == 1))
            }
        } label: {
            Text(selected.isEmpty ? "All model languages" : selected.map { $0.uppercased() }.joined(separator: " + "))
                .lineLimit(1)
        }.frame(width: 225).accessibilityLabel("Allowed languages").disabled(state.busy)
    }

    private var microphonePicker: some View {
        Picker("Microphone", selection: $state.preferences.deviceID) {
            Text("System default").tag(UInt32(0))
            ForEach(state.devices) { Text($0.name).tag($0.id) }
        }.labelsHidden().frame(width: 190).accessibilityLabel("Microphone")
    }
    private func chooseShortcut(_ code: UInt32, _ label: String) {
        state.preferences.shortcutCode = code
        state.preferences.shortcutModifiers = 0
        state.preferences.shortcutLabel = label
    }
    private var shortcutDisplayLabel: String {
        if state.preferences.shortcutModifiers == 0, let key = ShortcutKeys.modifier(state.preferences.shortcutCode) { return key.label }
        return state.preferences.shortcutLabel
    }
    private var modelTitle: String {
        state.preferences.modelPath.isEmpty ? "No model selected" : modelName(URL(fileURLWithPath: state.preferences.modelPath))
    }
    private func modelName(_ url: URL) -> String {
        CatalogModel.all.first { $0.filename == url.lastPathComponent }?.title ?? url.deletingPathExtension().lastPathComponent
    }
    private func icon(_ section: String) -> String {
        ["General":"slider.horizontal.3", "Dictation":"waveform", "Setup":"checklist", "Model":"cpu", "History":"clock.arrow.circlepath", "Post-processing":"sparkles", "Advanced":"gearshape", "About Vo1cy":"info.circle"][section] ?? "circle"
    }
    private func pickSound() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.audio]; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { state.importSound(url) }
    }
    private func pickAudio() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.audio]; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { state.importAudio(url) }
    }
    private func pickModel() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [UTType(filenameExtension: "gguf") ?? .data]; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { state.importModel(url) }
    }
    private func savePanel(name: String, action: (URL) -> Void) {
        let panel = NSSavePanel(); panel.nameFieldStringValue = name; panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url { action(url) }
    }
    private func confirmDeleteModel(_ url: URL) {
        let alert = NSAlert(); alert.messageText = "Delete model?"; alert.informativeText = url.lastPathComponent
        alert.addButton(withTitle: "Delete"); alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn { Task { await state.deleteModel(url) } }
    }
}

struct Vo1cyApplication: App {
    @StateObject private var state = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        Window("Vo1cy", id: "main") {
            MainView().environmentObject(state).onAppear { delegate.state = state }
        }.defaultSize(width: 820, height: 620)
            .commands { CommandGroup(replacing: .newItem) {} }
        MenuBarExtra("Vo1cy", systemImage: state.phase == .listening ? "mic.fill" : "waveform") {
            MenuContent().environmentObject(state)
        }
    }
}

struct MenuContent: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Text("Vo1cy · \(state.phase.rawValue)")
        if state.busy { Button("Cancel") { state.cancel() } }
        Divider()
        Button("Open Vo1cy") { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
        Button(state.updater.configured ? "Check for updates" : "View releases") { state.updater.check() }
        Divider(); Button("Quit") { NSApp.terminate(nil) }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var state: AppState?
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { state?.shutdown() }
}
