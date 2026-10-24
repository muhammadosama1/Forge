import Foundation

/// Parsed representation of the `forge make` subcommand.
struct Command {
    /// Raw feature name as provided on the command line.
    let featureName: String
    /// Directory where the feature will be created.
    let projectPath: URL
    /// Whether to emit a `Package.swift` manifest.
    let shouldCreatePackage: Bool
    /// Explicit Swift package target name, if `--target` was used.
    let packageTarget: String?
    /// Whether `--no-domain` was passed.
    let shouldSkipDomain: Bool
    /// Whether `--tests` was passed.
    let shouldGenerateTests: Bool
    /// Resolved architecture pattern (presentation + clean flag).
    let type: FeatureType
    /// Optional UI pattern category (form, list).
    let category: FeatureCategory?
    /// Team naming conventions loaded from `.forge.yml` (or defaults).
    let naming: NamingConfig
    /// Reactive state-binding mechanism loaded from `.forge.yml` (or defaults).
    let binding: BindingStrategy
    /// Unit testing framework loaded from `.forge.yml` (or defaults).
    let testing: TestFramework
    /// Dependency injection strategy loaded from `.forge.yml` (or defaults).
    let di: DependencyInjectionStrategy
    /// URL of the loaded `.forge.yml` file, if discovered or explicitly provided.
    let loadedConfigURL: URL?

    init(
        featureName: String,
        projectPath: URL,
        shouldCreatePackage: Bool,
        packageTarget: String?,
        shouldSkipDomain: Bool,
        shouldGenerateTests: Bool,
        type: FeatureType,
        category: FeatureCategory?,
        naming: NamingConfig = NamingConfig(),
        binding: BindingStrategy = .combine,
        testing: TestFramework = .xctest,
        di: DependencyInjectionStrategy = .native,
        loadedConfigURL: URL? = nil
    ) {
        self.featureName = featureName
        self.projectPath = projectPath
        self.shouldCreatePackage = shouldCreatePackage
        self.packageTarget = packageTarget
        self.shouldSkipDomain = shouldSkipDomain
        self.shouldGenerateTests = shouldGenerateTests
        self.type = type
        self.category = category
        self.naming = naming
        self.binding = binding
        self.testing = testing
        self.di = di
        self.loadedConfigURL = loadedConfigURL
    }

    static let usage = """
    Usage:
      forge make <FeatureName> [--path <ProjectRoot>] [--config <ConfigFile>] [--package] [--target <SwiftPackageTarget>] [-<architecture>] [-clean | --no-clean] [--no-domain | --domain] [--tests | --no-tests] [-form | -list]
      forge init [--path <ProjectRoot>] [--force]

    Architecture flags (pick one):
      -mvvm, -mvi, -viper, -vip, -mvp

    Category flags (optional, pick one):
      -form, -list

    Example:
      forge init
      forge make Login
      forge make Login --path /path/to/MyApp
      forge make Login --package
      forge make Login --path /path/to/MyPackage --target AppFeatureKit
      forge make Login -mvvm
      forge make Login -mvvm -clean
      forge make Login -viper -clean
      forge make Login -mvi
      forge make Login -mvvm -form
      forge make Login -mvvm -list
      forge make Login --no-domain
      forge make Login --tests
      forge make Login -mvvm --tests
      forge make Login --config /path/to/.forge.yml
    """

    /// Current release version of the forge tool.
    /// Tracked in Sources/forge/Version.swift and stamped by git tags via Makefile.
    static let version = forgeVersion

    /// Returns `true` when the argument is a help flag (`-h`, `--help`, or the literal `help`).
    static func isHelpFlag(_ argument: String) -> Bool {
        argument == "help" || argument == "--help" || argument == "-h"
    }

    /// Returns `true` when the argument is a version flag (`-v` or `--version`).
    static func isVersionFlag(_ argument: String) -> Bool {
        argument == "--version" || argument == "-v"
    }

    /// Comprehensive help text shown by `forge help`, `forge --help`, or `forge -h`.
    static let help = """
    forge - SwiftUI feature scaffolding tool

    USAGE:
      forge make <FeatureName> [options]
      forge init [options]
      forge help

    COMMANDS:
      make        Generate a new SwiftUI feature scaffold
      init        Create a starter .forge.yml configuration file
      help        Show this help message
      --version   Print the current forge version

    INIT OPTIONS:
      --path <dir>          Directory to create .forge.yml in (default: current directory)
      --force               Overwrite existing .forge.yml

    MAKE OPTIONS:
      --path <dir>          Project root directory (default: current directory)
      --config <path>       Path to .forge.yml configuration file
      --package             Generate a Package.swift manifest
      --target <name>       Swift package target name for multi-target packages
      -clean, --clean       Include Clean Architecture layers (Domain + Data)
      --no-clean            Omit Clean Architecture layers (overrides config)
      --no-domain           Skip Domain layer files (implies --clean)
      --domain, --with-domain Include Domain layer files (overrides config no_domain)
      --tests               Generate unit test files (XCTest or Swift Testing based on config)
      --no-tests            Skip generating test files (overrides config)

    ARCHITECTURE FLAGS (pick one):
      -mvvm                 Model-View-ViewModel
      -mvi                  Model-View-Intent
      -viper                View-Interactor-Presenter-Entity-Router
      -vip                  View-Interactor-Presenter
      -mvp                  Model-View-Presenter

    CATEGORY FLAGS (optional, pick one):
      -form                 Form view with two input fields and submit button
      -list                 List view connected to an array in the ViewModel

    When no architecture flag is provided and no .forge.yml config exists,
    Forge prompts you interactively.

    CONFIGURATION (.forge.yml):
      Commit a .forge.yml file to establish team standards. Options:
      architecture:  mvvm, mvi, viper, vip, mvp
      binding:       combine, concurrency (Observation framework)
      testing:       xctest, swift-testing
      di:            native, factory (Factory library)
      flags:         clean, no_domain, tests
      paths:         root, package, target
      naming:        type_prefix, type_suffix, folder_prefix, folder_suffix

    CLEAN ARCHITECTURE:
      Combining any architecture flag with -clean adds Domain layer
      (Entity, UseCase, Repository) and Data layer (RepositoryImpl,
      RemoteDataSource, Models). Use --no-domain to include Data but
      skip Domain files.

    GENERATED FILES:
      Each architecture produces a set of files in a feature folder:

      MVVM:       DependencyContainer, View, ViewModel
      MVI:        DependencyContainer, View, Store, State, Intent, Reducer
      VIPER:      DependencyContainer, View, Presenter, Interactor, Router,
                  Entity, Contracts
      VIP:        DependencyContainer, View, Interactor, Presenter, Worker,
                  PresentationModels
      MVP:        DependencyContainer, View, Presenter, Model

      Adding -clean appends Domain and Data layer files to any architecture.
      Adding --tests appends unit test files for the selected architecture.

    EXAMPLES:
      forge init
      forge make Login
      forge make Login -mvvm
      forge make Login -mvvm -clean
      forge make Login -mvvm --tests
      forge make Login --path /path/to/MyApp
      forge make Login --path /path/to/MyApp --package
      forge make Login --path /path/to/MyPackage --target FeatureKit
      forge make Login --path /path/to/MyApp --no-domain
      forge make Login --config .forge.yml
    """

    // MARK: - Subcommand Handlers

    /// Handles `forge init`: creates a starter `.forge.yml` file.
    static func runInit(arguments: [String]) throws {
        var path = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        var force = false
        var index = 1

        while index < arguments.count {
            let arg = arguments[index]
            if arg == "--force" || arg == "-f" {
                force = true
                index += 1
                continue
            }
            if arg == "--path" {
                let nextIndex = index + 1
                guard nextIndex < arguments.count, !arguments[nextIndex].hasPrefix("-") else {
                    throw ForgeError.invalidArguments("Missing value for --path.")
                }
                path = URL(fileURLWithPath: arguments[nextIndex], isDirectory: true)
                index += 2
                continue
            }
            throw ForgeError.invalidArguments("Unknown option for init: '\(arg)'. Supported: --path <dir>, --force")
        }

        for filename in ConfigLoader.configFilenames {
            let candidate = path.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: candidate.path) && !force {
                throw ForgeError.invalidArguments("\(filename) already exists at '\(candidate.path)'. Use --force to overwrite.")
            }
        }

        let targetURL = path.appendingPathComponent(".forge.yml")

        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        try ProjectConfig.starterTemplate.write(to: targetURL, atomically: true, encoding: .utf8)
        print("Created .forge.yml at \(targetURL.path)")
    }

    /// Parses CLI arguments into a `Command`, prompting interactively when needed.
    /// - Parameter arguments: All arguments after the program name (should start with `"make"`).
    /// - Throws: `ForgeError.invalidArguments` on bad flags, `ForgeError.cancelled` if the user quits an interactive prompt.
    static func parse(arguments: [String]) throws -> Command {
        // First argument must be the 'make' subcommand
        guard arguments.first == "make" else {
            throw ForgeError.invalidArguments("Expected command: make")
        }

        // Must specify at least the feature name following 'make'
        guard arguments.count >= 2 else {
            throw ForgeError.invalidArguments("Missing feature name.")
        }

        // CLI argument tracking (nil means not explicitly set on CLI)
        var explicitProjectPath: URL?
        var explicitConfigPath: URL?
        var cliCreatePackage: Bool?
        var cliPackageTarget: String?
        var cliSkipDomain: Bool?
        var cliGenerateTests: Bool?
        var cliCleanFlag: Bool?
        var selectedPresentation: PresentationArchitecture?
        var selectedCategory: FeatureCategory?
        var positional: [String] = []
        var index = 1

        // Loop through arguments starting after 'make' (index 1)
        while index < arguments.count {
            let argument = arguments[index]

            // Check argument against supported flag parsers; each helper increments index if matched
            if try parsePathFlag(argument, arguments: arguments, at: &index, projectPath: &explicitProjectPath) { continue }
            if try parseConfigFlag(argument, arguments: arguments, at: &index, configPath: &explicitConfigPath) { continue }
            if parsePackageFlag(argument, at: &index, shouldCreatePackage: &cliCreatePackage) { continue }
            if try parseTargetFlag(argument, arguments: arguments, at: &index, packageTarget: &cliPackageTarget) { continue }
            if try parseCleanFlag(argument, at: &index, hasCleanFlag: &cliCleanFlag) { continue }
            if try parseNoCleanFlag(argument, at: &index, hasCleanFlag: &cliCleanFlag) { continue }
            if try parseNoDomainFlag(argument, at: &index, shouldSkipDomain: &cliSkipDomain) { continue }
            if try parseDomainFlag(argument, at: &index, shouldSkipDomain: &cliSkipDomain) { continue }
            if try parseTestsFlag(argument, at: &index, shouldGenerateTests: &cliGenerateTests) { continue }
            if try parseNoTestsFlag(argument, at: &index, shouldGenerateTests: &cliGenerateTests) { continue }
            if try parseArchitectureFlag(argument, at: &index, selectedPresentation: &selectedPresentation) { continue }
            if try parseCategoryFlag(argument, at: &index, selectedCategory: &selectedCategory) { continue }
            if try parseUnknownFlag(argument) { continue }

            // Non-flag arguments are collected as positional arguments (e.g. feature name)
            positional.append(argument)
            index += 1
        }

        // Exactly one positional feature name is allowed
        guard positional.count == 1 else {
            throw ForgeError.invalidArguments("Expected exactly one feature name.")
        }

        // Reject contradictory CLI flags
        if cliCleanFlag == false && cliSkipDomain == true {
            throw ForgeError.invalidArguments("Cannot combine '--no-clean' with '--no-domain'.")
        }

        // Determine starting directory to look for .forge.yml
        let startingDir = explicitProjectPath ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let loadedConfig = try ConfigLoader.load(explicitPath: explicitConfigPath, startingDirectory: startingDir)
        let config = loadedConfig?.config ?? ProjectConfig()

        // Resolve destination project path: CLI --path > config paths.root > current directory
        var projectPath = explicitProjectPath ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        if explicitProjectPath == nil, let root = config.paths.root, !root.isEmpty {
            let base = loadedConfig?.fileURL.deletingLastPathComponent() ?? projectPath
            projectPath = (root as NSString).isAbsolutePath
                ? URL(fileURLWithPath: root, isDirectory: true)
                : base.appendingPathComponent(root, isDirectory: true)
        }

        // Resolve options: CLI flags override .forge.yml
        let shouldCreatePackage = cliCreatePackage ?? config.paths.package
        let packageTarget = cliPackageTarget ?? config.paths.target
        var shouldSkipDomain = cliSkipDomain ?? config.flags.noDomain
        let shouldGenerateTests = cliGenerateTests ?? config.flags.tests
        var useCleanLayers = cliCleanFlag ?? config.flags.clean

        // If user explicitly asks to skip domain files, Clean Architecture layers (Data) are implied
        if shouldSkipDomain {
            useCleanLayers = true
        }

        // CLI negative clean flag overrides everything (including config no_domain)
        if cliCleanFlag == false {
            useCleanLayers = false
            shouldSkipDomain = false
        }

        // Resolve architecture: CLI flag > config architecture > interactive prompt
        var presentation = selectedPresentation ?? config.architecture

        if presentation == nil && !useCleanLayers {
            presentation = try Terminal.promptSelection(
                title: "Which presentation pattern do you want to use?",
                options: PresentationArchitecture.allCases
            )
            if !shouldSkipDomain {
                useCleanLayers = try Terminal.promptYesNo(
                    title: "Do you want to include Clean Architecture layers (Domain/Data)?",
                    defaultIsYes: true
                )
            }
        } else if presentation == nil {
            // If only -clean was passed (or configured) with no specific presentation flag, default to MVVM
            presentation = .mvvm
        }

        // Map presentation pattern + clean flag into the concrete FeatureType enum
        let type = FeatureType.resolve(presentation: presentation!, clean: useCleanLayers)

        return Command(
            featureName: positional[0],
            projectPath: projectPath,
            shouldCreatePackage: shouldCreatePackage,
            packageTarget: packageTarget,
            shouldSkipDomain: shouldSkipDomain,
            shouldGenerateTests: shouldGenerateTests,
            type: type,
            category: selectedCategory,
            naming: config.naming,
            binding: config.binding,
            testing: config.testing,
            di: config.di,
            loadedConfigURL: loadedConfig?.fileURL
        )
    }

    /// Executes the command: validates the feature name, generates files, prints results.
    /// - Throws: `ForgeError` on validation failures, file conflicts, or cancellation.
    func run() throws {
        // Validate and normalize the feature name into PascalCase with project naming rules
        let feature = try FeatureName(rawValue: featureName, naming: naming)
        // Resolve the complete set of required file roles for this architecture
        let resolvedSelection = FeatureFileSelection.all(for: type)
        // Instantiate the code generator configured with parsed command options
        let generator = FeatureGenerator(
            projectPath: projectPath,
            shouldCreatePackage: shouldCreatePackage,
            packageTarget: packageTarget,
            shouldGenerateTests: shouldGenerateTests,
            shouldSkipDomain: shouldSkipDomain,
            type: type,
            category: category,
            binding: binding,
            testing: testing,
            di: di
        )
        // Generate templates and write files to disk
        let result = try generator.generate(feature: feature, selection: resolvedSelection)

        // Output summary of created files
        if let configURL = loadedConfigURL {
            print("Using standards from \(configURL.lastPathComponent)")
        }
        print("Created \(type.displayName) feature: \(feature.typeName)")
        for file in result.createdFiles {
            print("  + \(file.path)")
        }

        // Display additional package or Xcode project status
        if let packageRoot = result.createdSwiftPackage {
            print("\nCreated Swift package: \(packageRoot.path)")
        } else {
            if let xcodeProject = result.detectedXcodeProject {
                print("\nDetected Xcode project: \(xcodeProject.lastPathComponent)")
                print("Xcode project registration is the next step for this CLI.")
            }
            if let packageTarget = result.detectedSwiftPackageTarget {
                print("\nTargeted Swift package target: \(packageTarget)")
            } else if result.detectedXcodeProject == nil {
                print("\nNo .xcodeproj found under \(projectPath.path). Files were generated only.")
            }
        }
    }

    // MARK: - Argument parsing helpers

    /// Handles `--path <dir>`: sets `projectPath` and advances the index past the value.
    private static func parsePathFlag(
        _ argument: String, arguments: [String], at index: inout Int, projectPath: inout URL?
    ) throws -> Bool {
        guard argument == "--path" else { return false }
        let nextIndex = index + 1
        guard nextIndex < arguments.count, !arguments[nextIndex].hasPrefix("-") else {
            throw ForgeError.invalidArguments("Missing value for --path.")
        }
        projectPath = URL(fileURLWithPath: arguments[nextIndex], isDirectory: true)
        index += 2
        return true
    }

    /// Handles `--config <path>`: sets `configPath` and advances the index past the value.
    private static func parseConfigFlag(
        _ argument: String, arguments: [String], at index: inout Int, configPath: inout URL?
    ) throws -> Bool {
        guard argument == "--config" else { return false }
        let nextIndex = index + 1
        guard nextIndex < arguments.count, !arguments[nextIndex].hasPrefix("-") else {
            throw ForgeError.invalidArguments("Missing value for --config.")
        }
        configPath = URL(fileURLWithPath: arguments[nextIndex])
        index += 2
        return true
    }

    /// Handles `--package`: sets `shouldCreatePackage` and advances the index.
    private static func parsePackageFlag(
        _ argument: String, at index: inout Int, shouldCreatePackage: inout Bool?
    ) -> Bool {
        guard argument == "--package" else { return false }
        shouldCreatePackage = true
        index += 1
        return true
    }

    /// Handles `--target <name>`: sets `packageTarget` and advances the index past the value.
    private static func parseTargetFlag(
        _ argument: String, arguments: [String], at index: inout Int, packageTarget: inout String?
    ) throws -> Bool {
        guard argument == "--target" else { return false }
        let nextIndex = index + 1
        guard nextIndex < arguments.count, !arguments[nextIndex].hasPrefix("-") else {
            throw ForgeError.invalidArguments("Missing value for --target.")
        }
        packageTarget = arguments[nextIndex]
        index += 2
        return true
    }

    /// Handles `-clean` / `--clean`: sets `hasCleanFlag` and advances the index.
    private static func parseCleanFlag(
        _ argument: String, at index: inout Int, hasCleanFlag: inout Bool?
    ) throws -> Bool {
        guard argument == "-clean" || argument == "--clean" else { return false }
        if let existing = hasCleanFlag, !existing {
            throw ForgeError.invalidArguments("Cannot combine '-clean' and '--no-clean'.")
        }
        hasCleanFlag = true
        index += 1
        return true
    }

    /// Handles `--no-clean`: sets `hasCleanFlag` to false and advances the index.
    private static func parseNoCleanFlag(
        _ argument: String, at index: inout Int, hasCleanFlag: inout Bool?
    ) throws -> Bool {
        guard argument == "--no-clean" else { return false }
        if let existing = hasCleanFlag, existing {
            throw ForgeError.invalidArguments("Cannot combine '-clean' and '--no-clean'.")
        }
        hasCleanFlag = false
        index += 1
        return true
    }

    /// Handles `--no-domain`: sets `shouldSkipDomain` and advances the index.
    private static func parseNoDomainFlag(
        _ argument: String, at index: inout Int, shouldSkipDomain: inout Bool?
    ) throws -> Bool {
        guard argument == "--no-domain" else { return false }
        if let existing = shouldSkipDomain, !existing {
            throw ForgeError.invalidArguments("Cannot combine '--domain' and '--no-domain'.")
        }
        shouldSkipDomain = true
        index += 1
        return true
    }

    /// Handles `--domain` / `--with-domain`: sets `shouldSkipDomain` to false and advances the index.
    private static func parseDomainFlag(
        _ argument: String, at index: inout Int, shouldSkipDomain: inout Bool?
    ) throws -> Bool {
        guard argument == "--domain" || argument == "--with-domain" else { return false }
        if let existing = shouldSkipDomain, existing {
            throw ForgeError.invalidArguments("Cannot combine '--domain' and '--no-domain'.")
        }
        shouldSkipDomain = false
        index += 1
        return true
    }

    /// Handles `--tests`: sets `shouldGenerateTests` and advances the index.
    private static func parseTestsFlag(
        _ argument: String, at index: inout Int, shouldGenerateTests: inout Bool?
    ) throws -> Bool {
        guard argument == "--tests" else { return false }
        if let existing = shouldGenerateTests, !existing {
            throw ForgeError.invalidArguments("Cannot combine '--tests' and '--no-tests'.")
        }
        shouldGenerateTests = true
        index += 1
        return true
    }

    /// Handles `--no-tests`: sets `shouldGenerateTests` to false and advances the index.
    private static func parseNoTestsFlag(
        _ argument: String, at index: inout Int, shouldGenerateTests: inout Bool?
    ) throws -> Bool {
        guard argument == "--no-tests" else { return false }
        if let existing = shouldGenerateTests, existing {
            throw ForgeError.invalidArguments("Cannot combine '--tests' and '--no-tests'.")
        }
        shouldGenerateTests = false
        index += 1
        return true
    }

    /// Handles architecture flags (`-mvvm`, `-viper`, etc.): sets `selectedPresentation`.
    /// Rejects duplicate architecture flags.
    private static func parseArchitectureFlag(
        _ argument: String, at index: inout Int, selectedPresentation: inout PresentationArchitecture?
    ) throws -> Bool {
        guard let presentation = PresentationArchitecture.from(flag: argument) else { return false }
        if selectedPresentation != nil {
            throw ForgeError.invalidArguments(
                "Multiple architecture flags were provided. Pick one: \(PresentationArchitecture.validFlags)."
            )
        }
        selectedPresentation = presentation
        index += 1
        return true
    }

    /// Handles category flags (`-form`, `-list`): sets `selectedCategory`.
    /// Rejects duplicate category flags.
    private static func parseCategoryFlag(
        _ argument: String, at index: inout Int, selectedCategory: inout FeatureCategory?
    ) throws -> Bool {
        guard let category = FeatureCategory.from(flag: argument) else { return false }
        if selectedCategory != nil {
            throw ForgeError.invalidArguments(
                "Multiple category flags were provided. Pick one: \(FeatureCategory.validFlags)."
            )
        }
        selectedCategory = category
        index += 1
        return true
    }

    /// Catches any remaining `-` prefixed argument that wasn't handled above and throws an error.
    private static func parseUnknownFlag(_ argument: String) throws -> Bool {
        guard argument.hasPrefix("-") else { return false }
        throw ForgeError.invalidArguments(
            "Unknown option '\(argument)'. Architecture flags: \(PresentationArchitecture.validFlags). Add -clean for Clean Architecture layers."
        )
    }
}
