import Foundation
import CTranscribe
import VoiceCore

struct EngineFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct ModelCapabilities {
    var languages: [String] = []
    var autoLanguage = false
    var translation = false
    var streaming = false
    var maxSeconds = 30.0
    var backend = ""
}

struct Recognition {
    let text: String
    let raw: String
    let language: String
    let milliseconds: Double
}

final class AbortFlag {
    private let lock = NSLock()
    private var stopped = false
    func cancel() { lock.lock(); stopped = true; lock.unlock() }
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return stopped }
}

/// All native model calls, including destruction, are confined to this queue.
final class NativeEngine {
    private let queue = DispatchQueue(label: "app.vo1cy.inference", qos: .userInitiated)
    private var redux: ReduxEngine?
    private var session: OpaquePointer?
    private var vadModel: OpaquePointer?
    private var vadSession: OpaquePointer?
    private var speechFrames = 0
    private var voiceGateMS = 0.0
    private var loadedKey = ""
    private var caps = ModelCapabilities()
    private var abort: AbortFlag?
    private var streamMS = 0.0
    private static let initialized: Void = {
        // The runtime can log paths and model output. The app never records these.
        transcribe_log_set({ _, _, _ in }, nil)
        _ = transcribe_init_backends_default()
    }()

    private func check(_ status: transcribe_status) throws {
        guard status == TRANSCRIBE_OK else {
            throw EngineFailure(message: String(cString: transcribe_status_string(Int32(status.rawValue))))
        }
    }

    private func perform<T>(_ body: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do { continuation.resume(returning: try body()) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }

    func load(path: String, cpu: Bool) async throws -> ModelCapabilities {
        try await perform {
            _ = Self.initialized
            let key = path + (cpu ? "|cpu" : "|auto")
            if self.loadedKey == key, (self.session != nil || self.redux != nil) { return self.caps }
            self.release()
            guard FileManager.default.fileExists(atPath: path) else {
                throw EngineFailure(message: "Select or download a model first.")
            }
            var params = transcribe_model_load_params()
            transcribe_model_load_params_init(&params)
            params.backend = cpu ? TRANSCRIBE_BACKEND_CPU : TRANSCRIBE_BACKEND_AUTO
            try self.loadVAD()
            if URL(fileURLWithPath: path).pathExtension == "vo1cymodel" {
                guard URL(fileURLWithPath: path).lastPathComponent == "parakeet-redux.vo1cymodel" else {
                    self.release(); throw EngineFailure(message: "Unknown model package.")
                }
                do { self.redux = try ReduxEngine(directory: URL(fileURLWithPath: path), cpu: cpu) }
                catch { self.release(); throw error }
                self.caps = ModelCapabilities(languages: ReduxEngine.languages, autoLanguage: true,
                    translation: false, streaming: false, maxSeconds: 600,
                    backend: cpu ? "Core ML · CPU" : "Core ML · CPU/GPU")
                self.loadedKey = key
                return self.caps
            }
            do { try self.check(transcribe_open(path, &params, nil, &self.session)) }
            catch { self.release(); throw error }
            var c = transcribe_capabilities(); transcribe_capabilities_init(&c)
            do { try self.check(transcribe_model_get_capabilities(transcribe_get_model(self.session), &c)) }
            catch { self.release(); throw error }
            var languages: [String] = []
            if let pointers = c.languages {
                for i in 0..<Int(c.n_languages) { if let p = pointers[i] { languages.append(String(cString: p)) } }
            }
            self.caps = ModelCapabilities(languages: languages, autoLanguage: c.supports_language_detect,
                translation: c.supports_translate, streaming: c.supports_streaming,
                maxSeconds: c.max_audio_ms > 0 ? Double(c.max_audio_ms) / 1000 : 600,
                backend: transcribe_model_backend(transcribe_get_model(self.session)).map { String(cString: $0) } ?? "unknown")
            self.loadedKey = key
            return self.caps
        }
    }

    private func withParams<T>(language: String, translate: Bool, body: (inout transcribe_run_params) throws -> T) throws -> T {
        guard session != nil else { throw EngineFailure(message: "No model loaded.") }
        guard language != "auto" || caps.autoLanguage else { throw EngineFailure(message: "This model requires a fixed language.") }
        let resolved = caps.languages.contains(language) ? language : caps.languages.first(where: { LanguagePolicy.base($0) == LanguagePolicy.base(language) }) ?? language
        guard language == "auto" || caps.languages.isEmpty || caps.languages.contains(resolved) else {
            throw EngineFailure(message: "This language is not supported by the model.")
        }
        guard !translate || caps.translation else { throw EngineFailure(message: "This model does not support translation.") }
        var p = transcribe_run_params(); transcribe_run_params_init(&p)
        p.task = translate ? TRANSCRIBE_TASK_TRANSLATE : TRANSCRIBE_TASK_TRANSCRIBE
        return try resolved.withCString { lang in
            try "en".withCString { english in
                p.language = language == "auto" ? nil : lang
                // Explicitly preserve the source language for Canary's multitask decoder.
                p.target_language = translate ? english : p.language
                return try body(&p)
            }
        }
    }

    private func installAbort(_ flag: AbortFlag) {
        abort = flag
        if let session { transcribe_set_abort_callback(session, { pointer in
            guard let pointer else { return false }
            return Unmanaged<AbortFlag>.fromOpaque(pointer).takeUnretainedValue().isCancelled
        }, Unmanaged.passUnretained(flag).toOpaque()) }
        transcribe_vad_set_abort_callback(vadSession, { pointer in
            guard let pointer else { return false }
            return Unmanaged<AbortFlag>.fromOpaque(pointer).takeUnretainedValue().isCancelled
        }, Unmanaged.passUnretained(flag).toOpaque())
    }

    func run(samples: [Float], language: String, translate: Bool, flag: AbortFlag, voiceCheckedDuringCapture: Bool = false) async throws -> Recognition {
        try await perform {
            if flag.isCancelled { throw CancellationError() }
            guard !samples.isEmpty, samples.allSatisfy({ $0.isFinite }), Double(samples.count) <= self.caps.maxSeconds * 16000 else {
                throw EngineFailure(message: "The recording is empty or exceeds the model's duration limit.")
            }
            self.installAbort(flag)
            if let session = self.session { transcribe_stream_reset(session) }
            let start = DispatchTime.now()
            if voiceCheckedDuringCapture {
                try self.check(transcribe_vad_stream_flush(self.vadSession)); self.collectSpeechFrames()
                guard self.speechFrames >= 3 else { throw EngineFailure(message: "No speech detected.") }
            } else {
                try samples.withUnsafeBufferPointer { pcm in
                    try self.check(transcribe_vad_run(self.vadSession, pcm.baseAddress, Int32(pcm.count), nil))
                }
                var vadResult = transcribe_vad_result(); transcribe_vad_result_init(&vadResult)
                try self.check(transcribe_vad_get_result(self.vadSession, &vadResult))
                guard vadResult.n_segments > 0 else { throw EngineFailure(message: "No speech detected.") }
            }
            if let redux = self.redux {
                guard !translate else { throw EngineFailure(message: "This model does not support translation.") }
                let text = try redux.transcribe(samples: samples, language: language, flag: flag)
                let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1e6
                // Redux emits no language identifier. Never invent one from a hint.
                return Recognition(text: text, raw: text, language: "", milliseconds: elapsed + (voiceCheckedDuringCapture ? self.voiceGateMS : 0))
            }
            try self.withParams(language: language, translate: translate) { p in
                try samples.withUnsafeBufferPointer { pcm in
                    try self.check(transcribe_run(self.session, pcm.baseAddress, Int32(pcm.count), &p))
                }
            }
            if flag.isCancelled { throw CancellationError() }
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1e6
            return self.result(milliseconds: elapsed + (voiceCheckedDuringCapture ? self.voiceGateMS : 0))
        }
    }

    func beginVoiceGate(flag: AbortFlag) async throws {
        try await perform {
            if flag.isCancelled { throw CancellationError() }
            self.installAbort(flag); transcribe_vad_stream_reset(self.vadSession)
            self.speechFrames = 0; self.voiceGateMS = 0
        }
    }

    /// For batch models, run speech detection while recording, not after release.
    func feedVoiceGate(_ samples: [Float], flag: AbortFlag, completion: @escaping (Result<String, Error>) -> Void) {
        queue.async {
            do {
                if flag.isCancelled { throw CancellationError() }
                let start = DispatchTime.now()
                try samples.withUnsafeBufferPointer { p in
                    try self.check(transcribe_vad_stream_feed(self.vadSession, p.baseAddress, Int32(p.count)))
                }
                self.collectSpeechFrames()
                self.voiceGateMS += Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1e6
                completion(.success(""))
            } catch { completion(.failure(error)) }
        }
    }

    func beginStream(language: String, translate: Bool, flag: AbortFlag) async throws {
        try await perform {
            if flag.isCancelled { throw CancellationError() }
            guard self.caps.streaming else { throw EngineFailure(message: "This model recognizes speech after recording ends.") }
            self.installAbort(flag); self.streamMS = 0
            transcribe_stream_reset(self.session)
            transcribe_vad_stream_reset(self.vadSession); self.speechFrames = 0
            var stream = transcribe_stream_params(); transcribe_stream_params_init(&stream)
            try self.withParams(language: language, translate: translate) { p in
                try self.check(transcribe_stream_begin(self.session, &p, &stream))
            }
        }
    }

    func feed(_ samples: [Float], flag: AbortFlag, completion: @escaping (Result<String, Error>) -> Void) {
        queue.async {
            do {
                if flag.isCancelled { throw CancellationError() }
                let start = DispatchTime.now()
                try samples.withUnsafeBufferPointer { p in
                    try self.check(transcribe_vad_stream_feed(self.vadSession, p.baseAddress, Int32(p.count)))
                    self.collectSpeechFrames()
                    try self.check(transcribe_stream_feed(self.session, p.baseAddress, Int32(p.count), nil))
                }
                self.streamMS += Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1e6
                var t = transcribe_stream_text(); transcribe_stream_text_init(&t)
                try self.check(transcribe_stream_get_text(self.session, &t))
                completion(.success(t.full_text.map { String(cString: $0) } ?? ""))
            } catch { completion(.failure(error)) }
        }
    }

    func finishStream(flag: AbortFlag) async throws -> Recognition {
        try await perform {
            if flag.isCancelled { throw CancellationError() }
            let start = DispatchTime.now()
            try self.check(transcribe_vad_stream_flush(self.vadSession)); self.collectSpeechFrames()
            guard self.speechFrames >= 3 else { throw EngineFailure(message: "No speech detected.") }
            try self.check(transcribe_stream_finalize(self.session, nil))
            self.streamMS += Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1e6
            if flag.isCancelled { throw CancellationError() }
            return self.result(milliseconds: self.streamMS)
        }
    }

    private func result(milliseconds: Double) -> Recognition {
        Recognition(text: transcribe_full_text(session).map { String(cString: $0) } ?? "",
            raw: transcribe_raw_text(session).map { String(cString: $0) } ?? "",
            language: transcribe_detected_language(session).map { String(cString: $0) } ?? "", milliseconds: milliseconds)
    }
    func unload() async { try? await perform { self.release() } }
    func shutdown() { queue.sync { release() } }
    private func release() {
        redux?.shutdown(); redux = nil
        if let session { transcribe_session_free(session) }
        if let vadSession { transcribe_vad_session_free(vadSession) }
        if let vadModel { transcribe_model_free(vadModel) }
        vadSession = nil; vadModel = nil
        session = nil; abort = nil; loadedKey = ""
    }

    private func loadVAD() throws {
        let name = "silero-vad-v6.2-F32.gguf"
        let path = ProcessInfo.processInfo.environment["VO1CY_VAD_MODEL"] ?? Bundle.main.resourceURL?.appendingPathComponent(name).path ?? ""
        guard FileManager.default.fileExists(atPath: path) else { throw EngineFailure(message: "The speech activity filter is missing. Reinstall the complete app.") }
        var params = transcribe_model_load_params(); transcribe_model_load_params_init(&params)
        params.backend = TRANSCRIBE_BACKEND_CPU
        try check(transcribe_model_load_file(path, &params, &vadModel))
        do { try check(transcribe_vad_session_init(vadModel, nil, &vadSession)) }
        catch { release(); throw error }
    }
    private func collectSpeechFrames() {
        var result = transcribe_vad_result(); transcribe_vad_result_init(&result)
        guard transcribe_vad_get_result(vadSession, &result) == TRANSCRIBE_OK, let probs = transcribe_vad_probs(vadSession) else { return }
        for i in 0..<Int(result.n_probs) where probs[i] >= 0.5 { speechFrames += 1 }
    }
}
