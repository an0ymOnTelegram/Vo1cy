import Foundation

/// Editorial guidance ships with the app. This date is a review date, never Date().
/// Release dates refer to upstream models, not the pinned GGUF/Core ML conversion.
struct ModelAssessment {
    static let reviewedOn = "2026-10-19"
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
        if id == "parakeet-redux" {
            return .init(summary: "Runtime-provider measurement (FluidAudio): GPU encoder 21.3 ms per window. This measures the encoder only, not complete transcription, and is not directly comparable to the other figures.",
                source: URL(string: "https://github.com/FluidInference/FluidAudio/blob/v0.17.5/Documentation/ASR/ParakeetRedux.md")!)
        }
        let milliseconds = ["parakeet-ultra": 53, "orukeet": 59, "canary-180m-flash": 64, "nemotron-3.5-asr-streaming-0.6b": 76]
        guard let ms = milliseconds[id] else { return nil }
        let streamingNote = id == "nemotron-3.5-asr-streaming-0.6b" ? " Measured offline, not as live streaming delay." : ""
        return .init(summary: "Runtime-provider measurement (transcribe.cpp): \(ms) ms for 11 s of English audio, M4 Max / Metal / Q8. Mean of 3 warm runs; model computation only, excluding loading, recording, and insertion.\(streamingNote) Not a guaranteed result on other Macs.",
            source: URL(string: "https://github.com/handy-computer/transcribe.cpp/blob/b61b7f936e4e728f8999a8c3e98c7112e700410e/docs/models/\(id).md")!)
    }

    static let byID: [String: ModelAssessment] = [
        "parakeet-ultra": .init(
            badge: "Recommended · Multilingual", released: "2026-09-22",
            releaseSource: "https://moondream.ai/blog/introducing-parakeet-redux-and-ultra",
            recommendation: "A strong starting point for multilingual dictation. Published manufacturer comparisons support good recognition quality, including background noise.",
            tradeoff: "Text is produced after recording stops. Manufacturer results do not guarantee accuracy for every voice or this Q8 conversion; short words can still be misrecognized.",
            requirements: "Apple Silicon · macOS 14+ · Metal · Q8"),
        "nemotron-3.5-asr-streaming-0.6b": .init(
            badge: "For live text", released: "2026-06-04",
            releaseSource: "https://huggingface.co/nvidia/nemotron-3.5-asr-streaming-0.6b",
            recommendation: "Text appears while speaking. Languages are detected automatically, and part of the processing happens during recording.",
            tradeoff: "Live text is not an accuracy guarantee. Total compute time is different from the delay after releasing the shortcut.",
            requirements: "Apple Silicon · macOS 14+ · Metal · Q8"),
        "parakeet-redux": .init(
            badge: "Small download", released: "2026-09-22",
            releaseSource: "https://moondream.ai/blog/introducing-parakeet-redux-and-ultra",
            recommendation: "For reduced disk usage and automatic language detection. The complete Core ML package is about 220 MB.",
            tradeoff: "A smaller download does not always mean faster recognition or less RAM. Published tests show more errors in background noise than Ultra; isolated short words may be less reliable.",
            requirements: "Apple Silicon · macOS 15+ · Core ML · CPU/GPU"),
        "orukeet": .init(
            badge: "Multilingual alternative", released: "2026-09-11",
            releaseSource: "https://oruk.ai/research/orukeet",
            recommendation: "A fast multilingual alternative. Compare models using representative recordings before choosing one.",
            tradeoff: "Text is produced after recording stops. Published tests use different methods and do not establish a universal quality advantage over Ultra.",
            requirements: "Apple Silicon · macOS 14+ · Metal · Q8"),
        "canary-180m-flash": .init(
            badge: "Compact · Fixed language", released: "March 2025 · Model history; exact release day unconfirmed",
            releaseSource: "https://huggingface.co/nvidia/canary-180m-flash/commits/main",
            recommendation: "A compact model for a fixed language: English, German, French, or Spanish.",
            tradeoff: "Not the default recommendation for mixed-language dictation: Vo1cy uses a fixed language with this model. Very short words may be omitted.",
            requirements: "Apple Silicon · macOS 14+ · Metal · Q8")
    ]
}
