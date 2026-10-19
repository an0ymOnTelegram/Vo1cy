import Foundation

/// Editorial guidance ships with the app. This date is a review date, never Date().
/// Release dates refer to upstream models, not the pinned GGUF conversion.
struct ModelAssessment {
    static let reviewedOn = "2026-10-20"
    static let recommendedID = "parakeet-ultra"
    let badge: String
    let released: String
    let releaseSource: String
    let recommendation: String
    let tradeoff: String
    let requirements: String

    struct Benchmark {
        let summary: String
        let source: URL
    }
    static func benchmark(for id: String) -> Benchmark? {
        guard id == recommendedID else { return nil }
        return .init(summary: "Runtime-provider measurement (transcribe.cpp): 53 ms for 11 s of English audio, M4 Max / Metal / Q8. Mean of 3 warm runs; model computation only, excluding loading, recording, and insertion. Not a guaranteed result on other Macs.",
            source: URL(string: "https://github.com/handy-computer/transcribe.cpp/blob/b61b7f936e4e728f8999a8c3e98c7112e700410e/docs/models/parakeet-ultra.md")!)
    }

    static let byID: [String: ModelAssessment] = [
        "parakeet-ultra": .init(
            badge: "Multilingual · Local", released: "2026-09-22",
            releaseSource: "https://moondream.ai/blog/introducing-parakeet-redux-and-ultra",
            recommendation: "A strong starting point for multilingual dictation. Published manufacturer comparisons support good recognition quality, including background noise.",
            tradeoff: "Text is produced after recording stops. Manufacturer results do not guarantee accuracy for every voice or this Q8 conversion; short words can still be misrecognized.",
            requirements: "Apple Silicon · macOS 14+ · Metal · Q8")
    ]
}
