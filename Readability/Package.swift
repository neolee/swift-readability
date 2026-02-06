// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Readability",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "Readability",
            targets: ["Readability"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", .upToNextMajor(from: "2.11.3"))
    ],
    targets: [
        .target(
            name: "Readability",
            dependencies: ["SwiftSoup"]
        ),
        .testTarget(
            name: "ReadabilityTests",
            dependencies: ["Readability", "SwiftSoup"],
            resources: [
                .copy("Resources/test-pages"),
                .copy("Resources/realworld-pages")
            ]
        ),
    ]
)
