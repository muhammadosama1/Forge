import Foundation

/// Outcome of a feature generation run.
struct GenerationResult {
    /// Created/updated file paths, or planned paths when dryRun is enabled.
    let createdFiles: [URL]
    /// Configured or discovered Xcode project, if any.
    let detectedXcodeProject: URL?
    /// If `--package` was used, the URL of the created Swift package directory.
    let createdSwiftPackage: URL?
    /// The `--target` value supplied by the user, if any.
    let detectedSwiftPackageTarget: String?
    let registeredXcodeTarget: String?
    let registeredXcodeTestTarget: String?
}

/// Orchestrates rendering and writing of feature files to disk.
struct FeatureGenerator {
    /// Project discovery directory and default output root.
    let projectPath: URL
    let xcodeProject: URL?
    let featureDirectory: URL?
    /// Whether to create a `Package.swift` alongside the feature.
    let shouldCreatePackage: Bool
    /// Optional explicit Swift package target name.
    let packageTarget: String?
    let xcodeTarget: String?
    let xcodeTestTarget: String?
    let filesOnly: Bool
    let dryRun: Bool
    let templateDirectory: URL?
    /// Whether to generate test files.
    let shouldGenerateTests: Bool
    /// When `true`, Domain layer files (Entity, UseCase, Repository protocol) are skipped.
    let shouldSkipDomain: Bool
    /// The concrete architecture pattern to generate.
    let type: FeatureType
    /// Optional UI pattern category (form, list).
    let category: FeatureCategory?
    /// Reactive state-binding mechanism (Combine or Swift Concurrency).
    let binding: BindingStrategy
    /// Unit testing framework (XCTest or Swift Testing).
    let testing: TestFramework
    /// Dependency injection strategy (Native or Factory).
    let di: DependencyInjectionStrategy

    init(
        projectPath: URL,
        shouldCreatePackage: Bool,
        packageTarget: String?,
        xcodeTarget: String? = nil,
        xcodeTestTarget: String? = nil,
        xcodeProject: URL? = nil,
        featureDirectory: URL? = nil,
        filesOnly: Bool = false,
        dryRun: Bool = false,
        shouldGenerateTests: Bool,
        shouldSkipDomain: Bool,
        type: FeatureType,
        category: FeatureCategory?,
        binding: BindingStrategy = .combine,
        testing: TestFramework = .xctest,
        di: DependencyInjectionStrategy = .native,
        templateDirectory: URL? = nil
    ) {
        self.projectPath = projectPath
        self.xcodeProject = xcodeProject
        self.featureDirectory = featureDirectory
        self.shouldCreatePackage = shouldCreatePackage
        self.packageTarget = packageTarget
        self.xcodeTarget = xcodeTarget
        self.xcodeTestTarget = xcodeTestTarget
        self.filesOnly = filesOnly
        self.dryRun = dryRun
        self.templateDirectory = templateDirectory
        self.shouldGenerateTests = shouldGenerateTests
        self.shouldSkipDomain = shouldSkipDomain
        self.type = type
        self.category = category
        self.binding = binding
        self.testing = testing
        self.di = di
    }

    /// Renders all template files for the given feature and writes them to disk.
    /// Refuses existing files (throws `ForgeError.fileAlreadyExists`). Dry runs only plan and validate.
    /// - Parameter feature: Validated feature name.
    /// - Parameter selection: Controls which file roles to include.
    /// - Returns: A result with paths, detected Xcode project, and package info.
    func generate(
        feature: FeatureName,
        selection: FeatureFileSelection,
        readXcodeBuildSettings: XcodeProjectIntegration.BuildSettingsReader = XcodeProjectIntegration.readBuildSettings
    ) throws -> GenerationResult {
        if let packageTarget {
            try PackageTargetName.validate(packageTarget)
        }

        let packageOutput = shouldCreatePackage || packageTarget != nil
        let configuredProject = packageOutput || filesOnly ? nil : xcodeProject
        let xcodeProjects: [URL]
        if let configuredProject {
            var isDirectory: ObjCBool = false
            guard configuredProject.pathExtension == "xcodeproj",
                  FileManager.default.fileExists(atPath: configuredProject.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                throw ForgeError.invalidArguments("The 'paths.xcode_project' setting must point to an existing .xcodeproj directory. Check '\(configuredProject.path)'.")
            }
            xcodeProjects = [configuredProject]
        } else {
            xcodeProjects = findXcodeProjects(in: projectPath)
        }
        let integratesXcode = !filesOnly && (xcodeTarget != nil || xcodeTestTarget != nil || (!packageOutput && !xcodeProjects.isEmpty))
        if integratesXcode {
            try Self.validateXcodeOptions(package: packageOutput)
            guard !xcodeProjects.isEmpty else {
                throw ForgeError.invalidArguments("No .xcodeproj found in '\(projectPath.path)'. Set paths.xcode_project or point --path or paths.root at the directory containing your Xcode project.")
            }
            guard xcodeProjects.count == 1 else {
                let names = xcodeProjects.map(\.lastPathComponent).joined(separator: ", ")
                throw ForgeError.invalidArguments("Multiple Xcode projects found in '\(projectPath.path)': \(names). Select one with paths.xcode_project.")
            }
        }
        let xcodeProject    = xcodeProjects.first
        let headerContext   = FileHeaderContext(projectPath: projectPath, xcodeProject: xcodeProject)
        let outputDirectory = packageOutput ? projectPath : featureDirectory ?? projectPath
        let featureRoot     = outputDirectory.appendingPathComponent(feature.folderName, isDirectory: true)
        let targetName      = packageTarget ?? feature.typeName
        let testSpecs = shouldGenerateTests
            ? type.testTemplateSpecs.filter { !shouldSkipDomain || !$0.file.isDomainTest } : []

        let integratedProject = integratesXcode ? xcodeProject : nil
        let lockResource: URL
        if let integratedProject {
            lockResource = integratedProject.appendingPathComponent("project.pbxproj")
        } else if !shouldCreatePackage, packageTarget != nil {
            lockResource = projectPath.appendingPathComponent("Package.swift")
        } else {
            lockResource = outputDirectory
        }
        let lock = try dryRun ? nil : GenerationLock.acquire(for: lockResource)
        defer { if let lock { GenerationLock.release(lock) } }

        let xcodeIntegration = try integratedProject.map {
            try XcodeProjectIntegration(project: $0, target: xcodeTarget, testTarget: xcodeTestTarget,
                                        generatesTests: !testSpecs.isEmpty)
        }
        let sourcesRoot: URL
        let testsRoot: URL

        // Determine output directory structure based on packaging options
        if shouldCreatePackage {
            // Standalone Swift Package: places code under Feature/Sources/<Target> and Feature/Tests/<Target>Tests
            sourcesRoot = featureRoot
                .appendingPathComponent("Sources", isDirectory: true)
                .appendingPathComponent(targetName, isDirectory: true)
            testsRoot = featureRoot
                .appendingPathComponent("Tests", isDirectory: true)
                .appendingPathComponent("\(targetName)Tests", isDirectory: true)
        } else if let packageTarget {
            // Existing Swift package targets use SwiftPM's default Sources/<Target> layout.
            let sourcesDir = projectPath.appendingPathComponent("Sources", isDirectory: true)
            let targetSourcesDir = sourcesDir.appendingPathComponent(packageTarget, isDirectory: true)
            sourcesRoot = targetSourcesDir.appendingPathComponent(feature.folderName, isDirectory: true)

            let testsDir = projectPath.appendingPathComponent("Tests", isDirectory: true)
            let targetTestsDir = testsDir.appendingPathComponent("\(packageTarget)Tests", isDirectory: true)
            testsRoot = targetTestsDir.appendingPathComponent(feature.folderName, isDirectory: true)
        } else if let xcodeIntegration {
            (sourcesRoot, testsRoot) = try xcodeIntegration.outputDirectories(
                featureRoot: featureRoot, usesConfiguredFeatureDirectory: featureDirectory != nil
            )
        } else {
            // Standard Xcode directory: places code under Feature/ and tests under Feature/Tests
            sourcesRoot = featureRoot
            testsRoot = featureRoot.appendingPathComponent("Tests", isDirectory: true)
        }

        // Filter out Domain-layer files when --no-domain flag is used
        let activeSelection: FeatureFileSelection
        if shouldSkipDomain {
            activeSelection = FeatureFileSelection(including: selection.includedFiles.filter { !$0.isDomain })
        } else {
            activeSelection = selection
        }

        // Build the shared template context map — reused for every file in this generation run
        var sharedContext = activeSelection.contextMap
        sharedContext["name"] = feature.typeName
        sharedContext["propertyName"] = feature.propertyName
        // SwiftPM replaces hyphens in target names when forming Swift module names.
        sharedContext["moduleName"] = targetName.replacingOccurrences(of: "-", with: "_")
        sharedContext["isClean"] = type.hasCleanLayers
        sharedContext["isPackage"] = packageOutput
        for architecture in PresentationArchitecture.allCases {
            sharedContext["is\(architecture.rawValue.uppercased())"] =
                type == FeatureType.resolve(presentation: architecture, clean: type.hasCleanLayers)
        }
        if shouldSkipDomain {
            sharedContext["hasNoDomain"] = true
        }
        if binding == .concurrency {
            sharedContext["isConcurrency"] = true
        }
        if testing == .swiftTesting {
            sharedContext["isSwiftTesting"] = true
        }
        if di == .factory {
            sharedContext["isFactory"] = true
        }
        if let category {
            switch category {
            case .form:  sharedContext["isForm"] = true
            case .list:  sharedContext["isList"] = true
            }
        }

        // Render all specs that belong to the active selection (header + body)
        var files: [GeneratedFile] = try type.templateSpecs(for: category)
            .filter { activeSelection.contains($0.file) }
            .map { spec in
                let header  = try Templates.fileHeader(
                    fileName: spec.file.fileName(for: feature.typeName),
                    context: headerContext, overrides: templateDirectory
                )
                let body    = try TemplateRenderer.render("\(spec.templateName).stencil", context: sharedContext, overrides: templateDirectory)
                let layer   = spec.file.layer(for: type)
                // "Root" files (like DependencyContainer) sit directly in sourcesRoot, others inside layer folder
                let directory = layer == "Root"
                    ? sourcesRoot
                    : sourcesRoot.appendingPathComponent(layer, isDirectory: true)
                return GeneratedFile(
                    url: directory.appendingPathComponent(spec.file.fileName(for: feature.typeName)),
                    content: header + body
                )
            }

        // Optionally generate Package.swift if --package was specified
        var createdSwiftPackage: URL?
        if shouldCreatePackage {
            let packageContent = try TemplateRenderer.render("swiftPackage.stencil", context: [
                "name": targetName,
                "hasTests": shouldGenerateTests,
                "isConcurrency": binding == .concurrency,
                "isSwiftTesting": testing == .swiftTesting,
                "isFactory": di == .factory,
            ], overrides: templateDirectory)
            let packageUrl = featureRoot.appendingPathComponent("Package.swift")
            files.append(GeneratedFile(url: packageUrl, content: packageContent))
            createdSwiftPackage = featureRoot
        }

        let testURLs = testSpecs.map { testsRoot.appendingPathComponent($0.file.fileName(for: feature.typeName)) }

        // Check both destination files and the folders they need before writing anything.
        var checkedDirectories: Set<String> = []
        for url in files.map(\.url) + testURLs {
            if FileManager.default.fileExists(atPath: url.path) {
                throw ForgeError.fileAlreadyExists(url.path)
            }
            var parent = (url.path as NSString).deletingLastPathComponent
            while !parent.isEmpty, parent != "/", checkedDirectories.insert(parent).inserted {
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: parent, isDirectory: &isDirectory) {
                    guard isDirectory.boolValue else {
                        throw ForgeError.invalidArguments("Cannot generate '\(url.lastPathComponent)' because '\(parent)' is a file. Move it or choose a different output path.")
                    }
                    break
                }
                parent = (parent as NSString).deletingLastPathComponent
            }
        }

        // Validate every selected override before Xcode may resolve dependencies while
        // reading build settings. The actual app module is substituted after planning.
        for (spec, url) in zip(testSpecs, testURLs) {
            _ = try Templates.fileHeader(fileName: url.lastPathComponent, context: headerContext, overrides: templateDirectory)
            _ = try TemplateRenderer.render("\(spec.templateName).stencil", context: sharedContext, overrides: templateDirectory)
        }

        let packageUpdate: SwiftPackageIntegration.Update?
        if !shouldCreatePackage, let packageTarget {
            packageUpdate = try SwiftPackageIntegration.plan(
                at: projectPath, target: packageTarget, tests: shouldGenerateTests, factory: di == .factory
            )
        } else {
            packageUpdate = nil
        }

        let xcodeUpdate = try xcodeIntegration?.plan(
            files: files.map(\.url), testFiles: testURLs, factory: di == .factory,
            readBuildSettings: readXcodeBuildSettings, resolveBuildSettings: !dryRun
        )

        if let moduleName = xcodeUpdate?.testModuleName {
            sharedContext["moduleName"] = moduleName
        }
        for (spec, url) in zip(testSpecs, testURLs) {
            let header = try Templates.fileHeader(fileName: url.lastPathComponent, context: headerContext, overrides: templateDirectory)
            let body = try TemplateRenderer.render("\(spec.templateName).stencil", context: sharedContext, overrides: templateDirectory)
            files.append(GeneratedFile(url: url, content: header + body))
        }

        if dryRun {
            return GenerationResult(
                createdFiles: files.map(\.url) + (packageUpdate?.changed == true ? [packageUpdate!.manifestURL] : [])
                    + (xcodeUpdate.flatMap { $0.changed ? [$0.projectFile] : nil } ?? []),
                detectedXcodeProject: xcodeProject, createdSwiftPackage: createdSwiftPackage,
                detectedSwiftPackageTarget: packageTarget, registeredXcodeTarget: xcodeUpdate?.targetName,
                registeredXcodeTestTarget: xcodeUpdate?.testTargetName)
        }

        var written: [PublishedFile] = []
        defer {
            for file in written { file.removeStagingFile() }
        }
        var destination = projectPath
        do {
            for file in files {
                destination = file.url
                try FileManager.default.createDirectory(
                    at: file.url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                written.append(try PublishedFile.write(file.content, to: file.url))
            }
            if let packageUpdate, packageUpdate.changed {
                destination = packageUpdate.manifestURL
                guard try String(contentsOf: packageUpdate.manifestURL, encoding: .utf8) == packageUpdate.original else {
                    throw ForgeError.invalidArguments("Package.swift changed during generation; no manifest update was made.")
                }
                try packageUpdate.updated.write(to: packageUpdate.manifestURL, atomically: true, encoding: .utf8)
            }
            if let xcodeUpdate {
                destination = xcodeUpdate.projectFile
                try xcodeUpdate.apply()
            }
        } catch {
            let leftovers = written.reversed().filter { !$0.rollBack() }
            let message = (error as? ForgeError)?.message ?? "Could not write '\(destination.path)': \(error.localizedDescription)"
            if !leftovers.isEmpty {
                let paths = leftovers.map(\.url.path).joined(separator: ", ")
                throw ForgeError.invalidArguments("\(message) These output paths remain after rollback: \(paths). Review them before retrying.")
            }
            if let error = error as? ForgeError { throw error }
            throw ForgeError.invalidArguments(message)
        }

        return GenerationResult(
            createdFiles: files.map(\.url) + (packageUpdate?.changed == true ? [packageUpdate!.manifestURL] : [])
                + (xcodeUpdate.flatMap { $0.changed ? [$0.projectFile] : nil } ?? []),
            detectedXcodeProject: xcodeProject,
            createdSwiftPackage: createdSwiftPackage,
            detectedSwiftPackageTarget: packageTarget,
            registeredXcodeTarget: xcodeUpdate?.targetName,
            registeredXcodeTestTarget: xcodeUpdate?.testTargetName
        )
    }

    // MARK: - Helpers

    static func validateXcodeOptions(package: Bool) throws {
        if package {
            throw ForgeError.invalidArguments("Xcode app target integration cannot be combined with Swift package output. Choose either --xcode-target or Swift package options (--package or --target). Check paths.package and paths.target if these came from .forge.yml.")
        }
    }

    private func findXcodeProjects(in root: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: root.resolvingSymlinksInPath(),
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ))?.filter { candidate in
            guard candidate.pathExtension == "xcodeproj" else { return false }
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory)
                && isDirectory.boolValue
        }.sorted { $0.path < $1.path } ?? []
    }
}
