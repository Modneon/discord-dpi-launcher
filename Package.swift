// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DiscordDPILauncher",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "DiscordDPILauncher", targets: ["DiscordDPILauncher"])
    ],
    targets: [
        .executableTarget(
            name: "DiscordDPILauncher",
            path: "Sources/DiscordDPILauncher"
        )
    ]
)
