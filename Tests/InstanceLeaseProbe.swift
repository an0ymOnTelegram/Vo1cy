import Foundation
import Darwin

@main struct InstanceLeaseProbe {
    static func main() {
        do {
            guard let lease = try InstanceLease.acquire(at: URL(fileURLWithPath: CommandLine.arguments[1])) else {
                print("busy"); exit(3)
            }
            withExtendedLifetime(lease) {
                print("owned"); fflush(stdout)
                _ = readLine()
            }
        } catch { print("error"); exit(4) }
    }
}
