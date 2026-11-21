import Foundation

struct StackConfig: Equatable {
    struct File: Equatable {
        let template: String
        let output: String?
        let isTest: Bool
    }

    static let categories: [FeatureCategory?] = [nil, .form, .list]

    let categories: Set<String>
    let files: [String: File]

    init(_ values: [String: Any], architecture: PresentationArchitecture) throws {
        guard Set(values.keys).isSubset(of: ["version", "categories", "files"]),
              let version = values["version"] as? Int, version == 1 else {
            throw ForgeError.invalidArguments("Use stack.version: 1 and the supported stack keys version, categories, and files.")
        }

        let categoryNames = Set(Self.categories.map { $0?.rawValue ?? "default" })
        var enabled = categoryNames
        if let raw = values["categories"] {
            guard let settings = raw as? [String: Any] else {
                throw ForgeError.invalidArguments("Set stack.categories to a mapping of screen names to true or false.")
            }
            for (category, value) in settings {
                guard categoryNames.contains(category), let include = value as? Bool else {
                    throw ForgeError.invalidArguments("Invalid stack.categories.\(category). Use default, form, or list with true or false.")
                }
                if !include { enabled.remove(category) }
            }
        }
        guard !enabled.isEmpty else {
            throw ForgeError.invalidArguments("Enable at least one screen in stack.categories.")
        }
        categories = enabled

        let builtInRoles = Self.roles(for: architecture)
        var files: [String: File] = [:]
        if let raw = values["files"] {
            guard let settings = raw as? [String: Any] else {
                throw ForgeError.invalidArguments("Set stack.files to a mapping of role names to template settings.")
            }
            for (role, value) in settings {
                guard role.range(of: #"^[A-Za-z][A-Za-z0-9_]*$"#, options: .regularExpression) != nil,
                      let entry = value as? [String: Any],
                      let template = entry["template"] as? String,
                      template.hasSuffix(".stencil"), Self.isRelativePath(template) else {
                    throw ForgeError.invalidArguments("Set stack.files.\(role).template to a relative .stencil path under .templates/.")
                }
                if builtInRoles.contains(role) {
                    guard entry.count == 1 else {
                        throw ForgeError.invalidArguments("Built-in role '\(role)' inherits its output and target. Set only template.")
                    }
                    files[role] = File(template: template, output: nil, isTest: false)
                } else {
                    guard FeatureFile(rawValue: role) == nil, entry.count == 3,
                          let output = entry["output"] as? String, output.hasSuffix(".swift"), Self.isRelativePath(output),
                          let target = entry["target"] as? String, ["source", "test"].contains(target) else {
                        throw ForgeError.invalidArguments("For custom role '\(role)', set a relative Swift output and target: source or test. Built-in roles must belong to the selected architecture.")
                    }
                    files[role] = File(template: template, output: output, isTest: target == "test")
                }
            }
        }
        self.files = files
    }

    static func roles(for architecture: PresentationArchitecture) -> Set<String> {
        Set([false, true].flatMap { clean in
            let type = FeatureType.resolve(presentation: architecture, clean: clean)
            return (categories.flatMap { type.templateSpecs(for: $0) } + type.testTemplateSpecs)
                .map { $0.file.rawValue }
        })
    }

    static func isRelativePath(_ path: String) -> Bool {
        !path.contains("\\") && !path.unicodeScalars.contains { $0.value < 32 }
            && path.split(separator: "/", omittingEmptySubsequences: false)
                .allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }

    func checkCategory(_ category: FeatureCategory?) throws {
        let name = category?.rawValue ?? "default"
        guard categories.contains(name) else {
            throw ForgeError.invalidArguments("The '\(name)' screen is disabled. Choose an enabled screen or set stack.categories.\(name) to true.")
        }
    }
}
