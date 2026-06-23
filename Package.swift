// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "FaceCamOverlay",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "FaceCamOverlay",
            path: "Sources/FaceCamOverlay"
        )
    ]
)
