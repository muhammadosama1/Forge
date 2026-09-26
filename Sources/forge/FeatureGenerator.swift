import Foundation

/// Outcome of a feature generation run.
struct GenerationResult {
    /// Absolute paths of every file that was written to disk.
    let createdFiles: [URL]
    /// An `.xcodeproj` found under the project root, if any.
    let detectedXcodeProject: URL?
    /// If `--package` was used, the URL of the created Swift package directory.
    let createdSwiftPackage: URL?
    /// The `--target` value supplied by the user, if any.
    let detectedSwiftPackageTarget: String?
}

/// Orchestrates rendering and writing of feature files to disk.
struct FeatureGenerator {
    /// Root directory for the generated feature.
    let projectPath: URL
    /// Whether to create a `Package.swift` alongside the feature.
    let shouldCreatePackage: Bool
    /// Optional explicit Swift package target name.
    let packageTarget: String?
    /// Whether to generate test files.
    let shouldGenerateTests: Bool
    /// When `true`, Domain layer files (Entity, UseCase, Repository protocol) are skipped.
    let shouldSkipDomain: Bool
    /// The concrete architecture pattern to generate.
    let type: FeatureType
    /// Optional UI pattern category (form, list).
    let category: FeatureCategory?

    /// Renders all template files for the given feature and writes them to disk.
    /// Skips existing files (throws `ForgeError.fileAlreadyExists`).
    /// - Parameter feature: Validated feature name.
    /// - Parameter selection: Controls which file roles to include.
    /// - Returns: A result with paths, detected Xcode project, and package info.
    func generate(feature: FeatureName, selection: FeatureFileSelection) throws -> GenerationResult {
        // Inspect target directory for an existing .xcodeproj for contextual file headers
        let xcodeProject    = findXcodeProject(in: projectPath)
        let headerContext   = FileHeaderContext(projectPath: projectPath, xcodeProject: xcodeProject)
        let featureRoot     = projectPath.appendingPathComponent(feature.folderName, isDirectory: true)
        let targetName      = packageTarget ?? feature.typeName
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
            // Existing multi-target package: check for root Sources/ directory or place directly under target
            let sourcesDir = projectPath.appendingPathComponent("Sources", isDirectory: true)
            let targetSourcesDir = FileManager.default.fileExists(atPath: sourcesDir.path)
                ? sourcesDir.appendingPathComponent(packageTarget, isDirectory: true)
                : projectPath.appendingPathComponent(packageTarget, isDirectory: true)
            sourcesRoot = targetSourcesDir.appendingPathComponent(feature.folderName, isDirectory: true)

            let testsDir = projectPath.appendingPathComponent("Tests", isDirectory: true)
            let targetTestsDir = testsDir.appendingPathComponent("\(packageTarget)Tests", isDirectory: true)
            testsRoot = targetTestsDir.appendingPathComponent(feature.folderName, isDirectory: true)
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
        // SwiftPM replaces hyphens in target names when forming Swift module names.
        sharedContext["moduleName"] = targetName.replacingOccurrences(of: "-", with: "_")
        sharedContext["isClean"] = type.hasCleanLayers
        for architecture in PresentationArchitecture.allCases {
            sharedContext["is\(architecture.rawValue.uppercased())"] =
                type == FeatureType.resolve(presentation: architecture, clean: type.hasCleanLayers)
        }
        if shouldSkipDomain {
            sharedContext["hasNoDomain"] = true
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
                    context: headerContext
                )
                let body    = try TemplateRenderer.render("\(spec.templateName).stencil", context: sharedContext)
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
            ])
            let packageUrl = featureRoot.appendingPathComponent("Package.swift")
            files.append(GeneratedFile(url: packageUrl, content: packageContent))
            createdSwiftPackage = featureRoot
        }

        // Optionally generate unit test files if --tests was specified
        if shouldGenerateTests {
            for spec in type.testTemplateSpecs where !shouldSkipDomain || !spec.file.isDomainTest {
                let header = try Templates.fileHeader(
                    fileName: spec.file.fileName(for: feature.typeName),
                    context: headerContext
                )
                let body = try TemplateRenderer.render("\(spec.templateName).stencil", context: sharedContext)
                files.append(GeneratedFile(
                    url: testsRoot.appendingPathComponent(spec.file.fileName(for: feature.typeName)),
                    content: header + body
                ))
            }
        }

        // Pre-flight check: ensure no target files already exist before writing anything to disk
        for file in files where FileManager.default.fileExists(atPath: file.url.path) {
            throw ForgeError.fileAlreadyExists(file.url.path)
        }

        // Write all generated files atomically to disk, creating parent folders as needed
        for file in files {
            try FileManager.default.createDirectory(
                at: file.url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try file.content.write(to: file.url, atomically: true, encoding: .utf8)
        }

        return GenerationResult(
            createdFiles: files.map(\.url),
            detectedXcodeProject: xcodeProject,
            createdSwiftPackage: createdSwiftPackage,
            detectedSwiftPackageTarget: packageTarget
        )
    }

    // MARK: - Helpers

    /// Returns the first `.xcodeproj` found in `root`, or `nil`.
    private func findXcodeProject(in root: URL) -> URL? {
        (try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ))?.first { $0.pathExtension == "xcodeproj" }
    }
}
