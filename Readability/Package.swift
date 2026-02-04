// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Readability",
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
            name: "Readability"
        ),
        .testTarget(
            name: "ReadabilityTests",
            dependencies: ["Readability"]
        ),
    ]
)
