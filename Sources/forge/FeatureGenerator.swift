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

    /// Renders all template files for the given feature and writes them to disk.
    /// Skips existing files (throws `ForgeError.fileAlreadyExists`).
    /// - Parameter feature: Validated feature name.
    /// - Parameter selection: Controls which file roles to include.
    /// - Returns: A result with paths, detected Xcode project, and package info.
    func generate(feature: FeatureName, selection: FeatureFileSelection) throws -> GenerationResult {
        let xcodeProject    = findXcodeProject(in: projectPath)
        let headerContext   = FileHeaderContext(projectPath: projectPath, xcodeProject: xcodeProject)
        let featureRoot     = projectPath.appendingPathComponent(feature.folderName, isDirectory: true)
        let sourcesRoot     = shouldCreatePackage
            ? featureRoot.appendingPathComponent("Sources").appendingPathComponent(feature.typeName)
            : featureRoot

        // Filter out Domain-layer files when --no-domain is used
        let activeSelection: FeatureFileSelection
        if shouldSkipDomain {
            activeSelection = FeatureFileSelection(including: selection.includedFiles.filter { !$0.isDomain })
        } else {
            activeSelection = selection
        }

        // Build the template context once — reused for every file in this generation run.
        var sharedContext = activeSelection.contextMap
        sharedContext["name"] = feature.typeName
        if shouldSkipDomain {
            sharedContext["hasNoDomain"] = true
        }

        // Render all specs that belong to the resolved selection.
        var files: [GeneratedFile] = try type.templateSpecs
            .filter { activeSelection.contains($0.file) }
            .map { spec in
                let header  = try Templates.fileHeader(
                    fileName: spec.file.fileName(for: feature.typeName),
                    context: headerContext
                )
                let body    = try TemplateRenderer.render("\(spec.templateName).stencil", context: sharedContext)
                let layer   = spec.file.layer(for: type)
                let directory = layer == "Root"
                    ? sourcesRoot
                    : sourcesRoot.appendingPathComponent(layer, isDirectory: true)
                return GeneratedFile(
                    url: directory.appendingPathComponent(spec.file.fileName(for: feature.typeName)),
                    content: header + body
                )
            }

        // Optionally append Package.swift.
        var createdSwiftPackage: URL?
        if shouldCreatePackage {
            let packageContent = try Templates.render("swiftPackage", name: feature.typeName)
            let packageUrl = featureRoot.appendingPathComponent("Package.swift")
            files.append(GeneratedFile(url: packageUrl, content: packageContent))
            createdSwiftPackage = featureRoot
        }

        // Optionally generate test files.
        if shouldGenerateTests {
            let testsRoot = shouldCreatePackage
                ? featureRoot.appendingPathComponent("Tests").appendingPathComponent("\(feature.typeName)Tests")
                : featureRoot.appendingPathComponent("Tests")

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

        // Guard against overwriting existing files before touching the filesystem.
        for file in files where FileManager.default.fileExists(atPath: file.url.path) {
            throw ForgeError.fileAlreadyExists(file.url.path)
        }

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
