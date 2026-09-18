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
        templateSpecs(for: nil)
    }

    /// Ordered list of files to generate, with optional category-specific view templates.
    func templateSpecs(for category: FeatureCategory?) -> [TemplateSpec] {
        func viewSpec(_ name: String) -> TemplateSpec {
            TemplateSpec(file: .view, templateName: name)
        }

        func viewModelSpec(_ name: String) -> TemplateSpec {
            TemplateSpec(file: .viewModel, templateName: name)
        }

        func presenterSpec(_ name: String) -> TemplateSpec {
            TemplateSpec(file: .presenter, templateName: name)
        }

        func storeSpec(_ name: String) -> TemplateSpec {
            TemplateSpec(file: .store, templateName: name)
        }

        func stateSpec(_ name: String) -> TemplateSpec {
            TemplateSpec(file: .state, templateName: name)
        }

        func intentSpec(_ name: String) -> TemplateSpec {
            TemplateSpec(file: .intent, templateName: name)
        }

        func featureSpec(_ name: String) -> TemplateSpec {
            TemplateSpec(file: .feature, templateName: name)
        }

        switch self {
        case .cleanMVVM:
            let view: String
            let vm: String
            switch category {
            case .form:  view = "cleanMvvmFormView";     vm = "cleanMvvmFormViewModel"
            case .list:  view = "cleanMvvmListView";     vm = "cleanMvvmListViewModel"
            case nil:    view = "cleanMvvmView";         vm = "cleanMvvmViewModel"
            }
            return [
                TemplateSpec(file: .dependencyContainer, templateName: "cleanMvvmDependencyContainer"),
                viewSpec(view),
                viewModelSpec(vm),
            ] + cleanDomainDataSpecs

        case .cleanVIPER:
            let view: String
            let pres: String
            switch category {
            case .form:  view = "viperFormView";         pres = "viperFormPresenter"
            case .list:  view = "viperListView";         pres = "viperListPresenter"
            case nil:    view = "viperView";             pres = "viperPresenter"
            }
            return [
                TemplateSpec(file: .dependencyContainer, templateName: "cleanViperDependencyContainer"),
                viewSpec(view),
                presenterSpec(pres),
                TemplateSpec(file: .interactor, templateName: "cleanViperInteractor"),
                TemplateSpec(file: .router, templateName: "viperRouter"),
                TemplateSpec(file: .contracts, templateName: "cleanViperContracts"),
            ] + cleanDomainDataSpecs

        case .cleanVIP:
            let view: String
            let pres: String
            switch category {
            case .form:  view = "vipFormView";           pres = "vipFormPresenter"
            case .list:  view = "vipListView";           pres = "vipListPresenter"
            case nil:    view = "vipView";               pres = "cleanVipPresenter"
            }
            return [
                TemplateSpec(file: .dependencyContainer,  templateName: "cleanVipDependencyContainer"),
                viewSpec(view),
                TemplateSpec(file: .interactor,           templateName: "cleanVipInteractor"),
                presenterSpec(pres),
                TemplateSpec(file: .presentationModels,   templateName: "vipModels"),
            ] + cleanDomainDataSpecs

        case .cleanMVP:
            let view: String
            let pres: String
            switch category {
            case .form:  view = "mvpFormView";           pres = "mvpFormPresenter"
            case .list:  view = "mvpListView";           pres = "mvpListPresenter"
            case nil:    view = "mvpView";               pres = "cleanMvpPresenter"
            }
            return [
                TemplateSpec(file: .dependencyContainer, templateName: "cleanMvpDependencyContainer"),
                viewSpec(view),
                presenterSpec(pres),
                TemplateSpec(file: .model,               templateName: "mvpModel"),
            ] + cleanDomainDataSpecs

        case .cleanTCA:
            let feat: String
            let view: String
            switch category {
            case .form:  feat = "tcaFormFeature";        view = "tcaFormView"
            case .list:  feat = "tcaListFeature";        view = "tcaListView"
            case nil:    feat = "tcaFeature";            view = "tcaView"
            }
            return [
                featureSpec(feat),
                viewSpec(view),
            ] + cleanDomainDataSpecs

        case .cleanMVI:
            let view: String
            let store: String
            let state: String
            let intent: String
            switch category {
            case .form:  view = "mviFormView";           store = "mviFormStore";         state = "mviFormState";         intent = "mviFormIntent"
            case .list:  view = "mviListView";           store = "mviListStore";         state = "mviListState";         intent = "mviListIntent"
            case nil:    view = "mviView";               store = "cleanMviStore";        state = "cleanMviState";        intent = "cleanMviIntent"
            }
            return [
                TemplateSpec(file: .dependencyContainer, templateName: "cleanMviDependencyContainer"),
                viewSpec(view),
                storeSpec(store),
                stateSpec(state),
                intentSpec(intent),
                TemplateSpec(file: .reducer,             templateName: "cleanMviReducer"),
            ] + cleanDomainDataSpecs

        case .mvvm:
            let view: String
            let vm: String
            switch category {
            case .form:  view = "mvvmFormView";          vm = "mvvmFormViewModel"
            case .list:  view = "mvvmListView";          vm = "mvvmListViewModel"
            case nil:    view = "mvvmSwiftUIView";       vm = "mvvmViewModel"
            }
            return [
                TemplateSpec(file: .dependencyContainer, templateName: "mvvmDependencyContainer"),
                viewSpec(view),
                viewModelSpec(vm),
            ]

        case .mvi:
            let view: String
            let store: String
            let state: String
            let intent: String
            switch category {
            case .form:  view = "mviFormView";           store = "mviFormStore";         state = "mviFormState";         intent = "mviFormIntent"
            case .list:  view = "mviListView";           store = "mviListStore";         state = "mviListState";         intent = "mviListIntent"
            case nil:    view = "mviView";               store = "mviStore";             state = "mviState";             intent = "mviIntent"
            }
            return [
                TemplateSpec(file: .dependencyContainer, templateName: "mviDependencyContainer"),
                viewSpec(view),
                storeSpec(store),
                stateSpec(state),
                intentSpec(intent),
                TemplateSpec(file: .reducer,             templateName: "mviReducer"),
            ]

        case .viper:
            let view: String
            let pres: String
            switch category {
            case .form:  view = "viperFormView";         pres = "viperFormPresenter"
            case .list:  view = "viperListView";         pres = "viperListPresenter"
            case nil:    view = "viperView";             pres = "viperPresenter"
            }
            return [
                TemplateSpec(file: .dependencyContainer, templateName: "viperDependencyContainer"),
                viewSpec(view),
                presenterSpec(pres),
                TemplateSpec(file: .interactor,          templateName: "viperInteractor"),
                TemplateSpec(file: .router,              templateName: "viperRouter"),
                TemplateSpec(file: .entity,              templateName: "viperEntity"),
                TemplateSpec(file: .contracts,           templateName: "viperContracts"),
            ]

        case .vip:
            let view: String
            let pres: String
            switch category {
            case .form:  view = "vipFormView";           pres = "vipFormPresenter"
            case .list:  view = "vipListView";           pres = "vipListPresenter"
            case nil:    view = "vipView";               pres = "vipPresenter"
            }
            return [
                TemplateSpec(file: .dependencyContainer, templateName: "vipDependencyContainer"),
                viewSpec(view),
                TemplateSpec(file: .interactor,          templateName: "vipInteractor"),
                presenterSpec(pres),
                TemplateSpec(file: .worker,              templateName: "vipWorker"),
                TemplateSpec(file: .presentationModels,  templateName: "vipModels"),
            ]

        case .mvp:
            let view: String
            let pres: String
            switch category {
            case .form:  view = "mvpFormView";           pres = "mvpFormPresenter"
            case .list:  view = "mvpListView";           pres = "mvpListPresenter"
            case nil:    view = "mvpView";               pres = "mvpPresenter"
            }
            return [
                TemplateSpec(file: .dependencyContainer, templateName: "mvpDependencyContainer"),
                viewSpec(view),
                presenterSpec(pres),
                TemplateSpec(file: .model,               templateName: "mvpModel"),
            ]

        case .tca:
            let feat: String
            let view: String
            switch category {
            case .form:  feat = "tcaFormFeature";        view = "tcaFormView"
            case .list:  feat = "tcaListFeature";        view = "tcaListView"
            case nil:    feat = "tcaFeature";            view = "tcaView"
            }
            return [
                featureSpec(feat),
                viewSpec(view),
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
