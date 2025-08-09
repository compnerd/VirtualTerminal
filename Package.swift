// swift-tools-version:6.0

import PackageDescription

let _: Package =
  .init(name: "VirtualTerminal",
        platforms: [
          .macOS(.v14),
        ],
        products: [
          .executable(name: "VTDemo", targets: ["VTDemo"]),
          .library(name: "VirtualTerminal", targets: ["VirtualTerminal"]),
        ],
        dependencies: [
          .package(url: "https://github.com/zaneenders/swift-platform-core.git", branch: "zane-asahi-linux-patch"),
        ],
        targets: [
          .target(name: "Geometry"),
          .target(name: "Primitives"),
          .target(name: "VirtualTerminal", dependencies: [
            .target(name: "Geometry"),
            .target(name: "Primitives"),
            .product(name: "POSIXCore", package: "swift-platform-core", condition: .when(platforms: [.macOS, .linux])),
            .product(name: "WindowsCore", package: "swift-platform-core", condition: .when(platforms: [.windows])),
          ]),
          .executableTarget(name: "VTDemo", dependencies: [
            .target(name: "VirtualTerminal"),
            .product(name: "POSIXCore", package: "swift-platform-core", condition: .when(platforms: [.macOS, .linux])),
          ]),
        ])
