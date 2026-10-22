// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacClipboard",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MacClipboard", targets: ["MacClipboard"])
    ],
    targets: [
        .executableTarget(
            name: "MacClipboard",
            path: "Sources/MacClipboard",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
