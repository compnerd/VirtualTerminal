// swift-tools-version:6.1

import PackageDescription

let _: Package =
  .init(name: "VirtualTerminal",
        platforms: [
          .macOS(.v15),
        ],
        products: [
          .executable(name: "VTDemo", targets: ["VTDemo"]),
          .library(name: "VirtualTerminal", targets: ["VirtualTerminal"]),
        ],
        traits: [
          .trait(name: "GNU", description: "GNU C Library")
        ],
        dependencies: [
          .package(url: "https://github.com/compnerd/swift-platform-core.git", branch: "main",
                   traits: [.trait(name: "GNU", condition: .when(traits: ["GNU"]))]),
        ],
        targets: [
          .target(name: "libunistring"),
          .target(name: "Geometry"),
          .target(name: "Primitives"),
          .target(name: "VirtualTerminal", dependencies: [
            .target(name: "Geometry"),
            .target(name: "Primitives"),
            .target(name: "libunistring", condition: .when(traits: ["GNU"])),
            .product(name: "POSIXCore", package: "swift-platform-core", condition: .when(platforms: [.macOS, .linux])),
            .product(name: "WindowsCore", package: "swift-platform-core", condition: .when(platforms: [.windows])),
          ]),
          .executableTarget(name: "VTDemo", dependencies: [
            .target(name: "VirtualTerminal"),
            .product(name: "POSIXCore", package: "swift-platform-core", condition: .when(platforms: [.macOS, .linux])),
          ]),
        ])
