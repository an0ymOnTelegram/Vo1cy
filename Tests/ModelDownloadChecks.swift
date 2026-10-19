import Foundation
import CryptoKit

struct EngineFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
final class AbortFlag {
    private let lock = NSLock()
    private var stopped = false
    func cancel() { lock.lock(); stopped = true; lock.unlock() }
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return stopped }
}

@main struct ModelDownloadChecks {
    static func sha(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func check(_ condition: Bool) { precondition(condition) }
    static func main() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let serverRoot = base.appendingPathComponent("server/resolve/test")
        try FileManager.default.createDirectory(at: serverRoot.appendingPathComponent("encoder"), withIntermediateDirectories: true)
        let a = Data("GGUF-example-content".utf8), b = Data("vocabulary".utf8)
        try a.write(to: serverRoot.appendingPathComponent("single-Q8_0.gguf"))
        try a.write(to: serverRoot.appendingPathComponent("encoder/data"))
        try b.write(to: serverRoot.appendingPathComponent("vocab"))
        // A localhost HTTP server exercises the real URLSession download delegate.
        let server = Process(); server.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        let pipe = Pipe(); server.standardOutput = pipe; server.standardError = FileHandle.nullDevice
        server.arguments = ["python3", "-u", "-c", "import http.server,os; os.chdir(\(String(reflecting: base.appendingPathComponent("server").path))); s=http.server.ThreadingHTTPServer(('127.0.0.1',0),http.server.SimpleHTTPRequestHandler); print(s.server_port,flush=True); s.serve_forever()"]
        try server.run(); defer { server.terminate(); server.waitUntilExit() }
        let port = String(decoding: pipe.fileHandleForReading.availableData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        func model(_ bundle: Bool = false, hash: String? = nil) -> CatalogModel {
            CatalogModel(id: "single", title: "Test", detail: "", revision: "test", hash: hash ?? sha(a), bytes: Int64(a.count + (bundle ? b.count : 0)), license: "",
                bundle: bundle ? [.init(path: "encoder/data", hash: sha(a), bytes: Int64(a.count)), .init(path: "vocab", hash: sha(b), bytes: Int64(b.count))] : [], source: "http://127.0.0.1:\(port)")
        }
        func download(_ model: CatalogModel, name: String, cancel: Bool = false, cancelDuring: Bool = false) throws -> Bool {
            let target = base.appendingPathComponent(name)
            let done = DispatchSemaphore(value: 0)
            var success = false
            var active: ModelDownload?
            let operation = ModelDownload(model: model, destination: target, progress: { fraction in
                if cancelDuring && fraction > 0.8 { active?.cancel() }
            }, completion: {
                if case .success = $0 { success = true }; done.signal()
            })
            active = operation
            if cancel { operation.cancel() }
            operation.start()
            precondition(done.wait(timeout: .now() + 15) == .success, "download timed out")
            active = nil
            precondition(FileManager.default.fileExists(atPath: target.path) == success)
            let residue = try FileManager.default.contentsOfDirectory(atPath: base.path).filter { $0.hasPrefix(".download-") }
            precondition(residue.isEmpty, "partial model leaked")
            return success
        }
        check(try download(model(), name: "single"))
        check(try download(model(true), name: "bundle"))
        check(try Data(contentsOf: base.appendingPathComponent("bundle/encoder/data")) == a)
        check(try Data(contentsOf: base.appendingPathComponent("bundle/vocab")) == b)
        check(try !download(model(hash: String(repeating: "0", count: 64)), name: "bad-hash"))
        var wrongSize = model(); wrongSize = CatalogModel(id: wrongSize.id, title: "", detail: "", revision: "test", hash: sha(a), bytes: 1, license: "", source: wrongSize.source)
        check(try !download(wrongSize, name: "bad-size"))
        check(try !download(model(true), name: "cancelled", cancel: true))
        check(try !download(model(true), name: "cancelled-during-second-file", cancelDuring: true))
        try FileManager.default.removeItem(at: serverRoot.appendingPathComponent("vocab"))
        check(try !download(model(true), name: "incomplete"))
        let catalog = CatalogModel.all
        precondition(Set(catalog.map(\.id)).count == 5)
        precondition(Set(ModelAssessment.byID.keys) == Set(catalog.map(\.id)))
        precondition(catalog.contains { $0.id == ModelAssessment.recommendedID && $0.available })
        for entry in catalog {
            guard let guidance = ModelAssessment.byID[entry.id], let benchmark = ModelAssessment.benchmark(for: entry.id) else { fatalError("Missing model assessment") }
            precondition(!guidance.released.isEmpty && !guidance.recommendation.isEmpty)
            precondition(URL(string: guidance.releaseSource)?.scheme == "https" && benchmark.source.scheme == "https")
            precondition(entry.revision.count == 40)
            precondition(entry.bytes == entry.artifacts.reduce(0) { $0 + $1.bytes })
            precondition(Set(entry.artifacts.map(\.path)).count == entry.artifacts.count)
            for file in entry.artifacts {
                precondition(file.hash.count == 64 && file.bytes > 0)
                precondition(!file.path.hasPrefix("/") && !file.path.split(separator: "/").contains(".."))
            }
        }
        print("PASS: real HTTP single/bundle downloads, hash/size rejection, cancellation, partial cleanup, catalog manifests")
    }
}
