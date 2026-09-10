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
        .library(name: "Async Channel", targets: ["Async Channel"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-atoms/swift-async.git", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-async-waiter.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-buffer.git", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-buffer-ring.git", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-column.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-deque.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-index.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-memory.git", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-memory-allocation.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-ownership.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-pair.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-queue.git", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-storage-memory.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Async Channel",
            dependencies: [
                .product(name: "Async Continuation", package: "swift-async"),
                .product(name: "Async Mutex", package: "swift-async"),
                .product(name: "Async Primitive", package: "swift-async"),
                .product(name: "Async Waiter", package: "swift-async-waiter"),
                .product(name: "Buffer", package: "swift-buffer"),
                .product(name: "Buffer Ring Primitive", package: "swift-buffer-ring"),
                .product(name: "Column", package: "swift-column"),
                .product(name: "Deque", package: "swift-deque"),
                .product(name: "Index", package: "swift-index"),
                .product(name: "Memory", package: "swift-memory"),
                .product(name: "Memory Allocator", package: "swift-memory-allocation"),
                .product(name: "Ownership", package: "swift-ownership"),
                .product(name: "Pair", package: "swift-pair"),
                .product(name: "Queue", package: "swift-queue"),
                .product(name: "Storage Memory", package: "swift-storage-memory"),
            ],
            path: "Sources/Async Channel"
        ),
        .testTarget(
            name: "Async Channel Tests",
            dependencies: [
                .product(name: "Async", package: "swift-async"),
                .product(name: "Ownership", package: "swift-ownership"),
                .target(name: "Async Channel"),
            ],
            path: "Tests/Async Channel Tests"
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
