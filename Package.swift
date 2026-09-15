// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShotTessera",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ShotTessera", targets: ["ShotTesseraApp"])
    ],
    targets: [
        .executableTarget(
            name: "ShotTesseraApp",
            path: "Sources/ShotTesseraApp",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "ShotTesseraCoreTests",
            dependencies: ["ShotTesseraApp"],
            path: "Tests/ShotTesseraCoreTests"
        )
    ]
)
