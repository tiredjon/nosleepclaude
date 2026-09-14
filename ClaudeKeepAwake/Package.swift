// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "ClaudeKeepAwake",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "ClaudeKeepAwake",
            path: "Sources/ClaudeKeepAwake"
        ),
        .testTarget(
            name: "ClaudeKeepAwakeTests",
            dependencies: ["ClaudeKeepAwake"],
            path: "Tests/ClaudeKeepAwakeTests"
        )
    ]
)
