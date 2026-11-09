import XCTest
@testable import forge

final class ProjectConfigTests: XCTestCase {

    var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectConfigTests_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try super.tearDownWithError()
    }

    // MARK: - YAMLParser Tests

    func testYAMLParserBasicKeyValues() throws {
        let yaml = """
        architecture: mvvm
        version: 1
        name: "My App"
        enabled: true
        disabled: false
        """
        let parsed = try YAMLParser.parse(yaml)
        XCTAssertEqual(parsed["architecture"] as? String, "mvvm")
        XCTAssertEqual(parsed["version"] as? Int, 1)
        XCTAssertEqual(parsed["name"] as? String, "My App")
        XCTAssertEqual(parsed["enabled"] as? Bool, true)
        XCTAssertEqual(parsed["disabled"] as? Bool, false)
    }

    func testYAMLParserNestedMappings() throws {
        let yaml = """
        architecture: viper
        flags:
          clean: true
          tests: false
        paths:
          root: Sources/Features
          package: true
        """
        let parsed = try YAMLParser.parse(yaml)
        XCTAssertEqual(parsed["architecture"] as? String, "viper")

        let flags = try XCTUnwrap(parsed["flags"] as? [String: Any])
        XCTAssertEqual(flags["clean"] as? Bool, true)
        XCTAssertEqual(flags["tests"] as? Bool, false)

        let paths = try XCTUnwrap(parsed["paths"] as? [String: Any])
        XCTAssertEqual(paths["root"] as? String, "Sources/Features")
        XCTAssertEqual(paths["package"] as? Bool, true)
    }

    func testYAMLParserCommentsAndBlankLines() throws {
        let yaml = """
        # Global configuration
        architecture: mvi # selected pattern

        # Paths block
        paths:
          root: "App/Modules" # target directory
        """
        let parsed = try YAMLParser.parse(yaml)
        XCTAssertEqual(parsed["architecture"] as? String, "mvi")
        let paths = try XCTUnwrap(parsed["paths"] as? [String: Any])
        XCTAssertEqual(paths["root"] as? String, "App/Modules")
    }

    func testYAMLParserSyntaxErrorMissingColon() {
        let yaml = """
        architecture mvvm
        """
        XCTAssertThrowsError(try YAMLParser.parse(yaml)) { error in
            guard case YAMLParser.ParserError.invalidSyntax = error else {
                return XCTFail("Expected invalidSyntax error, got \(error)")
            }
        }
    }

    func testYAMLParserDuplicateKeyThrows() {
        let yaml = """
        architecture: mvvm
        architecture: viper
        """
        XCTAssertThrowsError(try YAMLParser.parse(yaml)) { error in
            guard case YAMLParser.ParserError.invalidSyntax(_, let message) = error else {
                return XCTFail("Expected invalidSyntax error, got \(error)")
            }
            XCTAssertTrue(message.contains("Duplicate key"))
        }
    }

    func testYAMLParserTabsIndentationThrows() {
        let yaml = "flags:\n\tclean: true"
        XCTAssertThrowsError(try YAMLParser.parse(yaml)) { error in
            guard case YAMLParser.ParserError.invalidSyntax(_, let message) = error else {
                return XCTFail("Expected invalidSyntax error, got \(error)")
            }
            XCTAssertTrue(message.contains("Tabs are not allowed"))
        }
    }

    func testYAMLParserCommentWithoutWhitespaceTreatedAsValue() throws {
        let yaml = """
        color: foo#bar
        note: hello # world
        """
        let parsed = try YAMLParser.parse(yaml)
        XCTAssertEqual(parsed["color"] as? String, "foo#bar")
        XCTAssertEqual(parsed["note"] as? String, "hello")
    }

    // MARK: - ProjectConfig Model Tests

    func testProjectConfigInitialization() throws {
        let yaml = """
        architecture: viper
        flags:
          clean: true
          no_domain: false
          tests: true
        paths:
          root: Sources/Modules
          package: true
          target: FeatureKit
        naming:
          type_prefix: App
          type_suffix: Feature
          folder_prefix: Mod
          folder_suffix: ""
          strip_redundant_suffix: true
        """
        let dict = try YAMLParser.parse(yaml)
        let config = try ProjectConfig(from: dict)

        XCTAssertEqual(config.architecture, .viper)
        XCTAssertTrue(config.flags.clean)
        XCTAssertFalse(config.flags.noDomain)
        XCTAssertTrue(config.flags.tests)
        XCTAssertEqual(config.paths.root, "Sources/Modules")
        XCTAssertTrue(config.paths.package)
        XCTAssertEqual(config.paths.target, "FeatureKit")
        XCTAssertEqual(config.naming.typePrefix, "App")
        XCTAssertEqual(config.naming.typeSuffix, "Feature")
        XCTAssertEqual(config.naming.folderPrefix, "Mod")
        XCTAssertTrue(config.naming.stripRedundantSuffix)
    }

    func testProjectConfigInvalidArchitectureThrows() throws {
        let yaml = """
        architecture: invalid_arch
        """
        let dict = try YAMLParser.parse(yaml)
        XCTAssertThrowsError(try ProjectConfig(from: dict))
    }

    func testProjectConfigUnknownTopLevelKeyThrows() throws {
        let yaml = """
        architecture: mvvm
        unknown_key: true
        """
        let dict = try YAMLParser.parse(yaml)
        XCTAssertThrowsError(try ProjectConfig(from: dict)) { error in
            guard case ForgeError.invalidArguments(let msg) = error else {
                return XCTFail("Expected invalidArguments, got \(error)")
            }
            XCTAssertTrue(msg.contains("Unknown configuration key 'unknown_key'"))
        }
    }

    func testProjectConfigUnknownFlagKeyThrows() throws {
        let yaml = """
        architecture: mvvm
        flags:
          clean: true
          invalid_flag: true
        """
        let dict = try YAMLParser.parse(yaml)
        XCTAssertThrowsError(try ProjectConfig(from: dict)) { error in
            guard case ForgeError.invalidArguments(let msg) = error else {
                return XCTFail("Expected invalidArguments, got \(error)")
            }
            XCTAssertTrue(msg.contains("Unknown flag 'invalid_flag'"))
        }
    }

    func testProjectConfigUnknownPathKeyThrows() throws {
        let yaml = """
        paths:
          wrong_path_key: "abc"
        """
        let dict = try YAMLParser.parse(yaml)
        XCTAssertThrowsError(try ProjectConfig(from: dict))
    }

    func testProjectConfigUnknownNamingKeyThrows() throws {
        let yaml = """
        naming:
          unknown_naming: "abc"
        """
        let dict = try YAMLParser.parse(yaml)
        XCTAssertThrowsError(try ProjectConfig(from: dict))
    }

    func testProjectConfigWrongTypeThrows() throws {
        let yaml = """
        flags:
          tests: "maybe"
        """
        let dict = try YAMLParser.parse(yaml)
        XCTAssertThrowsError(try ProjectConfig(from: dict)) { error in
            guard case ForgeError.invalidArguments(let msg) = error else {
                return XCTFail("Expected invalidArguments, got \(error)")
            }
            XCTAssertTrue(msg.contains("Expected boolean for 'flags.tests'"))
        }
    }

    func testProjectConfigStarterTemplateParsesSuccessfully() throws {
        let dict = try YAMLParser.parse(ProjectConfig.starterTemplate)
        let config = try ProjectConfig(from: dict)
        XCTAssertEqual(config.architecture, .mvvm)
        XCTAssertFalse(config.flags.clean)
        XCTAssertFalse(config.flags.tests)
        XCTAssertNil(config.paths.root)
        XCTAssertNil(config.paths.target)
        XCTAssertTrue(config.naming.stripRedundantPrefix)
        XCTAssertTrue(config.naming.stripRedundantSuffix)
    }

    // MARK: - ConfigLoader Tests

    func testConfigLoaderDiscoversFileInDirectory() throws {
        let configFile = tempDirectory.appendingPathComponent(".forge.yml")
        try "architecture: mvp\n".write(to: configFile, atomically: true, encoding: .utf8)

        let loaded = try ConfigLoader.load(startingDirectory: tempDirectory)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.config.architecture, .mvp)
        XCTAssertEqual(loaded?.fileURL.path, configFile.path)
    }

    func testConfigLoaderDiscoversFileViaUpwardTraversal() throws {
        // Root has .forge.yml and .git marker
        let rootDir = tempDirectory.appendingPathComponent("RepoRoot", isDirectory: true)
        let subDir = rootDir.appendingPathComponent("App/Sources/Subfolder", isDirectory: true)
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: rootDir.appendingPathComponent(".git"), withIntermediateDirectories: true)

        let configFile = rootDir.appendingPathComponent(".forge.yml")
        try "architecture: vip\n".write(to: configFile, atomically: true, encoding: .utf8)

        let loaded = try ConfigLoader.load(startingDirectory: subDir)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.config.architecture, .vip)
        XCTAssertEqual(loaded?.fileURL.path, configFile.path)
    }

    func testConfigLoaderExplicitPath() throws {
        let explicitFile = tempDirectory.appendingPathComponent("custom_config.yml")
        try "architecture: mvi\n".write(to: explicitFile, atomically: true, encoding: .utf8)

        let loaded = try ConfigLoader.load(explicitPath: explicitFile)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.config.architecture, .mvi)
    }

    func testConfigLoaderMissingExplicitPathThrows() {
        let missing = tempDirectory.appendingPathComponent("missing.yml")
        XCTAssertThrowsError(try ConfigLoader.load(explicitPath: missing))
    }

    // MARK: - FeatureName Naming Tests

    func testFeatureNameWithoutNamingConfig() throws {
        let name = try FeatureName(rawValue: "login")
        XCTAssertEqual(name.typeName, "Login")
        XCTAssertEqual(name.folderName, "Login")
    }

    func testFeatureNameWithTypePrefixAndSuffix() throws {
        let naming = NamingConfig(
            typePrefix: "App",
            typeSuffix: "Feature",
            folderPrefix: "",
            folderSuffix: "",
            stripRedundantSuffix: true
        )
        let name = try FeatureName(rawValue: "profile", naming: naming)
        XCTAssertEqual(name.typeName, "AppProfileFeature")
        XCTAssertEqual(name.folderName, "Profile")
    }

    func testFeatureNameDeduplicatesSuffixWhenConfigured() throws {
        let naming = NamingConfig(
            typePrefix: "",
            typeSuffix: "Feature",
            folderPrefix: "",
            folderSuffix: "",
            stripRedundantSuffix: true
        )
        // User typed "profile_feature" which normalizes to "ProfileFeature"
        let name = try FeatureName(rawValue: "profile_feature", naming: naming)
        XCTAssertEqual(name.typeName, "ProfileFeature") // NOT ProfileFeatureFeature
    }

    func testFeatureNameFolderPrefixAndSuffix() throws {
        let naming = NamingConfig(
            typePrefix: "",
            typeSuffix: "",
            folderPrefix: "Feature",
            folderSuffix: "Module",
            stripRedundantSuffix: true
        )
        let name = try FeatureName(rawValue: "orders", naming: naming)
        XCTAssertEqual(name.typeName, "Orders")
        XCTAssertEqual(name.folderName, "FeatureOrdersModule")
    }

    func testFeatureNameDeduplicatesPrefixWhenConfigured() throws {
        let naming = NamingConfig(
            typePrefix: "App",
            typeSuffix: "",
            folderPrefix: "App",
            folderSuffix: "",
            stripRedundantSuffix: true,
            stripRedundantPrefix: true
        )
        // User typed "app_login" which normalizes to "AppLogin"
        let name = try FeatureName(rawValue: "app_login", naming: naming)
        XCTAssertEqual(name.typeName, "AppLogin") // NOT AppAppLogin
        XCTAssertEqual(name.folderName, "AppLogin") // NOT AppAppLogin
    }

    func testFeatureNameInvalidPrefixThrows() {
        let naming = NamingConfig(
            typePrefix: "123Invalid",
            typeSuffix: "",
            folderPrefix: "",
            folderSuffix: ""
        )
        XCTAssertThrowsError(try FeatureName(rawValue: "profile", naming: naming)) { error in
            guard case ForgeError.invalidArguments = error else {
                return XCTFail("Expected invalidArguments, got \(error)")
            }
        }
    }

    func testFeatureNameInvalidFolderPrefixThrows() {
        let naming = NamingConfig(
            typePrefix: "",
            typeSuffix: "",
            folderPrefix: "illegal/folder",
            folderSuffix: ""
        )
        XCTAssertThrowsError(try FeatureName(rawValue: "profile", naming: naming)) { error in
            guard case ForgeError.invalidArguments = error else {
                return XCTFail("Expected invalidArguments, got \(error)")
            }
        }
    }

    // MARK: - forge init Command Tests

    func testCommandRunInitCreatesFile() throws {
        try Command.runInit(arguments: ["init", "--path", tempDirectory.path])
        let created = tempDirectory.appendingPathComponent(".forge.yml")
        XCTAssertTrue(FileManager.default.fileExists(atPath: created.path))

        let content = try String(contentsOf: created, encoding: .utf8)
        XCTAssertTrue(content.contains("architecture: mvvm"))
    }

    func testCommandRunInitRefusesToOverwriteWithoutForce() throws {
        let created = tempDirectory.appendingPathComponent(".forge.yml")
        try "custom: true".write(to: created, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try Command.runInit(arguments: ["init", "--path", tempDirectory.path]))
    }

    func testCommandRunInitOverwritesWithForce() throws {
        let created = tempDirectory.appendingPathComponent(".forge.yml")
        try "custom: true".write(to: created, atomically: true, encoding: .utf8)

        try Command.runInit(arguments: ["init", "--path", tempDirectory.path, "--force"])
        let content = try String(contentsOf: created, encoding: .utf8)
        XCTAssertTrue(content.contains("architecture: mvvm"))
    }

    // MARK: - Command.parse with .forge.yml Integration Tests

    func testCommandUsesArchitectureFromConfig() throws {
        let configFile = tempDirectory.appendingPathComponent(".forge.yml")
        try "architecture: viper\n".write(to: configFile, atomically: true, encoding: .utf8)

        let command = try Command.parse(arguments: [
            "make", "Profile", "--path", tempDirectory.path
        ])
        XCTAssertEqual(command.type, .viper)
        XCTAssertEqual(command.loadedConfigURL?.path, configFile.path)
    }

    func testCommandCLIArchitectureOverridesConfig() throws {
        let configFile = tempDirectory.appendingPathComponent(".forge.yml")
        try "architecture: viper\n".write(to: configFile, atomically: true, encoding: .utf8)

        // Passing -mvi on CLI should override viper from config
        let command = try Command.parse(arguments: [
            "make", "Profile", "-mvi", "--path", tempDirectory.path
        ])
        XCTAssertEqual(command.type, .mvi)
    }

    func testCommandAppliesFlagsFromConfig() throws {
        let configFile = tempDirectory.appendingPathComponent(".forge.yml")
        let yaml = """
        architecture: mvvm
        flags:
          clean: true
          tests: true
        paths:
          package: true
          target: CoreKit
        """
        try yaml.write(to: configFile, atomically: true, encoding: .utf8)

        let command = try Command.parse(arguments: [
            "make", "Profile", "--path", tempDirectory.path
        ])
        XCTAssertEqual(command.type, .cleanMVVM)
        XCTAssertTrue(command.shouldGenerateTests)
        XCTAssertTrue(command.shouldCreatePackage)
        XCTAssertEqual(command.packageTarget, "CoreKit")
    }

    func testCommandNegativeFlagsOverrideConfig() throws {
        let configFile = tempDirectory.appendingPathComponent(".forge.yml")
        let yaml = """
        architecture: mvvm
        flags:
          clean: true
          tests: true
        """
        try yaml.write(to: configFile, atomically: true, encoding: .utf8)

        // Pass --no-clean and --no-tests to override config
        let command = try Command.parse(arguments: [
            "make", "Profile", "--no-clean", "--no-tests", "--path", tempDirectory.path
        ])
        XCTAssertEqual(command.type, .mvvm) // Clean disabled
        XCTAssertFalse(command.shouldGenerateTests)
    }

    func testCommandConfigPathsRootResolution() throws {
        let configFile = tempDirectory.appendingPathComponent(".forge.yml")
        let yaml = """
        architecture: mvvm
        paths:
          root: Sources/Features
        """
        try yaml.write(to: configFile, atomically: true, encoding: .utf8)

        let command = try Command.parse(arguments: [
            "make", "Profile", "--config", configFile.path
        ])
        XCTAssertEqual(
            command.projectPath.standardizedFileURL.path,
            tempDirectory.appendingPathComponent("Sources/Features").standardizedFileURL.path
        )
    }

    func testCommandAppliesNamingConventionsFromConfig() throws {
        let configFile = tempDirectory.appendingPathComponent(".forge.yml")
        let yaml = """
        architecture: mvvm
        naming:
          type_prefix: App
          type_suffix: Feature
        """
        try yaml.write(to: configFile, atomically: true, encoding: .utf8)

        let command = try Command.parse(arguments: [
            "make", "Profile", "--config", configFile.path
        ])
        XCTAssertEqual(command.naming.typePrefix, "App")
        XCTAssertEqual(command.naming.typeSuffix, "Feature")

        let feature = try FeatureName(rawValue: command.featureName, naming: command.naming)
        XCTAssertEqual(feature.typeName, "AppProfileFeature")
    }

    func testCommandNoCleanOverridesConfigNoDomain() throws {
        let configFile = tempDirectory.appendingPathComponent(".forge.yml")
        let yaml = """
        architecture: mvvm
        flags:
          no_domain: true
        """
        try yaml.write(to: configFile, atomically: true, encoding: .utf8)

        let command = try Command.parse(arguments: [
            "make", "Profile", "--no-clean", "--config", configFile.path
        ])
        XCTAssertEqual(command.type, .mvvm)
        XCTAssertFalse(command.shouldSkipDomain)
    }

    func testCommandDomainFlagOverridesConfigNoDomain() throws {
        let configFile = tempDirectory.appendingPathComponent(".forge.yml")
        let yaml = """
        architecture: mvvm
        flags:
          no_domain: true
        """
        try yaml.write(to: configFile, atomically: true, encoding: .utf8)

        let command = try Command.parse(arguments: [
            "make", "Profile", "--domain", "--config", configFile.path
        ])
        XCTAssertEqual(command.type, .cleanMVVM)
        XCTAssertFalse(command.shouldSkipDomain)
    }

    // MARK: - Binding Strategy Tests

    func testProjectConfigBindingCombine() throws {
        let yaml = """
        architecture: mvvm
        binding: combine
        """
        let dict = try YAMLParser.parse(yaml)
        let config = try ProjectConfig(from: dict)
        XCTAssertEqual(config.binding, .combine)
    }

    func testProjectConfigBindingConcurrency() throws {
        let yaml = """
        architecture: mvvm
        binding: concurrency
        """
        let dict = try YAMLParser.parse(yaml)
        let config = try ProjectConfig(from: dict)
        XCTAssertEqual(config.binding, .concurrency)
    }

    func testProjectConfigBindingAliases() throws {
        for alias in ["swift-concurrency", "swift_concurrency", "observation"] {
            let yaml = """
            architecture: mvvm
            binding: \(alias)
            """
            let dict = try YAMLParser.parse(yaml)
            let config = try ProjectConfig(from: dict)
            XCTAssertEqual(config.binding, .concurrency, "Failed for alias \(alias)")
        }
    }

    func testProjectConfigBindingDefaultIsCombine() throws {
        let yaml = """
        architecture: mvvm
        """
        let dict = try YAMLParser.parse(yaml)
        let config = try ProjectConfig(from: dict)
        XCTAssertEqual(config.binding, .combine)
    }

    func testProjectConfigStarterTemplateHasCombineBinding() throws {
        let dict = try YAMLParser.parse(ProjectConfig.starterTemplate)
        let config = try ProjectConfig(from: dict)
        XCTAssertEqual(config.binding, .combine)
    }

    func testProjectConfigInvalidBindingThrows() throws {
        let yaml = """
        architecture: mvvm
        binding: reactive_swift
        """
        let dict = try YAMLParser.parse(yaml)
        XCTAssertThrowsError(try ProjectConfig(from: dict)) { error in
            guard case ForgeError.invalidArguments(let msg) = error else {
                return XCTFail("Expected invalidArguments, got \(error)")
            }
            XCTAssertTrue(msg.contains("Invalid binding"))
            XCTAssertTrue(msg.contains("reactive_swift"))
        }
    }

    func testProjectConfigInvalidBindingTypeThrows() throws {
        let yaml = """
        architecture: mvvm
        binding: 123
        """
        let dict = try YAMLParser.parse(yaml)
        XCTAssertThrowsError(try ProjectConfig(from: dict)) { error in
            guard case ForgeError.invalidArguments(let msg) = error else {
                return XCTFail("Expected invalidArguments, got \(error)")
            }
            XCTAssertTrue(msg.contains("Expected string for 'binding'"))
        }
    }

    func testCommandUsesBindingFromConfig() throws {
        let configFile = tempDirectory.appendingPathComponent(".forge.yml")
        let yaml = """
        architecture: mvvm
        binding: concurrency
        """
        try yaml.write(to: configFile, atomically: true, encoding: .utf8)

        let command = try Command.parse(arguments: [
            "make", "Profile", "--config", configFile.path
        ])
        XCTAssertEqual(command.binding, .concurrency)
    }

    func testFeatureGenerationWithConcurrencyBinding() throws {
        let configFile = tempDirectory.appendingPathComponent(".forge.yml")
        let yaml = """
        architecture: mvvm
        binding: concurrency
        paths:
          package: true
        """
        try yaml.write(to: configFile, atomically: true, encoding: .utf8)

        let command = try Command.parse(arguments: [
            "make", "Feed", "--config", configFile.path, "--path", tempDirectory.path
        ])
        try command.run()

        // Check ViewModel uses @Observable and Observation
        let vmPath = tempDirectory.appendingPathComponent("Feed/Sources/Feed/Presentation/FeedViewModel.swift")
        XCTAssertTrue(FileManager.default.fileExists(atPath: vmPath.path))
        let vmContent = try String(contentsOf: vmPath, encoding: .utf8)
        XCTAssertTrue(vmContent.contains("import Observation"))
        XCTAssertFalse(vmContent.contains("import Combine"))
        XCTAssertTrue(vmContent.contains("@Observable"))
        XCTAssertFalse(vmContent.contains("ObservableObject"))
        XCTAssertFalse(vmContent.contains("@Published"))

        // Check View uses @State instead of @StateObject
        let viewPath = tempDirectory.appendingPathComponent("Feed/Sources/Feed/Presentation/FeedView.swift")
        XCTAssertTrue(FileManager.default.fileExists(atPath: viewPath.path))
        let viewContent = try String(contentsOf: viewPath, encoding: .utf8)
        XCTAssertTrue(viewContent.contains("@State private var viewModel: FeedViewModel"))
        XCTAssertFalse(viewContent.contains("@StateObject"))

        // Check Package.swift specifies iOS 17 and macOS 14 for Concurrency
        let pkgPath = tempDirectory.appendingPathComponent("Feed/Package.swift")
        XCTAssertTrue(FileManager.default.fileExists(atPath: pkgPath.path))
        let pkgContent = try String(contentsOf: pkgPath, encoding: .utf8)
        XCTAssertTrue(pkgContent.contains(".iOS(.v17)"))
        XCTAssertTrue(pkgContent.contains(".macOS(.v14)"))
    }

    func testFeatureGenerationWithConcurrencyFormBinding() throws {
        let featureDir = tempDirectory.appendingPathComponent("FormsTest", isDirectory: true)
        try FileManager.default.createDirectory(at: featureDir, withIntermediateDirectories: true)
        let configFile = featureDir.appendingPathComponent(".forge.yml")
        let yaml = """
        architecture: mvvm
        binding: concurrency
        """
        try yaml.write(to: configFile, atomically: true, encoding: .utf8)

        let command = try Command.parse(arguments: [
            "make", "EditProfile", "form", "--config", configFile.path, "--path", featureDir.path
        ])
        try command.run()

        // Check View has @Bindable var viewModel = viewModel
        let viewPath = featureDir.appendingPathComponent("EditProfile/Presentation/EditProfileView.swift")
        XCTAssertTrue(FileManager.default.fileExists(atPath: viewPath.path))
        let viewContent = try String(contentsOf: viewPath, encoding: .utf8)
        XCTAssertTrue(viewContent.contains("@Bindable var viewModel = viewModel"))
        XCTAssertTrue(viewContent.contains("@State private var viewModel: EditProfileViewModel"))
        XCTAssertFalse(viewContent.contains("@StateObject"))
    }

    // MARK: - Testing Framework Tests

    func testProjectConfigTestingXCTest() throws {
        let yaml = """
        architecture: mvvm
        testing: xctest
        """
        let dict = try YAMLParser.parse(yaml)
        let config = try ProjectConfig(from: dict)
        XCTAssertEqual(config.testing, .xctest)
    }

    func testProjectConfigTestingSwiftTesting() throws {
        let yaml = """
        architecture: mvvm
        testing: swift-testing
        """
        let dict = try YAMLParser.parse(yaml)
        let config = try ProjectConfig(from: dict)
        XCTAssertEqual(config.testing, .swiftTesting)
    }

    func testProjectConfigTestingAliases() throws {
        for alias in ["swift-test", "swift_testing", "swift_test", "testing"] {
            let yaml = """
            architecture: mvvm
            testing: \(alias)
            """
            let dict = try YAMLParser.parse(yaml)
            let config = try ProjectConfig(from: dict)
            XCTAssertEqual(config.testing, .swiftTesting, "Failed for alias \(alias)")
        }
    }

    func testProjectConfigTestingDefaultIsXCTest() throws {
        let yaml = """
        architecture: mvvm
        """
        let dict = try YAMLParser.parse(yaml)
        let config = try ProjectConfig(from: dict)
        XCTAssertEqual(config.testing, .xctest)
    }

    func testProjectConfigStarterTemplateHasXCTest() throws {
        let dict = try YAMLParser.parse(ProjectConfig.starterTemplate)
        let config = try ProjectConfig(from: dict)
        XCTAssertEqual(config.testing, .xctest)
    }

    func testProjectConfigInvalidTestingThrows() throws {
        let yaml = """
        architecture: mvvm
        testing: quick_nimble
        """
        let dict = try YAMLParser.parse(yaml)
        XCTAssertThrowsError(try ProjectConfig(from: dict)) { error in
            guard case ForgeError.invalidArguments(let msg) = error else {
                return XCTFail("Expected invalidArguments, got \(error)")
            }
            XCTAssertTrue(msg.contains("Invalid testing framework"))
            XCTAssertTrue(msg.contains("quick_nimble"))
        }
    }

    func testProjectConfigInvalidTestingTypeThrows() throws {
        let yaml = """
        architecture: mvvm
        testing: 123
        """
        let dict = try YAMLParser.parse(yaml)
        XCTAssertThrowsError(try ProjectConfig(from: dict)) { error in
            guard case ForgeError.invalidArguments(let msg) = error else {
                return XCTFail("Expected invalidArguments, got \(error)")
            }
            XCTAssertTrue(msg.contains("Expected string for 'testing'"))
        }
    }

    func testCommandUsesTestingFromConfig() throws {
        let configFile = tempDirectory.appendingPathComponent(".forge.yml")
        let yaml = """
        architecture: mvvm
        testing: swift-testing
        """
        try yaml.write(to: configFile, atomically: true, encoding: .utf8)

        let command = try Command.parse(arguments: [
            "make", "Profile", "--config", configFile.path
        ])
        XCTAssertEqual(command.testing, .swiftTesting)
    }

    func testFeatureGenerationWithSwiftTesting() throws {
        let configFile = tempDirectory.appendingPathComponent(".forge.yml")
        let yaml = """
        architecture: mvvm
        testing: swift-testing
        flags:
          clean: true
          tests: true
        paths:
          package: true
        """
        try yaml.write(to: configFile, atomically: true, encoding: .utf8)

        let command = try Command.parse(arguments: [
            "make", "Profile", "--config", configFile.path, "--path", tempDirectory.path
        ])
        try command.run()

        // Check ViewModelTests uses Swift Testing (@Suite, @Test, #expect)
        let vmTestPath = tempDirectory.appendingPathComponent("Profile/Tests/ProfileTests/ProfileViewModelTests.swift")
        XCTAssertTrue(FileManager.default.fileExists(atPath: vmTestPath.path))
        let vmTestContent = try String(contentsOf: vmTestPath, encoding: .utf8)
        XCTAssertTrue(vmTestContent.contains("import Testing"))
        XCTAssertFalse(vmTestContent.contains("import XCTest"))
        XCTAssertTrue(vmTestContent.contains("@Suite struct ProfileViewModelTests"))
        XCTAssertFalse(vmTestContent.contains("class ProfileViewModelTests: XCTestCase"))
        XCTAssertTrue(vmTestContent.contains("@Test @MainActor"))
        XCTAssertTrue(vmTestContent.contains("#expect("))
        XCTAssertFalse(vmTestContent.contains("XCTAssert"))

        // Check UseCaseTests uses Swift Testing with #expect(throws: ...)
        let ucTestPath = tempDirectory.appendingPathComponent("Profile/Tests/ProfileTests/ProfileUseCaseTests.swift")
        XCTAssertTrue(FileManager.default.fileExists(atPath: ucTestPath.path))
        let ucTestContent = try String(contentsOf: ucTestPath, encoding: .utf8)
        XCTAssertTrue(ucTestContent.contains("import Testing"))
        XCTAssertTrue(ucTestContent.contains("@Suite struct ProfileUseCaseTests"))
        XCTAssertTrue(ucTestContent.contains("#expect(throws: ProfileUseCaseRepositoryStub.Failure.unavailable)"))

        // Check Package.swift sets minimum platforms to iOS 16, macOS 13 for Swift Testing
        let pkgPath = tempDirectory.appendingPathComponent("Profile/Package.swift")
        XCTAssertTrue(FileManager.default.fileExists(atPath: pkgPath.path))
        let pkgContent = try String(contentsOf: pkgPath, encoding: .utf8)
        XCTAssertTrue(pkgContent.contains(".iOS(.v16)"))
        XCTAssertTrue(pkgContent.contains(".macOS(.v13)"))
    }

    // MARK: - Dependency Injection Strategy Tests

    func testProjectConfigDIDefaultIsNative() throws {
        let yaml = """
        architecture: mvvm
        """
        let dict = try YAMLParser.parse(yaml)
        let config = try ProjectConfig(from: dict)
        XCTAssertEqual(config.di, .native)
    }

    func testProjectConfigDINative() throws {
        let yaml = """
        architecture: mvvm
        di: native
        """
        let dict = try YAMLParser.parse(yaml)
        let config = try ProjectConfig(from: dict)
        XCTAssertEqual(config.di, .native)
    }

    func testProjectConfigDIFactory() throws {
        let yaml = """
        architecture: mvvm
        di: factory
        """
        let dict = try YAMLParser.parse(yaml)
        let config = try ProjectConfig(from: dict)
        XCTAssertEqual(config.di, .factory)
    }

    func testProjectConfigDIAliases() throws {
        for alias in ["Factory", "FACTORY", " Native ", "NATIVE"] {
            let yaml = """
            architecture: mvvm
            di: \(alias)
            """
            let dict = try YAMLParser.parse(yaml)
            let config = try ProjectConfig(from: dict)
            if alias.trimmingCharacters(in: .whitespaces).lowercased() == "factory" {
                XCTAssertEqual(config.di, .factory)
            } else {
                XCTAssertEqual(config.di, .native)
            }
        }
    }

    func testProjectConfigDIUnknownThrows() throws {
        let yaml = """
        architecture: mvvm
        di: swinject
        """
        let dict = try YAMLParser.parse(yaml)
        XCTAssertThrowsError(try ProjectConfig(from: dict)) { error in
            guard case ForgeError.invalidArguments(let msg) = error else {
                return XCTFail("Expected invalidArguments, got \(error)")
            }
            XCTAssertTrue(msg.contains("Invalid dependency injection strategy 'swinject'"))
        }
    }

    func testProjectConfigInvalidDITypeThrows() throws {
        let yaml = """
        architecture: mvvm
        di: 42
        """
        let dict = try YAMLParser.parse(yaml)
        XCTAssertThrowsError(try ProjectConfig(from: dict)) { error in
            guard case ForgeError.invalidArguments(let msg) = error else {
                return XCTFail("Expected invalidArguments, got \(error)")
            }
            XCTAssertTrue(msg.contains("Expected string for 'di'"))
        }
    }

    func testCommandUsesDIFromConfig() throws {
        let configFile = tempDirectory.appendingPathComponent(".forge.yml")
        let yaml = """
        architecture: mvvm
        di: factory
        """
        try yaml.write(to: configFile, atomically: true, encoding: .utf8)

        let command = try Command.parse(arguments: [
            "make", "Profile", "--config", configFile.path
        ])
        XCTAssertEqual(command.di, .factory)
    }

    func testFeatureGenerationWithFactoryDI() throws {
        let configFile = tempDirectory.appendingPathComponent(".forge.yml")
        let yaml = """
        architecture: mvvm
        di: factory
        flags:
          clean: true
        """
        try yaml.write(to: configFile, atomically: true, encoding: .utf8)

        let command = try Command.parse(arguments: [
            "make", "UserProfile", "--config", configFile.path, "--path", tempDirectory.path
        ])
        try command.run()

        let containerPath = tempDirectory.appendingPathComponent("UserProfile/UserProfileDependencyContainer.swift")
        XCTAssertTrue(FileManager.default.fileExists(atPath: containerPath.path))
        let containerContent = try String(contentsOf: containerPath, encoding: .utf8)

        XCTAssertTrue(containerContent.contains("import Factory"))
        XCTAssertTrue(containerContent.contains("extension Container {"))
        XCTAssertTrue(containerContent.contains("var userProfileView: Factory<UserProfileView>"))
        XCTAssertTrue(containerContent.contains("var userProfileViewModel: Factory<UserProfileViewModel>"))
        XCTAssertTrue(containerContent.contains("var userProfileUseCase: Factory<UserProfileUseCase>"))
        XCTAssertTrue(containerContent.contains("var userProfileRepository: Factory<UserProfileRepository>"))
        XCTAssertTrue(containerContent.contains("var userProfileRemoteDataSource: Factory<UserProfileRemoteDataSource>"))
        XCTAssertTrue(containerContent.contains("Container.shared.userProfileView()"))
        XCTAssertTrue(containerContent.contains("Container.shared.userProfileViewModel()"))
        XCTAssertTrue(containerContent.contains("Container.shared.userProfileUseCase()"))
        XCTAssertTrue(containerContent.contains("Container.shared.userProfileRepository()"))
        XCTAssertTrue(containerContent.contains("Container.shared.userProfileRemoteDataSource()"))
    }

    func testFeatureGenerationWithFactoryDIAndPackage() throws {
        let configFile = tempDirectory.appendingPathComponent(".forge.yml")
        let yaml = """
        architecture: mvvm
        di: factory
        flags:
          tests: true
        paths:
          package: true
        """
        try yaml.write(to: configFile, atomically: true, encoding: .utf8)

        let command = try Command.parse(arguments: [
            "make", "Auth", "--config", configFile.path, "--path", tempDirectory.path
        ])
        try command.run()

        let pkgPath = tempDirectory.appendingPathComponent("Auth/Package.swift")
        XCTAssertTrue(FileManager.default.fileExists(atPath: pkgPath.path))
        let pkgContent = try String(contentsOf: pkgPath, encoding: .utf8)

        XCTAssertTrue(pkgContent.contains("https://github.com/hmlongco/Factory.git"))
        XCTAssertTrue(pkgContent.contains(".product(name: \"Factory\", package: \"Factory\")"))

        let containerPath = tempDirectory.appendingPathComponent("Auth/Sources/Auth/AuthDependencyContainer.swift")
        XCTAssertTrue(FileManager.default.fileExists(atPath: containerPath.path))
        let containerContent = try String(contentsOf: containerPath, encoding: .utf8)
        XCTAssertTrue(containerContent.contains("import Factory"))
        XCTAssertTrue(containerContent.contains("extension Container {"))
        XCTAssertTrue(containerContent.contains("var authView: Factory<AuthView>"))
        XCTAssertTrue(containerContent.contains("var authViewModel: Factory<AuthViewModel>"))
    }

    // MARK: - Regression & Edge Case Tests

    func testYAMLParserHandlesCRLF() throws {
        let crlfYAML = "architecture: mvvm\r\nbinding: concurrency\r\ntesting: swift-testing\r\ndi: factory\r\nflags:\r\n  clean: true\r\n"
        let parsed = try YAMLParser.parse(crlfYAML)
        let config = try ProjectConfig(from: parsed)
        XCTAssertEqual(config.architecture, .mvvm)
        XCTAssertEqual(config.binding, .concurrency)
        XCTAssertEqual(config.testing, .swiftTesting)
        XCTAssertEqual(config.di, .factory)
        XCTAssertTrue(config.flags.clean)
    }

    func testFeatureNameDoesNotStripPartialWordPrefix() throws {
        let naming = NamingConfig(
            typePrefix: "App",
            typeSuffix: "View",
            folderPrefix: "App",
            folderSuffix: "",
            stripRedundantSuffix: true,
            stripRedundantPrefix: true
        )
        // "appointments" has base name "Appointments" which starts with "App",
        // but 'o' is lowercase so it's a single word, not a pre-existing "App" prefix.
        let name = try FeatureName(rawValue: "appointments", naming: naming)
        XCTAssertEqual(name.typeName, "AppAppointmentsView")
        XCTAssertEqual(name.folderName, "AppAppointments")

        // In contrast, "app_login" has distinct "App" component, so it should not be duplicated.
        let name2 = try FeatureName(rawValue: "app_login", naming: naming)
        XCTAssertEqual(name2.typeName, "AppLoginView")
        XCTAssertEqual(name2.folderName, "AppLogin")
    }

    func testFeatureNameDoesNotStripPartialWordSuffix() throws {
        let naming = NamingConfig(
            typePrefix: "",
            typeSuffix: "test",
            folderPrefix: "",
            folderSuffix: "test",
            stripRedundantSuffix: true,
            stripRedundantPrefix: true
        )
        // "smartest" ends in "test", but preceding letter 'r' is lowercase, not a distinct suffix.
        let name = try FeatureName(rawValue: "smartest", naming: naming)
        XCTAssertEqual(name.typeName, "Smartesttest")
        XCTAssertEqual(name.folderName, "Smartesttest")
    }

    func testFlagValueSwallowingThrows() {
        XCTAssertThrowsError(try Command.parse(arguments: ["make", "Login", "--path", "-mvvm"])) { error in
            guard case ForgeError.invalidArguments(let msg) = error else {
                return XCTFail("Expected invalidArguments, got \(error)")
            }
            XCTAssertTrue(msg.contains("Missing value for --path"))
        }

        XCTAssertThrowsError(try Command.parse(arguments: ["make", "Login", "--config", "-mvvm"])) { error in
            guard case ForgeError.invalidArguments(let msg) = error else {
                return XCTFail("Expected invalidArguments, got \(error)")
            }
            XCTAssertTrue(msg.contains("Missing value for --config"))
        }

        XCTAssertThrowsError(try Command.parse(arguments: ["make", "Login", "--target", "-clean"])) { error in
            guard case ForgeError.invalidArguments(let msg) = error else {
                return XCTFail("Expected invalidArguments, got \(error)")
            }
            XCTAssertTrue(msg.contains("Missing value for --target"))
        }
    }

    func testContradictoryFlagsThrows() {
        XCTAssertThrowsError(try Command.parse(arguments: ["make", "Login", "-mvvm", "--no-clean", "--no-domain"])) { error in
            guard case ForgeError.invalidArguments(let msg) = error else {
                return XCTFail("Expected invalidArguments, got \(error)")
            }
            XCTAssertTrue(msg.contains("Cannot combine '--no-clean' with '--no-domain'"))
        }

        XCTAssertThrowsError(try Command.parse(arguments: ["make", "Login", "-mvvm", "-clean", "--no-clean"])) { error in
            guard case ForgeError.invalidArguments(let msg) = error else {
                return XCTFail("Expected invalidArguments, got \(error)")
            }
            XCTAssertTrue(msg.contains("Cannot combine '-clean' and '--no-clean'"))
        }

        XCTAssertThrowsError(try Command.parse(arguments: ["make", "Login", "-mvvm", "--domain", "--no-domain"])) { error in
            guard case ForgeError.invalidArguments(let msg) = error else {
                return XCTFail("Expected invalidArguments, got \(error)")
            }
            XCTAssertTrue(msg.contains("Cannot combine '--domain' and '--no-domain'"))
        }

        XCTAssertThrowsError(try Command.parse(arguments: ["make", "Login", "-mvvm", "--tests", "--no-tests"])) { error in
            guard case ForgeError.invalidArguments(let msg) = error else {
                return XCTFail("Expected invalidArguments, got \(error)")
            }
            XCTAssertTrue(msg.contains("Cannot combine '--tests' and '--no-tests'"))
        }
    }

    func testContradictoryConfigFlagsThrows() {
        let dict: [String: Any] = [
            "flags": [
                "clean": false,
                "no_domain": true
            ]
        ]
        XCTAssertThrowsError(try ProjectConfig(from: dict)) { error in
            guard case ForgeError.invalidArguments(let msg) = error else {
                return XCTFail("Expected invalidArguments, got \(error)")
            }
            XCTAssertTrue(msg.contains("Contradictory flags"))
        }
    }

    func testDuplicateConfigKeysThrows() {
        let duplicateFlags: [String: Any] = [
            "flags": [
                "no_domain": true,
                "noDomain": true
            ]
        ]
        XCTAssertThrowsError(try ProjectConfig(from: duplicateFlags)) { error in
            guard case ForgeError.invalidArguments(let msg) = error else {
                return XCTFail("Expected invalidArguments, got \(error)")
            }
            XCTAssertTrue(msg.contains("Cannot specify both 'no_domain' and 'noDomain'"))
        }

        let duplicateNaming: [String: Any] = [
            "naming": [
                "type_prefix": "App",
                "typePrefix": "App"
            ]
        ]
        XCTAssertThrowsError(try ProjectConfig(from: duplicateNaming)) { error in
            guard case ForgeError.invalidArguments(let msg) = error else {
                return XCTFail("Expected invalidArguments, got \(error)")
            }
            XCTAssertTrue(msg.contains("Cannot specify both 'type_prefix' and 'typePrefix'"))
        }
    }

    func testInitRejectsExistingForgeYaml() throws {
        let yamlFile = tempDirectory.appendingPathComponent(".forge.yaml")
        try "architecture: mvvm\n".write(to: yamlFile, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try Command.runInit(arguments: ["init", "--path", tempDirectory.path])) { error in
            guard case ForgeError.invalidArguments(let msg) = error else {
                return XCTFail("Expected invalidArguments, got \(error)")
            }
            XCTAssertTrue(msg.contains(".forge.yaml already exists"))
        }
    }
}

