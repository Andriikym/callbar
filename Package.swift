// swift-tools-version: 5.9

import PackageDescription

var products: [Product] = [
    .library(name: "CallBarCore", targets: ["CallBarCore"])
]

var targets: [Target] = [
    .target(name: "CallBarCore"),
    .testTarget(name: "CallBarCoreTests", dependencies: ["CallBarCore"])
]

#if os(macOS)
products.append(.executable(name: "CallBar", targets: ["CallBar"]))
targets.append(.executableTarget(name: "CallBar", dependencies: ["CallBarCore"]))
targets.append(.testTarget(name: "CallBarTests", dependencies: ["CallBar"]))
#endif

let package = Package(
    name: "CallBar",
    platforms: [.macOS(.v13)],
    products: products,
    targets: targets
)
