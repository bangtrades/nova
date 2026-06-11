// swift-tools-version: 5.9
import PackageDescription

// NovaClassroom — the V2 classroom scene model, extracted into its own
// SPM package.
//
// Why this package exists: `ClassroomSceneModel` is pure model logic
// (it derives classroom objects from lesson data) but it had been
// misfiled inside the NovaKids app target under `Views/Classroom/`.
// That left it untestable without an app test target — the May 22
// agent batch worked around it with a symlinked throwaway package.
// Extracting it properly gives it (1) a real test target that runs on
// the build graph, (2) a clean home outside `Views/`, and (3) a
// dependency boundary the compiler enforces. Mirrors the NovaCore /
// NovaAuth / NovaVoice / NovaStorage package idiom.
//
// Depends only on NovaCore (Lesson / LearningPath / Card models). No
// SwiftUI — the model uses CoreGraphics geometry types only.
let package = Package(
    name: "NovaClassroom",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "NovaClassroom", targets: ["NovaClassroom"]),
    ],
    dependencies: [
        .package(path: "../NovaCore"),
    ],
    targets: [
        .target(
            name: "NovaClassroom",
            dependencies: [
                .product(name: "NovaCore", package: "NovaCore"),
            ],
            path: "Sources/NovaClassroom"
        ),
        .testTarget(
            name: "NovaClassroomTests",
            dependencies: [
                "NovaClassroom",
                .product(name: "NovaCore", package: "NovaCore"),
            ],
            path: "Tests/NovaClassroomTests"
        ),
    ]
)
