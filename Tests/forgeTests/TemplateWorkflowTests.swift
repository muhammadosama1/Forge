import Foundation
import XCTest
@testable import forge

final class TemplateWorkflowTests: XCTestCase {
    private var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }

    func testDryRunPlansPackageWithoutCreatingIt() throws {
        let command = try Command.parse(arguments: ["make", "Profile", "-mvvm", "--package", "--tests", "--dry-run", "--path", root.path])
        XCTAssertTrue(command.dryRun)
        try command.run()
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
    }

    func testDryRunLeavesExistingManifestUnchanged() throws {
        let manifest = """
        // swift-tools-version: 6.2
        import PackageDescription
        let package = Package(name: "App", targets: [.target(name: "FeatureKit", dependencies: [])])
        """
        let url = root.appendingPathComponent("Package.swift")
        try manifest.write(to: url, atomically: true, encoding: .utf8)
        try Command.parse(arguments: ["make", "Profile", "-mvvm", "--target", "FeatureKit", "--tests", "--dry-run", "--path", root.path]).run()
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), manifest)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), ["Package.swift"])
    }

    func testExportPartialOverrideAndFallback() throws {
        try TemplateCatalog.run(arguments: ["templates", "export", "mvvmViewModel", "--path", root.path])
        let template = root.appendingPathComponent(".forge/templates/mvvmViewModel.stencil")
        try "// Custom {{ name }}\n".write(to: template, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try TemplateCatalog.run(arguments: ["templates", "export", "mvvmViewModel", "--path", root.path]))
        try Command.parse(arguments: ["make", "Profile", "-mvvm", "--path", root.path]).run()
        let model = root.appendingPathComponent("Profile/Presentation/ProfileViewModel.swift")
        XCTAssertTrue(try String(contentsOf: model, encoding: .utf8).contains("// Custom Profile"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("Profile/Presentation/ProfileView.swift").path))
    }

    func testInvalidOverrideFailsBeforeAnyFeatureWrite() throws {
        try TemplateCatalog.run(arguments: ["templates", "export", "mvvmViewModel", "--path", root.path])
        let template = root.appendingPathComponent(".forge/templates/mvvmViewModel.stencil")
        try "{{ misspelledName }}".write(to: template, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try Command.parse(arguments: ["make", "Profile", "-mvvm", "--path", root.path]).run())
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Profile").path))
    }

    func testUnknownVariablesAndMalformedSyntaxAreRejected() throws {
        for source in ["{{ typo }}", "{% if typo %}x{% endif %}", "{% if yes %}x", "{% else %}", "{{ name", "{% for x %}", "{% if yes %}a{% else %}b{% else %}c{% endif %}"] {
            XCTAssertThrowsError(try TemplateRenderer.renderSource(source, context: ["yes": true, "name": "Profile"], name: "custom"), source)
        }
        XCTAssertEqual(try TemplateRenderer.renderSource("{% if yes %}{{name}}{% else %}no{% endif %}", context: ["yes": true, "name": "Profile"], name: "custom"), "Profile")
    }

    func testConfigLocationOwnsOverridesEvenWithDifferentOutputRoot() throws {
        let output = root.appendingPathComponent("output")
        let config = root.appendingPathComponent("team.yml")
        try "architecture: mvvm\npaths:\n  root: output\n".write(to: config, atomically: true, encoding: .utf8)
        try TemplateCatalog.run(arguments: ["templates", "export", "mvvmViewModel", "--config", config.path])
        try "// Custom {{ name }}".write(to: root.appendingPathComponent(".forge/templates/mvvmViewModel.stencil"), atomically: true, encoding: .utf8)
        try Command.parse(arguments: ["make", "Profile", "--config", config.path]).run()
        XCTAssertTrue(try String(contentsOf: output.appendingPathComponent("Profile/Presentation/ProfileViewModel.swift"), encoding: .utf8).contains("// Custom Profile"))
    }

    func testIncompatibleContractAndEscapingSymlinkAreRejected() throws {
        try TemplateCatalog.run(arguments: ["templates", "export", "entity", "--path", root.path])
        let directory = root.appendingPathComponent(".forge/templates")
        try "99".write(to: directory.appendingPathComponent("contract-version"), atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try TemplateCatalog.source("entity.stencil", overrides: directory))
        try "1".write(to: directory.appendingPathComponent("contract-version"), atomically: true, encoding: .utf8)
        let outside = root.appendingPathComponent("outside.stencil")
        try "outside".write(to: outside, atomically: true, encoding: .utf8)
        let template = directory.appendingPathComponent("entity.stencil")
        try FileManager.default.removeItem(at: template)
        try FileManager.default.createSymbolicLink(at: template, withDestinationURL: outside)
        XCTAssertThrowsError(try TemplateCatalog.source("entity.stencil", overrides: directory))
    }

    func testBrokenOverrideDoesNotSilentlyFallBack() throws {
        try TemplateCatalog.run(arguments: ["templates", "export", "entity", "--path", root.path])
        let directory = root.appendingPathComponent(".forge/templates")
        let template = directory.appendingPathComponent("entity.stencil")
        try FileManager.default.removeItem(at: template)
        try FileManager.default.createSymbolicLink(at: template, withDestinationURL: directory.appendingPathComponent("missing.stencil"))
        XCTAssertThrowsError(try TemplateCatalog.source("entity.stencil", overrides: directory))
    }

    func testDryRunStillReportsConflicts() throws {
        let path = root.appendingPathComponent("Profile/Presentation")
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        let file = path.appendingPathComponent("ProfileView.swift")
        try "existing".write(to: file, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try Command.parse(arguments: ["make", "Profile", "-mvvm", "--dry-run", "--path", root.path]).run())
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "existing")
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Profile/ProfileDependencyContainer.swift").path))
    }
}
