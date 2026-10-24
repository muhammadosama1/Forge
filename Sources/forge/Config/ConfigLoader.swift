import Foundation

/// Result of loading a configuration file.
struct LoadedConfig: Equatable {
    let config: ProjectConfig
    let fileURL: URL
}

/// Locates and loads `.forge.yml` or `.forge.yaml` files from the filesystem.
enum ConfigLoader {

    static let configFilenames = [".forge.yml", ".forge.yaml"]

    /// Finds and parses the project configuration.
    ///
    /// - Parameters:
    ///   - explicitPath: Optional explicit config file URL from `--config`.
    ///   - startingDirectory: Directory to begin searching from (defaults to current directory).
    /// - Returns: `LoadedConfig` containing the parsed configuration and its URL, or `nil` if none found.
    /// - Throws: `ForgeError` if an explicitly provided file is missing or if parsing fails.
    static func load(
        explicitPath: URL? = nil,
        startingDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) throws -> LoadedConfig? {
        if let explicitPath {
            guard FileManager.default.fileExists(atPath: explicitPath.path) else {
                throw ForgeError.invalidArguments("Configuration file not found at '\(explicitPath.path)'")
            }
            return try parseFile(at: explicitPath)
        }

        guard let discoveredURL = findConfigFile(startingFrom: startingDirectory) else {
            return nil
        }

        return try parseFile(at: discoveredURL)
    }

    /// Searches for `.forge.yml` / `.forge.yaml` in `startingFrom` and its parent directories,
    /// stopping at git root (`.git`) or the root of the filesystem.
    static func findConfigFile(startingFrom: URL) -> URL? {
        var current = startingFrom.standardizedFileURL

        while true {
            for filename in configFilenames {
                let candidate = current.appendingPathComponent(filename)
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDir), !isDir.boolValue {
                    return candidate
                }
            }

            // Stop traversal if we reached a repository boundary (.git)
            let gitDir = current.appendingPathComponent(".git")
            if FileManager.default.fileExists(atPath: gitDir.path) {
                break
            }

            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                // Reached filesystem root
                break
            }
            current = parent
        }

        return nil
    }

    /// Reads and parses a YAML config file into `LoadedConfig`.
    private static func parseFile(at url: URL) throws -> LoadedConfig {
        let content: String
        do {
            content = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw ForgeError.invalidArguments("Unable to read configuration file at '\(url.path)': \(error.localizedDescription)")
        }

        do {
            let dict = try YAMLParser.parse(content)
            let config = try ProjectConfig(from: dict)
            return LoadedConfig(config: config, fileURL: url)
        } catch let error as ForgeError {
            throw error
        } catch {
            throw ForgeError.invalidArguments("Error parsing '\(url.lastPathComponent)': \(error.localizedDescription)")
        }
    }
}
