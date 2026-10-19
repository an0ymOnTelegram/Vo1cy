import Foundation
import CryptoKit

struct ModelArtifact {
    let path: String
    let hash: String
    let bytes: Int64
}

struct CatalogModel: Identifiable {
    let id: String
    let title: String
    let detail: String
    let revision: String
    let hash: String
    let bytes: Int64
    let license: String
    var bundle: [ModelArtifact] = []
    var source: String? = nil
    var modelCard: String? = nil
    var filename: String { bundle.isEmpty ? id + "-Q8_0.gguf" : id + ".vo1cymodel" }
    var repository: String { source ?? "https://huggingface.co/handy-computer/" + id + "-gguf" }
    var url: URL { downloadURL(for: filename) }
    var licenseURL: URL { URL(string: modelCard ?? repository)! }
    var artifacts: [ModelArtifact] { bundle.isEmpty ? [.init(path: filename, hash: hash, bytes: bytes)] : bundle }
    func downloadURL(for path: String) -> URL { URL(string: repository + "/resolve/" + revision + "/" + path)! }
    var available: Bool {
        if bundle.isEmpty { return true }
        if #available(macOS 15, *) { return true }
        return false
    }
    static let all: [CatalogModel] = [
        .init(id: "canary-180m-flash", title: "Canary 180M Flash", detail: "Compact · English, German, French, Spanish · fixed language", revision: "8b01fc77ac169a0a05c5c0332bbfe54acf65c26f", hash: "f942ab746040b531a29ab78ca3afc8dc9564efd8e4c942b5541e53644be9c408", bytes: 218447648, license: "CC BY 4.0 · NVIDIA", modelCard: "https://huggingface.co/nvidia/canary-180m-flash"),
        .init(id: "nemotron-3.5-asr-streaming-0.6b", title: "Nemotron 3.5 Streaming", detail: "Live transcription · automatic language detection", revision: "53ce288f69326b415aeef030cfcb02a08a8096dd", hash: "b94545b313b3223fda7b2857a52681da813935c2127643d1e9ff0c23d988089c", bytes: 751094240, license: "OpenMDW 1.1 · NVIDIA", modelCard: "https://huggingface.co/nvidia/nemotron-3.5-asr-streaming-0.6b"),
        .init(id: "parakeet-ultra", title: "Parakeet Ultra", detail: "25 languages · recognition after recording · Metal", revision: "a1539be1b849ea7463b88343e5277b373d0c4ea9", hash: "007a59761e9258779f189df396b50d12b83bb5b79e66df4b955c230d2f2a0a59", bytes: 740363168, license: "CC BY 4.0 · Moondream / NVIDIA", modelCard: "https://huggingface.co/moondream/parakeet-ultra"),
        .init(id: "parakeet-redux", title: "Parakeet Redux", detail: "Small download · 25 languages · recognition after recording · macOS 15+", revision: ReduxManifest.revision, hash: "", bytes: ReduxManifest.files.reduce(0) { $0 + $1.bytes }, license: "CC BY 4.0 · Moondream / NVIDIA", bundle: ReduxManifest.files, source: "https://huggingface.co/FluidInference/parakeet-redux-coreml", modelCard: "https://huggingface.co/moondream/parakeet-redux"),
        .init(id: "orukeet", title: "Orukeet", detail: "25 languages · recognition after recording · Metal", revision: "c5511a3850fce1cbbfa5d94ef815966e1d99275f", hash: "68cd64b2a6c3c747f0a9f109884ed75b277c266c0fb8e5888c5a9f4d824fb9f7", bytes: 739508704, license: "CC BY-SA 4.0 · Oruk / NVIDIA", modelCard: "https://huggingface.co/oruk/orukeet")
    ]
}

/// A dedicated serial delegate queue performs hashing away from the UI.
final class ModelDownload: NSObject, URLSessionDownloadDelegate {
    private let configuration: URLSessionConfiguration
    private var session: URLSession?
    private var task: URLSessionDownloadTask?
    private let model: CatalogModel
    private let destination: URL
    private let flag = AbortFlag()
    private let progress: (Double) -> Void
    private let completion: (Result<URL, Error>) -> Void
    private var finished = false
    private var index = 0
    private var completedBytes: Int64 = 0
    private var staging: URL?
    init(model: CatalogModel, destination: URL, configuration: URLSessionConfiguration = .ephemeral, progress: @escaping (Double) -> Void, completion: @escaping (Result<URL, Error>) -> Void) {
        self.model = model; self.destination = destination; self.configuration = configuration; self.progress = progress; self.completion = completion
    }
    func start() {
        let config = configuration
        config.timeoutIntervalForRequest = 60; config.timeoutIntervalForResource = 3600
        let queue = OperationQueue(); queue.maxConcurrentOperationCount = 1
        session = URLSession(configuration: config, delegate: self, delegateQueue: queue)
        guard model.available else { finish(.failure(EngineFailure(message: "This model requires macOS 15 or later."))); return }
        if !model.bundle.isEmpty {
            do {
                let stage = destination.deletingLastPathComponent().appendingPathComponent(".download-" + UUID().uuidString)
                try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: true)
                staging = stage
            } catch { finish(.failure(error)); return }
        }
        nextFile()
    }
    private func nextFile() {
        if flag.isCancelled { finish(.failure(CancellationError())); return }
        task = session?.downloadTask(with: model.downloadURL(for: model.artifacts[index].path)); task?.resume()
    }
    func cancel() { flag.cancel(); task?.cancel() }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesWritten > model.artifacts[index].bytes { cancel() }
        progress(min(0.99, Double(completedBytes + totalBytesWritten) / Double(model.bytes)))
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            guard let response = downloadTask.response as? HTTPURLResponse, response.statusCode == 200 else { throw EngineFailure(message: "The server rejected the download.") }
            let size = try location.resourceValues(forKeys: [.fileSizeKey]).fileSize
            guard Int64(size ?? 0) == model.artifacts[index].bytes else { throw EngineFailure(message: "The model file has an unexpected size.") }
            let handle = try FileHandle(forReadingFrom: location); defer { try? handle.close() }
            var sha = SHA256()
            while let bytes = try handle.read(upToCount: 1024 * 1024), !bytes.isEmpty {
                if flag.isCancelled { throw CancellationError() }; sha.update(data: bytes)
            }
            let digest = sha.finalize().map { String(format: "%02x", $0) }.joined()
            guard digest == model.artifacts[index].hash else { throw EngineFailure(message: "SHA-256 verification failed. The model was not installed.") }
            if flag.isCancelled { throw CancellationError() }
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            // Every component is verified before the directory becomes selectable.
            if let staging {
                let item = staging.appendingPathComponent(model.artifacts[index].path)
                try FileManager.default.createDirectory(at: item.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.moveItem(at: location, to: item)
            } else {
                try FileManager.default.moveItem(at: location, to: destination)
            }
            completedBytes += model.artifacts[index].bytes
            index += 1
            if index < model.artifacts.count {
                if flag.isCancelled { throw CancellationError() }
                nextFile()
            } else {
                if flag.isCancelled { throw CancellationError() }
                if let staging { try FileManager.default.moveItem(at: staging, to: destination) }
                finish(.success(destination))
            }
        } catch { finish(.failure(error)) }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { finish(.failure(error)) }
    }
    private func finish(_ result: Result<URL, Error>) {
        guard !finished else { return }; finished = true
        if let staging { try? FileManager.default.removeItem(at: staging) }; staging = nil
        completion(result); session?.finishTasksAndInvalidate(); session = nil; task = nil
    }
}
