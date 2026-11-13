import Foundation
import XcodeProj

/// Plans source membership changes before Forge writes any feature files.
enum XcodeProjectIntegration {
    struct Update {
        let targetName: String
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

    static func plan(project: URL, target name: String?, files: [URL]) throws -> Update {
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

        let sourceRoot = resolvedPath(project.deletingLastPathComponent())
        let paths = files.map(resolvedPath)
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

        let names = Set(files.map(\.lastPathComponent))
        let existingPaths = try Set(graph.fileReferences.compactMap { reference -> String? in
            guard let path = reference.path, names.contains((path as NSString).lastPathComponent),
                  let fullPath = try reference.fullPath(sourceRoot: sourceRoot) else { return nil }
            return resolvedPath(URL(fileURLWithPath: fullPath))
        })
        for path in paths {
            guard !existingPaths.contains(path) else {
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
            sources.files = (sources.files ?? []) + [buildFile]
        }

        guard let updated = try graph.dataRepresentation() else {
            throw ForgeError.invalidArguments("Could not serialize the updated Xcode project.")
        }
        return Update(targetName: target.name, projectFile: projectFile, original: original, updated: updated)
    }
}
