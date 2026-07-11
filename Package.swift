// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "forge",
    products: [
        .executable(
            name: "forge",
            targets: ["forge"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "forge"
        ),
    ]
)
