import Foundation
import XcodeProj

/// Plans source membership changes before Forge writes any feature files.
enum XcodeProjectIntegration {
    typealias BuildSettingsReader = (URL, String, String, String?) throws -> [String: String]

    struct Update {
        let targetName: String
        let testTargetName: String?
        let testModuleName: String?
        let projectFile: URL
        let original: Data
        let updated: Data

        func apply() throws {
            guard try Data(contentsOf: projectFile) == original else {
                throw ForgeError.invalidArguments("project.pbxproj changed during generation. Retry with the current project.")
            }
            try updated.write(to: projectFile, options: .atomic)
        }
    }

    static func plan(
        project: URL,
        target name: String?,
        files: [URL],
        testTarget testName: String? = nil,
        testFiles: [URL] = [],
        readBuildSettings: BuildSettingsReader = readBuildSettings
    ) throws -> Update {
        let projectFile = project.appendingPathComponent("project.pbxproj").resolvingSymlinksInPath()
        let original: Data
        do {
            original = try Data(contentsOf: projectFile)
        } catch {
            throw ForgeError.invalidArguments("Could not read '\(projectFile.path)': \(error.localizedDescription). Check that this is a complete, readable Xcode project.")
        }
        let graph: PBXProj
        do {
            graph = try PBXProj(data: original)
        } catch {
            throw ForgeError.invalidArguments("Forge could not parse '\(projectFile.path)'. Check that Xcode can open the project and resolve any merge conflicts in project.pbxproj.")
        }
        guard let root = try graph.rootProject(), let mainGroup = try graph.rootGroup(),
              root.projectDirPath.isEmpty else {
            throw ForgeError.invalidArguments("The Xcode project must use its containing directory as the source root.")
        }
        let appTargets = root.targets.compactMap { $0 as? PBXNativeTarget }.filter { $0.productType == .application }
        let available = appTargets.map(\.name).sorted().map { "'\($0)'" }.joined(separator: ", ")
        let matches = name.map { name in appTargets.filter { $0.name == name } } ?? appTargets
        guard let target = matches.first else {
            let hint = available.isEmpty ? "This project has no app targets." : "Choose an app target from: \(available)."
            let requested = name.map { " named '\($0)'" } ?? ""
            throw ForgeError.invalidArguments("No Xcode app target\(requested) in '\(project.lastPathComponent)'. \(hint) Use --files-only to generate without editing the project.")
        }
        guard matches.count == 1 else {
            if let name {
                throw ForgeError.invalidArguments("More than one Xcode app target is named '\(name)' in '\(project.lastPathComponent)'. Give the targets unique names in Xcode before retrying.")
            }
            throw ForgeError.invalidArguments("Multiple app targets found in '\(project.lastPathComponent)': \(available). Choose one with --xcode-target or set paths.xcode_target in .forge.yml.")
        }
        guard let sources = try target.sourcesBuildPhase() else {
            throw ForgeError.invalidArguments("Xcode app target '\(target.name)' has no Sources build phase. Add a Compile Sources phase in Xcode or select a different target.")
        }

        let testTarget = try testFiles.isEmpty ? nil : selectTestTarget(in: root, app: target, name: testName)
        let testSources = try testTarget?.sourcesBuildPhase()
        if let testTarget, testSources == nil || testSources === sources {
            throw ForgeError.invalidArguments("Xcode unit-test target '\(testTarget.name)' needs its own Sources build phase.")
        }

        let sourceRoot = resolvedPath(project.deletingLastPathComponent())
        var memberships = files.map { (file: $0, phase: sources) }
        if let testSources {
            memberships += testFiles.map { (file: $0, phase: testSources) }
        }
        let paths = memberships.map { resolvedPath($0.file) }
        let prefix = sourceRoot == "/" ? "/" : sourceRoot + "/"
        guard paths.allSatisfy({ $0.hasPrefix(prefix) }) else {
            throw ForgeError.invalidArguments("Xcode target output must stay inside the project directory.")
        }
        for group in graph.fileSystemSynchronizedRootGroups {
            guard let folder = try group.fullPath(sourceRoot: sourceRoot) else {
                throw ForgeError.invalidArguments("Forge could not resolve an Xcode synchronized folder.")
            }
            let folderPath = resolvedPath(URL(fileURLWithPath: folder))
            let folderPrefix = folderPath == "/" ? "/" : folderPath + "/"
            if paths.contains(where: { $0.hasPrefix(folderPrefix) }) {
                throw ForgeError.invalidArguments("Feature output overlaps the Xcode synchronized folder '\(folderPath)'. Generate outside that folder or use --files-only if Xcode already manages membership there.")
            }
        }

        let names = Set(memberships.map { $0.file.lastPathComponent })
        var existingPaths = try Set(graph.fileReferences.compactMap { reference -> String? in
            guard let path = reference.path, names.contains((path as NSString).lastPathComponent),
                  let fullPath = try reference.fullPath(sourceRoot: sourceRoot) else { return nil }
            return resolvedPath(URL(fileURLWithPath: fullPath))
        })
        for (path, membership) in zip(paths, memberships) {
            guard existingPaths.insert(path).inserted else {
                throw ForgeError.invalidArguments("The Xcode project already references '\(path)'.")
            }
            let reference = PBXFileReference(
                sourceTree: .sourceRoot,
                name: (path as NSString).lastPathComponent,
                lastKnownFileType: "sourcecode.swift",
                path: String(path.dropFirst(prefix.count))
            )
            let buildFile = PBXBuildFile(file: reference)
            graph.add(object: reference)
            graph.add(object: buildFile)
            mainGroup.children.append(reference)
            membership.phase.files = (membership.phase.files ?? []) + [buildFile]
        }

        let moduleName = try testTarget.map {
            try testModuleName(in: project, root: root, app: target, tests: $0, readBuildSettings: readBuildSettings)
        }
        guard let updated = try graph.dataRepresentation() else {
            throw ForgeError.invalidArguments("Could not serialize the updated Xcode project.")
        }
        return Update(targetName: target.name, testTargetName: testTarget?.name, testModuleName: moduleName,
                      projectFile: projectFile, original: original, updated: updated)
    }

    private static func selectTestTarget(in project: PBXProject, app: PBXNativeTarget, name: String?) throws -> PBXNativeTarget {
        let unitTests = project.targets.compactMap { $0 as? PBXNativeTarget }.filter { $0.productType == .unitTestBundle }
        let attributes = project.targetAttributes

        func appIDs(for target: PBXNativeTarget) -> Set<String> {
            if let host = attributes[target]?["TestTargetID"]?.stringValue {
                return [host]
            }
            return Set(target.dependencies.compactMap { dependency in
                guard let app = dependency.target as? PBXNativeTarget, app.productType == .application else { return nil }
                return app.uuid
            })
        }

        if let name {
            guard project.targets.filter({ $0.name == name }).count == 1,
                  let target = unitTests.first(where: { $0.name == name }) else {
                throw ForgeError.invalidArguments("Expected one Xcode unit-test target named '\(name)'. Select an existing unit-test target for '\(app.name)'.")
            }
            let hosts = appIDs(for: target)
            guard hosts.isEmpty || hosts.contains(app.uuid) else {
                throw ForgeError.invalidArguments("Xcode unit-test target '\(name)' is associated with a different app. Select a test target hosted by '\(app.name)'.")
            }
            return target
        }

        let matches = unitTests.filter { appIDs(for: $0) == [app.uuid] }
        guard let target = matches.first else {
            throw ForgeError.invalidArguments("No Xcode unit-test target matches '\(app.name)'. Add an app-hosted unit-test target in Xcode or select an existing one with --xcode-test-target or paths.xcode_test_target.")
        }
        guard matches.count == 1, project.targets.filter({ $0.name == target.name }).count == 1 else {
            let names = matches.map(\.name).sorted().map { "'\($0)'" }.joined(separator: ", ")
            throw ForgeError.invalidArguments("Xcode unit-test target selection is ambiguous for '\(app.name)': \(names). Use unique target names and select one with --xcode-test-target or paths.xcode_test_target.")
        }
        return target
    }

    private static func testModuleName(
        in project: URL, root: PBXProject, app: PBXNativeTarget, tests: PBXNativeTarget,
        readBuildSettings: BuildSettingsReader
    ) throws -> String {
        let appConfigurations = Set(app.buildConfigurationList?.buildConfigurations.map(\.name) ?? [])
        let shared = appConfigurations.intersection(tests.buildConfigurationList?.buildConfigurations.map(\.name) ?? [])
        let configuration = (["Debug", root.buildConfigurationList?.defaultConfigurationName].compactMap { $0 })
            .first(where: shared.contains) ?? (shared.count == 1 ? shared.first : nil)
        guard let configuration else {
            throw ForgeError.invalidArguments("Forge could not choose a shared build configuration for '\(app.name)' and '\(tests.name)'. Configure a shared Debug or project default configuration in Xcode.")
        }
        guard root.targets.filter({ $0.name == app.name }).count == 1 else {
            throw ForgeError.invalidArguments("Give Xcode app target '\(app.name)' a unique name before resolving its build settings.")
        }

        var appSettings = try readBuildSettings(project, app.name, configuration, nil)
        var sdk = appSettings["PLATFORM_NAME"].flatMap { $0.isEmpty ? nil : $0 }
        // Target-only queries can leave SDKROOT=auto unresolved. Use the same SDK for both targets.
        if sdk == nil, let platform = appSettings["SUPPORTED_PLATFORMS"]?.split(whereSeparator: \.isWhitespace).first {
            sdk = String(platform)
            appSettings = try readBuildSettings(project, app.name, configuration, sdk)
        }
        guard let module = appSettings["PRODUCT_MODULE_NAME"],
              module.range(of: #"\A[\p{L}_][\p{L}\p{M}\p{N}_]*\z"#, options: .regularExpression) != nil,
              module != "_", let buildDirectory = appSettings["TARGET_BUILD_DIR"], !buildDirectory.isEmpty,
              let executable = appSettings["EXECUTABLE_PATH"], !executable.isEmpty else {
            throw ForgeError.invalidArguments("Xcode app target '\(app.name)' (\(configuration)) needs a valid PRODUCT_MODULE_NAME and resolved executable path.")
        }
        guard appSettings["ENABLE_TESTABILITY"] == "YES" else {
            throw ForgeError.invalidArguments("Enable Testability for Xcode app target '\(app.name)' (\(configuration)) to generate @testable imports.")
        }

        let expectedHost = URL(fileURLWithPath: buildDirectory, isDirectory: true).appendingPathComponent(executable)
        let testSettings = try readBuildSettings(project, tests.name, configuration, sdk)
        guard let host = testSettings["TEST_HOST"], (host as NSString).isAbsolutePath,
              resolvedPath(URL(fileURLWithPath: host)) == resolvedPath(expectedHost) else {
            throw ForgeError.invalidArguments("Xcode unit-test target '\(tests.name)' (\(configuration)) must use '\(app.name)' as its Test Host. Check TEST_HOST in Xcode or select another unit-test target.")
        }
        return PackageTargetName.reservedNames.contains(module) ? "`\(module)`" : module
    }

    static func readBuildSettings(project: URL, target: String, configuration: String, sdk: String?) throws -> [String: String] {
        let context = "Xcode target '\(target)' (\(configuration))"
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: false)
            defer { try? FileManager.default.removeItem(at: temp) }
            let stdout = temp.appendingPathComponent("stdout")
            let stderr = temp.appendingPathComponent("stderr")
            try Data().write(to: stdout)
            try Data().write(to: stderr)
            let output = try FileHandle(forWritingTo: stdout)
            defer { try? output.close() }
            let errors = try FileHandle(forWritingTo: stderr)
            defer { try? errors.close() }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
            process.currentDirectoryURL = project.deletingLastPathComponent()
            var arguments = [
                "-project", project.path, "-target", target, "-configuration", configuration,
                "-disableAutomaticPackageResolution", "-skipPackageUpdates", "-showBuildSettings", "-json",
            ]
            if let sdk { arguments += ["-sdk", sdk] }
            process.arguments = arguments
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = output
            process.standardError = errors
            let finished = DispatchSemaphore(value: 0)
            process.terminationHandler = { _ in finished.signal() }
            try process.run()
            guard finished.wait(timeout: .now() + 60) == .success else {
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                throw ForgeError.invalidArguments("xcodebuild timed out while reading build settings for \(context).")
            }
            guard process.terminationStatus == 0 else {
                let diagnostic = try String(contentsOf: stderr, encoding: .utf8)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let detail = diagnostic.isEmpty ? "Exit status \(process.terminationStatus)." : String(diagnostic.suffix(2000))
                throw ForgeError.invalidArguments("Could not resolve build settings for \(context). Select a full Xcode installation and resolve project dependencies in Xcode. \(detail)")
            }
            return try decodeBuildSettings(Data(contentsOf: stdout), target: target, context: context)
        } catch let error as ForgeError {
            throw error
        } catch {
            throw ForgeError.invalidArguments("Could not read build settings for \(context) using xcodebuild: \(error.localizedDescription)")
        }
    }

    static func decodeBuildSettings(_ data: Data, target: String, context: String? = nil) throws -> [String: String] {
        struct Entry: Decodable {
            let target: String?
            let buildSettings: [String: String]?
        }
        let matching = try JSONDecoder().decode([Entry].self, from: data).filter { $0.target == target }
        guard matching.count == 1, let settings = matching.first?.buildSettings else {
            throw ForgeError.invalidArguments("Expected one set of xcodebuild settings for \(context ?? "target '\(target)'").")
        }
        return settings
    }
}
