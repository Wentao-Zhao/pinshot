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
    .binaryTarget(
      name: "Sparkle",
      url: "https://github.com/sparkle-project/Sparkle/releases/download/2.10.1/Sparkle-for-Swift-Package-Manager.zip",
      checksum: "4c2e48a3e50ebcc2c88a58a4c7264a1a99c3c31857ce754357afb9cdb323022a"
    ),
    .target(
      name: "PinShotCore",
      path: "Sources/PinShotCore"
    ),
    .executableTarget(
      name: "PinShot",
      dependencies: ["PinShotCore", "Sparkle"],
      path: "Sources/PinShot",
      linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
    ),
    .executableTarget(
      name: "PinShotLogicTests",
      dependencies: ["PinShotCore"],
      path: "Tests/PinShotTests"
    ),
  ]
)

