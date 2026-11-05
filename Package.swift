// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "VerciLumn",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "VerciLumn", targets: ["VerciLumn"]),
        .library(name: "VerciLumnSaver", type: .dynamic, targets: ["VerciLumnSaver"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "VerciLumn",
            dependencies: [],
            path: "Sources/VerciLumn",
            resources: [
                .process("Shaders/FisheyeShader.metal")
            ]
        ),
        .target(
            name: "VerciLumnSaver",
            dependencies: [],
            path: "Sources/VerciLumnSaver",
            exclude: [
                "Info.plist"
            ]
        ),
        .testTarget(
            name: "VerciLumnTests",
            dependencies: ["VerciLumn", "VerciLumnSaver"],
            path: "Tests/VerciLumnTests"
        )
    ]
)
