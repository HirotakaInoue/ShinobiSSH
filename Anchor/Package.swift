// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Anchor",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Anchor",
            path: ".",
            exclude: ["Info.plist", "Anchor.entitlements", "Assets.xcassets"],
            sources: ["AnchorApp.swift", "Models", "Services", "Views"]
        ),
    ]
)
