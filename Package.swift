// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "hyperMac",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/LebJe/TOMLKit.git", from: "0.5.0")
    ],
    targets: [
        .executableTarget(
            name: "hyperMac",
            dependencies: ["TOMLKit"],
            path: "Sources/hyperMac",
            exclude: ["Resources/Info.plist"],
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("CoreGraphics"),
            ]
        ),
        .testTarget(
            name: "hyperMacTests",
            dependencies: ["hyperMac"],
            path: "Tests/hyperMacTests"
        )
    ]
)
