import Foundation
import XcodeProj

/// Plans target membership and dependency changes before Forge writes any feature files.
struct XcodeProjectIntegration {
    typealias BuildSettingsReader = (URL, String, String, String?) throws -> [String: String]

    struct Update {
        let targetName: String
        let testTargetName: String?
        let testModuleName: String?
        let projectFile: URL
        let original: Data
        let updated: Data?
        var changed: Bool { updated != nil }

        func apply() throws {
            guard try Data(contentsOf: projectFile) == original else {
                throw ForgeError.invalidArguments("project.pbxproj changed during generation. Retry with the current project.")
            }
            try updated?.write(to: projectFile, options: .atomic)
        }
    }

    private struct SynchronizedFolder {
        let group: PBXFileSystemSynchronizedRootGroup
        let logicalPath: String
        let path: String
        let targets: [PBXTarget]
    }

    private let project: URL
    private let projectFile: URL
    private let original: Data
    private let graph: PBXProj
    private let root: PBXProject
    private let mainGroup: PBXGroup
    private let app: PBXNativeTarget
    private let tests: PBXNativeTarget?
    private let sourceRoot: String
    private let sourcePrefix: String
    private let projectPrefix: String
    private let synchronizedFolders: [SynchronizedFolder]

    init(project: URL, target name: String?, testTarget testName: String?, generatesTests: Bool) throws {
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
        let tests = try generatesTests ? Self.selectTestTarget(in: root, app: target, name: testName) : nil
        let projectDirectory = project.deletingLastPathComponent().standardizedFileURL
        let sourceRoot = resolvedPath(projectDirectory)
        let projectPrefix = Self.directoryPrefix(projectDirectory.path)
        let sourcePrefix = Self.directoryPrefix(sourceRoot)
        let synchronizedFolders = try graph.fileSystemSynchronizedRootGroups.map { group in
            guard let folder = try? group.fullPath(sourceRoot: sourceRoot) else {
                throw ForgeError.invalidArguments("Forge could not resolve an Xcode synchronized folder.")
            }
            let targets = root.targets.filter { target in
                target.fileSystemSynchronizedGroups?.contains { $0 === group } == true
            }
            let url = URL(fileURLWithPath: folder).standardizedFileURL
            let logicalPath = Self.projectRelativeSpelling(url.path, projectPrefix: projectPrefix, sourcePrefix: sourcePrefix)
            return SynchronizedFolder(group: group, logicalPath: logicalPath, path: resolvedPath(url), targets: targets)
        }
        self.project = project
        self.projectFile = projectFile
        self.original = original
        self.graph = graph
        self.root = root
        self.mainGroup = mainGroup
        self.app = target
        self.tests = tests
        self.sourceRoot = sourceRoot
        self.sourcePrefix = sourcePrefix
        self.projectPrefix = projectPrefix
        self.synchronizedFolders = synchronizedFolders
    }

    private static func directoryPrefix(_ path: String) -> String {
        path.hasSuffix("/") ? path : path + "/"
    }

    // Normalize aliases of the project directory while preserving symlinks inside it for validation.
    private static func projectRelativeSpelling(_ path: String, projectPrefix: String, sourcePrefix: String) -> String {
        guard path.hasPrefix(projectPrefix) else { return path }
        return sourcePrefix + path.dropFirst(projectPrefix.count)
    }

    func outputDirectories(featureRoot: URL) throws -> (sources: URL, tests: URL) {
        let feature = featureRoot.lastPathComponent
        let sources = try synchronizedDirectory(for: app, feature: feature) ?? featureRoot
        let testDirectory = try tests.flatMap { try synchronizedDirectory(for: $0, feature: feature) }
        return (sources, testDirectory ?? featureRoot.appendingPathComponent("Tests", isDirectory: true))
    }

    private func synchronizedDirectory(for target: PBXTarget, feature: String) throws -> URL? {
        let folders = synchronizedFolders.filter { folder in folder.targets.contains { $0 === target } }
        guard folders.count <= 1 else {
            let paths = folders.map(\.path).sorted().joined(separator: ", ")
            throw ForgeError.invalidArguments("Multiple Xcode synchronized folders for target '\(target.name)': \(paths). Use --files-only and choose the destinations manually.")
        }
        return folders.first.map { URL(fileURLWithPath: $0.logicalPath, isDirectory: true).appendingPathComponent(feature, isDirectory: true) }
    }

    func plan(files: [URL], testFiles: [URL], factory: Bool, readBuildSettings: BuildSettingsReader, resolveBuildSettings: Bool = true) throws -> Update {
        guard let sources = try app.sourcesBuildPhase() else {
            throw ForgeError.invalidArguments("Xcode app target '\(app.name)' has no Sources build phase. Add a Compile Sources phase in Xcode or select a different target.")
        }
        let testSources = try tests?.sourcesBuildPhase()
        if let tests, testSources == nil || testSources === sources {
            throw ForgeError.invalidArguments("Xcode unit-test target '\(tests.name)' needs its own Sources build phase.")
        }
        var memberships = files.map { (file: $0, target: app, phase: sources) }
        if let tests, let testSources {
            memberships += testFiles.map { (file: $0, target: tests, phase: testSources) }
        }

        let paths = memberships.map { resolvedPath($0.file) }
        guard paths.allSatisfy({ $0.hasPrefix(sourcePrefix) }) else {
            throw ForgeError.invalidArguments("Xcode target output must stay inside the project directory.")
        }

        let names = Set(memberships.map { $0.file.lastPathComponent })
        var existingPaths = try Set(graph.fileReferences.compactMap { reference -> String? in
            guard let path = reference.path, names.contains((path as NSString).lastPathComponent),
                  let fullPath = try reference.fullPath(sourceRoot: sourceRoot) else { return nil }
            return resolvedPath(URL(fileURLWithPath: fullPath))
        })
        var changed = try factory ? linkFactory() : false
        for (path, membership) in zip(paths, memberships) {
            guard existingPaths.insert(path).inserted else {
                throw ForgeError.invalidArguments("The Xcode project already references '\(path)'.")
            }
            if try usesSynchronizedMembership(membership.file, resolved: path, target: membership.target) {
                continue
            }
            changed = true
            let reference = PBXFileReference(
                sourceTree: .sourceRoot,
                name: (path as NSString).lastPathComponent,
                lastKnownFileType: "sourcecode.swift",
                path: String(path.dropFirst(sourcePrefix.count))
            )
            let buildFile = PBXBuildFile(file: reference)
            graph.add(object: reference)
            graph.add(object: buildFile)
            mainGroup.children.append(reference)
            membership.phase.files = (membership.phase.files ?? []) + [buildFile]
        }

        let moduleName = try resolveBuildSettings ? tests.map {
            try Self.testModuleName(in: project, root: root, app: app, tests: $0, readBuildSettings: readBuildSettings)
        } : nil
        var updated: Data?
        if changed {
            guard let data = try graph.dataRepresentation() else {
                throw ForgeError.invalidArguments("Could not serialize the updated Xcode project.")
            }
            updated = data
        }
        return Update(targetName: app.name, testTargetName: tests?.name, testModuleName: moduleName,
                      projectFile: projectFile, original: original, updated: updated)
    }

    private func linkFactory() throws -> Bool {
        let productName = "Factory"
        let repository = "https://github.com/hmlongco/Factory.git"
        let identity = "github.com/hmlongco/factory"
        let packages = root.remotePackages.filter {
            $0.repositoryURL.map(Self.repositoryIdentity) == identity
        }
        guard packages.count <= 1 else {
            throw ForgeError.invalidArguments("Multiple Factory package references found. Keep one Factory package reference in Xcode and retry.")
        }
        let frameworks = app.buildPhases.compactMap { $0 as? PBXFrameworksBuildPhase }
        let dependencies = app.packageProductDependencies ?? []
        let declared = dependencies.filter { $0.productName == productName }
        let linked = frameworks.flatMap { $0.files ?? [] }.filter { $0.product?.productName == productName }
        let existingProduct = declared.first ?? linked.first?.product
        let existingPackage = packages.first
        guard declared.count <= 1, linked.count <= 1,
              linked.allSatisfy({ $0.product === existingProduct && $0.platformFilter == nil && ($0.platformFilters ?? []).isEmpty }),
              existingProduct == nil || (existingPackage != nil && existingProduct?.package === existingPackage),
              !root.remotePackages.contains(where: { $0.name?.lowercased() == "factory" && $0 !== existingPackage }),
              !root.localPackages.contains(where: { URL(fileURLWithPath: $0.relativePath).lastPathComponent.lowercased() == "factory" }) else {
            throw ForgeError.invalidArguments("Conflicting Factory dependency for Xcode target '\(app.name)'. Check the project's Factory package and the target's linked libraries in Xcode.")
        }
        if let requirement = existingPackage?.versionRequirement {
            let minimum: String?
            switch requirement {
            case let .upToNextMajorVersion(version), let .upToNextMinorVersion(version), let .exact(version),
                 let .range(version, _):
                minimum = version
            case .branch, .revision:
                minimum = nil
            }
            if let minimum, let major = minimum.split(separator: ".").first.flatMap({ Int($0) }), major >= 3 {
                throw ForgeError.invalidArguments("Forge's Xcode templates require the Factory product from Factory 2.x. The project's Factory requirement starts at \(minimum). Use native DI or choose a compatible Factory version in Xcode.")
            }
        }

        let package = existingPackage ?? XCRemoteSwiftPackageReference(
            repositoryURL: repository, versionRequirement: .upToNextMajorVersion("2.4.0")
        )
        if existingPackage == nil {
            graph.add(object: package)
            root.remotePackages.append(package)
        }
        let product = existingProduct ?? XCSwiftPackageProductDependency(productName: productName, package: package)
        if existingProduct == nil {
            graph.add(object: product)
        }
        if declared.isEmpty {
            app.packageProductDependencies = dependencies + [product]
        }
        if linked.isEmpty {
            let phase = frameworks.first ?? PBXFrameworksBuildPhase()
            if frameworks.isEmpty {
                graph.add(object: phase)
                app.buildPhases.append(phase)
            }
            let file = PBXBuildFile(product: product)
            graph.add(object: file)
            phase.files = (phase.files ?? []) + [file]
        }
        return declared.isEmpty || linked.isEmpty
    }

    private static func repositoryIdentity(_ repository: String) -> String {
        var path = repository.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        for prefix in ["https://", "http://", "ssh://git@", "git@"] where path.hasPrefix(prefix) {
            path.removeFirst(prefix.count)
            break
        }
        if path.hasPrefix("github.com:") {
            path = "github.com/" + path.dropFirst("github.com:".count)
        }
        if path.hasSuffix(".git") {
            path.removeLast(4)
        }
        return path
    }

    private func usesSynchronizedMembership(_ file: URL, resolved path: String, target: PBXTarget) throws -> Bool {
        // A symlink in an output subdirectory can send a generated file into or out of a synchronized folder.
        let logicalPath = Self.projectRelativeSpelling(
            file.standardizedFileURL.path, projectPrefix: projectPrefix, sourcePrefix: sourcePrefix
        )
        let folders = synchronizedFolders.filter {
            path.hasPrefix(Self.directoryPrefix($0.path)) || logicalPath.hasPrefix(Self.directoryPrefix($0.logicalPath))
        }
        guard let folder = folders.first else { return false }
        guard folders.count == 1,
              folder.targets.count == 1, folder.targets.first === target else {
            throw ForgeError.invalidArguments("The Xcode synchronized folder membership for '\(path)' does not belong exclusively to '\(target.name)'. Use separate synchronized folders for the app and tests.")
        }
        let folderPrefix = Self.directoryPrefix(folder.path)
        guard logicalPath == path, folder.logicalPath == folder.path, path.hasPrefix(folderPrefix) else {
            throw ForgeError.invalidArguments("The output path '\(file.path)' crosses a symlink in an Xcode synchronized folder. Choose a folder with a direct path.")
        }

        let relative = String(path.dropFirst(folderPrefix.count))
        func applies(_ paths: some Sequence<String>) -> Bool {
            paths.contains { candidate in
                let prefix = candidate.hasSuffix("/") ? candidate : candidate + "/"
                return relative.compare(candidate, options: .caseInsensitive) == .orderedSame
                    || relative.range(of: prefix, options: [.anchored, .caseInsensitive]) != nil
            }
        }
        let group = folder.group
        let affected = (group.exceptions ?? []).contains { exception in
            switch exception {
            case let target as PBXFileSystemSynchronizedBuildFileExceptionSet:
                return applies(target.membershipExceptions ?? [])
                    || applies((target.platformFiltersByRelativePath ?? [:]).keys)
            case let phase as PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet:
                return applies(phase.membershipExceptions ?? [])
            default:
                return true
            }
        }
        let nonSwiftPaths = (group.explicitFileTypes ?? [:]).filter { $0.value != "sourcecode.swift" }.keys
        guard !affected, !applies(group.explicitFolders ?? []), !applies(nonSwiftPaths) else {
            throw ForgeError.invalidArguments("An exception or file type override in the Xcode synchronized folder changes how '\(path)' is included. Review the folder settings in Xcode.")
        }
        return true
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

            var arguments = [
                "-project", project.path, "-target", target, "-configuration", configuration,
                "-skipPackageUpdates", "-showBuildSettings", "-json",
            ]
            if let sdk { arguments += ["-sdk", sdk] }

            func query(allowsPackageResolution: Bool) throws -> (status: Int32, diagnostic: String) {
                for handle in [output, errors] {
                    try handle.truncate(atOffset: 0)
                    try handle.seek(toOffset: 0)
                }
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
                process.currentDirectoryURL = project.deletingLastPathComponent()
                process.arguments = arguments + (allowsPackageResolution ? [] : ["-disableAutomaticPackageResolution"])
                process.standardInput = FileHandle.nullDevice
                process.standardOutput = output
                process.standardError = errors
                let finished = DispatchSemaphore(value: 0)
                process.terminationHandler = { _ in finished.signal() }
                try process.run()
                guard finished.wait(timeout: .now() + (allowsPackageResolution ? 120 : 60)) == .success else {
                    if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                    throw ForgeError.invalidArguments("xcodebuild timed out while reading build settings for \(context).")
                }
                let diagnostic = try String(contentsOf: stderr, encoding: .utf8)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return (process.terminationStatus, diagnostic)
            }

            var result = try query(allowsPackageResolution: false)
            // A previous Forge run may have added Factory before Xcode has resolved it.
            if result.status != 0,
               result.diagnostic.contains("automatic dependency resolution is disabled"),
               result.diagnostic.range(of: #"dependencies were added:[^\n]*'factory'\s*\("#, options: .regularExpression) != nil {
                result = try query(allowsPackageResolution: true)
            }
            guard result.status == 0 else {
                let detail = result.diagnostic.isEmpty ? "Exit status \(result.status)." : String(result.diagnostic.suffix(2000))
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
