// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NovaCore",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "NovaCore", targets: ["NovaCore"]),
    ],
    targets: [
        .target(name: "NovaCore", path: "Sources/NovaCore"),
        .testTarget(name: "NovaCoreTests", dependencies: ["NovaCore"], path: "Tests/NovaCoreTests"),
    ]
)
