// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Ziran",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Ziran", targets: ["Ziran"])
    ],
    targets: [
        .executableTarget(
            name: "Ziran",
            path: "Sources/Ziran"
        ),
        .testTarget(
            name: "ZiranTests",
            dependencies: ["Ziran"],
            path: "Tests/ZiranTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
