// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "PinShot",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(name: "PinShot", targets: ["PinShot"]),
    .executable(name: "PinShotLogicTests", targets: ["PinShotLogicTests"]),
  ],
  targets: [
    .target(
      name: "PinShotCore",
      path: "Sources/PinShotCore"
    ),
    .executableTarget(
      name: "PinShot",
      dependencies: ["PinShotCore"],
      path: "Sources/PinShot"
    ),
    .executableTarget(
      name: "PinShotLogicTests",
      dependencies: ["PinShotCore"],
      path: "Tests/PinShotTests"
    ),
  ]
)

