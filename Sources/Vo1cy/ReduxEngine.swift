import Foundation
import CoreML
import FluidAudio
import VoiceCore

/// Accessed only on NativeEngine's dedicated serial queue. No network access:
/// loadLocal consumes the already verified, atomically installed model bundle.
final class ReduxEngine {
    private let manager: AsrManager
    static let languages = ["bg", "hr", "cs", "da", "nl", "en", "et", "fi", "fr", "de", "el", "hu", "it", "lv", "lt", "mt", "pl", "pt", "ro", "ru", "sk", "sl", "es", "sv", "uk"]

    init(directory: URL, cpu: Bool) throws {
        guard #available(macOS 15, *) else { throw EngineFailure(message: "Parakeet Redux requires macOS 15 or later.") }
        AppLogger.minimumLevel = .fault
        AppLogger.mirrorsToConsole = false
        let config = MLModelConfiguration()
        // CPU decoder; GPU encoder avoids the multi-minute first ANE compile.
        config.computeUnits = .cpuOnly
        let models = try AsrModels.loadLocal(from: directory, version: .redux,
            configuration: config, encoderComputeUnits: cpu ? .cpuOnly : .cpuAndGPU)
        manager = AsrManager(config: ASRConfig(parallelChunkConcurrency: 1), models: models)
    }

    func transcribe(samples: [Float], language: String, flag: AbortFlag) throws -> String {
        let language = LanguagePolicy.base(language)
        guard language == "auto" || Self.languages.contains(language) else {
            throw EngineFailure(message: "This language is not supported by the model.")
        }
        let manager = manager
        return try Self.wait(flag: flag) {
            var state = try TdtDecoderState()
            let result = try await manager.transcribe(samples, decoderState: &state,
                language: language == "auto" ? nil : Language(rawValue: language))
            return result.text
        }
    }

    func shutdown() {
        let manager = manager
        let _: Bool? = try? Self.wait { await manager.cleanup(); return true }
    }

    /// Bridge the library actor to our serial inference worker, never a Swift
    /// cooperative executor. Application shutdown also waits for cleanup.
    private static func wait<T: Sendable>(flag: AbortFlag? = nil, _ body: @escaping @Sendable () async throws -> T) throws -> T {
        let box = ResultBox<T>()
        let done = DispatchSemaphore(value: 0)
        let task = Task.detached(priority: .userInitiated) {
            do { box.set(.success(try await body())) }
            catch { box.set(.failure(error)) }
            done.signal()
        }
        while done.wait(timeout: .now() + .milliseconds(25)) == .timedOut {
            if flag?.isCancelled == true { task.cancel() }
        }
        if flag?.isCancelled == true { throw CancellationError() }
        return try box.get().get()
    }
}

private final class ResultBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Result<T, Error>?
    func set(_ value: Result<T, Error>) { lock.lock(); self.value = value; lock.unlock() }
    func get() -> Result<T, Error> { lock.lock(); defer { lock.unlock() }; return value! }
}
