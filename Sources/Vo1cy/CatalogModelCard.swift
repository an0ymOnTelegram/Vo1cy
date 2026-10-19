import SwiftUI

struct CatalogModelCard: View {
    @EnvironmentObject var state: AppState
    let model: CatalogModel
    private var assessment: ModelAssessment? { ModelAssessment.byID[model.id] }
    private var selected: Bool { URL(fileURLWithPath: state.preferences.modelPath).lastPathComponent == model.filename }

    var body: some View {
        SettingsCard("") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: model.id == ModelAssessment.recommendedID ? "sparkles" : "cpu")
                        .font(.system(size: 19)).foregroundStyle(Vo1cyStyle.accent)
                        .frame(width: 37, height: 37)
                        .background(Vo1cyStyle.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.title).font(.system(size: 14, weight: .semibold))
                        Text("Download: \(ByteCountFormatter.string(fromByteCount: model.bytes, countStyle: .file))")
                            .font(.system(size: 11)).foregroundStyle(Vo1cyStyle.muted)
                    }
                    Spacer()
                    if selected { AccentBadge(text: "Active") }
                }
                if let assessment { AccentBadge(text: assessment.badge) }
                Text(model.detail).font(.system(size: 12)).foregroundStyle(Vo1cyStyle.muted)
                if let assessment {
                    Text("Released: \(assessment.released)").font(.system(size: 10)).foregroundStyle(Vo1cyStyle.muted)
                    DisclosureGroup("Recommendation, performance & sources") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(assessment.recommendation)
                            Text(assessment.tradeoff).foregroundStyle(Vo1cyStyle.muted)
                            Text(assessment.requirements).foregroundStyle(Vo1cyStyle.muted)
                            if let benchmark = ModelAssessment.benchmark(for: model.id) {
                                Text(benchmark.summary).foregroundStyle(Vo1cyStyle.muted)
                                Link("Methodology & results", destination: benchmark.source)
                                    .foregroundStyle(Vo1cyStyle.accent)
                            }
                            Text("Download size is not RAM usage. Speed and accuracy depend on the Mac, voice, and background noise.")
                                .foregroundStyle(Vo1cyStyle.muted)
                            HStack(spacing: 16) {
                                Link("Release information", destination: URL(string: assessment.releaseSource)!)
                                Link("Model card", destination: model.licenseURL)
                                Link("Download source", destination: URL(string: model.repository + "/tree/" + model.revision)!)
                            }.foregroundStyle(Vo1cyStyle.accent)
                            Text("Reviewed: \(ModelAssessment.reviewedOn) · Original model date; pinned and verified download.")
                                .font(.system(size: 10)).foregroundStyle(Vo1cyStyle.muted)
                        }.font(.system(size: 11)).padding(.top, 6)
                    }.font(.system(size: 11))
                }
                HStack {
                    Link(model.license, destination: model.licenseURL).font(.system(size: 10)).foregroundStyle(Vo1cyStyle.accent)
                    Spacer()
                    action
                }
                if state.downloadID == model.id {
                    ProgressView(value: state.downloadProgress)
                    Text("\(Int(state.downloadProgress * 100)) % · integrity check follows")
                        .font(.caption).foregroundStyle(Vo1cyStyle.muted)
                }
            }.padding(14)
        }
    }

    @ViewBuilder private var action: some View {
        if state.downloadID == model.id {
            Button("Cancel") { state.cancelDownload() }
                .accessibilityLabel("\(model.title): cancel download")
        } else if let url = state.installedModels.first(where: { $0.lastPathComponent == model.filename }) {
            Button(selected ? "Reload" : "Use model") { state.selectModel(url) }
                .disabled(state.busy || !model.available)
                .accessibilityLabel("\(model.title): \(selected ? "Reload" : "Use model")")
        } else {
            Button(model.available ? "Download" : "Requires macOS 15", systemImage: "arrow.down") { state.download(model) }
                .buttonStyle(CompactButtonStyle(prominent: true))
                .disabled(state.downloadID != nil || !model.available)
                .accessibilityLabel("\(model.title): \(model.available ? "Download" : "Requires macOS 15")")
        }
    }
}
