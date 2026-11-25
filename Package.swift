// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DietApp",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "DietCore", targets: ["DietCore"]),
        .library(name: "DietFeatures", targets: ["DietFeatures"])
    ],
    targets: [
        .target(
            name: "DietCore",
            path: "Sources/DietCore"
        ),
        .target(
            name: "DietFeatures",
            dependencies: ["DietCore"],
            path: "Sources/DietFeatures"
        ),
        .testTarget(
            name: "DietCoreTests",
            dependencies: ["DietCore"],
            path: "Tests/DietCoreTests"
        ),
        .testTarget(
            name: "DietFeaturesTests",
            dependencies: ["DietCore", "DietFeatures"],
            path: "Tests/DietFeaturesTests"
        )
    ]
)
