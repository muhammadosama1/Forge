import Foundation

/// Every file role that an architecture pattern can produce.
///
/// Each case maps to a subdirectory layer, a display name, and generated file name.
/// The same case can behave differently per architecture (e.g. `.entity` lives in
/// `Domain/` for Clean variants but in `Presentation/` for plain VIPER).
enum FeatureFile: String, CaseIterable, Hashable {
    case dependencyContainer
    case feature
    case view
    case viewModel
    case store
    case state
    case intent
    case reducer
    case presenter
    case interactor
    case router
    case contracts
    case worker
    case presentationModels
    case model
    case entity
    case useCase
    case repository
    case repositoryImpl
    case remoteDataSource
    case models
    case viewModelTests
    case storeTests
    case reducerTests
    case presenterTests
    case interactorTests
    case featureTests
    case useCaseTests
    case repositoryTests

    /// Returns the subdirectory name where this file belongs.
    /// - `"Root"` places the file directly at the feature/sources root (e.g. DependencyContainer).
    /// - `"Presentation"`, `"Domain"`, or `"Data"` for layered architectures.
    /// - `"Tests"` for test files.
    ///
    /// The mapping varies per `FeatureType` — for example VIPER keeps `.entity`
    /// in `Presentation/` while Clean architectures place it in `Domain/`.
    func layer(for type: FeatureType) -> String {
        switch self {
        case .dependencyContainer:
            return "Root"
        case .feature:
            return "Presentation"
        case .view, .viewModel, .store, .state, .intent, .reducer:
            return "Presentation"
        case .presenter, .interactor, .router, .contracts, .worker, .presentationModels, .model:
            return "Presentation"
        case .entity, .useCase, .repository:
            if type == .viper {
                return "Presentation"
            }
            return "Domain"
        case .repositoryImpl, .remoteDataSource, .models:
            if type == .vip || type == .mvp {
                return "Presentation"
            }
            return "Data"
        case .viewModelTests, .storeTests, .reducerTests, .presenterTests, .interactorTests, .featureTests, .useCaseTests, .repositoryTests:
            return "Tests"
        }
    }

    /// Whether this file belongs to the Domain layer (Entity, UseCase, Repository protocol).
    /// Used by `--no-domain` to filter out Domain-layer files.
    var isDomain: Bool {
        switch self {
        case .entity, .useCase, .repository:
            return true
        default:
            return false
        }
    }

    /// Whether this file is a Domain-layer test (UseCaseTests, RepositoryTests).
    /// Skipped when `--no-domain` is active.
    var isDomainTest: Bool {
        switch self {
        case .useCaseTests, .repositoryTests:
            return true
        default:
            return false
        }
    }

    /// Whether this file is any test file (presentation or domain).
    var isTest: Bool {
        switch self {
        case .viewModelTests, .storeTests, .reducerTests, .presenterTests, .interactorTests, .featureTests, .useCaseTests, .repositoryTests:
            return true
        default:
            return false
        }
    }

    /// Human-readable name used to build the generated Swift file name.
    /// E.g. `.viewModel` → `"ViewModel"`, giving `SearchViewModel.swift`.
    var displayName: String {
        switch self {
        case .dependencyContainer:
            return "DependencyContainer"
        case .feature:
            return "Feature"
        case .view:
            return "View"
        case .viewModel:
            return "ViewModel"
        case .store:
            return "Store"
        case .state:
            return "State"
        case .intent:
            return "Intent"
        case .reducer:
            return "Reducer"
        case .presenter:
            return "Presenter"
        case .interactor:
            return "Interactor"
        case .router:
            return "Router"
        case .contracts:
            return "Contracts"
        case .worker:
            return "Worker"
        case .presentationModels:
            return "PresentationModels"
        case .model:
            return "Model"
        case .entity:
            return "Entity"
        case .useCase:
            return "UseCase"
        case .repository:
            return "Repository"
        case .repositoryImpl:
            return "RepositoryImpl"
        case .remoteDataSource:
            return "RemoteDataSource"
        case .models:
            return "Models"
        case .viewModelTests:
            return "ViewModelTests"
        case .storeTests:
            return "StoreTests"
        case .reducerTests:
            return "ReducerTests"
        case .presenterTests:
            return "PresenterTests"
        case .interactorTests:
            return "InteractorTests"
        case .featureTests:
            return "FeatureTests"
        case .useCaseTests:
            return "UseCaseTests"
        case .repositoryTests:
            return "RepositoryTests"
        }
    }

    /// Returns the full `.swift` filename for this role, e.g. `"NotesViewModel.swift"`.
    func fileName(for featureName: String) -> String {
        "\(featureName)\(displayName).swift"
    }
}

