// swift-tools-version:5.9
// HumanTyper for macOS — native SwiftUI/AppKit app. Build the .app with ./build-app.sh (needs Xcode / Command Line Tools).
import PackageDescription

let package = Package(
    name: "HumanTyper",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "HumanTyper",
            path: "Sources/HumanTyper",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ApplicationServices"),
            ]
        )
    ]
)
