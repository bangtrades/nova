// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NovaStorage",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "NovaStorage", targets: ["NovaStorage"]),
    ],
    dependencies: [
        .package(path: "../NovaCore"),
    ],
    targets: [
        .target(
            name: "NovaStorage",
            dependencies: ["NovaCore"],
            path: "Sources/NovaStorage"
        ),
        .testTarget(
            name: "NovaStorageTests",
            dependencies: ["NovaStorage"],
            path: "Tests/NovaStorageTests"
        ),
    ]
)
