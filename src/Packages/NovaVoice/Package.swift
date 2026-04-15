// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NovaVoice",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "NovaVoice", targets: ["NovaVoice"]),
    ],
    targets: [
        .target(name: "NovaVoice", path: "Sources/NovaVoice"),
        .testTarget(name: "NovaVoiceTests", dependencies: ["NovaVoice"], path: "Tests/NovaVoiceTests"),
    ]
)
