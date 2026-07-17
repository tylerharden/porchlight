// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PorchlightMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Porchlight", targets: ["Porchlight"])
    ],
    targets: [
        .executableTarget(
            name: "Porchlight",
            path: "Sources/Porchlight"
        )
    ]
)
