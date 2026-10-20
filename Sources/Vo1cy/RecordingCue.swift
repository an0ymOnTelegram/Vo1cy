import Foundation

/// The start cue must finish before global muting. A stopped or replaced
/// recording must never mute the output later when its delay completes.
@MainActor
final class RecordingCue {
    private var generation: UInt64 = 0
    private var pending: Task<Void, Never>?
    private let wait: (UInt64) async throws -> Void

    init(wait: @escaping (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) }) {
        self.wait = wait
    }

    func schedule(after seconds: TimeInterval, action: @escaping () throws -> Void,
                  onFailure: @escaping (Error) -> Void) {
        cancel()
        let token = generation
        let delay = seconds.isFinite ? min(0.25, max(0, seconds)) : 0
        guard delay > 0 else {
            do { try action() } catch { onFailure(error) }
            return
        }
        pending = Task { [weak self, wait] in
            do { try await wait(UInt64(delay * 1_000_000_000)) }
            catch { return }
            guard let self, !Task.isCancelled, self.generation == token else { return }
            self.pending = nil
            do { try action() } catch { onFailure(error) }
        }
    }

    func cancel() {
        generation &+= 1
        pending?.cancel()
        pending = nil
    }
}
