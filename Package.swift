// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Pasty",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Pasty", targets: ["Pasty"])
    ],
    targets: [
        .executableTarget(
            name: "Pasty"
        )
    ]
)
