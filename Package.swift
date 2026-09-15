// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FrameWeave",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "FrameWeave", targets: ["FrameWeaveApp"])
    ],
    targets: [
        .executableTarget(
            name: "FrameWeaveApp",
            path: "Sources/FrameWeaveApp"
        ),
        .testTarget(
            name: "FrameWeaveCoreTests",
            dependencies: ["FrameWeaveApp"],
            path: "Tests/FrameWeaveCoreTests"
        )
    ]
)
