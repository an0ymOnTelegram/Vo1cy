import Foundation
import AppKit

// Headless reproducible inference uses exactly the same runtime as the app.
if CommandLine.arguments.contains("--download-model") {
    let args = CommandLine.arguments
    guard let i = args.firstIndex(of: "--download-model"), args.count > i + 2,
          let model = CatalogModel.all.first(where: { $0.id == args[i + 1] }) else {
        fputs("Usage: Vo1cy --download-model <catalog-id> <destination-directory>\n", stderr); exit(2)
    }
    let downloader = ModelDownload(model: model,
        destination: URL(fileURLWithPath: args[i + 2]).appendingPathComponent(model.filename),
        progress: { _ in }, completion: { result in
            switch result {
            case .success(let url): print("Verified: \(url.path)"); exit(0)
            case .failure(let error): fputs("\(error.localizedDescription)\n", stderr); exit(1)
            }
        })
    downloader.start()
    dispatchMain()
} else if CommandLine.arguments.contains("--transcribe") {
    let args = CommandLine.arguments
    guard let i = args.firstIndex(of: "--transcribe"), args.count > i + 3 else {
        fputs("Usage: Vo1cy --transcribe parakeet-ultra-Q8_0.gguf audio.wav de|en|auto [--stream] [--cpu]\n", stderr); exit(2)
    }
    Task {
        let engine = NativeEngine()
        do {
            let start = DispatchTime.now()
            let caps = try await engine.load(path: args[i + 1], cpu: args.contains("--cpu"))
            let loadMS = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1e6
            let samples = try AudioCapture.readFile(URL(fileURLWithPath: args[i + 2]), maxSeconds: min(600, caps.maxSeconds))
            if args.contains("--check-cancel") {
                let flag = AbortFlag()
                if caps.streaming {
                    try await engine.beginStream(language: args[i + 3], translate: false, flag: flag)
                    let _: String = try await withCheckedThrowingContinuation { continuation in
                        engine.feed(Array(samples.prefix(1600)), flag: flag) { continuation.resume(with: $0) }
                    }
                }
                flag.cancel()
                do {
                    if caps.streaming { _ = try await engine.finishStream(flag: flag) }
                    else { _ = try await engine.run(samples: samples, language: args[i + 3], translate: false, flag: flag) }
                    throw EngineFailure(message: "Cancellation did not reject the result")
                } catch is CancellationError { /* The following normal rounds test session recovery. */ }
            }
            var runs: [[String: Any]] = []
            for round in 0..<3 {
                if round == 1 && args.contains("--check-reload") {
                    await engine.unload()
                    _ = try await engine.load(path: args[i + 1], cpu: args.contains("--cpu"))
                }
                let flag = AbortFlag(); let result: Recognition
                if args.contains("--stream") {
                    try await engine.beginStream(language: args[i + 3], translate: false, flag: flag)
                    for offset in stride(from: 0, to: samples.count, by: 1600) {
                        let chunk = Array(samples[offset..<min(samples.count, offset + 1600)])
                        let _: String = try await withCheckedThrowingContinuation { continuation in
                            engine.feed(chunk, flag: flag) { continuation.resume(with: $0) }
                        }
                    }
                    result = try await engine.finishStream(flag: flag)
                } else if args.contains("--capture-gate") {
                    try await engine.beginVoiceGate(flag: flag)
                    for offset in stride(from: 0, to: samples.count, by: 1600) {
                        let chunk = Array(samples[offset..<min(samples.count, offset + 1600)])
                        let _: String = try await withCheckedThrowingContinuation { continuation in
                            engine.feedVoiceGate(chunk, flag: flag) { continuation.resume(with: $0) }
                        }
                    }
                    result = try await engine.run(samples: samples, language: args[i + 3], translate: false, flag: flag, voiceCheckedDuringCapture: true)
                } else {
                    result = try await engine.run(samples: samples, language: args[i + 3], translate: false, flag: flag)
                }
                runs.append(["text": result.text, "raw": result.raw, "language": result.language, "computeMS": result.milliseconds])
            }
            let object: [String: Any] = ["loadMS": loadMS, "duration": Double(samples.count) / 16000, "backend": caps.backend, "streaming": caps.streaming, "languages": caps.languages, "runs": runs]
            let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
            print(String(decoding: data, as: UTF8.self)); await engine.unload(); exit(0)
        } catch { fputs("\(error.localizedDescription)\n", stderr); await engine.unload(); exit(1) }
    }
    dispatchMain()
} else {
    guard AppInstance.prepare() else { exit(0) }
    Vo1cyApplication.main()
}
