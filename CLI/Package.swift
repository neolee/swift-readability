// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ReadabilityCLI",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(path: "..")
    ],
    targets: [
        .executableTarget(
            name: "ReadabilityCLI",
            dependencies: [
                .product(name: "Readability", package: "readability")
            ]
        )
    ]
)
