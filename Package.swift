// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Porta",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Porta",
            dependencies: [],
            path: "Porta",
            resources: []
        )
    ]
)
