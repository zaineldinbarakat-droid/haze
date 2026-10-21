// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Haze",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Haze",
            path: "Sources/Haze",
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [.linkedFramework("IOKit")]
        )
    ]
)
