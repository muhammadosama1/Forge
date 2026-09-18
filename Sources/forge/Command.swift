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

    static let usage = """
    Usage:
      forge make <FeatureName> [--path <ProjectRoot>] [--package] [--target <SwiftPackageTarget>] [-<architecture>] [-clean] [--no-domain] [--tests] [-form | -list]

    Architecture flags (pick one):
      -mvvm, -mvi, -viper, -vip, -mvp, -tca

    Category flags (optional, pick one):
      -form, -list

    Example:
      forge make Login
      forge make Login --path /path/to/MyApp
      forge make Login --package
      forge make Login --path /path/to/MyPackage --target AppFeatureKit
      forge make Login -mvvm
      forge make Login -mvvm -clean
      forge make Login -viper -clean
      forge make Login -mvi
      forge make Login -tca -clean
      forge make Login -mvvm -form
      forge make Login -mvvm -list
      forge make Login --no-domain
      forge make Login --tests
      forge make Login -mvvm --tests
    """

    /// Returns `true` when the argument is a help flag (`-h`, `--help`, or the literal `help`).
    static func isHelpFlag(_ argument: String) -> Bool {
        argument == "help" || argument == "--help" || argument == "-h"
    }

    /// Comprehensive help text shown by `forge help`, `forge --help`, or `forge -h`.
    static let help = """
    forge - SwiftUI feature scaffolding tool

    USAGE:
      forge make <FeatureName> [options]
      forge help

    COMMANDS:
      make    Generate a new SwiftUI feature scaffold
      help    Show this help message

    MAKE OPTIONS:
      --path <dir>          Project root directory (default: current directory)
      --package             Generate a Package.swift manifest
      --target <name>       Swift package target name (requires --path)
      -clean, --clean       Include Clean Architecture layers (Domain + Data)
      --no-domain           Skip Domain layer files (implies --clean)
      --tests               Generate XCTest files for the architecture

    ARCHITECTURE FLAGS (pick one):
      -mvvm                 Model-View-ViewModel
      -mvi                  Model-View-Intent
      -viper                View-Interactor-Presenter-Entity-Router
      -vip                  View-Interactor-Presenter
      -mvp                  Model-View-Presenter
      -tca                  The Composable Architecture

    CATEGORY FLAGS (optional, pick one):
      -form                 Form view with two input fields and submit button
      -list                 List view connected to an array in the ViewModel

    When no architecture flag is provided, Forge prompts you interactively.

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
      TCA:        Feature, View

      Adding -clean appends Domain and Data layer files to any architecture.
      Adding --tests appends XCTest files for the selected architecture.

    EXAMPLES:
      forge make Login
      forge make Login -mvvm
      forge make Login -mvvm -clean
      forge make Login -mvvm --tests
      forge make Login -tca -clean --tests
      forge make Login --path /path/to/MyApp
      forge make Login --path /path/to/MyApp --package
      forge make Login --path /path/to/MyPackage --target FeatureKit
      forge make Login --path /path/to/MyApp --no-domain
    """

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

        // Initialize default options before argument iteration
        var projectPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        var shouldCreatePackage = false
        var packageTarget: String?
        var shouldSkipDomain = false
        var shouldGenerateTests = false
        var selectedPresentation: PresentationArchitecture?
        var selectedCategory: FeatureCategory?
        var hasCleanFlag = false
        var positional: [String] = []
        var index = 1

        // Loop through arguments starting after 'make' (index 1)
        while index < arguments.count {
            let argument = arguments[index]

            // Check argument against supported flag parsers; each helper increments index if matched
            if try parsePathFlag(argument, arguments: arguments, at: &index, projectPath: &projectPath) { continue }
            if parsePackageFlag(argument, at: &index, shouldCreatePackage: &shouldCreatePackage) { continue }
            if try parseTargetFlag(argument, arguments: arguments, at: &index, packageTarget: &packageTarget) { continue }
            if parseCleanFlag(argument, at: &index, hasCleanFlag: &hasCleanFlag) { continue }
            if parseNoDomainFlag(argument, at: &index, shouldSkipDomain: &shouldSkipDomain) { continue }
            if parseTestsFlag(argument, at: &index, shouldGenerateTests: &shouldGenerateTests) { continue }
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

        var presentation = selectedPresentation
        var useCleanLayers = hasCleanFlag

        // If user explicitly asks to skip domain files, Clean Architecture layers (Data) are implied
        if shouldSkipDomain {
            useCleanLayers = true
        }

        // If no architecture or clean flag provided, enter interactive terminal mode
        if presentation == nil && !hasCleanFlag {
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
            // If only -clean was passed with no specific presentation flag, default to MVVM
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
            category: selectedCategory
        )
    }

    /// Executes the command: validates the feature name, generates files, prints results.
    /// - Throws: `ForgeError` on validation failures, file conflicts, or cancellation.
    func run() throws {
        // Validate and normalize the feature name into PascalCase
        let feature = try FeatureName(rawValue: featureName)
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
            category: category
        )
        // Generate templates and write files to disk
        let result = try generator.generate(feature: feature, selection: resolvedSelection)

        // Output summary of created files
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
        _ argument: String, arguments: [String], at index: inout Int, projectPath: inout URL
    ) throws -> Bool {
        guard argument == "--path" else { return false }
        let nextIndex = index + 1
        guard nextIndex < arguments.count else {
            throw ForgeError.invalidArguments("Missing value for --path.")
        }
        projectPath = URL(fileURLWithPath: arguments[nextIndex], isDirectory: true)
        index += 2
        return true
    }

    /// Handles `--package`: sets `shouldCreatePackage` and advances the index.
    private static func parsePackageFlag(
        _ argument: String, at index: inout Int, shouldCreatePackage: inout Bool
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
        guard nextIndex < arguments.count else {
            throw ForgeError.invalidArguments("Missing value for --target.")
        }
        packageTarget = arguments[nextIndex]
        index += 2
        return true
    }

    /// Handles `-clean` / `--clean`: sets `hasCleanFlag` and advances the index.
    private static func parseCleanFlag(
        _ argument: String, at index: inout Int, hasCleanFlag: inout Bool
    ) -> Bool {
        guard argument == "-clean" || argument == "--clean" else { return false }
        hasCleanFlag = true
        index += 1
        return true
    }

    /// Handles `--no-domain`: sets `shouldSkipDomain` and advances the index.
    private static func parseNoDomainFlag(
        _ argument: String, at index: inout Int, shouldSkipDomain: inout Bool
    ) -> Bool {
        guard argument == "--no-domain" else { return false }
        shouldSkipDomain = true
        index += 1
        return true
    }

    /// Handles `--tests`: sets `shouldGenerateTests` and advances the index.
    private static func parseTestsFlag(
        _ argument: String, at index: inout Int, shouldGenerateTests: inout Bool
    ) -> Bool {
        guard argument == "--tests" else { return false }
        shouldGenerateTests = true
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
