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
        let paths = try registeredPaths()
        XCTAssertEqual(paths.count, 3)
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

    func testConcurrentDistinctFeaturesKeepEverySourceAndMembership() throws {
        // Exercise two spellings of the same project root.
        let alias = root.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: root)
        let names = (1...16).map { "Feature\($0)" }
        let results = try runConcurrently(names.enumerated().map { index, name in
            cliArguments(name, at: index.isMultiple(of: 2) ? root : alias)
        })
        for result in results { XCTAssertEqual(result.status, 0, result.error) }
        let paths = try registeredPaths()
        XCTAssertEqual(paths.count, 3 * names.count)
        XCTAssertEqual(Set(paths), Set(names.flatMap(expectedPaths)))
        for path in paths {
            XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path))
        }
    }

    func testConcurrentDuplicateFeaturesKeepTheWinningRunIntact() throws {
        let results = try runConcurrently(Array(repeating: cliArguments("Login", at: root), count: 16))
        XCTAssertEqual(results.filter { $0.status == 0 }.count, 1)
        for result in results where result.status != 0 {
            XCTAssertTrue(result.error.contains("Refusing to overwrite existing file"), result.error)
        }
        let paths = try registeredPaths()
        XCTAssertEqual(paths.sorted(), expectedPaths("Login").sorted())
        for path in paths {
            XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path))
        }
    }

    func testConcurrentFilesOnlyCommandsKeepTheWinningRunIntact() throws {
        let args = ["make", "Login", "-mvvm", "--path", root.path, "--files-only"]
        let original = try Data(contentsOf: projectFile)
        let results = try runConcurrently(Array(repeating: args, count: 8))
        XCTAssertEqual(results.filter { $0.status == 0 }.count, 1)
        for path in expectedPaths("Login") {
            XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path))
        }
        XCTAssertEqual(try Data(contentsOf: projectFile), original)
    }

    func testConcurrentSwiftPackageUpdatesKeepBothTestTargets() throws {
        let manifest = root.appendingPathComponent("Package.swift")
        try """
        import PackageDescription
        let package = Package(name: "Demo", targets: [
            .target(name: "First"),
            .target(name: "Second"),
        ])
        """.write(to: manifest, atomically: true, encoding: .utf8)
        let results = try runConcurrently(["First", "Second"].map {
            ["make", "Login", "-mvvm", "--path", root.path, "--target", $0, "--tests"]
        })
        for result in results { XCTAssertEqual(result.status, 0, result.error) }
        let updated = try String(contentsOf: manifest, encoding: .utf8)
        for target in ["First", "Second"] {
            XCTAssertTrue(updated.contains(".testTarget(name: \"\(target)Tests\""))
            let path = root.appendingPathComponent("Tests/\(target)Tests/Login/LoginViewModelTests.swift")
            XCTAssertTrue(FileManager.default.fileExists(atPath: path.path))
        }
    }

    func testRegularFileWithProjectExtensionIsIgnored() throws {
        try "notes".write(to: root.appendingPathComponent("Notes.xcodeproj"), atomically: true, encoding: .utf8)
        try command(target: "Demo App").run()
        XCTAssertEqual(try registeredPaths().sorted(), expectedPaths("Login").sorted())
    }

    func testSymlinkedProjectDirectoryIsDiscovered() throws {
        let actual = root.appendingPathComponent("ProjectBundle")
        try FileManager.default.moveItem(at: projectFile.deletingLastPathComponent(), to: actual)
        try FileManager.default.createSymbolicLink(at: projectFile.deletingLastPathComponent(), withDestinationURL: actual)
        try command(target: "Demo App").run()
        XCTAssertEqual(try registeredPaths().sorted(), expectedPaths("Login").sorted())
    }

    func testMalformedProjectDirectoryFailsBeforePublishingSources() throws {
        try "invalid project".write(to: projectFile, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try command(target: "Demo App").run()) { error in
            XCTAssertTrue((error as? ForgeError)?.message.contains("could not parse") == true)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Login").path))
    }

    func testPublicationConflictRollsBackEarlierSourcesAndPreservesDanglingSymlink() throws {
        let original = try Data(contentsOf: projectFile)
        let path = root.appendingPathComponent("Login/Presentation/LoginViewModel.swift")
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(atPath: path.path, withDestinationPath: "missing.swift")
        XCTAssertThrowsError(try command(target: "Demo App").run()) { error in
            XCTAssertTrue((error as? ForgeError)?.message.contains("Refusing to overwrite existing file") == true)
        }
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: path.path), "missing.swift")
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Login/LoginDependencyContainer.swift").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Login/Presentation/LoginView.swift").path))
        XCTAssertEqual(try Data(contentsOf: projectFile), original)
    }

    func testFailedProjectWriteRollsBackPublishedSources() throws {
        let original = try Data(contentsOf: projectFile)
        try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: projectFile.path)
        defer { try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: projectFile.path) }
        XCTAssertThrowsError(try command(target: "Demo App").run()) { error in
            XCTAssertTrue((error as? ForgeError)?.message.contains("Could not write") == true)
        }
        let feature = root.appendingPathComponent("Login")
        XCTAssertTrue(FileManager.default.fileExists(atPath: feature.path))
        let files = try XCTUnwrap(FileManager.default.enumerator(atPath: feature.path)).allObjects as? [String]
        XCTAssertEqual(files, ["Presentation"])
        XCTAssertEqual(try Data(contentsOf: projectFile), original)
    }

    func testRollbackPreservesReplacementAtPublishedPath() throws {
        let path = root.appendingPathComponent("Source.swift")
        let published = try PublishedFile.write("original", to: path)
        defer { published.removeStagingFile() }
        try FileManager.default.removeItem(at: path)
        try "replacement".write(to: path, atomically: true, encoding: .utf8)
        XCTAssertFalse(published.rollBack())
        XCTAssertEqual(try String(contentsOf: path, encoding: .utf8), "replacement")
    }

    private func registeredPaths() throws -> [String] {
        let data = try Data(contentsOf: projectFile)
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        let objects = try XCTUnwrap(plist["objects"] as? [String: [String: Any]])
        let files = try XCTUnwrap(objects["A00000000000000000000005"]?["files"] as? [String])
        XCTAssertEqual(objects["A00000000000000000000006"]?["files"] as? [String], [])
        return try files.map { id in
            let ref = try XCTUnwrap(objects[id]?["fileRef"] as? String)
            return try XCTUnwrap(objects[ref]?["path"] as? String)
        }
    }

    private func expectedPaths(_ name: String) -> [String] {
        [
            "\(name)/\(name)DependencyContainer.swift",
            "\(name)/Presentation/\(name)View.swift",
            "\(name)/Presentation/\(name)ViewModel.swift",
        ]
    }

    private func cliArguments(_ name: String, at root: URL) -> [String] {
        ["make", name, "-mvvm", "--path", root.path, "--xcode-target", "Demo App"]
    }

    private func runConcurrently(_ arguments: [[String]]) throws -> [(status: Int32, error: String)] {
        let binary = Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("forge")
        let completed = DispatchGroup()
        var jobs: [(Process, Pipe)] = []
        defer {
            for (process, _) in jobs where process.isRunning { process.terminate() }
        }
        for args in arguments {
            let process = Process()
            let stderr = Pipe()
            process.executableURL = binary
            process.arguments = args
            process.standardOutput = FileHandle.nullDevice
            process.standardError = stderr
            completed.enter()
            process.terminationHandler = { _ in completed.leave() }
            do {
                try process.run()
            } catch {
                completed.leave()
                throw error
            }
            jobs.append((process, stderr))
        }
        guard completed.wait(timeout: .now() + 15) == .success else {
            throw ForgeError.invalidArguments("Concurrent Forge commands timed out")
        }
        return jobs.map { process, stderr in
            (process.terminationStatus, String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self))
        }
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
