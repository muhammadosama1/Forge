import Foundation
import XCTest
@testable import forge

final class XcodeProjectIntegrationTests: XCTestCase {
    private var root: URL!
    private var projectFile: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let project = root.appendingPathComponent("Demo.xcodeproj")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        projectFile = project.appendingPathComponent("project.pbxproj")
        try Self.project.write(to: projectFile, atomically: true, encoding: .utf8)
    }

    override func tearDownWithError() throws {
        if let root { try FileManager.default.removeItem(at: root) }
    }

    func testRegistersSourcesOnlyWithSelectedAppTarget() throws {
        try writeConfig(target: "Demo App")
        let configuredCommand = try Command.parse(arguments: ["make", "Login", "-mvvm", "--path", root.path])
        try configuredCommand.run()
        let project = try Data(contentsOf: projectFile)
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: project, format: nil) as? [String: Any])
        let objects = try XCTUnwrap(plist["objects"] as? [String: [String: Any]])
        let files = try XCTUnwrap(objects["A00000000000000000000005"]?["files"] as? [String])
        XCTAssertEqual(files.count, 3)
        XCTAssertEqual(objects["A00000000000000000000006"]?["files"] as? [String], [])
        let paths = try files.map { id in
            let ref = try XCTUnwrap(objects[id]?["fileRef"] as? String)
            return try XCTUnwrap(objects[ref]?["path"] as? String)
        }
        XCTAssertEqual(Set(paths), [
            "Login/LoginDependencyContainer.swift",
            "Login/Presentation/LoginView.swift",
            "Login/Presentation/LoginViewModel.swift",
        ])
        for path in paths {
            XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path))
        }
        XCTAssertThrowsError(try configuredCommand.run())
        XCTAssertEqual(try Data(contentsOf: projectFile), project)
    }

    func testExplicitOutputOptionsOverrideConfiguredXcodeTarget() throws {
        try writeConfig(target: "Other")
        XCTAssertEqual(try command(target: "Demo App").xcodeTarget, "Demo App")

        let arguments = ["make", "Login", "-mvvm", "--path", root.path]
        let standalone = try Command.parse(arguments: arguments + ["--package"])
        XCTAssertTrue(standalone.shouldCreatePackage)
        XCTAssertNil(standalone.xcodeTarget)
        let existingPackage = try Command.parse(arguments: arguments + ["--target", "FeatureKit"])
        XCTAssertEqual(existingPackage.packageTarget, "FeatureKit")
        XCTAssertNil(existingPackage.xcodeTarget)
    }

    func testInvalidTargetLeavesProjectAndOutputUntouched() throws {
        let original = try Data(contentsOf: projectFile)
        XCTAssertThrowsError(try command(target: "Missing App").run()) { error in
            let message = (error as? ForgeError)?.message ?? ""
            XCTAssertTrue(message.contains("Missing App"))
            XCTAssertTrue(message.contains("Choose an app target from: 'Demo App', 'Other'"))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Login").path))
        XCTAssertEqual(try Data(contentsOf: projectFile), original)
    }

    func testInfersOnlyAppTargetAndIgnoresTestTarget() throws {
        let original = Self.project.replacingOccurrences(
            of: "name = Other; productType = \"com.apple.product-type.application\"",
            with: "name = Other; productType = \"com.apple.product-type.bundle.unit-test\""
        )
        try original.write(to: projectFile, atomically: true, encoding: .utf8)
        try Command.parse(arguments: ["make", "Login", "-mvvm", "--path", root.path]).run()
        let updated = try String(contentsOf: projectFile, encoding: .utf8)
        XCTAssertTrue(updated.contains("LoginView.swift in Sources"))
    }

    func testAmbiguousAppTargetsRequireAChoiceOrFilesOnly() throws {
        let original = try Data(contentsOf: projectFile)
        let args = ["make", "Login", "-mvvm", "--path", root.path]
        XCTAssertThrowsError(try Command.parse(arguments: args).run()) { error in
            let message = (error as? ForgeError)?.message ?? ""
            XCTAssertTrue(message.contains("'Demo App', 'Other'"))
            XCTAssertTrue(message.contains("--xcode-target"))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Login").path))
        try Command.parse(arguments: args + ["--files-only", "--tests"]).run()
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("Login/Tests").path))
        XCTAssertEqual(try Data(contentsOf: projectFile), original)
    }

    private func command(target: String) throws -> Command {
        try Command.parse(arguments: ["make", "Login", "-mvvm", "--path", root.path, "--xcode-target", target])
    }

    private func writeConfig(target: String) throws {
        try "paths:\n  xcode_target: \"\(target)\"\n".write(
            to: root.appendingPathComponent(".forge.yml"), atomically: true, encoding: .utf8
        )
    }

    private static let project = """
    // !$*UTF8*$!
    {
        archiveVersion = 1;
        classes = {};
        objectVersion = 56;
        objects = {
            A00000000000000000000001 = {isa = PBXProject; mainGroup = A00000000000000000000002; buildConfigurationList = A00000000000000000000007; targets = (A00000000000000000000003, A00000000000000000000004);};
            A00000000000000000000002 = {isa = PBXGroup; children = (); sourceTree = "<group>";};
            A00000000000000000000003 = {isa = PBXNativeTarget; name = "Demo App"; productType = "com.apple.product-type.application"; buildPhases = (A00000000000000000000005); buildConfigurationList = A00000000000000000000007;};
            A00000000000000000000004 = {isa = PBXNativeTarget; name = Other; productType = "com.apple.product-type.application"; buildPhases = (A00000000000000000000006); buildConfigurationList = A00000000000000000000007;};
            A00000000000000000000005 = {isa = PBXSourcesBuildPhase; files = ();};
            A00000000000000000000006 = {isa = PBXSourcesBuildPhase; files = ();};
            A00000000000000000000007 = {isa = XCConfigurationList; buildConfigurations = (A00000000000000000000008); defaultConfigurationName = Debug;};
            A00000000000000000000008 = {isa = XCBuildConfiguration; name = Debug; buildSettings = {};};
        };
        rootObject = A00000000000000000000001;
    }
    """
}
