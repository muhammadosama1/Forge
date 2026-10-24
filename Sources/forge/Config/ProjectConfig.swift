import Foundation

/// Project-wide standards loaded from `.forge.yml` (committed to git).
struct ProjectConfig: Equatable {
    /// Default presentation architecture for the project (e.g. .mvvm, .viper).
    var architecture: PresentationArchitecture?

    /// Reactive state-binding mechanism (e.g. .combine, .concurrency).
    var binding: BindingStrategy = .combine

    /// Unit testing framework (e.g. .xctest, .swiftTesting).
    var testing: TestFramework = .xctest

    /// Dependency injection strategy (e.g. .native, .factory).
    var di: DependencyInjectionStrategy = .native

    /// Project-level flags standardizing layers and test suites.
    var flags: FlagsConfig

    /// Project routing and package structure standards.
    var paths: PathsConfig

    /// Team naming conventions for generated types and folders.
    var naming: NamingConfig

    init(
        architecture: PresentationArchitecture? = nil,
        binding: BindingStrategy = .combine,
        testing: TestFramework = .xctest,
        di: DependencyInjectionStrategy = .native,
        flags: FlagsConfig = FlagsConfig(),
        paths: PathsConfig = PathsConfig(),
        naming: NamingConfig = NamingConfig()
    ) {
        self.architecture = architecture
        self.binding = binding
        self.testing = testing
        self.di = di
        self.flags = flags
        self.paths = paths
        self.naming = naming
    }

    /// Initializes a `ProjectConfig` from a parsed YAML dictionary.
    init(from dictionary: [String: Any]) throws {
        // Top-level allowed keys
        let allowedTopLevelKeys: Set<String> = ["architecture", "binding", "testing", "di", "flags", "paths", "naming"]
        for key in dictionary.keys {
            guard allowedTopLevelKeys.contains(key) else {
                throw ForgeError.invalidArguments("Unknown configuration key '\(key)' in .forge.yml.")
            }
        }

        // 1. Architecture
        if let rawValue = dictionary["architecture"] {
            guard let rawArch = rawValue as? String else {
                throw ForgeError.invalidArguments("Expected string for 'architecture' in .forge.yml.")
            }
            guard let arch = PresentationArchitecture.from(flag: rawArch) else {
                let valid = PresentationArchitecture.allCases.map(\.rawValue).joined(separator: ", ")
                throw ForgeError.invalidArguments("Invalid architecture '\(rawArch)' in .forge.yml. Valid options: \(valid)")
            }
            self.architecture = arch
        } else {
            self.architecture = nil
        }

        // 2. Binding
        if let rawValue = dictionary["binding"] {
            guard let rawStr = rawValue as? String else {
                throw ForgeError.invalidArguments("Expected string for 'binding' in .forge.yml.")
            }
            guard let strategy = BindingStrategy.from(string: rawStr) else {
                let valid = BindingStrategy.allCases.map(\.rawValue).joined(separator: ", ")
                throw ForgeError.invalidArguments("Invalid binding '\(rawStr)' in .forge.yml. Valid options: \(valid)")
            }
            self.binding = strategy
        } else {
            self.binding = .combine
        }

        // 3. Testing
        if let rawValue = dictionary["testing"] {
            guard let rawStr = rawValue as? String else {
                throw ForgeError.invalidArguments("Expected string for 'testing' in .forge.yml.")
            }
            guard let framework = TestFramework.from(string: rawStr) else {
                let valid = TestFramework.allCases.map(\.rawValue).joined(separator: ", ")
                throw ForgeError.invalidArguments("Invalid testing framework '\(rawStr)' in .forge.yml. Valid options: \(valid)")
            }
            self.testing = framework
        } else {
            self.testing = .xctest
        }

        // 4. Dependency Injection
        if let rawValue = dictionary["di"] {
            guard let rawStr = rawValue as? String else {
                throw ForgeError.invalidArguments("Expected string for 'di' in .forge.yml.")
            }
            guard let strategy = DependencyInjectionStrategy.from(string: rawStr) else {
                let valid = DependencyInjectionStrategy.allCases.map(\.rawValue).joined(separator: ", ")
                throw ForgeError.invalidArguments("Invalid dependency injection strategy '\(rawStr)' in .forge.yml. Valid options: \(valid)")
            }
            self.di = strategy
        } else {
            self.di = .native
        }

        // 5. Flags
        if let rawFlags = dictionary["flags"] {
            guard let flagsDict = rawFlags as? [String: Any] else {
                throw ForgeError.invalidArguments("Expected mapping for 'flags' in .forge.yml.")
            }

            let allowedFlagsKeys: Set<String> = ["clean", "no_domain", "noDomain", "tests"]
            for key in flagsDict.keys {
                guard allowedFlagsKeys.contains(key) else {
                    throw ForgeError.invalidArguments("Unknown flag '\(key)' under 'flags' in .forge.yml.")
                }
            }

            if flagsDict["no_domain"] != nil && flagsDict["noDomain"] != nil {
                throw ForgeError.invalidArguments("Cannot specify both 'no_domain' and 'noDomain' in .forge.yml.")
            }

            var noDomain = false
            if let val = flagsDict["no_domain"] ?? flagsDict["noDomain"] {
                guard let boolVal = val as? Bool else {
                    throw ForgeError.invalidArguments("Expected boolean for 'flags.no_domain' in .forge.yml.")
                }
                noDomain = boolVal
            }

            var clean = false
            if let val = flagsDict["clean"] {
                guard let boolVal = val as? Bool else {
                    throw ForgeError.invalidArguments("Expected boolean for 'flags.clean' in .forge.yml.")
                }
                clean = boolVal
                if !clean && noDomain {
                    throw ForgeError.invalidArguments("Contradictory flags: 'clean: false' cannot be combined with 'no_domain: true' in .forge.yml.")
                }
            } else if noDomain {
                clean = true
            }

            var tests = false
            if let val = flagsDict["tests"] {
                guard let boolVal = val as? Bool else {
                    throw ForgeError.invalidArguments("Expected boolean for 'flags.tests' in .forge.yml.")
                }
                tests = boolVal
            }

            self.flags = FlagsConfig(clean: clean, noDomain: noDomain, tests: tests)
        } else {
            self.flags = FlagsConfig()
        }

        // 6. Paths
        if let rawPaths = dictionary["paths"] {
            guard let pathsDict = rawPaths as? [String: Any] else {
                throw ForgeError.invalidArguments("Expected mapping for 'paths' in .forge.yml.")
            }

            let allowedPathsKeys: Set<String> = ["root", "package", "target"]
            for key in pathsDict.keys {
                guard allowedPathsKeys.contains(key) else {
                    throw ForgeError.invalidArguments("Unknown path setting '\(key)' under 'paths' in .forge.yml.")
                }
            }

            var root: String?
            if let val = pathsDict["root"] {
                guard let strVal = val as? String else {
                    throw ForgeError.invalidArguments("Expected string for 'paths.root' in .forge.yml.")
                }
                root = strVal
            }

            var package = false
            if let val = pathsDict["package"] {
                guard let boolVal = val as? Bool else {
                    throw ForgeError.invalidArguments("Expected boolean for 'paths.package' in .forge.yml.")
                }
                package = boolVal
            }

            var target: String?
            if let val = pathsDict["target"] {
                guard let strVal = val as? String else {
                    throw ForgeError.invalidArguments("Expected string for 'paths.target' in .forge.yml.")
                }
                target = strVal
            }

            self.paths = PathsConfig(root: root, package: package, target: target)
        } else {
            self.paths = PathsConfig()
        }

        // 7. Naming
        if let rawNaming = dictionary["naming"] {
            guard let namingDict = rawNaming as? [String: Any] else {
                throw ForgeError.invalidArguments("Expected mapping for 'naming' in .forge.yml.")
            }

            let allowedNamingKeys: Set<String> = [
                "type_prefix", "typePrefix",
                "type_suffix", "typeSuffix",
                "folder_prefix", "folderPrefix",
                "folder_suffix", "folderSuffix",
                "strip_redundant_suffix", "stripRedundantSuffix",
                "strip_redundant_prefix", "stripRedundantPrefix"
            ]
            for key in namingDict.keys {
                guard allowedNamingKeys.contains(key) else {
                    throw ForgeError.invalidArguments("Unknown naming setting '\(key)' under 'naming' in .forge.yml.")
                }
            }

            func parseString(_ snakeKey: String, _ camelKey: String) throws -> String {
                if namingDict[snakeKey] != nil && namingDict[camelKey] != nil {
                    throw ForgeError.invalidArguments("Cannot specify both '\(snakeKey)' and '\(camelKey)' in .forge.yml.")
                }
                if let val = namingDict[snakeKey] ?? namingDict[camelKey] {
                    guard let strVal = val as? String else {
                        throw ForgeError.invalidArguments("Expected string for 'naming.\(snakeKey)' in .forge.yml.")
                    }
                    return strVal
                }
                return ""
            }

            func parseBool(_ snakeKey: String, _ camelKey: String, defaultValue: Bool) throws -> Bool {
                if namingDict[snakeKey] != nil && namingDict[camelKey] != nil {
                    throw ForgeError.invalidArguments("Cannot specify both '\(snakeKey)' and '\(camelKey)' in .forge.yml.")
                }
                if let val = namingDict[snakeKey] ?? namingDict[camelKey] {
                    guard let boolVal = val as? Bool else {
                        throw ForgeError.invalidArguments("Expected boolean for 'naming.\(snakeKey)' in .forge.yml.")
                    }
                    return boolVal
                }
                return defaultValue
            }

            self.naming = NamingConfig(
                typePrefix: try parseString("type_prefix", "typePrefix"),
                typeSuffix: try parseString("type_suffix", "typeSuffix"),
                folderPrefix: try parseString("folder_prefix", "folderPrefix"),
                folderSuffix: try parseString("folder_suffix", "folderSuffix"),
                stripRedundantSuffix: try parseBool("strip_redundant_suffix", "stripRedundantSuffix", defaultValue: true),
                stripRedundantPrefix: try parseBool("strip_redundant_prefix", "stripRedundantPrefix", defaultValue: true)
            )
        } else {
            self.naming = NamingConfig()
        }
    }

    /// Default starter `.forge.yml` template used by `forge init`.
    static let starterTemplate = """
# .forge.yml - Forge Project Configuration
# Commit this file to the root of your repository to enforce team standards.

# Default presentation architecture: mvvm, mvi, viper, vip, mvp
architecture: mvvm

# State binding mechanism: combine or concurrency (Observation framework)
binding: combine

# Unit testing framework: xctest or swift-testing
testing: xctest

# Dependency injection strategy: native or factory (Factory library)
di: native

# Project-wide layer and test standards
flags:
  clean: false        # Include Clean Architecture layers (Domain + Data)
  no_domain: false    # Skip Domain layer files (implies clean)
  tests: false        # Generate unit test suites by default

# Output paths and packaging standard (uncomment to configure)
# paths:
#   root: Sources/Features  # Target directory relative to project root
#   package: false          # Scaffold features as standalone Swift Packages
#   target: FeatureKit      # Default target in existing multi-target packages

# Team naming conventions
naming:
  type_prefix: ""         # e.g., "App" -> AppLoginView
  type_suffix: ""         # e.g., "Feature" -> LoginFeatureView
  folder_prefix: ""       # e.g., "Feature" -> FeatureLogin/
  folder_suffix: ""       # e.g., "Module" -> LoginModule/
  strip_redundant_suffix: true  # Prevent 'LoginFeatureFeature' when suffix is 'Feature'
  strip_redundant_prefix: true  # Prevent 'AppAppLogin' when prefix is 'App'
"""
}

/// Project-wide flag defaults.
struct FlagsConfig: Equatable {
    /// Whether to generate Clean Architecture layers (Domain + Data) by default.
    var clean: Bool = false
    /// Whether to skip Domain layer files (implies clean).
    var noDomain: Bool = false
    /// Whether to generate automated test suites by default.
    var tests: Bool = false
}

/// Project-wide directory and package defaults.
struct PathsConfig: Equatable {
    /// Default target directory relative to the repository/project root (e.g. `"Sources/Features"`).
    var root: String?
    /// Whether to scaffold features as standalone Swift packages by default.
    var package: Bool = false
    /// Default Swift package target name in existing multi-target packages.
    var target: String?
}

/// Team naming conventions for types and folders.
struct NamingConfig: Equatable {
    /// Prefix prepended to the feature type name (e.g. `"App"` -> `AppLoginView`).
    var typePrefix: String = ""
    /// Suffix appended to the feature type name (e.g. `"Feature"` -> `LoginFeatureView`).
    var typeSuffix: String = ""
    /// Prefix prepended to the feature folder name.
    var folderPrefix: String = ""
    /// Suffix appended to the feature folder name.
    var folderSuffix: String = ""
    /// When true, prevents redundant suffix duplication (e.g. `LoginFeature` + suffix `Feature` remains `LoginFeature`).
    var stripRedundantSuffix: Bool = true
    /// When true, prevents redundant prefix duplication (e.g. `AppLogin` + prefix `App` remains `AppLogin`).
    var stripRedundantPrefix: Bool = true
}
