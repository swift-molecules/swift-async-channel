// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-async-channel",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(
            name: "Async Channel",
            targets: ["Async Channel"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swift-molecules/swift-async", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-async-waiter", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-buffer", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-buffer-ring", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-column", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-deque", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-index", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-memory-allocation", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-memory-heap", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-ownership", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-pair", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-queue", branch: "main"),
    ],
    targets: [
        .target(
            name: "Async Channel",
            dependencies: [
                .product(name: "Async", package: "swift-async"),
                .product(name: "Async Waiter", package: "swift-async-waiter"),
                .product(name: "Buffer", package: "swift-buffer"),
                .product(name: "Buffer Ring", package: "swift-buffer-ring"),
                .product(name: "Column", package: "swift-column"),
                .product(name: "Deque", package: "swift-deque"),
                .product(name: "Index", package: "swift-index"),
                .product(name: "Memory Allocator", package: "swift-memory-allocation"),
                .product(name: "Memory Heap", package: "swift-memory-heap"),
                .product(name: "Ownership", package: "swift-ownership"),
                .product(name: "Pair", package: "swift-pair"),
                .product(name: "Queue", package: "swift-queue"),
            ]
        ),
        .testTarget(
            name: "Async Channel Tests",
            dependencies: [
                "Async Channel",
                .product(name: "Async", package: "swift-async"),
                .product(name: "Ownership", package: "swift-ownership"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("Lifetimes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
    ]

    let package: [SwiftSetting] = [
        .enableExperimentalFeature("RawLayout")
    ]

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
