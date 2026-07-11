import Foundation

/// Dictionary of all `.stencil` template strings, keyed by their filename.
///
/// Each entry is a plain string — no file I/O at runtime. New templates are added
/// by inserting a new key-value pair here and referencing the key in `FeatureType.templateSpecs`.
enum TemplateContent {
    /// Template name → raw template content.
    static let files: [String: String] = [
        // MARK: Infrastructure

        "fileHeader.stencil": """
//
//  {{ fileName }}
//  {{ projectName }}
//
//  Created by {{ authorName }} on {{ createdDate }}.
//

""",

        "swiftPackage.stencil": """
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "{{ name }}",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(
            name: "{{ name }}",
            targets: ["{{ name }}"]
        ),
    ],
    targets: [
        .target(
            name: "{{ name }}"
        )
    ]
)

""",

        // MARK: Domain / Data

        "entity.stencil": """
import Foundation

struct {{ name }}Entity: Equatable, Identifiable {
    let id: UUID
    let title: String
}


""",

        "models.stencil": """
import Foundation

struct {{ name }}Response: Decodable {
    let id: UUID
    let title: String
{% if hasUseCase %}
    func toDomain() -> {{ name }}Entity {
        {{ name }}Entity(id: id, title: title)
    }
{% endif %}
}

""",

        "remoteDataSource.stencil": """
import Foundation

final class {{ name }}RemoteDataSource {
    func fetch{{ name }}() async throws -> {{ name }}Response {
        {{ name }}Response(id: UUID(), title: "{{ name }}")
    }
}

""",

        "repository.stencil": """
import Foundation

protocol {{ name }}Repository {
    func fetch{{ name }}() async throws -> {{ name }}Entity
}


""",

        "repositoryImpl.stencil": """
import Foundation

final class {{ name }}RepositoryImpl{% if hasRepository %}: {{ name }}Repository{% endif %} {
    private let remoteDataSource: {{ name }}RemoteDataSource

    init(remoteDataSource: {{ name }}RemoteDataSource) {
        self.remoteDataSource = remoteDataSource
    }

    func fetch{{ name }}() async throws -> {% if hasNoDomain %}{{ name }}Response{% else %}{{ name }}Entity{% endif %} {
        let response = try await remoteDataSource.fetch{{ name }}()
        {% if hasNoDomain %}return response{% else %}return response.toDomain(){% endif %}
    }
}

""",

        "useCase.stencil": """
import Foundation

struct {{ name }}UseCase {
    private let repository: {{ name }}Repository

    init(repository: {{ name }}Repository) {
        self.repository = repository
    }

    func execute() async throws -> {{ name }}Entity {
        try await repository.fetch{{ name }}()
    }
}

""",

        // MARK: MVVM

        "cleanMvvmDependencyContainer.stencil": """
import SwiftUI

enum {{ name }}DependencyContainer {
{% if hasView %}
    @MainActor
    static func makeView() -> {{ name }}View {
        {{ name }}View(viewModel: makeViewModel())
    }
{% endif %}

{% if hasViewModel %}
    @MainActor
    static func makeViewModel() -> {{ name }}ViewModel {
{% if hasNoDomain %}
        {{ name }}ViewModel(repository: makeRepository())
{% else %}
        {{ name }}ViewModel(useCase: makeUseCase())
{% endif %}
    }
{% endif %}
{% if hasNoDomain %}

    static func makeRepository() -> {{ name }}RepositoryImpl {
        {{ name }}RepositoryImpl(remoteDataSource: makeRemoteDataSource())
    }
{% endif %}

{% if hasUseCase %}
    static func makeUseCase() -> {{ name }}UseCase {
        {{ name }}UseCase(repository: makeRepository())
    }
{% endif %}

{% if hasRepository %}
    static func makeRepository() -> {{ name }}Repository {
        {{ name }}RepositoryImpl(remoteDataSource: makeRemoteDataSource())
    }
{% endif %}

{% if hasRemoteDataSource %}
    static func makeRemoteDataSource() -> {{ name }}RemoteDataSource {
        {{ name }}RemoteDataSource()
    }
{% endif %}
}

""",

        "mvvmDependencyContainer.stencil": """
import SwiftUI

enum {{ name }}DependencyContainer {
    {% if hasView %}
        @MainActor
        static func makeView() -> {{ name }}View {
            {{ name }}View(viewModel: makeViewModel())
        }
    {% endif %}
    {% if hasViewModel %}
        @MainActor
        static func makeViewModel() -> {{ name }}ViewModel {
            {{ name }}ViewModel()
        }
    {% endif %}
}

""",

        "mvvmSwiftUIView.stencil": """
import SwiftUI

struct {{ name }}View: View {
    @StateObject private var viewModel: {{ name }}ViewModel

    init(viewModel: {{ name }}ViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Text(viewModel.title)
            .task {
                await viewModel.load()
            }
    }
}
        {% if hasDependencyContainer %}
#Preview {
    {{ name }}DependencyContainer.makeView()
}
{% endif %}

""",

        "mvvmViewModel.stencil": """
import Combine
import Foundation

@MainActor
final class {{ name }}ViewModel: ObservableObject {
    @Published private(set) var title = "{{ name }}"
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }

        errorMessage = nil
    }
}

""",

        "cleanMvvmView.stencil": """
import SwiftUI

struct {{ name }}View: View {
    @StateObject private var viewModel: {{ name }}ViewModel

    init(viewModel: {{ name }}ViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Text(viewModel.{% if hasNoDomain %}response?.title ?? ""{% else %}entity?.title ?? ""{% endif %})
            .task {
                await viewModel.load()
            }
    }
}
{% if hasDependencyContainer %}
#Preview {
    {{ name }}DependencyContainer.makeView()
}
{% endif %}

""",

        "cleanMvvmViewModel.stencil": """
import Combine
import Foundation

@MainActor
final class {{ name }}ViewModel: ObservableObject {
    @Published private(set) var {% if hasNoDomain %}response{% else %}entity{% endif %}: {% if hasNoDomain %}{{ name }}Response?{% else %}{{ name }}Entity?{% endif %}
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
{% if hasNoDomain %}
    private let repository: {{ name }}RepositoryImpl

    init(repository: {{ name }}RepositoryImpl) {
        self.repository = repository
    }
{% else %}
    private let useCase: {{ name }}UseCase

    init(useCase: {{ name }}UseCase) {
        self.useCase = useCase
    }
{% endif %}

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
{% if hasNoDomain %}
            response = try await repository.fetch{{ name }}()
{% else %}
            entity = try await useCase.execute()
{% endif %}
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

""",

        // MARK: MVI

        "mviDependencyContainer.stencil": """
import SwiftUI

enum {{ name }}DependencyContainer {
        {% if hasStore %}
            @MainActor
            static func makeStore() -> {{ name }}Store {
                {{ name }}Store(reducer: {{ name }}Reducer())
            }
{% endif %}

}

""",

        "mviIntent.stencil": """
import Foundation

enum {{ name }}Intent: Equatable {
    case onAppear
}


""",

        "mviReducer.stencil": """
import Foundation

struct {{ name }}Reducer {
    func reduce(state: inout {{ name }}State, intent: {{ name }}Intent) {
        switch intent {
        case .onAppear:
            state.isLoading = false
            state.errorMessage = nil
        }
    }
}

""",

        "mviState.stencil": """
import Foundation

struct {{ name }}State: Equatable {
    var title = "{{ name }}"
    var isLoading = false
    var errorMessage: String?
}


""",

        "mviStore.stencil": """
import Combine
import Foundation

@MainActor
final class {{ name }}Store: ObservableObject {
    @Published private(set) var state: {{ name }}State

    private let reducer: {{ name }}Reducer

    init(state: {{ name }}State = {{ name }}State(), reducer: {{ name }}Reducer) {
        self.state = state
        self.reducer = reducer
    }

    func send(_ intent: {{ name }}Intent) async {
        reducer.reduce(state: &state, intent: intent)
    }
}

""",

        "mviView.stencil": """
import SwiftUI

struct {{ name }}View: View {
    @StateObject private var store: {{ name }}Store

    init(store: {{ name }}Store) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.state.title)

            if store.state.isLoading {
                ProgressView()
            }

            if let errorMessage = store.state.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
        .task {
            await store.send(.onAppear)
        }
    }
}
        {% if hasDependencyContainer %}
#Preview {
    {{ name }}DependencyContainer.makeView()
}
{% endif %}

""",

        "cleanMviDependencyContainer.stencil": """
import SwiftUI

enum {{ name }}DependencyContainer {
{% if hasStore %}
    @MainActor
    static func makeStore() -> {{ name }}Store {
{% if hasNoDomain %}
        {{ name }}Store(repository: makeRepository(), reducer: {{ name }}Reducer())
{% else %}
        {{ name }}Store(useCase: makeUseCase(), reducer: {{ name }}Reducer())
{% endif %}
    }
{% endif %}
{% if hasNoDomain %}

    static func makeRepository() -> {{ name }}RepositoryImpl {
        {{ name }}RepositoryImpl(remoteDataSource: makeRemoteDataSource())
    }
{% endif %}
{% if hasUseCase %}
    static func makeUseCase() -> {{ name }}UseCase {
        {{ name }}UseCase(repository: makeRepository())
    }
{% endif %}
{% if hasRepository %}
    static func makeRepository() -> {{ name }}Repository {
        {{ name }}RepositoryImpl(remoteDataSource: makeRemoteDataSource())
    }
{% endif %}
{% if hasRemoteDataSource %}
    static func makeRemoteDataSource() -> {{ name }}RemoteDataSource {
        {{ name }}RemoteDataSource()
    }
{% endif %}
}

""",

        "cleanMviIntent.stencil": """
import Foundation

enum {{ name }}Intent: Equatable {
    case onAppear
    case didLoad({% if hasNoDomain %}{{ name }}Response{% else %}{{ name }}Entity{% endif %})
    case didFail(String)
}


""",

        "cleanMviReducer.stencil": """
import Foundation

struct {{ name }}Reducer {
    func reduce(state: inout {{ name }}State, intent: {{ name }}Intent) {
        switch intent {
        case .onAppear:
            state.isLoading = true
            state.errorMessage = nil
        case .didLoad(let value):
{% if hasNoDomain %}
            state.response = value
{% else %}
            state.entity = value
{% endif %}
            state.title = value.title
            state.isLoading = false
        case .didFail(let message):
            state.errorMessage = message
            state.isLoading = false
        }
    }
}


""",

        "cleanMviState.stencil": """
import Foundation

struct {{ name }}State: Equatable {
    {% if hasNoDomain %}var response: {{ name }}Response?
    {% else %}var entity: {{ name }}Entity?
    {% endif %}var title = "{{ name }}"
    var isLoading = false
    var errorMessage: String?
}


""",

        "cleanMviStore.stencil": """
import Combine
import Foundation

@MainActor
final class {{ name }}Store: ObservableObject {
    @Published private(set) var state: {{ name }}State

    private let reducer: {{ name }}Reducer
{% if hasNoDomain %}
    private let repository: {{ name }}RepositoryImpl

    init(state: {{ name }}State = {{ name }}State(), repository: {{ name }}RepositoryImpl, reducer: {{ name }}Reducer) {
        self.state = state
        self.repository = repository
        self.reducer = reducer
    }
{% else %}
    private let useCase: {{ name }}UseCase

    init(state: {{ name }}State = {{ name }}State(), useCase: {{ name }}UseCase, reducer: {{ name }}Reducer) {
        self.state = state
        self.useCase = useCase
        self.reducer = reducer
    }
{% endif %}

    func send(_ intent: {{ name }}Intent) async {
        reducer.reduce(state: &state, intent: intent)

        guard case .onAppear = intent else {
            return
        }

        do {
{% if hasNoDomain %}
            let response = try await repository.fetch{{ name }}()
            reducer.reduce(state: &state, intent: .didLoad(response))
{% else %}
            let entity = try await useCase.execute()
            reducer.reduce(state: &state, intent: .didLoad(entity))
{% endif %}
        } catch {
            reducer.reduce(state: &state, intent: .didFail(error.localizedDescription))
        }
    }
}

""",

        // MARK: VIPER

        "viperContracts.stencil": """
import Foundation

protocol {{ name }}ViewInput: AnyObject {}

protocol {{ name }}PresenterInput {
    func viewDidLoad() async
}

protocol {{ name }}InteractorInput {
    func load() async -> {{ name }}Entity
}

protocol {{ name }}RouterInput {}


""",

        "viperDependencyContainer.stencil": """
import SwiftUI

enum {{ name }}DependencyContainer {
{% if hasPresenter %}
    @MainActor
    static func makePresenter() -> {{ name }}Presenter {
        {{ name }}Presenter(interactor: makeInteractor(), router: makeRouter())
    }
{% endif %}
{% if hasInteractor %}
    static func makeInteractor() -> {{ name }}Interactor {
        {{ name }}Interactor()
    }
{% endif %}
{% if hasRouter %}
    static func makeRouter() -> {{ name }}Router {
        {{ name }}Router()
    }
{% endif %}
}

""",

        "viperEntity.stencil": """
import Foundation

struct {{ name }}Entity: Equatable {
    let title: String
}


""",

        "viperInteractor.stencil": """
import Foundation

final class {{ name }}Interactor {
    func load() async -> {{ name }}Entity {
        {{ name }}Entity(title: "{{ name }}")
    }
}

""",

        "viperPresenter.stencil": """
import Combine
import Foundation

@MainActor
final class {{ name }}Presenter: ObservableObject, {{ name }}PresenterInput {
    @Published private(set) var title = "{{ name }}"

    private let interactor: {{ name }}Interactor
    private let router: {{ name }}Router

    init(interactor: {{ name }}Interactor, router: {{ name }}Router) {
        self.interactor = interactor
        self.router = router
    }

    func viewDidLoad() async {
        let entity = await interactor.load()
        title = entity.title
    }
}

""",

        "viperRouter.stencil": """
import SwiftUI

struct {{ name }}Router {
    func destination() -> some View {
        EmptyView()
    }
}

""",

        "viperView.stencil": """
import SwiftUI

struct {{ name }}View: View {
    @StateObject private var presenter: {{ name }}Presenter

    init(presenter: {{ name }}Presenter) {
        _presenter = StateObject(wrappedValue: presenter)
    }

    var body: some View {
        Text(presenter.title)
            .task {
                await presenter.viewDidLoad()
            }
    }
}
{% if hasDependencyContainer %}
#Preview {
    {{ name }}DependencyContainer.makeView()
}
{% endif %}

""",

        "cleanViperContracts.stencil": """
import Foundation

protocol {{ name }}ViewInput: AnyObject {}

protocol {{ name }}PresenterInput {
    func viewDidLoad() async
}

protocol {{ name }}InteractorInput {
{% if hasNoDomain %}
    func load() async -> {{ name }}Response
{% else %}
    func load() async -> {{ name }}Entity
{% endif %}
}

protocol {{ name }}RouterInput {}


""",

        "cleanViperDependencyContainer.stencil": """
import SwiftUI

enum {{ name }}DependencyContainer {
{% if hasPresenter %}
    @MainActor
    static func makePresenter() -> {{ name }}Presenter {
        {{ name }}Presenter(interactor: makeInteractor(), router: makeRouter())
    }
{% endif %}
{% if hasInteractor %}
    static func makeInteractor() -> {{ name }}Interactor {
{% if hasNoDomain %}
        {{ name }}Interactor(repository: makeRepository())
{% else %}
        {{ name }}Interactor(useCase: makeUseCase())
{% endif %}
    }
{% endif %}
{% if hasRouter %}
    static func makeRouter() -> {{ name }}Router {
        {{ name }}Router()
    }
{% endif %}
{% if hasNoDomain %}

    static func makeRepository() -> {{ name }}RepositoryImpl {
        {{ name }}RepositoryImpl(remoteDataSource: makeRemoteDataSource())
    }
{% endif %}
{% if hasUseCase %}
    static func makeUseCase() -> {{ name }}UseCase {
        {{ name }}UseCase(repository: makeRepository())
    }
{% endif %}
{% if hasRepository %}
    static func makeRepository() -> {{ name }}Repository {
        {{ name }}RepositoryImpl(remoteDataSource: makeRemoteDataSource())
    }
{% endif %}
{% if hasRemoteDataSource %}
    static func makeRemoteDataSource() -> {{ name }}RemoteDataSource {
        {{ name }}RemoteDataSource()
    }
{% endif %}
}

""",

        "cleanViperInteractor.stencil": """
import Foundation

final class {{ name }}Interactor {
{% if hasNoDomain %}
    private let repository: {{ name }}RepositoryImpl

    init(repository: {{ name }}RepositoryImpl) {
        self.repository = repository
    }

    func load() async -> {{ name }}Response {
        do {
            return try await repository.fetch{{ name }}()
        } catch {
            return {{ name }}Response(id: UUID(), title: "{{ name }}")
        }
    }
{% else %}
    private let useCase: {{ name }}UseCase

    init(useCase: {{ name }}UseCase) {
        self.useCase = useCase
    }

    func load() async -> {{ name }}Entity {
        do {
            return try await useCase.execute()
        } catch {
            return {{ name }}Entity(id: UUID(), title: "{{ name }}")
        }
    }
{% endif %}
}


""",

        // MARK: VIP

        "vipDependencyContainer.stencil": """
import SwiftUI

enum {{ name }}DependencyContainer {
        {% if hasInteractor %}
            @MainActor
            static func makeInteractor() -> {{ name }}Interactor {
                {{ name }}Interactor(presenter: makePresenter(), worker: makeWorker())
            }
{% endif %}
{% if hasPresenter %}
            @MainActor
            static func makePresenter() -> {{ name }}Presenter {
                {{ name }}Presenter()
            }
{% endif %}
{% if hasWorker %}
            static func makeWorker() -> {{ name }}Worker {
                {{ name }}Worker()
            }
{% endif %}

}

""",

        "vipInteractor.stencil": """
import Combine
import Foundation

@MainActor
final class {{ name }}Interactor: ObservableObject {
    @Published private(set) var viewModel = {{ name }}.ViewModel(title: "{{ name }}")

    private let presenter: {{ name }}Presenter
    private let worker: {{ name }}Worker

    init(presenter: {{ name }}Presenter, worker: {{ name }}Worker) {
        self.presenter = presenter
        self.worker = worker
    }

    func load() async {
        let response = await worker.fetch()
        viewModel = presenter.present(response: response)
    }
}

""",

        "vipModels.stencil": """
import Foundation

enum {{ name }} {
    struct Request {}

    struct Response {
        let title: String
    }

    struct ViewModel {
        let title: String
    }
}

""",

        "vipPresenter.stencil": """
import Foundation

@MainActor
final class {{ name }}Presenter {
    func present(response: {{ name }}.Response) -> {{ name }}.ViewModel {
{{ name }}.ViewModel(title: response.title)
    }
}


""",

        "vipView.stencil": """
import SwiftUI

struct {{ name }}View: View {
    @StateObject private var interactor: {{ name }}Interactor

    init(interactor: {{ name }}Interactor) {
        _interactor = StateObject(wrappedValue: interactor)
    }

    var body: some View {
        Text(interactor.viewModel.title)
            .task {
                await interactor.load()
            }
    }
}
        {% if hasDependencyContainer %}
#Preview {
    {{ name }}DependencyContainer.makeView()
}
{% endif %}

""",

        "vipWorker.stencil": """
import Foundation

struct {{ name }}Worker {
    func fetch() async -> {{ name }}.Response {
        {{ name }}.Response(title: "{{ name }}")
    }
}

""",

        "cleanVipDependencyContainer.stencil": """
import SwiftUI

enum {{ name }}DependencyContainer {
{% if hasInteractor %}
    @MainActor
    static func makeInteractor() -> {{ name }}Interactor {
{% if hasNoDomain %}
        {{ name }}Interactor(presenter: makePresenter(), repository: makeRepository())
{% else %}
        {{ name }}Interactor(presenter: makePresenter(), useCase: makeUseCase())
{% endif %}
    }
{% endif %}
{% if hasPresenter %}
    @MainActor
    static func makePresenter() -> {{ name }}Presenter {
        {{ name }}Presenter()
    }
{% endif %}
{% if hasNoDomain %}

    static func makeRepository() -> {{ name }}RepositoryImpl {
        {{ name }}RepositoryImpl(remoteDataSource: makeRemoteDataSource())
    }
{% endif %}
{% if hasUseCase %}
    static func makeUseCase() -> {{ name }}UseCase {
        {{ name }}UseCase(repository: makeRepository())
    }
{% endif %}
{% if hasRepository %}
    static func makeRepository() -> {{ name }}Repository {
        {{ name }}RepositoryImpl(remoteDataSource: makeRemoteDataSource())
    }
{% endif %}
{% if hasRemoteDataSource %}
    static func makeRemoteDataSource() -> {{ name }}RemoteDataSource {
        {{ name }}RemoteDataSource()
    }
{% endif %}
}

""",

        "cleanVipInteractor.stencil": """
import Combine
import Foundation

@MainActor
final class {{ name }}Interactor: ObservableObject {
    @Published private(set) var viewModel = {{ name }}.ViewModel(title: "{{ name }}")

    private let presenter: {{ name }}Presenter
{% if hasNoDomain %}
    private let repository: {{ name }}RepositoryImpl

    init(presenter: {{ name }}Presenter, repository: {{ name }}RepositoryImpl) {
        self.presenter = presenter
        self.repository = repository
    }
{% else %}
    private let useCase: {{ name }}UseCase

    init(presenter: {{ name }}Presenter, useCase: {{ name }}UseCase) {
        self.presenter = presenter
        self.useCase = useCase
    }
{% endif %}

    func load() async {
        do {
{% if hasNoDomain %}
            let response = try await repository.fetch{{ name }}()
            viewModel = presenter.present(response: response)
{% else %}
            let entity = try await useCase.execute()
            viewModel = presenter.present(entity: entity)
{% endif %}
        } catch {
            viewModel = {{ name }}.ViewModel(title: error.localizedDescription)
        }
    }
}

""",

        "cleanVipPresenter.stencil": """
import Foundation

@MainActor
final class {{ name }}Presenter {
{% if hasNoDomain %}
    func present(response: {{ name }}Response) -> {{ name }}.ViewModel {
        {{ name }}.ViewModel(title: response.title)
    }
{% else %}
    func present(entity: {{ name }}Entity) -> {{ name }}.ViewModel {
        {{ name }}.ViewModel(title: entity.title)
    }
{% endif %}
}


""",

        // MARK: MVP

        "mvpDependencyContainer.stencil": """
import SwiftUI

enum {{ name }}DependencyContainer {
        {% if hasPresenter %}
            @MainActor
            static func makePresenter() -> {{ name }}Presenter {
                {{ name }}Presenter(model: {{ name }}Model(title: "{{ name }}"))
            }
{% endif %}

}

""",

        "mvpModel.stencil": """
import Foundation

struct {{ name }}Model: Equatable {
    let title: String
}


""",

        "mvpPresenter.stencil": """
import Combine
import Foundation

@MainActor
final class {{ name }}Presenter: ObservableObject {
    @Published private(set) var title = "{{ name }}"

    private let model: {{ name }}Model

    init(model: {{ name }}Model) {
        self.model = model
    }

    func load() async {
        title = model.title
    }
}

""",

        "mvpView.stencil": """
import SwiftUI

struct {{ name }}View: View {
    @StateObject private var presenter: {{ name }}Presenter

    init(presenter: {{ name }}Presenter) {
        _presenter = StateObject(wrappedValue: presenter)
    }

    var body: some View {
        Text(presenter.title)
            .task {
                await presenter.load()
            }
    }
}
        {% if hasDependencyContainer %}
#Preview {
    {{ name }}DependencyContainer.makeView()
}
{% endif %}

""",

        "cleanMvpDependencyContainer.stencil": """
import SwiftUI

enum {{ name }}DependencyContainer {
{% if hasPresenter %}
    @MainActor
    static func makePresenter() -> {{ name }}Presenter {
{% if hasNoDomain %}
        {{ name }}Presenter(model: {{ name }}Model(title: "{{ name }}"), repository: makeRepository())
{% else %}
        {{ name }}Presenter(model: {{ name }}Model(title: "{{ name }}"), useCase: makeUseCase())
{% endif %}
    }
{% endif %}
{% if hasNoDomain %}

    static func makeRepository() -> {{ name }}RepositoryImpl {
        {{ name }}RepositoryImpl(remoteDataSource: makeRemoteDataSource())
    }
{% endif %}
{% if hasUseCase %}
    static func makeUseCase() -> {{ name }}UseCase {
        {{ name }}UseCase(repository: makeRepository())
    }
{% endif %}
{% if hasRepository %}
    static func makeRepository() -> {{ name }}Repository {
        {{ name }}RepositoryImpl(remoteDataSource: makeRemoteDataSource())
    }
{% endif %}
{% if hasRemoteDataSource %}
    static func makeRemoteDataSource() -> {{ name }}RemoteDataSource {
        {{ name }}RemoteDataSource()
    }
{% endif %}
}

""",

        "cleanMvpPresenter.stencil": """
import Combine
import Foundation

@MainActor
final class {{ name }}Presenter: ObservableObject {
    @Published private(set) var title = "{{ name }}"

    private let model: {{ name }}Model
{% if hasNoDomain %}
    private let repository: {{ name }}RepositoryImpl

    init(model: {{ name }}Model, repository: {{ name }}RepositoryImpl) {
        self.model = model
        self.repository = repository
    }
{% else %}
    private let useCase: {{ name }}UseCase

    init(model: {{ name }}Model, useCase: {{ name }}UseCase) {
        self.model = model
        self.useCase = useCase
    }
{% endif %}

    func load() async {
        do {
{% if hasNoDomain %}
            let response = try await repository.fetch{{ name }}()
            title = response.title
{% else %}
            let entity = try await useCase.execute()
            title = entity.title
{% endif %}
        } catch {
            title = model.title
        }
    }
}


""",

        // MARK: TCA

        "tcaFeature.stencil": """
import ComposableArchitecture
import Foundation

@Reducer
struct {{ name }}Feature {
    @ObservableState
    struct State: Equatable {
        var title = "{{ name }}"
        var isLoading = false
{% if hasNoDomain %}
        var response: {{ name }}Response?
        var errorMessage: String?
{% endif %}
    }

    enum Action: Equatable {
        case onAppear
{% if hasNoDomain %}
        case didLoad({{ name }}Response)
        case didFail(String)
{% endif %}
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
{% if hasNoDomain %}
                state.isLoading = true
                return .run { send in
                    let repository = {{ name }}RepositoryImpl(remoteDataSource: {{ name }}RemoteDataSource())
                    do {
                        let response = try await repository.fetch{{ name }}()
                        await send(.didLoad(response))
                    } catch {
                        await send(.didFail(error.localizedDescription))
                    }
                }
{% else %}
                state.isLoading = false
                return .none
{% endif %}
{% if hasNoDomain %}
            case .didLoad(let response):
                state.response = response
                state.title = response.title
                state.isLoading = false
                return .none
            case .didFail(let message):
                state.errorMessage = message
                state.isLoading = false
                return .none
{% endif %}
            }
        }
    }
}

""",

        "tcaView.stencil": """
import ComposableArchitecture
import SwiftUI

struct {{ name }}View: View {
    let store: StoreOf<{{ name }}Feature>

    var body: some View {
        WithPerceptionTracking {
            Text(store.title)
                .task {
                    store.send(.onAppear)
                }
        }
    }
}

#Preview {
    {{ name }}View(
        store: Store(initialState: {{ name }}Feature.State()) {
            {{ name }}Feature()
        }
    )
}

""",

        "cleanTcaDependencyContainer.stencil": """
import ComposableArchitecture
import SwiftUI

enum {{ name }}DependencyContainer {

}

""",

        // MARK: Test templates

        "viewModelTests.stencil": """
import XCTest
@testable import {{ name }}

final class {{ name }}ViewModelTests: XCTestCase {
    func testInitialState() {
        let sut = makeSUT()
        XCTAssertEqual(sut.title, "{{ name }}")
        XCTAssertFalse(sut.isLoading)
    }

    private func makeSUT() -> {{ name }}ViewModel {
{% if hasUseCase %}
        {{ name }}ViewModel(useCase: {{ name }}UseCase(repository: {{ name }}RepositoryMock()))
{% else %}
        {{ name }}ViewModel()
{% endif %}
    }
}
{% if hasUseCase %}

private final class {{ name }}RepositoryMock: {{ name }}Repository {
    func fetch{{ name }}() async throws -> {{ name }}Entity {
        {{ name }}Entity(id: UUID(), title: "Mock")
    }
}
{% endif %}

""",

        "storeTests.stencil": """
import XCTest
@testable import {{ name }}

final class {{ name }}StoreTests: XCTestCase {
    func testInitialState() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.title, "{{ name }}")
        XCTAssertFalse(sut.state.isLoading)
    }

    private func makeSUT() -> {{ name }}Store {
        {{ name }}Store(reducer: {{ name }}Reducer())
    }
}

""",

        "reducerTests.stencil": """
import XCTest
@testable import {{ name }}

final class {{ name }}ReducerTests: XCTestCase {
    func testReduceOnAppear() {
        let sut = {{ name }}Reducer()
        var state = {{ name }}State()
        sut.reduce(state: &state, intent: .onAppear)
        XCTAssertTrue(state.isLoading)
    }
}

""",

        "presenterTests.stencil": """
import XCTest
@testable import {{ name }}

final class {{ name }}PresenterTests: XCTestCase {
    func testInitialState() {
        let sut = makeSUT()
        XCTAssertEqual(sut.title, "{{ name }}")
    }

    private func makeSUT() -> {{ name }}Presenter {
        {{ name }}Presenter(interactor: {{ name }}Interactor(), router: {{ name }}Router())
    }
}

""",

        "interactorTests.stencil": """
import XCTest
@testable import {{ name }}

final class {{ name }}InteractorTests: XCTestCase {
    func testLoad() async {
        let sut = makeSUT()
        let entity = await sut.load()
        XCTAssertEqual(entity.title, "{{ name }}")
    }

    private func makeSUT() -> {{ name }}Interactor {
        {{ name }}Interactor()
    }
}

""",

        "featureTests.stencil": """
import ComposableArchitecture
import XCTest
@testable import {{ name }}

final class {{ name }}FeatureTests: XCTestCase {
    func testOnAppear() {
        let store = TestStore(initialState: {{ name }}Feature.State()) {
            {{ name }}Feature()
        }

        store.send(.onAppear) {
            $0.isLoading = false
        }
    }
}

""",

        "useCaseTests.stencil": """
import XCTest
@testable import {{ name }}

final class {{ name }}UseCaseTests: XCTestCase {
    func testExecute() async throws {
        let repository = {{ name }}RepositoryMock()
        let sut = {{ name }}UseCase(repository: repository)
        let entity = try await sut.execute()
        XCTAssertEqual(entity.title, "Mock")
    }
}

private final class {{ name }}RepositoryMock: {{ name }}Repository {
    func fetch{{ name }}() async throws -> {{ name }}Entity {
        {{ name }}Entity(id: UUID(), title: "Mock")
    }
}

""",

        "repositoryTests.stencil": """
import XCTest
@testable import {{ name }}

final class {{ name }}RepositoryTests: XCTestCase {
    func testFetch() async throws {
        let dataSource = {{ name }}RemoteDataSource()
        let sut = {{ name }}RepositoryImpl(remoteDataSource: dataSource)
        let entity = try await sut.fetch{{ name }}()
        XCTAssertEqual(entity.title, "{{ name }}")
    }
}

""",
    ]
}
