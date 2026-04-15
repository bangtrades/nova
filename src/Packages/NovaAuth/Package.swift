// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NovaAuth",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "NovaAuth", targets: ["NovaAuth"]),
    ],
    dependencies: [
        .package(path: "../NovaCore"),
    ],
    targets: [
        .target(
            name: "NovaAuth",
            dependencies: ["NovaCore"],
            path: "Sources/NovaAuth"
        ),
        .testTarget(
            name: "NovaAuthTests",
            dependencies: ["NovaAuth"],
            path: "Tests/NovaAuthTests"
        ),
    ]
)
