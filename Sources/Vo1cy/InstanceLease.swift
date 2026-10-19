import Foundation
import Darwin

/// Kernel-owned, per-user GUI lease. Never unlink this file: another process may
/// already have the inode open. Process exit (including a crash) releases the lock.
final class InstanceLease {
    private let descriptor: Int32
    private init(_ descriptor: Int32) { self.descriptor = descriptor }
    deinit { close(descriptor) }

    static func acquire(at url: URL) throws -> InstanceLease? {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let fd = open(url.path, O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_uid == getuid(), (info.st_mode & S_IFMT) == S_IFREG else {
            close(fd); throw POSIXError(.EACCES)
        }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            let failure = errno; close(fd)
            if failure == EWOULDBLOCK { return nil }
            throw POSIXError(POSIXErrorCode(rawValue: failure) ?? .EIO)
        }
        return InstanceLease(fd)
    }
}
