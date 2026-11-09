import XCTest
@testable import forge

final class SwiftPackageIntegrationTests: XCTestCase {
    private func makeRoot(_ manifest: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try manifest.write(to: root.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        return root
    }

    private let basicManifest = """
    // swift-tools-version: 6.2
    import PackageDescription
    let package = Package(
        name: "App",
        targets: [
            .target(name: "FeatureKit", dependencies: []),
        ]
    )
    """

    func testAddsTestTargetAndFactoryOnce() throws {
        let root = try makeRoot(basicManifest)
        defer { try? FileManager.default.removeItem(at: root) }
        let update = try SwiftPackageIntegration.plan(at: root, target: "FeatureKit", tests: true, factory: true)
        XCTAssertTrue(update.changed)
        XCTAssertEqual(update.updated.components(separatedBy: "https://github.com/hmlongco/Factory.git").count - 1, 1)
        XCTAssertEqual(update.updated.components(separatedBy: ".product(name: \"Factory\"").count - 1, 1)
        XCTAssertEqual(update.updated.components(separatedBy: ".testTarget(name: \"FeatureKitTests\"").count - 1, 1)
        try update.updated.write(to: update.manifestURL, atomically: true, encoding: .utf8)
        let second = try SwiftPackageIntegration.plan(at: root, target: "FeatureKit", tests: true, factory: true)
        XCTAssertFalse(second.changed)
    }

    func testRejectsMissingTargetBeforeFeatureFilesAreWritten() throws {
        let root = try makeRoot(basicManifest)
        defer { try? FileManager.default.removeItem(at: root) }
        let generator = FeatureGenerator(projectPath: root, shouldCreatePackage: false,
            packageTarget: "OtherKit", shouldGenerateTests: true, shouldSkipDomain: false,
            type: .mvvm, category: nil)
        XCTAssertThrowsError(try generator.generate(
            feature: FeatureName(rawValue: "Login"), selection: .all(for: .mvvm)))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources/OtherKit/Login").path))
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("Package.swift"), encoding: .utf8), basicManifest)
    }

    func testRejectsDynamicTargetsWithoutChangingManifest() throws {
        let manifest = """
        // swift-tools-version: 6.2
        import PackageDescription
        let targets: [Target] = [.target(name: "FeatureKit")]
        let package = Package(name: "App", targets: targets)
        """
        let root = try makeRoot(manifest)
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertThrowsError(try SwiftPackageIntegration.plan(at: root, target: "FeatureKit", tests: true, factory: false))
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("Package.swift"), encoding: .utf8), manifest)
    }

    func testAddsMissingDependencyToExistingTestTarget() throws {
        let manifest = basicManifest.replacingOccurrences(
            of: ".target(name: \"FeatureKit\", dependencies: []),",
            with: ".target(name: \"FeatureKit\", dependencies: []),\n        .testTarget(name: \"FeatureKitTests\", dependencies: []),"
        )
        let root = try makeRoot(manifest)
        defer { try? FileManager.default.removeItem(at: root) }
        let update = try SwiftPackageIntegration.plan(at: root, target: "FeatureKit", tests: true, factory: false)
        XCTAssertTrue(update.updated.contains(".testTarget(name: \"FeatureKitTests\", dependencies: [\n            \"FeatureKit\"]"))
        XCTAssertEqual(update.updated.components(separatedBy: ".testTarget(").count - 1, 1)
    }

    func testRejectsCustomSourcePath() throws {
        let manifest = basicManifest.replacingOccurrences(of: "dependencies: []),",
            with: "dependencies: [], path: \"Modules/FeatureKit\"),")
        let root = try makeRoot(manifest)
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertThrowsError(try SwiftPackageIntegration.plan(at: root, target: "FeatureKit", tests: false, factory: false))
    }
}
