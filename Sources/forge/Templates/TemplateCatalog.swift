import Foundation

/// Local overrides never execute code. Destinations remain owned by Forge.
enum TemplateCatalog {
    static let version = "1"

    static func source(_ name: String, overrides: URL?) throws -> String {
        guard let builtIn = TemplateContent.files[name] else {
            throw ForgeError.invalidArguments("Unknown template '\(name)'. Run forge templates list.")
        }
        guard let overrides else { return builtIn }
        let candidate = overrides.appendingPathComponent(name)
        let exists = FileManager.default.fileExists(atPath: candidate.path)
        let isSymlink = (try? FileManager.default.destinationOfSymbolicLink(atPath: candidate.path)) != nil
        guard exists || isSymlink else { return builtIn }
        let marker = overrides.appendingPathComponent("contract-version")
        guard (try? String(contentsOf: marker, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)) == version else {
            throw ForgeError.invalidArguments("Template overrides require contract-version containing '\(version)' in '\(overrides.path)'. Re-export templates for this Forge version.")
        }
        guard resolvedPath(candidate).hasPrefix(resolvedPath(overrides) + "/") else {
            throw ForgeError.invalidArguments("Template override must stay inside '\(overrides.path)'.")
        }
        do { return try String(contentsOf: candidate, encoding: .utf8) }
        catch { throw ForgeError.invalidArguments("Cannot read template '\(candidate.path)': \(error.localizedDescription)") }
    }

    static func run(arguments: [String]) throws {
        guard arguments.count >= 2 else { throw ForgeError.invalidArguments("Use forge templates list or forge templates export <name> [--path <project>] [--config <file>].") }
        if arguments == ["templates", "list"] {
            print("Forge template contract v\(version)")
            TemplateContent.files.keys.sorted().forEach { print($0) }
            return
        }
        guard arguments.count >= 3, arguments[1] == "export" else {
            throw ForgeError.invalidArguments("Use forge templates list or forge templates export <name> [--path <project>] [--config <file>].")
        }
        let name = arguments[2].hasSuffix(".stencil") ? arguments[2] : arguments[2] + ".stencil"
        let source = try source(name, overrides: nil)
        var root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        var config: URL?
        var index = 3
        while index < arguments.count {
            let flag = arguments[index]
            guard ["--path", "--config"].contains(flag), index + 1 < arguments.count,
                  !arguments[index + 1].hasPrefix("-") else {
                throw ForgeError.invalidArguments("Expected --path <project> or --config <file>.")
            }
            let url = URL(fileURLWithPath: arguments[index + 1])
            if flag == "--path" { root = url } else { config = url }
            index += 2
        }
        let loaded = try ConfigLoader.load(explicitPath: config, startingDirectory: root)
        let base = loaded?.fileURL.deletingLastPathComponent() ?? root
        let directory = base.appendingPathComponent(".forge/templates")
        let destination = directory.appendingPathComponent(name)
        let marker = directory.appendingPathComponent("contract-version")
        if FileManager.default.fileExists(atPath: destination.path) { throw ForgeError.fileAlreadyExists(destination.path) }
        if FileManager.default.fileExists(atPath: marker.path),
           try String(contentsOf: marker, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) != version {
            throw ForgeError.invalidArguments("Existing template contract is incompatible. Export into a different project and migrate overrides explicitly.")
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: marker.path) { try (version + "\n").write(to: marker, atomically: true, encoding: .utf8) }
        let published = try PublishedFile.write(source, to: destination)
        published.removeStagingFile()
        print("Exported \(destination.path)")
    }
}
