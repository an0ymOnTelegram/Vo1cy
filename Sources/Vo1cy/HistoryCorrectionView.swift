import SwiftUI
import VoiceCore

final class CorrectionDraft: ObservableObject {
    let original: String
    @Published var corrected: String { didSet { suggest() } }
    @Published var remember = true
    @Published var heard = ""
    @Published var written = ""
    @Published var wholeUtterance = true
    @Published var error: String?

    init(text: String) { original = text; corrected = text }
    private func suggest() {
        let suggestion = CorrectionRules.suggestion(original: original, corrected: corrected)
        heard = suggestion?.heard ?? ""; written = suggestion?.written ?? ""
        wholeUtterance = suggestion?.wholeUtterance ?? true
        error = nil
    }
    var rule: Replacement? {
        guard remember, !CorrectionRules.key(heard).isEmpty,
              !written.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return Replacement(heard: heard, written: written, wholeUtterance: wholeUtterance)
    }
    var changed: Bool {
        let text = corrected.trimmingCharacters(in: .whitespacesAndNewlines)
        return !text.isEmpty && text != original
    }
}

struct HistoryCorrectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var draft: CorrectionDraft
    let save: (String, Replacement?) throws -> Void

    init(text: String, save: @escaping (String, Replacement?) throws -> Void) {
        _draft = StateObject(wrappedValue: CorrectionDraft(text: text)); self.save = save
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Correct dictation").font(.system(size: 20, weight: .semibold))
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Recognized").font(.caption).foregroundStyle(Vo1cyStyle.muted)
                    Text(draft.original).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    Text("Corrected text").font(.caption).foregroundStyle(Vo1cyStyle.muted)
                    TextEditor(text: $draft.corrected)
                        .font(.system(size: 13)).scrollContentBackground(.hidden)
                        .padding(8).frame(height: 95).background(Vo1cyStyle.raised, in: RoundedRectangle(cornerRadius: 7))
                        .accessibilityLabel("Corrected text")
                    Toggle("Remember for future dictations", isOn: $draft.remember)
                    if draft.remember {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                TextField("Misrecognized text", text: $draft.heard).accessibilityLabel("Misrecognized text")
                                Image(systemName: "arrow.right").foregroundStyle(Vo1cyStyle.accent)
                                TextField("Replacement", text: $draft.written).accessibilityLabel("Correct spelling")
                            }.textFieldStyle(.roundedBorder)
                            Picker("Apply to", selection: $draft.wholeUtterance) {
                                Text("Entire dictation").tag(true)
                                Text("Words within text").tag(false)
                            }.pickerStyle(.segmented)
                            Text(draft.wholeUtterance
                                ? "Apply only when the entire dictation matches. Similar words within longer sentences remain unchanged."
                                : "Replace these words within longer sentences too. Use Entire dictation for ambiguous words.")
                                .font(.system(size: 11)).foregroundStyle(Vo1cyStyle.muted)
                            if draft.rule == nil {
                                Text("Fill in both fields to create a reusable correction. You can save the corrected text without a rule.")
                                    .font(.system(size: 11)).foregroundStyle(Vo1cyStyle.muted)
                            }
                        }.padding(12).background(Vo1cyStyle.surface, in: RoundedRectangle(cornerRadius: 8))
                    }
                    Text("Saved rules appear under Post-processing. They change recognized text locally; they do not retrain speech recognition.")
                        .font(.system(size: 11)).foregroundStyle(Vo1cyStyle.muted)
                    if let error = draft.error { Text(error).font(.caption).foregroundStyle(.orange) }
                }
            }
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { commit(copy: false) }.disabled(!draft.changed)
                Button("Save & copy") { commit(copy: true) }
                    .buttonStyle(CompactButtonStyle(prominent: true)).disabled(!draft.changed)
            }
            Text("Text already inserted into other apps remains unchanged.")
                .font(.system(size: 10)).foregroundStyle(Vo1cyStyle.muted)
        }.padding(22).frame(width: 550, height: 560)
            .background(Vo1cyStyle.background).preferredColorScheme(.dark)
            .tint(Vo1cyStyle.accent).buttonStyle(CompactButtonStyle())
    }
    private func commit(copy: Bool) {
        do {
            let text = draft.corrected.trimmingCharacters(in: .whitespacesAndNewlines)
            try save(text, draft.rule)
            if copy { TextOutput.copy(text) }
            dismiss()
        } catch { draft.error = error.localizedDescription }
    }
}
