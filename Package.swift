// swift-tools-version: 6.4

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("ImmutableWeakCaptures"),
    .strictMemorySafety(),
]

let package = Package(
    name: "Wiring",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "Wiring", targets: ["Wiring"]),
    ],
    targets: [
        .target(
            name: "Wiring",
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "WiringTests",
            dependencies: ["Wiring"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "WiringDefaultIsolationTests",
            dependencies: ["Wiring"],
            swiftSettings: swiftSettings + [.defaultIsolation(MainActor.self)]
        ),
    ]
)
