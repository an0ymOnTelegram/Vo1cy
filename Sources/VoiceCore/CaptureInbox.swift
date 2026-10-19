import Foundation

/// Audio arrives independently of UI scheduling. Seal after stopping the producer
/// to preserve all delivered samples even when its main-queue notifications lag.
public final class CaptureInbox: @unchecked Sendable {
    private let lock = NSLock()
    private var chunks: [[Float]] = []
    private var closed = false
    public init() {}
    @discardableResult public func append(_ samples: [Float]) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !closed else { return false }
        if !samples.isEmpty { chunks.append(samples) }
        return true
    }
    public func drain() -> [[Float]] {
        lock.lock(); defer { lock.unlock() }
        let result = chunks; chunks = []; return result
    }
    public func finish() -> [[Float]] {
        lock.lock(); defer { lock.unlock() }
        closed = true
        let result = chunks; chunks = []; return result
    }
}
