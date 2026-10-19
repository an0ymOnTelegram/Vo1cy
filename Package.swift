// swift-tools-version: 6.2
import PackageDescription
import Foundation
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let package = Package(
    name: "Vo1cy", platforms: [.macOS(.v14)],
    products: [.executable(name: "Vo1cy", targets: ["Vo1cy"])],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle.git", exact: "2.10.0")],
    targets: [
        .systemLibrary(name: "CTranscribe"),
        .target(name: "VoiceCore"),
        .executableTarget(name: "Vo1cy", dependencies: ["VoiceCore", "CTranscribe", .product(name: "Sparkle", package: "Sparkle")],
            swiftSettings: [.unsafeFlags(["-Xcc", "-I" + root + "/vendor/include"])],
            linkerSettings: [.unsafeFlags(["-L", root + "/vendor/lib", "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .testTarget(name: "VoiceCoreTests", dependencies: ["VoiceCore"])
    ], swiftLanguageModes: [.v5])
