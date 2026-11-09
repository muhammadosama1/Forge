// swift-tools-version: 6.2

import PackageDescription
import Foundation

// Release builds stamp this optional source through `make generate-version`.
// A clean checkout builds directly with a development version instead.
let stampedVersionPath = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Sources/forge/Version.swift").path
let versionSettings: [SwiftSetting] = FileManager.default.fileExists(atPath: stampedVersionPath)
    ? [.define("FORGE_STAMPED_VERSION")]
    : []

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
            name: "forge",
            swiftSettings: versionSettings
        ),
        .testTarget(
            name: "forgeTests",
            dependencies: ["forge"]
        ),
    ]
)
