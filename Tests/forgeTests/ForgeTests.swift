import XCTest
@testable import forge

// MARK: - ForgeTests

final class ForgeTests: XCTestCase {
    var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
        try super.tearDownWithError()
    }

    // MARK: - FeatureName Tests

    func testFeatureNameSimple() throws {
        let name = try FeatureName(rawValue: "Login")
        XCTAssertEqual(name.typeName, "Login")
        XCTAssertEqual(name.folderName, "Login")
    }

    func testFeatureNameFromSpaces() throws {
        let name = try FeatureName(rawValue: "user profile")
        XCTAssertEqual(name.typeName, "UserProfile")
    }

    func testFeatureNameFromDashes() throws {
        let name = try FeatureName(rawValue: "user-profile")
        XCTAssertEqual(name.typeName, "UserProfile")
    }

    func testFeatureNameFromUnderscores() throws {
        let name = try FeatureName(rawValue: "user_profile")
        XCTAssertEqual(name.typeName, "UserProfile")
    }

    func testFeatureNameAlreadyPascalCase() throws {
        let name = try FeatureName(rawValue: "UserProfile")
        XCTAssertEqual(name.typeName, "UserProfile")
    }

    func testFeatureNameInvalidSpecialChars() {
        XCTAssertThrowsError(try FeatureName(rawValue: "Login!")) { error in
            guard case ForgeError.invalidFeatureName = error else {
                return XCTFail("Expected invalidFeatureName error")
            }
        }
    }

    func testFeatureNameInvalidEmpty() {
        XCTAssertThrowsError(try FeatureName(rawValue: "")) { error in
            guard case ForgeError.invalidFeatureName = error else {
                return XCTFail("Expected invalidFeatureName error")
            }
        }
    }

    func testFeatureNameStartsWithNumber() {
        XCTAssertThrowsError(try FeatureName(rawValue: "123Login")) { error in
            guard case ForgeError.invalidFeatureName = error else {
                return XCTFail("Expected invalidFeatureName error")
            }
        }
    }

    func testFeatureNameOnlySpaces() {
        XCTAssertThrowsError(try FeatureName(rawValue: "   ")) { error in
            guard case ForgeError.invalidFeatureName = error else {
                return XCTFail("Expected invalidFeatureName error")
            }
        }
    }

    // MARK: - FeatureType Resolution Tests

    func testResolveCleanMVVM() {
        XCTAssertEqual(FeatureType.resolve(presentation: .mvvm, clean: true), .cleanMVVM)
    }

    func testResolveMVVM() {
        XCTAssertEqual(FeatureType.resolve(presentation: .mvvm, clean: false), .mvvm)
    }

    func testResolveCleanVIPER() {
        XCTAssertEqual(FeatureType.resolve(presentation: .viper, clean: true), .cleanVIPER)
    }

    func testResolveVIPER() {
        XCTAssertEqual(FeatureType.resolve(presentation: .viper, clean: false), .viper)
    }

    func testResolveCleanVIP() {
        XCTAssertEqual(FeatureType.resolve(presentation: .vip, clean: true), .cleanVIP)
    }

    func testResolveVIP() {
        XCTAssertEqual(FeatureType.resolve(presentation: .vip, clean: false), .vip)
    }

    func testResolveCleanMVP() {
        XCTAssertEqual(FeatureType.resolve(presentation: .mvp, clean: true), .cleanMVP)
    }

    func testResolveMVP() {
        XCTAssertEqual(FeatureType.resolve(presentation: .mvp, clean: false), .mvp)
    }

    func testResolveCleanTCA() {
        XCTAssertEqual(FeatureType.resolve(presentation: .tca, clean: true), .cleanTCA)
    }

    func testResolveTCA() {
        XCTAssertEqual(FeatureType.resolve(presentation: .tca, clean: false), .tca)
    }

    func testResolveCleanMVI() {
        XCTAssertEqual(FeatureType.resolve(presentation: .mvi, clean: true), .cleanMVI)
    }

    func testResolveMVI() {
        XCTAssertEqual(FeatureType.resolve(presentation: .mvi, clean: false), .mvi)
    }

    // MARK: - FeatureType hasCleanLayers

    func testHasCleanLayersTrueForCleanVariants() {
        XCTAssertTrue(FeatureType.cleanMVVM.hasCleanLayers)
        XCTAssertTrue(FeatureType.cleanVIPER.hasCleanLayers)
        XCTAssertTrue(FeatureType.cleanVIP.hasCleanLayers)
        XCTAssertTrue(FeatureType.cleanMVP.hasCleanLayers)
        XCTAssertTrue(FeatureType.cleanTCA.hasCleanLayers)
        XCTAssertTrue(FeatureType.cleanMVI.hasCleanLayers)
    }

    func testHasCleanLayersFalseForStandalone() {
        XCTAssertFalse(FeatureType.mvvm.hasCleanLayers)
        XCTAssertFalse(FeatureType.mvi.hasCleanLayers)
        XCTAssertFalse(FeatureType.viper.hasCleanLayers)
        XCTAssertFalse(FeatureType.vip.hasCleanLayers)
        XCTAssertFalse(FeatureType.mvp.hasCleanLayers)
        XCTAssertFalse(FeatureType.tca.hasCleanLayers)
    }

    // MARK: - FeatureType displayName

    func testDisplayNames() {
        XCTAssertEqual(FeatureType.cleanMVVM.displayName, "Clean Architecture + MVVM")
        XCTAssertEqual(FeatureType.cleanVIPER.displayName, "Clean Architecture + VIPER")
        XCTAssertEqual(FeatureType.cleanVIP.displayName, "Clean Architecture + VIP")
        XCTAssertEqual(FeatureType.cleanMVP.displayName, "Clean Architecture + MVP")
        XCTAssertEqual(FeatureType.cleanTCA.displayName, "Clean Architecture + TCA")
        XCTAssertEqual(FeatureType.cleanMVI.displayName, "Clean Architecture + MVI")
        XCTAssertEqual(FeatureType.mvvm.displayName, "MVVM")
        XCTAssertEqual(FeatureType.mvi.displayName, "MVI")
        XCTAssertEqual(FeatureType.viper.displayName, "VIPER")
        XCTAssertEqual(FeatureType.vip.displayName, "VIP")
        XCTAssertEqual(FeatureType.mvp.displayName, "MVP")
        XCTAssertEqual(FeatureType.tca.displayName, "TCA")
    }

    // MARK: - PresentationArchitecture Parsing

    func testParseSingleDashFlag() {
        XCTAssertEqual(PresentationArchitecture.from(flag: "-mvvm"), .mvvm)
        XCTAssertEqual(PresentationArchitecture.from(flag: "-viper"), .viper)
        XCTAssertEqual(PresentationArchitecture.from(flag: "-tca"), .tca)
        XCTAssertEqual(PresentationArchitecture.from(flag: "-mvi"), .mvi)
        XCTAssertEqual(PresentationArchitecture.from(flag: "-vip"), .vip)
        XCTAssertEqual(PresentationArchitecture.from(flag: "-mvp"), .mvp)
    }

    func testParseDoubleDashFlag() {
        XCTAssertEqual(PresentationArchitecture.from(flag: "--mvvm"), .mvvm)
        XCTAssertEqual(PresentationArchitecture.from(flag: "--viper"), .viper)
    }

    func testParseInvalidFlag() {
        XCTAssertNil(PresentationArchitecture.from(flag: "-unknown"))
        XCTAssertNil(PresentationArchitecture.from(flag: "--unknown"))
        // bare "mvvm" is intentionally accepted (no prefix required by the implementation)
        XCTAssertNotNil(PresentationArchitecture.from(flag: "mvvm"))
    }

    func testPresentationArchitectureDescription() {
        XCTAssertEqual(PresentationArchitecture.mvvm.description, "MVVM")
        XCTAssertEqual(PresentationArchitecture.viper.description, "VIPER")
        XCTAssertEqual(PresentationArchitecture.tca.description, "TCA")
    }

    // MARK: - FeatureCategory Parsing

    func testParseCategoryFormFlag() {
        XCTAssertEqual(FeatureCategory.from(flag: "-form"), .form)
        XCTAssertEqual(FeatureCategory.from(flag: "--form"), .form)
    }

    func testParseCategoryListFlag() {
        XCTAssertEqual(FeatureCategory.from(flag: "-list"), .list)
        XCTAssertEqual(FeatureCategory.from(flag: "--list"), .list)
    }

    func testParseCategoryInvalid() {
        XCTAssertNil(FeatureCategory.from(flag: "-unknown"))
    }

    func testCategoryDescription() {
        XCTAssertEqual(FeatureCategory.form.description, "Form")
        XCTAssertEqual(FeatureCategory.list.description, "List")
    }

    // MARK: - FeatureFile Tests

    func testFeatureFileName() {
        XCTAssertEqual(FeatureFile.viewModel.fileName(for: "Login"), "LoginViewModel.swift")
        XCTAssertEqual(FeatureFile.view.fileName(for: "Search"), "SearchView.swift")
        XCTAssertEqual(FeatureFile.dependencyContainer.fileName(for: "Profile"), "ProfileDependencyContainer.swift")
    }

    func testFeatureFileDisplayName() {
        for file in FeatureFile.allCases {
            let expected = file.rawValue.prefix(1).uppercased() + file.rawValue.dropFirst()
            XCTAssertEqual(file.displayName, expected)
        }
    }

    func testFeatureFileIsDomain() {
        XCTAssertTrue(FeatureFile.entity.isDomain)
        XCTAssertTrue(FeatureFile.useCase.isDomain)
        XCTAssertTrue(FeatureFile.repository.isDomain)
        XCTAssertFalse(FeatureFile.view.isDomain)
        XCTAssertFalse(FeatureFile.viewModel.isDomain)
        XCTAssertFalse(FeatureFile.repositoryImpl.isDomain)
    }

    func testFeatureFileIsDomainTest() {
        XCTAssertTrue(FeatureFile.useCaseTests.isDomainTest)
        XCTAssertTrue(FeatureFile.repositoryTests.isDomainTest)
        XCTAssertFalse(FeatureFile.viewModelTests.isDomainTest)
        XCTAssertFalse(FeatureFile.presenterTests.isDomainTest)
    }

    func testFeatureFileIsTest() {
        XCTAssertTrue(FeatureFile.viewModelTests.isTest)
        XCTAssertTrue(FeatureFile.storeTests.isTest)
        XCTAssertTrue(FeatureFile.reducerTests.isTest)
        XCTAssertTrue(FeatureFile.presenterTests.isTest)
        XCTAssertTrue(FeatureFile.interactorTests.isTest)
        XCTAssertTrue(FeatureFile.featureTests.isTest)
        XCTAssertTrue(FeatureFile.useCaseTests.isTest)
        XCTAssertTrue(FeatureFile.repositoryTests.isTest)
        XCTAssertFalse(FeatureFile.view.isTest)
        XCTAssertFalse(FeatureFile.viewModel.isTest)
    }

    func testFeatureFileLayerForViper() {
        XCTAssertEqual(FeatureFile.entity.layer(for: .viper), "Presentation")
        XCTAssertEqual(FeatureFile.entity.layer(for: .cleanMVVM), "Domain")
    }

    func testFeatureFileLayerForVIPAndMVP() {
        XCTAssertEqual(FeatureFile.models.layer(for: .vip), "Presentation")
        XCTAssertEqual(FeatureFile.models.layer(for: .mvp), "Presentation")
        XCTAssertEqual(FeatureFile.models.layer(for: .cleanMVVM), "Data")
    }

    func testFeatureFileDependencyContainerIsRoot() {
        for type in FeatureType.allCases {
            XCTAssertEqual(FeatureFile.dependencyContainer.layer(for: type), "Root",
                           "Expected Root layer for dependencyContainer in \(type.rawValue)")
        }
    }

    // MARK: - FeatureFileSelection Tests

    func testFeatureFileSelectionAllForMVVM() {
        let selection = FeatureFileSelection.all(for: .mvvm)
        XCTAssertTrue(selection.contains(.view))
        XCTAssertTrue(selection.contains(.viewModel))
        XCTAssertTrue(selection.contains(.dependencyContainer))
        XCTAssertFalse(selection.contains(.entity))
        XCTAssertFalse(selection.contains(.useCase))
    }

    func testFeatureFileSelectionAllForCleanMVVM() {
        let selection = FeatureFileSelection.all(for: .cleanMVVM)
        XCTAssertTrue(selection.contains(.view))
        XCTAssertTrue(selection.contains(.viewModel))
        XCTAssertTrue(selection.contains(.entity))
        XCTAssertTrue(selection.contains(.useCase))
        XCTAssertTrue(selection.contains(.repository))
        XCTAssertTrue(selection.contains(.repositoryImpl))
        XCTAssertTrue(selection.contains(.remoteDataSource))
        XCTAssertTrue(selection.contains(.models))
    }

    func testFeatureFileSelectionAllForTCA() {
        let selection = FeatureFileSelection.all(for: .tca)
        XCTAssertTrue(selection.contains(.feature))
        XCTAssertTrue(selection.contains(.view))
        XCTAssertFalse(selection.contains(.viewModel))
        XCTAssertFalse(selection.contains(.dependencyContainer))
    }

    func testFeatureFileSelectionAllForCleanTCA() {
        let selection = FeatureFileSelection.all(for: .cleanTCA)
        XCTAssertTrue(selection.contains(.feature))
        XCTAssertTrue(selection.contains(.view))
        XCTAssertTrue(selection.contains(.useCase))
        XCTAssertTrue(selection.contains(.repositoryImpl))
        XCTAssertFalse(selection.contains(.dependencyContainer))
    }

    func testFeatureFileSelectionAllForMVI() {
        let selection = FeatureFileSelection.all(for: .mvi)
        XCTAssertTrue(selection.contains(.view))
        XCTAssertTrue(selection.contains(.store))
        XCTAssertTrue(selection.contains(.state))
        XCTAssertTrue(selection.contains(.intent))
        XCTAssertTrue(selection.contains(.reducer))
        XCTAssertTrue(selection.contains(.dependencyContainer))
    }

    func testFeatureFileSelectionAllForVIPER() {
        let selection = FeatureFileSelection.all(for: .viper)
        XCTAssertTrue(selection.contains(.view))
        XCTAssertTrue(selection.contains(.presenter))
        XCTAssertTrue(selection.contains(.interactor))
        XCTAssertTrue(selection.contains(.router))
        XCTAssertTrue(selection.contains(.entity))
        XCTAssertTrue(selection.contains(.contracts))
        XCTAssertTrue(selection.contains(.dependencyContainer))
    }

    func testFeatureFileSelectionAllForVIP() {
        let selection = FeatureFileSelection.all(for: .vip)
        XCTAssertTrue(selection.contains(.view))
        XCTAssertTrue(selection.contains(.interactor))
        XCTAssertTrue(selection.contains(.presenter))
        XCTAssertTrue(selection.contains(.worker))
        XCTAssertTrue(selection.contains(.presentationModels))
        XCTAssertTrue(selection.contains(.dependencyContainer))
    }

    func testFeatureFileSelectionAllForMVP() {
        let selection = FeatureFileSelection.all(for: .mvp)
        XCTAssertTrue(selection.contains(.view))
        XCTAssertTrue(selection.contains(.presenter))
        XCTAssertTrue(selection.contains(.model))
        XCTAssertTrue(selection.contains(.dependencyContainer))
    }

    // MARK: - TemplateRenderer Tests

    func testRendererVariableSubstitution() throws {
        let result = try TemplateRenderer.render("entity.stencil", context: ["name": "Login"])
        XCTAssertTrue(result.contains("LoginEntity"))
    }

    func testRendererConditionalIfTrue() throws {
        let result = try TemplateRenderer.render("models.stencil", context: [
            "name": "Login",
            "hasUseCase": true
        ])
        XCTAssertTrue(result.contains("toDomain()"))
    }

    func testRendererConditionalIfFalse() throws {
        let result = try TemplateRenderer.render("models.stencil", context: [
            "name": "Login",
            "hasUseCase": false
        ])
        XCTAssertFalse(result.contains("toDomain()"))
    }

    func testRendererTemplateNotFound() {
        XCTAssertThrowsError(try TemplateRenderer.render("nonexistent.stencil", context: [:])) { error in
            guard case TemplateRenderer.RendererError.templateNotFound = error else {
                return XCTFail("Expected templateNotFound error")
            }
        }
    }

    func testRendererRepositoryImplWithRepository() throws {
        let result = try TemplateRenderer.render("repositoryImpl.stencil", context: [
            "name": "Profile",
            "hasRepository": true
        ])
        XCTAssertTrue(result.contains(": ProfileRepository"))
    }

    func testRendererRepositoryImplWithoutRepository() throws {
        let result = try TemplateRenderer.render("repositoryImpl.stencil", context: [
            "name": "Profile",
            "hasRepository": false
        ])
        XCTAssertFalse(result.contains(": ProfileRepository"))
    }

    // MARK: - Command Parsing Tests

    func testCommandParsingMVVM() throws {
        let command = try Command.parse(arguments: [
            "make", "Login", "--path", tempDirectory.path, "-mvvm"
        ])
        XCTAssertEqual(command.featureName, "Login")
        XCTAssertEqual(command.type, .mvvm)
        XCTAssertFalse(command.shouldGenerateTests)
        XCTAssertFalse(command.shouldCreatePackage)
    }

    func testCommandParsingCleanMVVM() throws {
        let command = try Command.parse(arguments: [
            "make", "Login", "--path", tempDirectory.path, "-mvvm", "-clean"
        ])
        XCTAssertEqual(command.type, .cleanMVVM)
    }

    func testCommandParsingWithTests() throws {
        let command = try Command.parse(arguments: [
            "make", "Login", "--path", tempDirectory.path, "-mvvm", "--tests"
        ])
        XCTAssertTrue(command.shouldGenerateTests)
    }

    func testCommandParsingWithPackage() throws {
        let command = try Command.parse(arguments: [
            "make", "Login", "--path", tempDirectory.path, "-mvvm", "--package"
        ])
        XCTAssertTrue(command.shouldCreatePackage)
    }

    func testCommandParsingWithNoDomain() throws {
        let command = try Command.parse(arguments: [
            "make", "Login", "--path", tempDirectory.path, "-mvvm", "--no-domain"
        ])
        XCTAssertTrue(command.shouldSkipDomain)
    }

    func testCommandParsingWithFormCategory() throws {
        let command = try Command.parse(arguments: [
            "make", "Login", "--path", tempDirectory.path, "-mvvm", "-form"
        ])
        XCTAssertEqual(command.category, .form)
    }

    func testCommandParsingWithListCategory() throws {
        let command = try Command.parse(arguments: [
            "make", "Login", "--path", tempDirectory.path, "-mvvm", "-list"
        ])
        XCTAssertEqual(command.category, .list)
    }

    func testCommandParsingMissingMakeSubcommand() {
        XCTAssertThrowsError(try Command.parse(arguments: ["Login", "-mvvm"])) { error in
            guard case ForgeError.invalidArguments = error else {
                return XCTFail("Expected invalidArguments error")
            }
        }
    }

    func testCommandParsingMissingFeatureName() {
        XCTAssertThrowsError(try Command.parse(arguments: ["make"])) { error in
            guard case ForgeError.invalidArguments = error else {
                return XCTFail("Expected invalidArguments error")
            }
        }
    }

    func testCommandParsingUnknownFlag() {
        XCTAssertThrowsError(try Command.parse(arguments: [
            "make", "Login", "--path", tempDirectory.path, "-unknown"
        ])) { error in
            guard case ForgeError.invalidArguments = error else {
                return XCTFail("Expected invalidArguments error")
            }
        }
    }

    func testCommandParsingDuplicateArchitectureFlags() {
        XCTAssertThrowsError(try Command.parse(arguments: [
            "make", "Login", "--path", tempDirectory.path, "-mvvm", "-viper"
        ])) { error in
            guard case ForgeError.invalidArguments = error else {
                return XCTFail("Expected invalidArguments error")
            }
        }
    }

    func testCommandParsingDuplicateCategoryFlags() {
        XCTAssertThrowsError(try Command.parse(arguments: [
            "make", "Login", "--path", tempDirectory.path, "-mvvm", "-form", "-list"
        ])) { error in
            guard case ForgeError.invalidArguments = error else {
                return XCTFail("Expected invalidArguments error")
            }
        }
    }

    func testCommandParsingMissingPathValue() {
        XCTAssertThrowsError(try Command.parse(arguments: [
            "make", "Login", "--path"
        ])) { error in
            guard case ForgeError.invalidArguments = error else {
                return XCTFail("Expected invalidArguments error")
            }
        }
    }

    func testCommandParsingMissingTargetValue() {
        XCTAssertThrowsError(try Command.parse(arguments: [
            "make", "Login", "--path", tempDirectory.path, "-mvvm", "--target"
        ])) { error in
            guard case ForgeError.invalidArguments = error else {
                return XCTFail("Expected invalidArguments error")
            }
        }
    }

    func testCommandParsingWithTargetFlag() throws {
        let command = try Command.parse(arguments: [
            "make", "Search",
            "--path", tempDirectory.path,
            "--target", "SearchKit",
            "-mvvm"
        ])
        XCTAssertEqual(command.featureName, "Search")
        XCTAssertEqual(command.packageTarget, "SearchKit")
    }

    func testCommandParsingWithAlternativeCleanFlag() throws {
        let command = try Command.parse(arguments: [
            "make", "Login", "--path", tempDirectory.path, "-mvvm", "--clean"
        ])
        XCTAssertEqual(command.type, .cleanMVVM)
    }

    // MARK: - isHelpFlag Tests

    func testIsHelpFlagVariants() {
        XCTAssertTrue(Command.isHelpFlag("help"))
        XCTAssertTrue(Command.isHelpFlag("--help"))
        XCTAssertTrue(Command.isHelpFlag("-h"))
        XCTAssertFalse(Command.isHelpFlag("make"))
        XCTAssertFalse(Command.isHelpFlag("Login"))
    }

    // MARK: - FeatureGenerator Tests - Standalone Architectures

    func testGenerateMVVM() throws {
        let feature = try FeatureName(rawValue: "Login")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: false,
            packageTarget: nil,
            shouldGenerateTests: false,
            shouldSkipDomain: false,
            type: .mvvm,
            category: nil
        )
        let result = try generator.generate(feature: feature, selection: .all(for: .mvvm))

        let presentation = tempDirectory.appendingPathComponent("Login/Presentation")
        XCTAssertTrue(FileManager.default.fileExists(atPath: presentation.appendingPathComponent("LoginView.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: presentation.appendingPathComponent("LoginViewModel.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDirectory.appendingPathComponent("Login/LoginDependencyContainer.swift").path))
        XCTAssertNil(result.createdSwiftPackage)
        XCTAssertFalse(result.createdFiles.isEmpty)
    }

    func testGenerateMVI() throws {
        let feature = try FeatureName(rawValue: "Home")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: false,
            packageTarget: nil,
            shouldGenerateTests: false,
            shouldSkipDomain: false,
            type: .mvi,
            category: nil
        )
        _ = try generator.generate(feature: feature, selection: .all(for: .mvi))

        let presentation = tempDirectory.appendingPathComponent("Home/Presentation")
        XCTAssertTrue(FileManager.default.fileExists(atPath: presentation.appendingPathComponent("HomeView.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: presentation.appendingPathComponent("HomeStore.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: presentation.appendingPathComponent("HomeState.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: presentation.appendingPathComponent("HomeIntent.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: presentation.appendingPathComponent("HomeReducer.swift").path))
    }

    func testGenerateVIPER() throws {
        let feature = try FeatureName(rawValue: "Settings")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: false,
            packageTarget: nil,
            shouldGenerateTests: false,
            shouldSkipDomain: false,
            type: .viper,
            category: nil
        )
        _ = try generator.generate(feature: feature, selection: .all(for: .viper))

        let presentation = tempDirectory.appendingPathComponent("Settings/Presentation")
        XCTAssertTrue(FileManager.default.fileExists(atPath: presentation.appendingPathComponent("SettingsView.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: presentation.appendingPathComponent("SettingsPresenter.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: presentation.appendingPathComponent("SettingsInteractor.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: presentation.appendingPathComponent("SettingsRouter.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: presentation.appendingPathComponent("SettingsEntity.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: presentation.appendingPathComponent("SettingsContracts.swift").path))
    }

    func testGenerateVIP() throws {
        let feature = try FeatureName(rawValue: "Dashboard")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: false,
            packageTarget: nil,
            shouldGenerateTests: false,
            shouldSkipDomain: false,
            type: .vip,
            category: nil
        )
        _ = try generator.generate(feature: feature, selection: .all(for: .vip))

        let presentation = tempDirectory.appendingPathComponent("Dashboard/Presentation")
        XCTAssertTrue(FileManager.default.fileExists(atPath: presentation.appendingPathComponent("DashboardView.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: presentation.appendingPathComponent("DashboardInteractor.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: presentation.appendingPathComponent("DashboardPresenter.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: presentation.appendingPathComponent("DashboardWorker.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: presentation.appendingPathComponent("DashboardPresentationModels.swift").path))
    }

    func testGenerateMVP() throws {
        let feature = try FeatureName(rawValue: "Onboarding")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: false,
            packageTarget: nil,
            shouldGenerateTests: false,
            shouldSkipDomain: false,
            type: .mvp,
            category: nil
        )
        _ = try generator.generate(feature: feature, selection: .all(for: .mvp))

        let presentation = tempDirectory.appendingPathComponent("Onboarding/Presentation")
        XCTAssertTrue(FileManager.default.fileExists(atPath: presentation.appendingPathComponent("OnboardingView.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: presentation.appendingPathComponent("OnboardingPresenter.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: presentation.appendingPathComponent("OnboardingModel.swift").path))
    }

    func testGenerateTCA() throws {
        let feature = try FeatureName(rawValue: "Cart")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: false,
            packageTarget: nil,
            shouldGenerateTests: false,
            shouldSkipDomain: false,
            type: .tca,
            category: nil
        )
        _ = try generator.generate(feature: feature, selection: .all(for: .tca))

        let presentation = tempDirectory.appendingPathComponent("Cart/Presentation")
        XCTAssertTrue(FileManager.default.fileExists(atPath: presentation.appendingPathComponent("CartFeature.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: presentation.appendingPathComponent("CartView.swift").path))
        // TCA has no dependency container
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDirectory.appendingPathComponent("Cart/CartDependencyContainer.swift").path))
    }

    // MARK: - FeatureGenerator Tests - Clean Architectures

    func testGenerateCleanMVVM() throws {
        let feature = try FeatureName(rawValue: "Register")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: false,
            packageTarget: nil,
            shouldGenerateTests: false,
            shouldSkipDomain: false,
            type: .cleanMVVM,
            category: nil
        )
        _ = try generator.generate(feature: feature, selection: .all(for: .cleanMVVM))

        let base = tempDirectory.appendingPathComponent("Register")
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("Presentation/RegisterView.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("Presentation/RegisterViewModel.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("Domain/RegisterEntity.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("Domain/RegisterUseCase.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("Domain/RegisterRepository.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("Data/RegisterRepositoryImpl.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("Data/RegisterRemoteDataSource.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("Data/RegisterModels.swift").path))
    }

    func testGenerateCleanVIPER() throws {
        let feature = try FeatureName(rawValue: "Feed")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: false,
            packageTarget: nil,
            shouldGenerateTests: false,
            shouldSkipDomain: false,
            type: .cleanVIPER,
            category: nil
        )
        _ = try generator.generate(feature: feature, selection: .all(for: .cleanVIPER))

        let base = tempDirectory.appendingPathComponent("Feed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("Presentation/FeedView.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("Presentation/FeedPresenter.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("Presentation/FeedInteractor.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("Presentation/FeedRouter.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("Domain/FeedEntity.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("Data/FeedRepositoryImpl.swift").path))
    }

    func testGenerateCleanMVI() throws {
        let feature = try FeatureName(rawValue: "Notifications")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: false,
            packageTarget: nil,
            shouldGenerateTests: false,
            shouldSkipDomain: false,
            type: .cleanMVI,
            category: nil
        )
        _ = try generator.generate(feature: feature, selection: .all(for: .cleanMVI))

        let base = tempDirectory.appendingPathComponent("Notifications")
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("Domain/NotificationsEntity.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("Presentation/NotificationsStore.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("Presentation/NotificationsReducer.swift").path))
    }

    func testGenerateCleanTCA() throws {
        let feature = try FeatureName(rawValue: "Orders")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: false,
            packageTarget: nil,
            shouldGenerateTests: false,
            shouldSkipDomain: false,
            type: .cleanTCA,
            category: nil
        )
        _ = try generator.generate(feature: feature, selection: .all(for: .cleanTCA))

        let base = tempDirectory.appendingPathComponent("Orders")
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("Presentation/OrdersFeature.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("Domain/OrdersUseCase.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("Data/OrdersRepositoryImpl.swift").path))
    }

    func testGenerateCleanVIP() throws {
        let feature = try FeatureName(rawValue: "Checkout")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: false,
            packageTarget: nil,
            shouldGenerateTests: false,
            shouldSkipDomain: false,
            type: .cleanVIP,
            category: nil
        )
        _ = try generator.generate(feature: feature, selection: .all(for: .cleanVIP))

        let base = tempDirectory.appendingPathComponent("Checkout")
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("Presentation/CheckoutView.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("Domain/CheckoutUseCase.swift").path))
    }

    func testGenerateCleanMVP() throws {
        let feature = try FeatureName(rawValue: "Wishlist")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: false,
            packageTarget: nil,
            shouldGenerateTests: false,
            shouldSkipDomain: false,
            type: .cleanMVP,
            category: nil
        )
        _ = try generator.generate(feature: feature, selection: .all(for: .cleanMVP))

        let base = tempDirectory.appendingPathComponent("Wishlist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("Presentation/WishlistView.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("Domain/WishlistUseCase.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("Data/WishlistRepositoryImpl.swift").path))
    }

    // MARK: - FeatureGenerator Tests - Categories

    func testGenerateMVVMFormCategory() throws {
        let feature = try FeatureName(rawValue: "Login")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: false,
            packageTarget: nil,
            shouldGenerateTests: false,
            shouldSkipDomain: false,
            type: .mvvm,
            category: .form
        )
        _ = try generator.generate(feature: feature, selection: .all(for: .mvvm))

        let viewFile = tempDirectory.appendingPathComponent("Login/Presentation/LoginView.swift")
        XCTAssertTrue(FileManager.default.fileExists(atPath: viewFile.path))
        let content = try String(contentsOf: viewFile, encoding: .utf8)
        XCTAssertTrue(content.contains("TextField"))
    }

    func testGenerateMVVMListCategory() throws {
        let feature = try FeatureName(rawValue: "Items")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: false,
            packageTarget: nil,
            shouldGenerateTests: false,
            shouldSkipDomain: false,
            type: .mvvm,
            category: .list
        )
        _ = try generator.generate(feature: feature, selection: .all(for: .mvvm))

        let viewFile = tempDirectory.appendingPathComponent("Items/Presentation/ItemsView.swift")
        XCTAssertTrue(FileManager.default.fileExists(atPath: viewFile.path))
        let content = try String(contentsOf: viewFile, encoding: .utf8)
        XCTAssertTrue(content.contains("List") || content.contains("ForEach"))
    }

    func testGenerateTCAFormCategory() throws {
        let feature = try FeatureName(rawValue: "Auth")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: false,
            packageTarget: nil,
            shouldGenerateTests: false,
            shouldSkipDomain: false,
            type: .tca,
            category: .form
        )
        _ = try generator.generate(feature: feature, selection: .all(for: .tca))

        let viewFile = tempDirectory.appendingPathComponent("Auth/Presentation/AuthView.swift")
        XCTAssertTrue(FileManager.default.fileExists(atPath: viewFile.path))
        let content = try String(contentsOf: viewFile, encoding: .utf8)
        XCTAssertTrue(content.contains("TextField"))
    }

    func testGenerateVIPERFormCategory() throws {
        let feature = try FeatureName(rawValue: "Contact")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: false,
            packageTarget: nil,
            shouldGenerateTests: false,
            shouldSkipDomain: false,
            type: .viper,
            category: .form
        )
        _ = try generator.generate(feature: feature, selection: .all(for: .viper))

        let viewFile = tempDirectory.appendingPathComponent("Contact/Presentation/ContactView.swift")
        XCTAssertTrue(FileManager.default.fileExists(atPath: viewFile.path))
        let content = try String(contentsOf: viewFile, encoding: .utf8)
        XCTAssertTrue(content.contains("TextField"))
    }

    func testGenerateMVPListCategory() throws {
        let feature = try FeatureName(rawValue: "Products")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: false,
            packageTarget: nil,
            shouldGenerateTests: false,
            shouldSkipDomain: false,
            type: .mvp,
            category: .list
        )
        _ = try generator.generate(feature: feature, selection: .all(for: .mvp))

        let viewFile = tempDirectory.appendingPathComponent("Products/Presentation/ProductsView.swift")
        XCTAssertTrue(FileManager.default.fileExists(atPath: viewFile.path))
        let content = try String(contentsOf: viewFile, encoding: .utf8)
        XCTAssertTrue(content.contains("List") || content.contains("ForEach"))
    }

    // MARK: - FeatureGenerator Tests - Test Generation

    func testGenerateWithTestsMVVM() throws {
        let feature = try FeatureName(rawValue: "Login")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: false,
            packageTarget: nil,
            shouldGenerateTests: true,
            shouldSkipDomain: false,
            type: .mvvm,
            category: nil
        )
        _ = try generator.generate(feature: feature, selection: .all(for: .mvvm))

        let testsDir = tempDirectory.appendingPathComponent("Login/Tests")
        XCTAssertTrue(FileManager.default.fileExists(atPath: testsDir.appendingPathComponent("LoginViewModelTests.swift").path))
    }

    func testGenerateWithTestsCleanMVVM() throws {
        let feature = try FeatureName(rawValue: "Profile")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: false,
            packageTarget: nil,
            shouldGenerateTests: true,
            shouldSkipDomain: false,
            type: .cleanMVVM,
            category: nil
        )
        _ = try generator.generate(feature: feature, selection: .all(for: .cleanMVVM))

        let testsDir = tempDirectory.appendingPathComponent("Profile/Tests")
        XCTAssertTrue(FileManager.default.fileExists(atPath: testsDir.appendingPathComponent("ProfileViewModelTests.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: testsDir.appendingPathComponent("ProfileUseCaseTests.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: testsDir.appendingPathComponent("ProfileRepositoryTests.swift").path))
    }

    func testGenerateWithTestsMVI() throws {
        let feature = try FeatureName(rawValue: "Feed")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: false,
            packageTarget: nil,
            shouldGenerateTests: true,
            shouldSkipDomain: false,
            type: .mvi,
            category: nil
        )
        _ = try generator.generate(feature: feature, selection: .all(for: .mvi))

        let testsDir = tempDirectory.appendingPathComponent("Feed/Tests")
        XCTAssertTrue(FileManager.default.fileExists(atPath: testsDir.appendingPathComponent("FeedStoreTests.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: testsDir.appendingPathComponent("FeedReducerTests.swift").path))
    }

    func testGenerateWithTestsVIPER() throws {
        let feature = try FeatureName(rawValue: "Map")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: false,
            packageTarget: nil,
            shouldGenerateTests: true,
            shouldSkipDomain: false,
            type: .viper,
            category: nil
        )
        _ = try generator.generate(feature: feature, selection: .all(for: .viper))

        let testsDir = tempDirectory.appendingPathComponent("Map/Tests")
        XCTAssertTrue(FileManager.default.fileExists(atPath: testsDir.appendingPathComponent("MapPresenterTests.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: testsDir.appendingPathComponent("MapInteractorTests.swift").path))
    }

    func testGenerateWithTestsTCA() throws {
        let feature = try FeatureName(rawValue: "Wallet")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: false,
            packageTarget: nil,
            shouldGenerateTests: true,
            shouldSkipDomain: false,
            type: .tca,
            category: nil
        )
        _ = try generator.generate(feature: feature, selection: .all(for: .tca))

        let testsDir = tempDirectory.appendingPathComponent("Wallet/Tests")
        XCTAssertTrue(FileManager.default.fileExists(atPath: testsDir.appendingPathComponent("WalletFeatureTests.swift").path))
    }

    // MARK: - FeatureGenerator Tests - --no-domain Flag

    func testGenerateWithNoDomainSkipsDomainFiles() throws {
        let feature = try FeatureName(rawValue: "Store")
        let baseSelection = FeatureFileSelection.all(for: .cleanMVVM)
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: false,
            packageTarget: nil,
            shouldGenerateTests: false,
            shouldSkipDomain: true,
            type: .cleanMVVM,
            category: nil
        )
        _ = try generator.generate(feature: feature, selection: baseSelection)

        let base = tempDirectory.appendingPathComponent("Store")
        XCTAssertFalse(FileManager.default.fileExists(atPath: base.appendingPathComponent("Domain/StoreEntity.swift").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: base.appendingPathComponent("Domain/StoreUseCase.swift").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: base.appendingPathComponent("Domain/StoreRepository.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("Data/StoreRepositoryImpl.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("Data/StoreRemoteDataSource.swift").path))
    }

    func testGenerateWithNoDomainSkipsDomainTests() throws {
        let feature = try FeatureName(rawValue: "Gallery")
        let baseSelection = FeatureFileSelection.all(for: .cleanMVVM)
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: false,
            packageTarget: nil,
            shouldGenerateTests: true,
            shouldSkipDomain: true,
            type: .cleanMVVM,
            category: nil
        )
        _ = try generator.generate(feature: feature, selection: baseSelection)

        let testsDir = tempDirectory.appendingPathComponent("Gallery/Tests")
        XCTAssertTrue(FileManager.default.fileExists(atPath: testsDir.appendingPathComponent("GalleryViewModelTests.swift").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: testsDir.appendingPathComponent("GalleryUseCaseTests.swift").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: testsDir.appendingPathComponent("GalleryRepositoryTests.swift").path))
    }

    // MARK: - FeatureGenerator Tests - Package Generation

    func testTargetFlagWithPackageCreation() throws {
        let feature = try FeatureName(rawValue: "Login")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: true,
            packageTarget: "AppFeatureKit",
            shouldGenerateTests: true,
            shouldSkipDomain: false,
            type: .mvvm,
            category: nil
        )
        let result = try generator.generate(feature: feature, selection: .all(for: .mvvm))

        XCTAssertNotNil(result.createdSwiftPackage)
        let expectedSourceFile = tempDirectory
            .appendingPathComponent("Login")
            .appendingPathComponent("Sources")
            .appendingPathComponent("AppFeatureKit")
            .appendingPathComponent("Presentation")
            .appendingPathComponent("LoginViewModel.swift")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedSourceFile.path))

        let packageSwiftFile = tempDirectory.appendingPathComponent("Login/Package.swift")
        XCTAssertTrue(FileManager.default.fileExists(atPath: packageSwiftFile.path))
        let packageContent = try String(contentsOf: packageSwiftFile, encoding: .utf8)
        XCTAssertTrue(packageContent.contains("AppFeatureKit"))
        XCTAssertTrue(packageContent.contains("swift-tools-version"))
        XCTAssertTrue(packageContent.contains(".testTarget("))
        XCTAssertTrue(packageContent.contains("name: \"AppFeatureKitTests\""))
        XCTAssertTrue(packageContent.contains("dependencies: [\"AppFeatureKit\"]"))

        let testFile = tempDirectory.appendingPathComponent("Login/Tests/AppFeatureKitTests/LoginViewModelTests.swift")
        let testContent = try String(contentsOf: testFile, encoding: .utf8)
        XCTAssertTrue(testContent.contains("@testable import AppFeatureKit"))
        XCTAssertFalse(testContent.contains("@testable import Login"))
    }

    func testTargetFlagWithExistingPackageStructure() throws {
        let sourcesDir = tempDirectory.appendingPathComponent("Sources").appendingPathComponent("FeatureKit")
        try FileManager.default.createDirectory(at: sourcesDir, withIntermediateDirectories: true)

        let feature = try FeatureName(rawValue: "Profile")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: false,
            packageTarget: "FeatureKit",
            shouldGenerateTests: true,
            shouldSkipDomain: false,
            type: .cleanMVVM,
            category: nil
        )
        let result = try generator.generate(feature: feature, selection: .all(for: .cleanMVVM))

        XCTAssertEqual(result.detectedSwiftPackageTarget, "FeatureKit")
        let expectedViewModelPath = sourcesDir
            .appendingPathComponent("Profile")
            .appendingPathComponent("Presentation")
            .appendingPathComponent("ProfileViewModel.swift")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedViewModelPath.path))

        let expectedTestPath = tempDirectory.appendingPathComponent("Tests/FeatureKitTests/Profile/ProfileViewModelTests.swift")
        let testContent = try String(contentsOf: expectedTestPath, encoding: .utf8)
        XCTAssertTrue(testContent.contains("@testable import FeatureKit"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDirectory.appendingPathComponent("FeatureKitTests").path))
    }

    func testPackageWithoutTestsDoesNotDeclareTestTarget() throws {
        let feature = try FeatureName(rawValue: "Profile")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: true,
            packageTarget: nil,
            shouldGenerateTests: false,
            shouldSkipDomain: false,
            type: .mvvm,
            category: nil
        )
        _ = try generator.generate(feature: feature, selection: .all(for: .mvvm))
        let manifest = try String(contentsOf: tempDirectory.appendingPathComponent("Profile/Package.swift"), encoding: .utf8)
        XCTAssertFalse(manifest.contains(".testTarget("))
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDirectory.appendingPathComponent("Profile/Tests").path))
    }

    func testHyphenatedPackageTargetUsesSwiftModuleName() throws {
        let feature = try FeatureName(rawValue: "Profile")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: true,
            packageTarget: "Feature-Kit",
            shouldGenerateTests: true,
            shouldSkipDomain: false,
            type: .mvvm,
            category: nil
        )
        _ = try generator.generate(feature: feature, selection: .all(for: .mvvm))

        let testFile = tempDirectory.appendingPathComponent("Profile/Tests/Feature-KitTests/ProfileViewModelTests.swift")
        let testContent = try String(contentsOf: testFile, encoding: .utf8)
        XCTAssertTrue(testContent.contains("@testable import Feature_Kit"))
        let manifest = try String(contentsOf: tempDirectory.appendingPathComponent("Profile/Package.swift"), encoding: .utf8)
        XCTAssertTrue(manifest.contains("name: \"Feature-Kit\""))
    }

    // MARK: - Duplicate File Guard

    func testGenerateThrowsOnExistingFile() throws {
        let feature = try FeatureName(rawValue: "Login")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: false,
            packageTarget: nil,
            shouldGenerateTests: false,
            shouldSkipDomain: false,
            type: .mvvm,
            category: nil
        )
        _ = try generator.generate(feature: feature, selection: .all(for: .mvvm))

        XCTAssertThrowsError(try generator.generate(feature: feature, selection: .all(for: .mvvm))) { error in
            guard case ForgeError.fileAlreadyExists = error else {
                return XCTFail("Expected fileAlreadyExists error")
            }
        }
    }

    // MARK: - Generated File Content Tests

    func testGeneratedViewModelContainsFeatureName() throws {
        let feature = try FeatureName(rawValue: "Splash")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: false,
            packageTarget: nil,
            shouldGenerateTests: false,
            shouldSkipDomain: false,
            type: .mvvm,
            category: nil
        )
        _ = try generator.generate(feature: feature, selection: .all(for: .mvvm))

        let vmFile = tempDirectory.appendingPathComponent("Splash/Presentation/SplashViewModel.swift")
        let content = try String(contentsOf: vmFile, encoding: .utf8)
        XCTAssertTrue(content.contains("SplashViewModel"))
    }

    func testGeneratedFileHasHeaderComment() throws {
        let feature = try FeatureName(rawValue: "Login")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: false,
            packageTarget: nil,
            shouldGenerateTests: false,
            shouldSkipDomain: false,
            type: .mvvm,
            category: nil
        )
        _ = try generator.generate(feature: feature, selection: .all(for: .mvvm))

        let vmFile = tempDirectory.appendingPathComponent("Login/Presentation/LoginViewModel.swift")
        let content = try String(contentsOf: vmFile, encoding: .utf8)
        XCTAssertTrue(content.hasPrefix("//"))
        XCTAssertTrue(content.contains("LoginViewModel.swift"))
    }

    func testGeneratedEntityContainsFeatureName() throws {
        let feature = try FeatureName(rawValue: "Product")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: false,
            packageTarget: nil,
            shouldGenerateTests: false,
            shouldSkipDomain: false,
            type: .cleanMVVM,
            category: nil
        )
        _ = try generator.generate(feature: feature, selection: .all(for: .cleanMVVM))

        let entityFile = tempDirectory.appendingPathComponent("Product/Domain/ProductEntity.swift")
        let content = try String(contentsOf: entityFile, encoding: .utf8)
        XCTAssertTrue(content.contains("ProductEntity"))
    }

    func testGeneratedRepositoryImplConformsToProtocol() throws {
        let feature = try FeatureName(rawValue: "News")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: false,
            packageTarget: nil,
            shouldGenerateTests: false,
            shouldSkipDomain: false,
            type: .cleanMVVM,
            category: nil
        )
        _ = try generator.generate(feature: feature, selection: .all(for: .cleanMVVM))

        let implFile = tempDirectory.appendingPathComponent("News/Data/NewsRepositoryImpl.swift")
        let content = try String(contentsOf: implFile, encoding: .utf8)
        XCTAssertTrue(content.contains(": NewsRepository"))
    }

    func testGeneratedModelsHasToDomainWhenUseCasePresent() throws {
        let feature = try FeatureName(rawValue: "Article")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: false,
            packageTarget: nil,
            shouldGenerateTests: false,
            shouldSkipDomain: false,
            type: .cleanMVVM,
            category: nil
        )
        _ = try generator.generate(feature: feature, selection: .all(for: .cleanMVVM))

        let modelsFile = tempDirectory.appendingPathComponent("Article/Data/ArticleModels.swift")
        let content = try String(contentsOf: modelsFile, encoding: .utf8)
        XCTAssertTrue(content.contains("toDomain()"))
    }

    // MARK: - ForgeError Tests

    func testForgeErrorMessages() {
        XCTAssertEqual(ForgeError.invalidArguments("Bad arg").message, "Bad arg")
        XCTAssertEqual(
            ForgeError.invalidFeatureName("123").message,
            "'123' is not a valid feature name. Use letters, numbers, spaces, dashes, or underscores."
        )
        XCTAssertTrue(ForgeError.fileAlreadyExists("/path/to/file.swift").message.contains("/path/to/file.swift"))
        XCTAssertEqual(ForgeError.cancelled.message, "Cancelled.")
    }

    // MARK: - FeatureType templateSpecs Count Tests

    func testMVVMTemplateSpecsDefaultHasThreeFiles() {
        XCTAssertEqual(FeatureType.mvvm.templateSpecs.count, 3)
    }

    func testCleanMVVMTemplateSpecsHasNineFiles() {
        XCTAssertEqual(FeatureType.cleanMVVM.templateSpecs.count, 9)
    }

    func testTCATemplateSpecsHasTwoFiles() {
        XCTAssertEqual(FeatureType.tca.templateSpecs.count, 2)
    }

    func testMVITemplateSpecsHasSixFiles() {
        XCTAssertEqual(FeatureType.mvi.templateSpecs.count, 6)
    }

    func testVIPERTemplateSpecsHasSevenFiles() {
        XCTAssertEqual(FeatureType.viper.templateSpecs.count, 7)
    }

    func testVIPTemplateSpecsHasSixFiles() {
        XCTAssertEqual(FeatureType.vip.templateSpecs.count, 6)
    }

    func testMVPTemplateSpecsHasFourFiles() {
        XCTAssertEqual(FeatureType.mvp.templateSpecs.count, 4)
    }

    func testCleanMVVMTestTemplateSpecsHasThreeFiles() {
        XCTAssertEqual(FeatureType.cleanMVVM.testTemplateSpecs.count, 3)
    }

    func testMVVMTestTemplateSpecsHasOneFile() {
        let specs = FeatureType.mvvm.testTemplateSpecs
        XCTAssertEqual(specs.count, 1)
        XCTAssertEqual(specs[0].file, .viewModelTests)
    }

    func testMVITestTemplateSpecsHasTwoFiles() {
        XCTAssertEqual(FeatureType.mvi.testTemplateSpecs.count, 2)
    }

    func testTCATestTemplateSpecsHasOneFile() {
        let specs = FeatureType.tca.testTemplateSpecs
        XCTAssertEqual(specs.count, 1)
        XCTAssertEqual(specs[0].file, .featureTests)
    }
}

// MARK: - Best Practices Content Tests

/// Renders every template and audits the generated Swift code against
/// iOS/Swift best-practice patterns.
final class BestPracticesTests: XCTestCase {

    var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    private func generateAll(type: FeatureType, category: FeatureCategory? = nil) throws -> [URL: String] {
        let feature = try FeatureName(rawValue: "Login")
        let generator = FeatureGenerator(
            projectPath: tempDirectory,
            shouldCreatePackage: false,
            packageTarget: nil,
            shouldGenerateTests: true,
            shouldSkipDomain: false,
            type: type,
            category: category
        )
        let result = try generator.generate(feature: feature, selection: .all(for: type))
        var map: [URL: String] = [:]
        for url in result.createdFiles {
            map[url] = try String(contentsOf: url, encoding: .utf8)
        }
        return map
    }

    private func content(named suffix: String, in files: [URL: String]) -> String? {
        files.first(where: { $0.key.lastPathComponent.hasSuffix(suffix) })?.value
    }

    // MARK: - Swift 6 / Concurrency Best Practices

    /// ViewModels must be annotated `@MainActor` to guarantee UI updates on the main thread.
    func testMVVMViewModelIsMainActor() throws {
        let files = try generateAll(type: .mvvm)
        let vm = try XCTUnwrap(content(named: "LoginViewModel.swift", in: files))
        XCTAssertTrue(vm.contains("@MainActor"),
            "ViewModel must be annotated @MainActor for thread-safe UI publishing.")
    }

    /// `ObservableObject` is from Combine — `import Combine` must be present in ViewModel.
    func testMVVMViewModelImportsCombine() throws {
        let files = try generateAll(type: .mvvm)
        let vm = try XCTUnwrap(content(named: "LoginViewModel.swift", in: files))
        XCTAssertTrue(vm.contains("import Combine"),
            "ViewModel uses ObservableObject which requires Combine import.")
    }

    /// `@Published private(set)` enforces one-way data flow — view cannot mutate VM state directly.
    func testMVVMViewModelPublishedPropertiesArePrivateSet() throws {
        let files = try generateAll(type: .mvvm)
        let vm = try XCTUnwrap(content(named: "LoginViewModel.swift", in: files))
        // isLoading and errorMessage should not be publicly writable
        XCTAssertTrue(vm.contains("@Published private(set) var isLoading"),
            "isLoading must use private(set) to enforce unidirectional data flow.")
        XCTAssertTrue(vm.contains("@Published private(set) var errorMessage"),
            "errorMessage must use private(set) to enforce unidirectional data flow.")
    }

    /// `load()` is `async` — it must be called via `.task` modifier, not `onAppear`.
    func testMVVMViewUsesTaskModifierForAsyncLoad() throws {
        let files = try generateAll(type: .mvvm)
        let view = try XCTUnwrap(content(named: "LoginView.swift", in: files))
        XCTAssertTrue(view.contains(".task"),
            "Async ViewModel.load() should be triggered from .task{} not .onAppear to handle cancellation.")
        XCTAssertFalse(view.contains("onAppear"),
            "Prefer .task over .onAppear for async calls to get automatic task cancellation.")
    }

    /// View must inject ViewModel via init and wrap with `StateObject(wrappedValue:)`.
    func testMVVMViewInjectsViewModelViaInit() throws {
        let files = try generateAll(type: .mvvm)
        let view = try XCTUnwrap(content(named: "LoginView.swift", in: files))
        XCTAssertTrue(view.contains("init(viewModel: "),
            "View should accept ViewModel via init for testability and DI.")
        XCTAssertTrue(view.contains("StateObject(wrappedValue: viewModel)"),
            "Must use StateObject(wrappedValue:) in init to correctly own the object lifecycle.")
    }

    /// `@StateObject` is correct ownership: the View that creates the VM should own it.
    func testMVVMViewUsesStateObject() throws {
        let files = try generateAll(type: .mvvm)
        let view = try XCTUnwrap(content(named: "LoginView.swift", in: files))
        XCTAssertTrue(view.contains("@StateObject"),
            "Views that own the object lifecycle should use @StateObject, not @ObservedObject.")
    }

    /// ViewModel must be `final` — prevents subclass overrides that bypass `@MainActor`.
    func testMVVMViewModelIsFinalClass() throws {
        let files = try generateAll(type: .mvvm)
        let vm = try XCTUnwrap(content(named: "LoginViewModel.swift", in: files))
        XCTAssertTrue(vm.contains("final class"),
            "ViewModel class should be `final` to prevent unintended subclassing.")
    }

    // MARK: - Error Handling Best Practices

    /// `load()` must catch errors and store them — not let them propagate silently or crash.
    func testCleanMVVMViewModelHandlesErrorsGracefully() throws {
        let files = try generateAll(type: .cleanMVVM)
        let vm = try XCTUnwrap(content(named: "LoginViewModel.swift", in: files))
        XCTAssertTrue(vm.contains("do {"),
            "Async load must use do-catch for error handling.")
        XCTAssertTrue(vm.contains("} catch {"),
            "Errors must be caught and surfaced to the user, not swallowed silently.")
        XCTAssertTrue(vm.contains("errorMessage = error.localizedDescription"),
            "Error should be mapped to a user-facing message via localizedDescription.")
    }

    /// `isLoading` must always reset — use `defer` or explicit reset in catch branch.
    func testCleanMVVMViewModelResetsIsLoadingOnError() throws {
        let files = try generateAll(type: .cleanMVVM)
        let vm = try XCTUnwrap(content(named: "LoginViewModel.swift", in: files))
        // defer { isLoading = false } ensures reset even on throw paths
        XCTAssertTrue(vm.contains("defer { isLoading = false }"),
            "isLoading must reset on all paths — use defer to guarantee it.")
    }

    // MARK: - Dependency Injection Best Practices

    /// UseCase should depend on the Repository protocol, not the concrete impl, for testability.
    func testUseCaseDependsOnRepositoryProtocol() throws {
        let result = try TemplateRenderer.render("useCase.stencil", context: ["name": "Login"])
        XCTAssertTrue(result.contains("LoginRepository"),
            "UseCase should depend on LoginRepository (protocol) not LoginRepositoryImpl (concrete).")
        XCTAssertFalse(result.contains("LoginRepositoryImpl"),
            "UseCase must not depend on concrete RepositoryImpl — violates Dependency Inversion.")
    }

    /// RepositoryImpl should conform to the Repository protocol.
    func testRepositoryImplConformsToProtocol() throws {
        let result = try TemplateRenderer.render("repositoryImpl.stencil", context: [
            "name": "Login", "hasRepository": true, "hasNoDomain": false
        ])
        XCTAssertTrue(result.contains(": LoginRepository"),
            "RepositoryImpl must conform to the Repository protocol — Open/Closed & testability.")
    }

    /// DI containers must use `@MainActor` on methods that return `@MainActor` objects.
    func testCleanMVVMDependencyContainerMakeViewIsMainActor() throws {
        let files = try generateAll(type: .cleanMVVM)
        let dc = try XCTUnwrap(content(named: "LoginDependencyContainer.swift", in: files))
        XCTAssertTrue(dc.contains("@MainActor") && dc.contains("makeView"),
            "Factory methods returning @MainActor view/viewModel must themselves be @MainActor.")
    }

    /// TCA uses @Dependency / DependencyValues instead of a DependencyContainer file.
    func testCleanTCADoesNotGenerateDependencyContainer() throws {
        let files = try generateAll(type: .cleanTCA)
        let dc = content(named: "LoginDependencyContainer.swift", in: files)
        XCTAssertNil(dc, "Clean TCA should not generate a DependencyContainer file — TCA uses @Dependency instead.")
    }

    // MARK: - Clean Architecture Layer Separation

    /// Domain layer (Entity, UseCase, Repository) must NOT import SwiftUI — framework independence.
    func testEntityDoesNotImportSwiftUI() throws {
        let files = try generateAll(type: .cleanMVVM)
        let entity = try XCTUnwrap(content(named: "LoginEntity.swift", in: files))
        XCTAssertFalse(entity.contains("import SwiftUI"),
            "Domain entities must not import SwiftUI — domain layer must be framework-independent.")
    }

    func testUseCaseDoesNotImportSwiftUI() throws {
        let result = try TemplateRenderer.render("useCase.stencil", context: ["name": "Login"])
        XCTAssertFalse(result.contains("import SwiftUI"),
            "UseCase must not import SwiftUI — domain layer must be UI-framework independent.")
    }

    func testRepositoryProtocolDoesNotImportSwiftUI() throws {
        let result = try TemplateRenderer.render("repository.stencil", context: ["name": "Login"])
        XCTAssertFalse(result.contains("import SwiftUI"),
            "Repository protocol must not import SwiftUI — it's a domain concern.")
    }

    /// Data layer must not import SwiftUI either.
    func testRepositoryImplDoesNotImportSwiftUI() throws {
        let result = try TemplateRenderer.render("repositoryImpl.stencil", context: [
            "name": "Login", "hasRepository": true, "hasNoDomain": false
        ])
        XCTAssertFalse(result.contains("import SwiftUI"),
            "RepositoryImpl must not import SwiftUI — data layer is framework-independent.")
    }

    func testRemoteDataSourceDoesNotImportSwiftUI() throws {
        let result = try TemplateRenderer.render("remoteDataSource.stencil", context: ["name": "Login"])
        XCTAssertFalse(result.contains("import SwiftUI"),
            "RemoteDataSource must not import SwiftUI.")
    }

    // MARK: - Entity Design Best Practices

    /// Entity must be `Equatable` for comparison in tests and state diffing.
    func testEntityIsEquatable() throws {
        let result = try TemplateRenderer.render("entity.stencil", context: ["name": "Login"])
        XCTAssertTrue(result.contains("Equatable"),
            "Entities should conform to Equatable for easy state comparison.")
    }

    /// Entity must be `Identifiable` for use in SwiftUI List.
    func testEntityIsIdentifiable() throws {
        let result = try TemplateRenderer.render("entity.stencil", context: ["name": "Login"])
        XCTAssertTrue(result.contains("Identifiable"),
            "Entities should conform to Identifiable to be usable in SwiftUI List directly.")
    }

    /// Entity should be a `struct` (value type), not a class — prevents shared mutable state.
    func testEntityIsStruct() throws {
        let result = try TemplateRenderer.render("entity.stencil", context: ["name": "Login"])
        XCTAssertTrue(result.contains("struct LoginEntity"),
            "Entities must be value types (struct) — prevents accidental shared mutable state.")
        XCTAssertFalse(result.contains("class LoginEntity"),
            "Entities must not be reference types.")
    }

    // MARK: - Model (Response) Best Practices

    /// Response model should be `Decodable` for JSON decoding from API.
    func testResponseModelIsDecodable() throws {
        let result = try TemplateRenderer.render("models.stencil", context: [
            "name": "Login", "hasUseCase": true
        ])
        XCTAssertTrue(result.contains("Decodable"),
            "API response models must conform to Decodable for JSON parsing.")
    }

    /// Response model should have a `toDomain()` mapping method when a UseCase is present.
    func testResponseModelHasToDomainMapping() throws {
        let result = try TemplateRenderer.render("models.stencil", context: [
            "name": "Login", "hasUseCase": true
        ])
        XCTAssertTrue(result.contains("toDomain()"),
            "Response models should provide a toDomain() mapping to keep Data layer clean.")
    }

    /// RemoteDataSource should return the Response model, not the Domain Entity — respects layer boundaries.
    func testRemoteDataSourceReturnsResponse() throws {
        let result = try TemplateRenderer.render("remoteDataSource.stencil", context: ["name": "Login"])
        XCTAssertTrue(result.contains("LoginResponse"),
            "RemoteDataSource should return LoginResponse (data model), not LoginEntity (domain).")
        XCTAssertFalse(result.contains("LoginEntity"),
            "RemoteDataSource must not return domain entities directly — that's the repository's job.")
    }

    // MARK: - MVI Best Practices

    /// MVI State must be Equatable for efficient diff/comparison.
    func testMVIStateIsEquatable() throws {
        let files = try generateAll(type: .mvi)
        let state = try XCTUnwrap(content(named: "LoginState.swift", in: files))
        XCTAssertTrue(state.contains("Equatable"),
            "MVI State must be Equatable for value comparison and test assertions.")
    }

    /// MVI Intent must be Equatable.
    func testMVIIntentIsEquatable() throws {
        let files = try generateAll(type: .mvi)
        let intent = try XCTUnwrap(content(named: "LoginIntent.swift", in: files))
        XCTAssertTrue(intent.contains("Equatable"),
            "MVI Intent must be Equatable for reliable switching and test assertions.")
    }

    /// MVI State must be a `struct` (value type) for copy-on-write semantics.
    func testMVIStateIsStruct() throws {
        let files = try generateAll(type: .mvi)
        let state = try XCTUnwrap(content(named: "LoginState.swift", in: files))
        XCTAssertTrue(state.contains("struct LoginState"),
            "MVI State should be a value type (struct) for predictable copy semantics.")
    }

    /// MVI Reducer must be pure — a struct, not a class.
    func testMVIReducerIsStruct() throws {
        let files = try generateAll(type: .mvi)
        let reducer = try XCTUnwrap(content(named: "LoginReducer.swift", in: files))
        XCTAssertTrue(reducer.contains("struct LoginReducer"),
            "Reducer should be a pure value type (struct) with no stored mutable state.")
    }

    /// MVI Store must be `@MainActor final class` for thread-safe ObservableObject publishing.
    func testMVIStoreIsMainActorFinalClass() throws {
        let files = try generateAll(type: .mvi)
        let store = try XCTUnwrap(content(named: "LoginStore.swift", in: files))
        XCTAssertTrue(store.contains("@MainActor"),
            "MVI Store must be @MainActor for safe @Published updates.")
        XCTAssertTrue(store.contains("final class"),
            "MVI Store should be final class to prevent subclassing.")
    }

    /// MVI Store state should be `@Published private(set)` — read-only from outside.
    func testMVIStoreStateIsReadOnly() throws {
        let files = try generateAll(type: .mvi)
        let store = try XCTUnwrap(content(named: "LoginStore.swift", in: files))
        XCTAssertTrue(store.contains("@Published private(set) var state"),
            "Store state must be @Published private(set) — only the store should mutate state.")
    }

    // MARK: - Clean MVI Best Practices

    /// Clean MVI Store must handle async side effects (`.onAppear` → fetch → `.didLoad`).
    func testCleanMVIStoreHandlesAsyncOnAppear() throws {
        let files = try generateAll(type: .cleanMVI)
        let store = try XCTUnwrap(content(named: "LoginStore.swift", in: files))
        XCTAssertTrue(store.contains(".didLoad"),
            "Clean MVI Store must dispatch .didLoad after async fetch, not mutate state directly.")
        XCTAssertTrue(store.contains(".didFail"),
            "Clean MVI Store must dispatch .didFail on error, mapping it to an intent.")
    }

    /// Clean MVI Reducer must handle all three lifecycle intents.
    func testCleanMVIReducerHandlesAllIntents() throws {
        let files = try generateAll(type: .cleanMVI)
        let reducer = try XCTUnwrap(content(named: "LoginReducer.swift", in: files))
        XCTAssertTrue(reducer.contains(".onAppear"),  "Reducer must handle .onAppear")
        XCTAssertTrue(reducer.contains(".didLoad"),   "Reducer must handle .didLoad")
        XCTAssertTrue(reducer.contains(".didFail"),   "Reducer must handle .didFail")
    }

    // MARK: - VIPER Best Practices

    /// VIPER Contracts must define all four protocol boundaries.
    func testVIPERContractsDefinesAllProtocols() throws {
        let files = try generateAll(type: .viper)
        let contracts = try XCTUnwrap(content(named: "LoginContracts.swift", in: files))
        XCTAssertTrue(contracts.contains("protocol LoginViewInput"),
            "VIPER Contracts must define ViewInput protocol.")
        XCTAssertTrue(contracts.contains("protocol LoginPresenterInput"),
            "VIPER Contracts must define PresenterInput protocol.")
        XCTAssertTrue(contracts.contains("protocol LoginInteractorInput"),
            "VIPER Contracts must define InteractorInput protocol.")
        XCTAssertTrue(contracts.contains("protocol LoginRouterInput"),
            "VIPER Contracts must define RouterInput protocol.")
    }

    /// VIPER Presenter must be `@MainActor` — it publishes to the View.
    func testVIPERPresenterIsMainActor() throws {
        let files = try generateAll(type: .viper)
        let presenter = try XCTUnwrap(content(named: "LoginPresenter.swift", in: files))
        XCTAssertTrue(presenter.contains("@MainActor"),
            "VIPER Presenter must be @MainActor since it drives UI updates.")
    }

    /// VIPER Presenter must conform to PresenterInput protocol.
    func testVIPERPresenterConformsToPresenterInput() throws {
        let files = try generateAll(type: .viper)
        let presenter = try XCTUnwrap(content(named: "LoginPresenter.swift", in: files))
        XCTAssertTrue(presenter.contains("LoginPresenterInput"),
            "VIPER Presenter must conform to LoginPresenterInput protocol for contract enforcement.")
    }

    /// VIPER ViewInput protocol must be `AnyObject` (weak reference support).
    func testVIPERViewInputIsAnyObject() throws {
        let files = try generateAll(type: .viper)
        let contracts = try XCTUnwrap(content(named: "LoginContracts.swift", in: files))
        XCTAssertTrue(contracts.contains("protocol LoginViewInput: AnyObject"),
            "ViewInput must be AnyObject-constrained to allow weak references and prevent retain cycles.")
    }

    // MARK: - VIP Best Practices

    /// VIP uses a scoped Models enum for Request/Response/ViewModel — prevents naming collisions.
    func testVIPHasScopedModelsEnum() throws {
        let files = try generateAll(type: .vip)
        let models = try XCTUnwrap(content(named: "LoginPresentationModels.swift", in: files))
        XCTAssertTrue(models.contains("enum Login"),
            "VIP should scope models in a namespace enum (Login.Request, Login.Response, Login.ViewModel).")
        XCTAssertTrue(models.contains("struct Request"),  "VIP Models must include Request type.")
        XCTAssertTrue(models.contains("struct Response"), "VIP Models must include Response type.")
        XCTAssertTrue(models.contains("struct ViewModel"),"VIP Models must include ViewModel type.")
    }

    /// VIP Interactor is the entry point and must be `ObservableObject` + `@MainActor`.
    func testVIPInteractorIsObservableAndMainActor() throws {
        let files = try generateAll(type: .vip)
        let interactor = try XCTUnwrap(content(named: "LoginInteractor.swift", in: files))
        XCTAssertTrue(interactor.contains("ObservableObject"),
            "VIP Interactor serves as the observable source for the View.")
        XCTAssertTrue(interactor.contains("@MainActor"),
            "VIP Interactor must be @MainActor for safe UI state publishing.")
    }

    // MARK: - MVP Best Practices

    /// MVP Presenter must be `ObservableObject` + `@MainActor`.
    func testMVPPresenterIsObservableAndMainActor() throws {
        let files = try generateAll(type: .mvp)
        let presenter = try XCTUnwrap(content(named: "LoginPresenter.swift", in: files))
        XCTAssertTrue(presenter.contains("ObservableObject"),
            "MVP Presenter must be ObservableObject to drive the View.")
        XCTAssertTrue(presenter.contains("@MainActor"),
            "MVP Presenter must be @MainActor for safe @Published updates.")
    }

    /// MVP Model must be a struct (value type).
    func testMVPModelIsStruct() throws {
        let files = try generateAll(type: .mvp)
        let model = try XCTUnwrap(content(named: "LoginModel.swift", in: files))
        XCTAssertTrue(model.contains("struct LoginModel"),
            "MVP Model should be a value type (struct) for immutability and predictability.")
    }

    /// MVP Model should be `Equatable`.
    func testMVPModelIsEquatable() throws {
        let files = try generateAll(type: .mvp)
        let model = try XCTUnwrap(content(named: "LoginModel.swift", in: files))
        XCTAssertTrue(model.contains("Equatable"),
            "MVP Model should be Equatable for reliable comparison in tests.")
    }

    // MARK: - TCA Best Practices

    /// TCA Feature must use `@Reducer` macro — the modern TCA 1.x entry point.
    func testTCAFeatureUsesReducerMacro() throws {
        let files = try generateAll(type: .tca)
        let feature = try XCTUnwrap(content(named: "LoginFeature.swift", in: files))
        XCTAssertTrue(feature.contains("@Reducer"),
            "TCA Feature must use @Reducer macro (TCA 1.x+), not the old Reducer protocol directly.")
    }

    /// TCA State must use `@ObservableState` for observation in TCA 1.x.
    func testTCAStateUsesObservableStateMacro() throws {
        let files = try generateAll(type: .tca)
        let feature = try XCTUnwrap(content(named: "LoginFeature.swift", in: files))
        XCTAssertTrue(feature.contains("@ObservableState"),
            "TCA 1.x State must be annotated with @ObservableState for modern observation support.")
    }

    /// TCA State must be `Equatable` for store diffing.
    func testTCAStateIsEquatable() throws {
        let files = try generateAll(type: .tca)
        let feature = try XCTUnwrap(content(named: "LoginFeature.swift", in: files))
        XCTAssertTrue(feature.contains("struct State: Equatable"),
            "TCA State must conform to Equatable for the TestStore diff assertions.")
    }

    /// TCA Action must be `Equatable`.
    func testTCAActionIsEquatable() throws {
        let files = try generateAll(type: .tca)
        let feature = try XCTUnwrap(content(named: "LoginFeature.swift", in: files))
        XCTAssertTrue(feature.contains("enum Action: Equatable"),
            "TCA Action must be Equatable for TestStore assertions.")
    }

    /// TCA View receives a `StoreOf<Feature>` — not a ViewModel or store class.
    func testTCAViewReceivesStoreOf() throws {
        let files = try generateAll(type: .tca)
        let view = try XCTUnwrap(content(named: "LoginView.swift", in: files))
        XCTAssertTrue(view.contains("StoreOf<LoginFeature>"),
            "TCA View must receive StoreOf<Feature> — the idiomatic TCA entry point.")
    }

    /// TCA View must use `WithPerceptionTracking` for iOS 16 backward compat with @ObservableState.
    func testTCAViewUsesWithPerceptionTracking() throws {
        let files = try generateAll(type: .tca)
        let view = try XCTUnwrap(content(named: "LoginView.swift", in: files))
        XCTAssertTrue(view.contains("WithPerceptionTracking"),
            "TCA View should wrap body in WithPerceptionTracking for iOS 16 compatibility.")
    }

    /// TCA Preview uses the idiomatic Store + Feature initializer.
    func testTCAViewHasIdiomatic​Preview() throws {
        let files = try generateAll(type: .tca)
        let view = try XCTUnwrap(content(named: "LoginView.swift", in: files))
        XCTAssertTrue(view.contains("#Preview"),
            "TCA View must include a #Preview macro block.")
        XCTAssertTrue(view.contains("Store(initialState: LoginFeature.State())"),
            "TCA Preview must instantiate Store with initialState for correctness.")
    }

    // MARK: - SwiftUI View Best Practices

    /// All non-TCA Views must have `#Preview` using DependencyContainer.
    func testNonTCAViewsHavePreviewMacro() throws {
        for type in [FeatureType.mvvm, .mvi, .viper, .vip, .mvp] {
            // Use a fresh sub-directory per type to avoid fileAlreadyExists collision
            let subDir = tempDirectory.appendingPathComponent(type.rawValue)
            try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
            let feature = try FeatureName(rawValue: "Login")
            let generator = FeatureGenerator(
                projectPath: subDir,
                shouldCreatePackage: false,
                packageTarget: nil,
                shouldGenerateTests: false,
                shouldSkipDomain: false,
                type: type,
                category: nil
            )
            let result = try generator.generate(feature: feature, selection: .all(for: type))
            var viewContent: String?
            for url in result.createdFiles where url.lastPathComponent == "LoginView.swift" {
                viewContent = try String(contentsOf: url, encoding: .utf8)
            }
            let view = try XCTUnwrap(viewContent, "Could not find LoginView.swift for \(type.rawValue)")
            XCTAssertTrue(view.contains("#Preview"),
                "\(type.rawValue) View must include a #Preview block for Xcode Canvas.")
        }
    }

    // MARK: - Package.swift Best Practices

    /// Package.swift must target iOS 15+ minimum (SwiftUI async/await support).
    func testSwiftPackageTargetiOS15() throws {
        let result = try TemplateRenderer.render("swiftPackage.stencil", context: ["name": "MyKit"])
        XCTAssertTrue(result.contains(".iOS(.v15)"),
            "Package.swift must declare iOS 15+ to support async/await and modern SwiftUI APIs.")
    }

    /// Package.swift must specify `swift-tools-version: 5.9` or higher.
    func testSwiftPackageUsesModernToolsVersion() throws {
        let result = try TemplateRenderer.render("swiftPackage.stencil", context: ["name": "MyKit"])
        XCTAssertTrue(result.contains("swift-tools-version: 5.9"),
            "Package.swift should use swift-tools-version 5.9+ for macro support.")
    }

    // MARK: - Test Template Best Practices

    /// ViewModel tests use the same dependency wiring as generated views.
    func testViewModelTestUsesDependencyContainer() throws {
        let result = try TemplateRenderer.render("viewModelTests.stencil", context: [
            "name": "Login", "hasUseCase": false
        ])
        XCTAssertTrue(result.contains("LoginDependencyContainer.makeViewModel()"),
            "Tests must construct the selected variant with its required dependencies.")
    }

    /// UseCase tests inject controllable repository results.
    func testUseCaseTestUsesRepositoryStub() throws {
        let result = try TemplateRenderer.render("useCaseTests.stencil", context: ["name": "Login"])
        XCTAssertTrue(result.contains("UseCaseRepositoryStub"),
            "UseCase tests must inject a repository stub for isolation.")
        XCTAssertTrue(result.contains(": LoginRepository"),
            "Mock must conform to the LoginRepository protocol, not subclass the impl.")
    }

    /// Repository test must test integration with RemoteDataSource (not mock it out).
    func testRepositoryTestUsesRealDataSource() throws {
        let result = try TemplateRenderer.render("repositoryTests.stencil", context: ["name": "Login"])
        XCTAssertTrue(result.contains("LoginRemoteDataSource()"),
            "RepositoryTests are integration tests — they use the real RemoteDataSource.")
        XCTAssertTrue(result.contains("LoginRepositoryImpl(remoteDataSource:"),
            "RepositoryTests instantiate the real Impl to test layer integration.")
    }

    /// TCA Feature test must use `TestStore` — TCA's purpose-built test helper.
    func testTCAFeatureTestUsesTestStore() throws {
        let result = try TemplateRenderer.render("featureTests.stencil", context: ["name": "Login"])
        XCTAssertTrue(result.contains("TestStore"),
            "TCA feature tests must use TestStore, TCA's built-in exhaustive test helper.")
        XCTAssertTrue(result.contains("LoginFeature.State()"),
            "TestStore must be initialized with the Feature's State.")
    }

    /// Reducer test must mutate state via the reducer, not directly.
    func testReducerTestCallsReduceMethod() throws {
        let result = try TemplateRenderer.render("reducerTests.stencil", context: ["name": "Login"])
        XCTAssertTrue(result.contains("sut.reduce(state: &state, intent: .onAppear)"),
            "Reducer tests must call reduce() directly — testing pure function behavior.")
        XCTAssertTrue(result.contains("XCTAssertFalse(state.isLoading)"),
            "Standalone reducers finish loading without performing an effect.")

        let cleanResult = try TemplateRenderer.render("reducerTests.stencil", context: [
            "name": "Login", "isClean": true
        ])
        XCTAssertTrue(cleanResult.contains("XCTAssertTrue(state.isLoading)"),
            "Clean reducers start loading while their store performs the effect.")
    }

    // MARK: - Form Category Best Practices

    /// Form ViewModel `@Published var field1` must be publicly writable (two-way binding).
    func testMVVMFormFieldsArePubliclyWritable() throws {
        let files = try generateAll(type: .mvvm, category: .form)
        let vm = try XCTUnwrap(content(named: "LoginViewModel.swift", in: files))
        // Two-way binding requires public write access — no private(set)
        XCTAssertTrue(vm.contains("@Published var field1"),
            "Form fields need public @Published (no private(set)) for two-way TextField binding.")
        XCTAssertTrue(vm.contains("@Published var field2"),
            "Form fields need public @Published (no private(set)) for two-way TextField binding.")
        XCTAssertFalse(vm.contains("@Published private(set) var field1"),
            "Form fields must not be private(set) — $viewModel.field1 binding requires write access.")
    }

    /// Form view must use `$viewModel.field1` binding (not read-only access).
    func testMVVMFormViewUsesBindingNotReadOnly() throws {
        let files = try generateAll(type: .mvvm, category: .form)
        let view = try XCTUnwrap(content(named: "LoginView.swift", in: files))
        XCTAssertTrue(view.contains("$viewModel.field1"),
            "Form TextField must use binding ($viewModel.field1) for two-way data flow.")
        XCTAssertTrue(view.contains("$viewModel.field2"),
            "Form TextField must use binding ($viewModel.field2) for two-way data flow.")
    }

    // MARK: - List Category Best Practices

    /// List items must be `Identifiable` for efficient SwiftUI diffing.
    func testMVVMListItemIsIdentifiable() throws {
        let files = try generateAll(type: .mvvm, category: .list)
        let vm = try XCTUnwrap(content(named: "LoginViewModel.swift", in: files))
        XCTAssertTrue(vm.contains("Identifiable"),
            "List items must conform to Identifiable for SwiftUI List performance.")
    }

    /// List item structs must have `let id: UUID` rather than `let id = UUID()`.
    /// Initializing UUID() inline means every time a struct copy is made or recreated,
    /// a new UUID is generated, breaking List diffing, animations, and state tracking.
    func testListItemHasStableIdProperty() throws {
        let templates = [
            "mvvmListViewModel.stencil",
            "cleanMvvmListViewModel.stencil",
            "mviListState.stencil",
            "viperListPresenter.stencil",
            "mvpListPresenter.stencil",
            "tcaListFeature.stencil",
        ]
        for t in templates {
            let content = try TemplateRenderer.render(t, context: ["name": "Login"])
            XCTAssertFalse(content.contains("let id = UUID()"),
                "\(t) uses unstable `let id = UUID()`. It should be `let id: UUID`.")
            XCTAssertTrue(content.contains("let id: UUID"),
                "\(t) should declare `let id: UUID` for stable item identity.")
        }
    }

    /// List view must use `List(viewModel.items)` — not `ForEach` standalone in ScrollView.
    func testMVVMListViewUsesListComponent() throws {
        let files = try generateAll(type: .mvvm, category: .list)
        let view = try XCTUnwrap(content(named: "LoginView.swift", in: files))
        XCTAssertTrue(view.contains("List(viewModel.items)"),
            "List view should use SwiftUI List for built-in performance and accessibility.")
    }

    // MARK: - Router Best Practices

    /// VIPER Router must import SwiftUI (it returns `some View`).
    func testVIPERRouterImportsSwiftUI() throws {
        let files = try generateAll(type: .viper)
        let router = try XCTUnwrap(content(named: "LoginRouter.swift", in: files))
        XCTAssertTrue(router.contains("import SwiftUI"),
            "Router returns `some View` — it must import SwiftUI.")
    }

    /// VIPER Router must be a `struct` — stateless, no retained references.
    func testVIPERRouterIsStruct() throws {
        let files = try generateAll(type: .viper)
        let router = try XCTUnwrap(content(named: "LoginRouter.swift", in: files))
        XCTAssertTrue(router.contains("struct LoginRouter"),
            "Router should be a struct — it's a stateless navigation factory.")
    }

    // MARK: - Indentation Consistency

    /// All generated Swift files should not mix tabs and spaces.
    func testGeneratedFilesDoNotMixTabsAndSpaces() throws {
        let feature = try FeatureName(rawValue: "Login")
        for type in FeatureType.allCases {
            let generator = FeatureGenerator(
                projectPath: tempDirectory,
                shouldCreatePackage: false,
                packageTarget: nil,
                shouldGenerateTests: false,
                shouldSkipDomain: false,
                type: type,
                category: nil
            )
            let result = try generator.generate(feature: feature, selection: .all(for: type))
            for url in result.createdFiles {
                let content = try String(contentsOf: url, encoding: .utf8)
                XCTAssertFalse(content.contains("\t"),
                    "\(url.lastPathComponent) (\(type.rawValue)) uses tabs — all indentation should use spaces for Swift style.")
            }
            // Clean up between types
            try FileManager.default.removeItem(at: tempDirectory.appendingPathComponent("Login"))
        }
    }
}
