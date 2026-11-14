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
        .library(name: "Motion Take File", targets: ["Motion Take File"]),
        .library(name: "Motion Picture", targets: ["Motion Picture"]),
        .library(name: "Motion Command", targets: ["Motion Command"]),
        .library(name: "Motion Graphics", targets: ["Motion Graphics"]),
        .library(name: "Motion Clock Shims", type: .dynamic, targets: ["Motion Clock Shims"]),
    ],
    traits: [
        .trait(name: "Picture", description: "Motion Picture: frames and reels drawn from pictures of swift-picture"),
        .trait(name: "File", description: "Motion Take File: takes kept in files through swift-file-system"),
        .trait(name: "Command", description: "Motion Command: a reel's proofs written from the command line", enabledTraits: ["Picture"]),
        .trait(name: "Graphics", description: "Motion Graphics: on-screen components drawn as pictures of swift-picture", enabledTraits: ["Picture"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-atoms/swift-rate.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-rational.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-numeric.git", branch: "main"),
        .package(url: "https://github.com/swift-standards/swift-itu-t-h-273.git", branch: "main"),
        .package(url: "https://github.com/swift-standards/swift-smpte-st-12.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-cardinal.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-formatter.git", branch: "main", traits: ["Number"]),
        .package(url: "https://github.com/swift-molecules/swift-raster.git", branch: "main", traits: ["Geometry"]),
        .package(url: "https://github.com/swift-iec/swift-iec-61966.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-picture.git", branch: "main", traits: ["PNG", "Store"]),
        .package(url: "https://github.com/swift-compositions/swift-witnesses.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-test-apple.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-threads.git", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-timeline.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-arguments.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-file-system.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-process.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-standard-library-extensions.git", branch: "main"),
        .package(url: "https://github.com/swift-ietf/swift-rfc-1951.git", branch: "main"),
        .package(url: "https://github.com/swift-standards/swift-fips-180-4.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-byte.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-binary.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-integer.git", branch: "main"),
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
                .product(name: "IEC 61966", package: "swift-iec-61966"),
                .product(name: "FIPS 180-4", package: "swift-fips-180-4"),
                .product(name: "RFC 1951", package: "swift-rfc-1951"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "Binary", package: "swift-binary"),
                .product(name: "Integer", package: "swift-integer"),
            ]
        ),
        .target(
            name: "Motion Take File",
            dependencies: [
                .target(name: "Motion"),
                .product(name: "File System", package: "swift-file-system", condition: .when(traits: ["File"])),
            ]
        ),
        .target(
            name: "Motion Picture",
            dependencies: [
                .target(name: "Motion"),
                .product(name: "Picture", package: "swift-picture", condition: .when(traits: ["Picture"])),
                .product(name: "Picture CPU", package: "swift-picture", condition: .when(traits: ["Picture"])),
                .product(name: "Picture PNG Integration", package: "swift-picture", condition: .when(traits: ["Picture"])),
                .product(name: "Picture Store", package: "swift-picture", condition: .when(traits: ["Picture"])),
                .product(name: "Thread Pool", package: "swift-threads", condition: .when(traits: ["Picture"])),
                .product(name: "Witnesses", package: "swift-witnesses", condition: .when(traits: ["Picture"])),
                .product(name: "Timeline", package: "swift-timeline", condition: .when(traits: ["Picture"])),
                .product(name: "RFC 1951", package: "swift-rfc-1951", condition: .when(traits: ["Picture"])),
                .product(name: "Byte", package: "swift-byte", condition: .when(traits: ["Picture"])),
                .product(name: "Binary", package: "swift-binary", condition: .when(traits: ["Picture"])),
                .product(name: "FIPS 180-4", package: "swift-fips-180-4", condition: .when(traits: ["Picture"])),
                .product(name: "Standard Library Extensions", package: "swift-standard-library-extensions", condition: .when(traits: ["Picture"])),
            ]
        ),
        .target(
            name: "Motion Command",
            dependencies: [
                .target(name: "Motion"),
                .target(name: "Motion Picture"),
                .target(name: "Motion Encoding", condition: .when(platforms: [.macOS, .iOS, .tvOS, .visionOS])),
                .product(name: "Picture", package: "swift-picture", condition: .when(traits: ["Command"])),
                .product(name: "Picture PNG Integration", package: "swift-picture", condition: .when(traits: ["Command"])),
                .product(name: "Picture Store", package: "swift-picture", condition: .when(traits: ["Command"])),
                .product(name: "Timeline", package: "swift-timeline", condition: .when(traits: ["Command"])),
                .product(name: "Command", package: "swift-arguments", condition: .when(traits: ["Command"])),
                .product(name: "File System", package: "swift-file-system", condition: .when(traits: ["Command"])),
                .product(name: "Process", package: "swift-process", condition: .when(traits: ["Command"])),
            ]
        ),
        .target(
            name: "Motion Graphics",
            dependencies: [
                .target(name: "Motion"),
                .product(name: "Formatter", package: "swift-formatter", condition: .when(traits: ["Graphics"])),
                .product(name: "Numeric", package: "swift-numeric", condition: .when(traits: ["Graphics"])),
                .product(name: "Picture", package: "swift-picture", condition: .when(traits: ["Graphics"])),
                .product(name: "Timeline", package: "swift-timeline", condition: .when(traits: ["Graphics"])),
                .product(name: "Standard Library Extensions", package: "swift-standard-library-extensions", condition: .when(traits: ["Graphics"])),
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
            name: "Motion Clock Lookup Shims",
            publicHeadersPath: "include"
        ),
        .target(
            name: "Motion Clock",
            dependencies: [
                .target(name: "Motion"),
                .target(name: "Motion Clock Lookup Shims"),
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
                .product(name: "Test Apple", package: "swift-test-apple"),
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
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "FIPS 180-4", package: "swift-fips-180-4"),
                .product(name: "Rational", package: "swift-rational"),
                .product(name: "SMPTE ST 12", package: "swift-smpte-st-12"),
            ]
        ),
        .testTarget(
            name: "Motion Take File Tests",
            dependencies: [
                .target(name: "Motion"),
                .target(name: "Motion Take File"),
                .product(name: "File System", package: "swift-file-system"),
            ]
        ),
        .testTarget(
            name: "Motion Encoding Tests",
            dependencies: [
                .product(name: "Test Apple", package: "swift-test-apple"),
                .target(name: "Motion"),
                .target(name: "Motion Encoding"),
                .target(name: "Motion Cache"),
                .product(name: "ITU-T H 273", package: "swift-itu-t-h-273"),
            ]
        ),
        .testTarget(
            name: "Motion Picture Tests",
            dependencies: [
                .target(name: "Motion"),
                .target(name: "Motion Picture"),
                .target(name: "Motion Take File"),
                .target(name: "Motion Encoding"),
                .product(name: "Picture", package: "swift-picture"),
                .product(name: "Picture CPU", package: "swift-picture"),
                .product(name: "Witnesses", package: "swift-witnesses"),
                .product(name: "Picture PNG Integration", package: "swift-picture"),
                .product(name: "Timeline", package: "swift-timeline"),
                .product(name: "Picture Store", package: "swift-picture"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "Test Apple", package: "swift-test-apple"),
                .product(name: "RFC 1951", package: "swift-rfc-1951"),
                .product(name: "Standard Library Extensions", package: "swift-standard-library-extensions"),
            ]
        ),
        .testTarget(
            name: "Motion Command Tests",
            dependencies: [
                .target(name: "Motion"),
                .target(name: "Motion Picture"),
                .target(name: "Motion Command"),
                .target(name: "Motion Encoding"),
                .product(name: "Picture", package: "swift-picture"),
                .product(name: "Command", package: "swift-arguments"),
                .product(name: "File System", package: "swift-file-system"),
            ]
        ),
        .testTarget(
            name: "Motion Graphics Tests",
            dependencies: [
                .target(name: "Motion"),
                .target(name: "Motion Graphics"),
                .product(name: "Picture", package: "swift-picture"),
                .product(name: "Timeline", package: "swift-timeline"),
                .product(name: "Standard Library Extensions", package: "swift-standard-library-extensions"),
            ]
        ),
        .testTarget(
            name: "Motion Cache Tests",
            dependencies: [
                .product(name: "Test Apple", package: "swift-test-apple"),
                .target(name: "Motion"),
                .target(name: "Motion Cache"),
            ]
        ),
        .testTarget(
            name: "Motion Window Tests",
            dependencies: [
                .product(name: "Test Apple", package: "swift-test-apple"),
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
