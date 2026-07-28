// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PoseioscShared",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "PoseioscShared", targets: ["PoseioscShared"]),
        .executable(name: "poseiosc-testsend", targets: ["poseiosc-testsend"]),
        .executable(name: "poseiosc-testlisten", targets: ["poseiosc-testlisten"])
    ],
    dependencies: [
        .package(url: "https://github.com/orchetect/swift-osc", from: "3.1.0")
    ],
    targets: [
        .target(
            name: "PoseioscShared",
            dependencies: [
                .product(name: "SwiftOSC", package: "swift-osc")
            ]
        ),
        .executableTarget(
            name: "poseiosc-testsend",
            dependencies: [
                "PoseioscShared",
                .product(name: "SwiftOSC", package: "swift-osc")
            ]
        ),
        .executableTarget(
            name: "poseiosc-testlisten",
            dependencies: [
                "PoseioscShared",
                .product(name: "SwiftOSC", package: "swift-osc")
            ]
        ),
        .testTarget(
            name: "PoseioscSharedTests",
            dependencies: ["PoseioscShared"]
        )
    ]
)
