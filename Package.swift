// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "VerciLumn",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "VerciLumn", targets: ["VerciLumn"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "VerciLumn",
            dependencies: [],
            path: "Sources/VerciLumn",
            resources: [
                .process("Resources"),
                .process("Shaders")
            ]
        )
    ]
)
