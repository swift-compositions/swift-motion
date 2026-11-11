// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-motion",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(name: "Motion", targets: ["Motion"]),
        .library(name: "Motion Encoding", targets: ["Motion Encoding"]),
        .library(name: "Motion Cache", targets: ["Motion Cache"]),
        .library(name: "Motion Window", targets: ["Motion Window"]),
        .library(name: "Motion Clock", targets: ["Motion Clock"]),
        .library(name: "Motion Clock Shims", type: .dynamic, targets: ["Motion Clock Shims"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-atoms/swift-rate.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-rational.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-numeric.git", branch: "main"),
        .package(url: "https://github.com/swift-standards/swift-itu-t-h-273.git", branch: "main"),
        .package(url: "https://github.com/swift-standards/swift-smpte-st-12.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-cardinal.git", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-raster.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Motion",
            dependencies: [
                .product(name: "Rate", package: "swift-rate"),
                .product(name: "Rational", package: "swift-rational"),
                .product(name: "Numeric", package: "swift-numeric"),
                .product(name: "ITU-T H 273", package: "swift-itu-t-h-273"),
                .product(name: "SMPTE ST 12", package: "swift-smpte-st-12"),
                .product(name: "Cardinal", package: "swift-cardinal"),
                .product(name: "Raster", package: "swift-raster"),
            ]
        ),
        .target(
            name: "Motion Encoding",
            dependencies: [
                .target(name: "Motion"),
                .product(name: "ITU-T H 273", package: "swift-itu-t-h-273"),
            ]
        ),
        .target(
            name: "Motion Cache",
            dependencies: [
                .target(name: "Motion")
            ]
        ),
        .target(
            name: "Motion Window",
            dependencies: [
                .target(name: "Motion"),
                .target(name: "Motion Cache"),
                .target(name: "Motion Clock"),
            ]
        ),
        .target(
            name: "Motion Clock Shims",
            publicHeadersPath: "include",
            linkerSettings: [.linkedFramework("QuartzCore")]
        ),
        .target(
            name: "Motion Clock",
            dependencies: [
                .target(name: "Motion")
            ]
        ),
        .executableTarget(
            name: "Motion Fixture",
            dependencies: [
                .target(name: "Motion"),
                .target(name: "Motion Clock"),
                .target(name: "Motion Window"),
            ],
            path: "Tests/Motion Fixture"
        ),
        .testTarget(
            name: "Motion Clock Tests",
            dependencies: [
                .target(name: "Motion"),
                .target(name: "Motion Clock"),
                .target(name: "Motion Window"),
                .target(name: "Motion Fixture"),
            ]
        ),
        .testTarget(
            name: "Motion Tests",
            dependencies: [
                .target(name: "Motion"),
                .product(name: "Rational", package: "swift-rational"),
                .product(name: "SMPTE ST 12", package: "swift-smpte-st-12"),
            ]
        ),
        .testTarget(
            name: "Motion Encoding Tests",
            dependencies: [
                .target(name: "Motion"),
                .target(name: "Motion Encoding"),
                .target(name: "Motion Cache"),
                .product(name: "ITU-T H 273", package: "swift-itu-t-h-273"),
            ]
        ),
        .testTarget(
            name: "Motion Cache Tests",
            dependencies: [
                .target(name: "Motion"),
                .target(name: "Motion Cache"),
            ]
        ),
        .testTarget(
            name: "Motion Window Tests",
            dependencies: [
                .target(name: "Motion"),
                .target(name: "Motion Cache"),
                .target(name: "Motion Window"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    target.swiftSettings =
        (target.swiftSettings ?? []) + [
            .strictMemorySafety(),
            .enableUpcomingFeature("ExistentialAny"),
            .enableUpcomingFeature("InternalImportsByDefault"),
            .enableUpcomingFeature("MemberImportVisibility"),
            .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            .enableUpcomingFeature("InferIsolatedConformances"),
            .enableExperimentalFeature("Lifetimes"),
            .treatAllWarnings(as: .error),
        ]
}
