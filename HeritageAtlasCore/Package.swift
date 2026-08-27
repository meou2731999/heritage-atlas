// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HeritageAtlasCore",
    platforms: [
        .iOS(.v18),
        .watchOS(.v11),
        .macOS(.v15),
    ],
    products: [
        .library(name: "HeritageAtlasCore", targets: ["HeritageAtlasCore"]),
    ],
    targets: [
        .target(
            name: "HeritageAtlasCore",
            swiftSettings: [
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),
        .testTarget(
            name: "HeritageAtlasCoreTests",
            dependencies: ["HeritageAtlasCore"]
        ),
    ]
)
