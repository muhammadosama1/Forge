import Foundation

/// Presentation pattern selected via CLI flags (`-mvvm`, `-mvi`, etc.).
/// Combined with `-clean` to produce a full `FeatureType`.
enum PresentationArchitecture: String, CaseIterable, CustomStringConvertible {
    case mvvm
    case mvi
    case viper
    case vip
    case mvp
    case tca

    /// Uppercased display name (e.g. `"MVVM"`, `"VIPER"`).
    var description: String {
        rawValue.uppercased()
    }

    /// Comma-separated string of valid CLI flags (e.g. `"-mvvm, -mvi, …"`).
    static var validFlags: String {
        allCases.map { "-\($0.rawValue)" }.joined(separator: ", ")
    }

    /// Parses a CLI flag (e.g. `"-mvvm"`, `"--mvvm"`) into a presentation architecture.
    /// Handles both single-dash and double-dash prefixes.
    static func from(flag: String) -> PresentationArchitecture? {
        let name: String
        if flag.hasPrefix("--") {
            name = String(flag.dropFirst(2))
        } else if flag.hasPrefix("-") {
            name = String(flag.dropFirst())
        } else {
            name = flag
        }
        return PresentationArchitecture(rawValue: name)
    }
}

/// Template specs shared by every Clean Architecture variant (MVVM, MVI, VIPER, VIP, MVP, TCA).
/// These produce the Entity, UseCase, Repository, RepositoryImpl, RemoteDataSource, and Response model.
private let cleanDomainDataSpecs: [TemplateSpec] = [
    TemplateSpec(file: .entity,           templateName: "entity"),
    TemplateSpec(file: .useCase,          templateName: "useCase"),
    TemplateSpec(file: .repository,       templateName: "repository"),
    TemplateSpec(file: .repositoryImpl,   templateName: "repositoryImpl"),
    TemplateSpec(file: .remoteDataSource, templateName: "remoteDataSource"),
    TemplateSpec(file: .models,           templateName: "models"),
]

/// A concrete feature type combining a presentation pattern with optional Clean Architecture layers.
///
/// Each case defines an ordered list of `TemplateSpec` values — the template renderer iterates
/// through them to produce every file for that architecture.
enum FeatureType: String, CaseIterable {
    case cleanMVVM  = "clean-mvvm"
    case cleanVIPER = "clean-viper"
    case cleanVIP   = "clean-vip"
    case cleanMVP   = "clean-mvp"
    case cleanTCA   = "clean-tca"
    case cleanMVI   = "clean-mvi"
    case mvvm
    case mvi
    case viper
    case vip
    case mvp
    case tca

    /// Comma-separated string of all valid feature type identifiers.
    static var validOptions: String {
        allCases.map(\.rawValue).joined(separator: ", ")
    }

    /// Combines a presentation pattern and a clean-architecture flag into a concrete `FeatureType`.
    /// - Parameter presentation: The presentation pattern (mvvm, mvi, …).
    /// - Parameter clean: Whether to include Clean Architecture layers.
    static func resolve(presentation: PresentationArchitecture, clean: Bool) -> FeatureType {
        switch (presentation, clean) {
        case (.mvvm, true):   return .cleanMVVM
        case (.mvvm, false):   return .mvvm
        case (.mvi, true):     return .cleanMVI
        case (.mvi, false):    return .mvi
        case (.viper, true):   return .cleanVIPER
        case (.viper, false):  return .viper
        case (.vip, true):     return .cleanVIP
        case (.vip, false):    return .vip
        case (.mvp, true):     return .cleanMVP
        case (.mvp, false):    return .mvp
        case (.tca, true):     return .cleanTCA
        case (.tca, false):    return .tca
        }
    }

    /// Human-readable name shown in CLI output (e.g. `"Clean Architecture + MVVM"`).
    var displayName: String {
        switch self {
        case .cleanMVVM:  return "Clean Architecture + MVVM"
        case .cleanVIPER: return "Clean Architecture + VIPER"
        case .cleanVIP:   return "Clean Architecture + VIP"
        case .cleanMVP:   return "Clean Architecture + MVP"
        case .cleanTCA:   return "Clean Architecture + TCA"
        case .cleanMVI:   return "Clean Architecture + MVI"
        case .mvvm:       return "MVVM"
        case .mvi:        return "MVI"
        case .viper:      return "VIPER"
        case .vip:        return "VIP"
        case .mvp:        return "MVP"
        case .tca:        return "TCA"
        }
    }

    /// Whether this type includes Clean Architecture Domain and Data layers.
    var hasCleanLayers: Bool {
        switch self {
        case .cleanMVVM, .cleanVIPER, .cleanVIP, .cleanMVP, .cleanTCA, .cleanMVI: return true
        case .mvvm, .mvi, .viper, .vip, .mvp, .tca:                               return false
        }
    }

    // MARK: - Data-driven template specifications

    /// Ordered list of files available for this architecture pattern.
    var availableFiles: [FeatureFile] {
        templateSpecs.map(\.file)
    }

    /// Ordered list of files to generate for this architecture pattern.
    /// Adding a new pattern only requires adding one case here — no new methods elsewhere.
    var templateSpecs: [TemplateSpec] {
        switch self {
        case .cleanMVVM:
            return [
                TemplateSpec(file: .dependencyContainer, templateName: "cleanMvvmDependencyContainer"),
                TemplateSpec(file: .view,                templateName: "cleanMvvmView"),
                TemplateSpec(file: .viewModel,           templateName: "cleanMvvmViewModel"),
            ] + cleanDomainDataSpecs

        case .cleanVIPER:
            return [
                TemplateSpec(file: .dependencyContainer, templateName: "cleanViperDependencyContainer"),
                TemplateSpec(file: .view,                templateName: "viperView"),
                TemplateSpec(file: .presenter,           templateName: "viperPresenter"),
                TemplateSpec(file: .interactor,          templateName: "cleanViperInteractor"),
                TemplateSpec(file: .router,              templateName: "viperRouter"),
                TemplateSpec(file: .contracts,           templateName: "cleanViperContracts"),
            ] + cleanDomainDataSpecs

        case .cleanVIP:
            return [
                TemplateSpec(file: .dependencyContainer,  templateName: "cleanVipDependencyContainer"),
                TemplateSpec(file: .view,                 templateName: "vipView"),
                TemplateSpec(file: .interactor,           templateName: "cleanVipInteractor"),
                TemplateSpec(file: .presenter,            templateName: "cleanVipPresenter"),
                TemplateSpec(file: .presentationModels,   templateName: "vipModels"),
            ] + cleanDomainDataSpecs

        case .cleanMVP:
            return [
                TemplateSpec(file: .dependencyContainer, templateName: "cleanMvpDependencyContainer"),
                TemplateSpec(file: .view,                templateName: "mvpView"),
                TemplateSpec(file: .presenter,           templateName: "cleanMvpPresenter"),
                TemplateSpec(file: .model,               templateName: "mvpModel"),
            ] + cleanDomainDataSpecs

        case .cleanTCA:
            return [
                TemplateSpec(file: .dependencyContainer, templateName: "cleanTcaDependencyContainer"),
                TemplateSpec(file: .feature,             templateName: "tcaFeature"),
                TemplateSpec(file: .view,                templateName: "tcaView"),
            ] + cleanDomainDataSpecs

        case .cleanMVI:
            return [
                TemplateSpec(file: .dependencyContainer, templateName: "cleanMviDependencyContainer"),
                TemplateSpec(file: .view,                templateName: "mviView"),
                TemplateSpec(file: .store,               templateName: "cleanMviStore"),
                TemplateSpec(file: .state,               templateName: "cleanMviState"),
                TemplateSpec(file: .intent,              templateName: "cleanMviIntent"),
                TemplateSpec(file: .reducer,             templateName: "cleanMviReducer"),
            ] + cleanDomainDataSpecs

        case .mvvm:
            return [
                TemplateSpec(file: .dependencyContainer, templateName: "mvvmDependencyContainer"),
                TemplateSpec(file: .view,                templateName: "mvvmSwiftUIView"),
                TemplateSpec(file: .viewModel,           templateName: "mvvmViewModel"),
            ]

        case .mvi:
            return [
                TemplateSpec(file: .dependencyContainer, templateName: "mviDependencyContainer"),
                TemplateSpec(file: .view,                templateName: "mviView"),
                TemplateSpec(file: .store,               templateName: "mviStore"),
                TemplateSpec(file: .state,               templateName: "mviState"),
                TemplateSpec(file: .intent,              templateName: "mviIntent"),
                TemplateSpec(file: .reducer,             templateName: "mviReducer"),
            ]

        case .viper:
            return [
                TemplateSpec(file: .dependencyContainer, templateName: "viperDependencyContainer"),
                TemplateSpec(file: .view,                templateName: "viperView"),
                TemplateSpec(file: .presenter,           templateName: "viperPresenter"),
                TemplateSpec(file: .interactor,          templateName: "viperInteractor"),
                TemplateSpec(file: .router,              templateName: "viperRouter"),
                TemplateSpec(file: .entity,              templateName: "viperEntity"),
                TemplateSpec(file: .contracts,           templateName: "viperContracts"),
            ]

        case .vip:
            return [
                TemplateSpec(file: .dependencyContainer, templateName: "vipDependencyContainer"),
                TemplateSpec(file: .view,                templateName: "vipView"),
                TemplateSpec(file: .interactor,          templateName: "vipInteractor"),
                TemplateSpec(file: .presenter,           templateName: "vipPresenter"),
                TemplateSpec(file: .worker,              templateName: "vipWorker"),
                TemplateSpec(file: .presentationModels,  templateName: "vipModels"),
            ]

        case .mvp:
            return [
                TemplateSpec(file: .dependencyContainer, templateName: "mvpDependencyContainer"),
                TemplateSpec(file: .view,                templateName: "mvpView"),
                TemplateSpec(file: .presenter,           templateName: "mvpPresenter"),
                TemplateSpec(file: .model,               templateName: "mvpModel"),
            ]

        case .tca:
            return [
                TemplateSpec(file: .feature, templateName: "tcaFeature"),
                TemplateSpec(file: .view,    templateName: "tcaView"),
            ]
        }
    }

    /// Ordered list of test specs for this architecture pattern.
    var testTemplateSpecs: [TemplateSpec] {
        let presentationTests: [TemplateSpec]
        switch self {
        case .cleanMVVM, .mvvm:
            presentationTests = [
                TemplateSpec(file: .viewModelTests, templateName: "viewModelTests"),
            ]
        case .cleanMVI, .mvi:
            presentationTests = [
                TemplateSpec(file: .storeTests,   templateName: "storeTests"),
                TemplateSpec(file: .reducerTests,  templateName: "reducerTests"),
            ]
        case .cleanVIPER, .viper:
            presentationTests = [
                TemplateSpec(file: .presenterTests,  templateName: "presenterTests"),
                TemplateSpec(file: .interactorTests, templateName: "interactorTests"),
            ]
        case .cleanVIP, .vip:
            presentationTests = [
                TemplateSpec(file: .presenterTests,  templateName: "presenterTests"),
                TemplateSpec(file: .interactorTests, templateName: "interactorTests"),
            ]
        case .cleanMVP, .mvp:
            presentationTests = [
                TemplateSpec(file: .presenterTests, templateName: "presenterTests"),
            ]
        case .cleanTCA, .tca:
            presentationTests = [
                TemplateSpec(file: .featureTests, templateName: "featureTests"),
            ]
        }

        if hasCleanLayers {
            return presentationTests + [
                TemplateSpec(file: .useCaseTests,    templateName: "useCaseTests"),
                TemplateSpec(file: .repositoryTests, templateName: "repositoryTests"),
            ]
        }
        return presentationTests
    }
}
