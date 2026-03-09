// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShinobiSSH",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ShinobiSSH",
            path: ".",
            exclude: ["Info.plist", "ShinobiSSH.entitlements", "Assets.xcassets"],
            sources: ["ShinobiSSHApp.swift", "Models", "Services", "Views"]
        ),
    ]
)
