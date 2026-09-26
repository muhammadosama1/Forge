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
        ),
{% if hasTests %}
        .testTarget(
            name: "{{ name }}Tests",
            dependencies: ["{{ name }}"]
        ),
{% endif %}
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

struct {{ name }}Response: Decodable, Equatable {
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

        // MARK: MVVM Form

        "mvvmFormView.stencil": """
import SwiftUI

struct {{ name }}View: View {
    @StateObject private var viewModel: {{ name }}ViewModel

    init(viewModel: {{ name }}ViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Form {
            TextField("Field 1", text: $viewModel.field1)
            TextField("Field 2", text: $viewModel.field2)
            Button("Submit") {
                viewModel.submit()
            }
        }
    }
}
        {% if hasDependencyContainer %}
#Preview {
    {{ name }}DependencyContainer.makeView()
}
{% endif %}

""",

        "mvvmFormViewModel.stencil": """
import Combine
import Foundation

@MainActor
final class {{ name }}ViewModel: ObservableObject {
    @Published var field1 = ""
    @Published var field2 = ""

    func submit() {
        // Handle form submission
    }
}

""",

        // MARK: MVVM List

        "mvvmListView.stencil": """
import SwiftUI

struct {{ name }}View: View {
    @StateObject private var viewModel: {{ name }}ViewModel

    init(viewModel: {{ name }}ViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List(viewModel.items) { item in
            Text(item.title)
        }
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

        "mvvmListViewModel.stencil": """
import Combine
import Foundation

@MainActor
final class {{ name }}ViewModel: ObservableObject {
    @Published private(set) var items: [{{ name }}Item] = []

    func load() async {
        // Load items
    }
}

struct {{ name }}Item: Identifiable {
    let id: UUID
    let title: String
}

""",

        // MARK: Clean MVVM Form

        "cleanMvvmFormView.stencil": """
import SwiftUI

struct {{ name }}View: View {
    @StateObject private var viewModel: {{ name }}ViewModel

    init(viewModel: {{ name }}ViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Form {
            TextField("Field 1", text: $viewModel.field1)
            TextField("Field 2", text: $viewModel.field2)
            Button("Submit") {
                viewModel.submit()
            }
        }
    }
}
{% if hasDependencyContainer %}
#Preview {
    {{ name }}DependencyContainer.makeView()
}
{% endif %}

""",

        "cleanMvvmFormViewModel.stencil": """
import Combine
import Foundation

@MainActor
final class {{ name }}ViewModel: ObservableObject {
    @Published var field1 = ""
    @Published var field2 = ""
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

    func submit() {
        // Handle form submission
    }
}

""",

        // MARK: Clean MVVM List

        "cleanMvvmListView.stencil": """
import SwiftUI

struct {{ name }}View: View {
    @StateObject private var viewModel: {{ name }}ViewModel

    init(viewModel: {{ name }}ViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List(viewModel.items) { item in
            Text(item.title)
        }
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

        "cleanMvvmListViewModel.stencil": """
import Combine
import Foundation

@MainActor
final class {{ name }}ViewModel: ObservableObject {
    @Published private(set) var items: [{{ name }}Item] = []
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
        // Load items
    }
}

struct {{ name }}Item: Identifiable {
    let id: UUID
    let title: String
}

""",

        // MARK: MVI

        "mviDependencyContainer.stencil": """
import SwiftUI

enum {{ name }}DependencyContainer {
{% if hasView %}
    @MainActor
    static func makeView() -> {{ name }}View {
        {{ name }}View(store: makeStore())
    }
{% endif %}
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

        // MARK: MVI Form Intent

        "mviFormIntent.stencil": """
import Foundation

enum {{ name }}Intent: Equatable {
    case field1Changed(String)
    case field2Changed(String)
    case submit
}

""",

        // MARK: MVI List Intent

        "mviListIntent.stencil": """
import Foundation

enum {{ name }}Intent: Equatable {
    case onAppear
    case didLoad([{{ name }}Item])
}


""",

        "mviReducer.stencil": """
import Foundation

struct {{ name }}Reducer {
    func reduce(state: inout {{ name }}State, intent: {{ name }}Intent) {
        switch intent {
{% if isForm %}
        case .field1Changed(let value):
            state.field1 = value
        case .field2Changed(let value):
            state.field2 = value
        case .submit:
            // Handle form submission using the current state.
            break
{% else %}
        case .onAppear:
            state.isLoading = false
{% if isList %}
        case .didLoad(let items):
            state.items = items
            state.isLoading = false
{% else %}
            state.errorMessage = nil
{% endif %}
{% endif %}
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
{% if hasView %}
    @MainActor
    static func makeView() -> {{ name }}View {
        {{ name }}View(store: makeStore())
    }
{% endif %}
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
{% if isForm %}
    case field1Changed(String)
    case field2Changed(String)
    case submit
{% endif %}
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
{% if isForm %}
        case .field1Changed(let value):
            state.field1 = value
        case .field2Changed(let value):
            state.field2 = value
        case .submit:
            // Handle form submission using the current state.
            break
{% endif %}
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
{% if isList %}
            state.items = [{{ name }}Item(id: value.id, title: value.title)]
{% endif %}
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
{% if isForm %}
    var field1 = ""
    var field2 = ""
{% endif %}
{% if isList %}
    var items: [{{ name }}Item] = []
{% endif %}
    {% if hasNoDomain %}var response: {{ name }}Response?
    {% else %}var entity: {{ name }}Entity?
    {% endif %}var title = "{{ name }}"
    var isLoading = false
    var errorMessage: String?
}


{% if isList %}
struct {{ name }}Item: Equatable, Identifiable {
    let id: UUID
    let title: String
}
{% endif %}

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


{% if isForm %}
    func updateField1(_ value: String) {
        reducer.reduce(state: &state, intent: .field1Changed(value))
    }

    func updateField2(_ value: String) {
        reducer.reduce(state: &state, intent: .field2Changed(value))
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

        // MARK: MVI Form

        "mviFormView.stencil": """
import SwiftUI

struct {{ name }}View: View {
    @StateObject private var store: {{ name }}Store

    init(store: {{ name }}Store) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        Form {
            TextField("Field 1", text: Binding(
                get: { store.state.field1 },
                set: { store.updateField1($0) }
            ))
            TextField("Field 2", text: Binding(
                get: { store.state.field2 },
                set: { store.updateField2($0) }
            ))
            Button("Submit") {
                Task { await store.send(.submit) }
            }
        }
    }
}
        {% if hasDependencyContainer %}
#Preview {
    {{ name }}DependencyContainer.makeView()
}
{% endif %}

""",

        "mviFormStore.stencil": """
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


{% if isForm %}
    func updateField1(_ value: String) {
        reducer.reduce(state: &state, intent: .field1Changed(value))
    }

    func updateField2(_ value: String) {
        reducer.reduce(state: &state, intent: .field2Changed(value))
    }
{% endif %}

    func send(_ intent: {{ name }}Intent) async {
        reducer.reduce(state: &state, intent: intent)
    }
}

""",

        "mviFormState.stencil": """
import Foundation

struct {{ name }}State: Equatable {
    var field1 = ""
    var field2 = ""
}


""",

        // MARK: MVI List

        "mviListView.stencil": """
import SwiftUI

struct {{ name }}View: View {
    @StateObject private var store: {{ name }}Store

    init(store: {{ name }}Store) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        List(store.state.items) { item in
            Text(item.title)
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

        "mviListStore.stencil": """
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

        "mviListState.stencil": """
import Foundation

struct {{ name }}State: Equatable {
    var items: [{{ name }}Item] = []
    var isLoading = false
}

struct {{ name }}Item: Equatable, Identifiable {
    let id: UUID
    let title: String
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
{% if hasView %}
    @MainActor
    static func makeView() -> {{ name }}View {
        {{ name }}View(presenter: makePresenter())
    }
{% endif %}
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

        // MARK: VIPER Form

        "viperFormView.stencil": """
import SwiftUI

struct {{ name }}View: View {
    @StateObject private var presenter: {{ name }}Presenter

    init(presenter: {{ name }}Presenter) {
        _presenter = StateObject(wrappedValue: presenter)
    }

    var body: some View {
        Form {
            TextField("Field 1", text: $presenter.field1)
            TextField("Field 2", text: $presenter.field2)
            Button("Submit") {
                presenter.submit()
            }
        }
    }
}
{% if hasDependencyContainer %}
#Preview {
    {{ name }}DependencyContainer.makeView()
}
{% endif %}

""",

        "viperFormPresenter.stencil": """
import Combine
import Foundation

@MainActor
final class {{ name }}Presenter: ObservableObject {
    @Published var field1 = ""
    @Published var field2 = ""

    private let interactor: {{ name }}Interactor
    private let router: {{ name }}Router

    init(interactor: {{ name }}Interactor, router: {{ name }}Router) {
        self.interactor = interactor
        self.router = router
    }

    func submit() {
        // Handle form submission
    }
}

""",

        // MARK: VIPER List

        "viperListView.stencil": """
import SwiftUI

struct {{ name }}View: View {
    @StateObject private var presenter: {{ name }}Presenter

    init(presenter: {{ name }}Presenter) {
        _presenter = StateObject(wrappedValue: presenter)
    }

    var body: some View {
        List(presenter.items) { item in
            Text(item.title)
        }
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

        "viperListPresenter.stencil": """
import Combine
import Foundation

@MainActor
final class {{ name }}Presenter: ObservableObject {
    @Published private(set) var items: [{{ name }}Item] = []

    private let interactor: {{ name }}Interactor
    private let router: {{ name }}Router

    init(interactor: {{ name }}Interactor, router: {{ name }}Router) {
        self.interactor = interactor
        self.router = router
    }

    func viewDidLoad() async {
        // Load items
    }
}

struct {{ name }}Item: Identifiable {
    let id: UUID
    let title: String
}

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
{% if hasView %}
    @MainActor
    static func makeView() -> {{ name }}View {
        {{ name }}View(presenter: makePresenter())
    }
{% endif %}
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
{% if hasView %}
    @MainActor
    static func makeView() -> {{ name }}View {
        {{ name }}View(interactor: makeInteractor())
    }
{% endif %}
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
{% if isForm %}
    @Published var field1 = ""
    @Published var field2 = ""

    func submit() {
        // Handle form submission.
    }
{% endif %}
{% if isList %}
    var items: [{{ name }}.Item] { viewModel.items }
{% endif %}

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
{% if isList %}
        var items: [Item] = []
{% endif %}
    }
{% if isList %}

    struct Item: Identifiable, Equatable {
        let id: UUID
        let title: String
    }
{% endif %}
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

        // MARK: VIP Form

        "vipFormView.stencil": """
import SwiftUI

struct {{ name }}View: View {
    @StateObject private var interactor: {{ name }}Interactor

    init(interactor: {{ name }}Interactor) {
        _interactor = StateObject(wrappedValue: interactor)
    }

    var body: some View {
        Form {
            TextField("Field 1", text: $interactor.field1)
            TextField("Field 2", text: $interactor.field2)
            Button("Submit") {
                interactor.submit()
            }
        }
    }
}
        {% if hasDependencyContainer %}
#Preview {
    {{ name }}DependencyContainer.makeView()
}
{% endif %}

""",

        "vipFormPresenter.stencil": """
import Foundation

@MainActor
final class {{ name }}Presenter {
    func present(response: {{ name }}.Response) -> {{ name }}.ViewModel {
        {{ name }}.ViewModel(title: response.title)
    }
}

""",

        // MARK: VIP List

        "vipListView.stencil": """
import SwiftUI

struct {{ name }}View: View {
    @StateObject private var interactor: {{ name }}Interactor

    init(interactor: {{ name }}Interactor) {
        _interactor = StateObject(wrappedValue: interactor)
    }

    var body: some View {
        List(interactor.items) { item in
            Text(item.title)
        }
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

        "vipListPresenter.stencil": """
import Foundation

@MainActor
final class {{ name }}Presenter {
    func present(response: {{ name }}.Response) -> {{ name }}.ViewModel {
        {{ name }}.ViewModel(
            title: response.title,
            items: [{{ name }}.Item(id: UUID(), title: response.title)]
        )
    }
}

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
{% if hasView %}
    @MainActor
    static func makeView() -> {{ name }}View {
        {{ name }}View(interactor: makeInteractor())
    }
{% endif %}
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
{% if isForm %}
    @Published var field1 = ""
    @Published var field2 = ""

    func submit() {
        // Handle form submission.
    }
{% endif %}
{% if isList %}
    var items: [{{ name }}.Item] { viewModel.items }
{% endif %}

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
        {{ name }}.ViewModel(
            title: response.title{% if isList %},
            items: [{{ name }}.Item(id: response.id, title: response.title)]{% endif %}
        )
    }
{% else %}
    func present(entity: {{ name }}Entity) -> {{ name }}.ViewModel {
        {{ name }}.ViewModel(
            title: entity.title{% if isList %},
            items: [{{ name }}.Item(id: entity.id, title: entity.title)]{% endif %}
        )
    }
{% endif %}
}

""",

        // MARK: MVP

        "mvpDependencyContainer.stencil": """
import SwiftUI

enum {{ name }}DependencyContainer {
{% if hasView %}
    @MainActor
    static func makeView() -> {{ name }}View {
        {{ name }}View(presenter: makePresenter())
    }
{% endif %}
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

        // MARK: MVP Form

        "mvpFormView.stencil": """
import SwiftUI

struct {{ name }}View: View {
    @StateObject private var presenter: {{ name }}Presenter

    init(presenter: {{ name }}Presenter) {
        _presenter = StateObject(wrappedValue: presenter)
    }

    var body: some View {
        Form {
            TextField("Field 1", text: $presenter.field1)
            TextField("Field 2", text: $presenter.field2)
            Button("Submit") {
                presenter.submit()
            }
        }
    }
}
        {% if hasDependencyContainer %}
#Preview {
    {{ name }}DependencyContainer.makeView()
}
{% endif %}

""",

        "mvpFormPresenter.stencil": """
import Combine
import Foundation

@MainActor
final class {{ name }}Presenter: ObservableObject {
    @Published var field1 = ""
    @Published var field2 = ""

    private let model: {{ name }}Model

    init(model: {{ name }}Model) {
        self.model = model
    }

    func submit() {
        // Handle form submission
    }
}

""",

        // MARK: MVP List

        "mvpListView.stencil": """
import SwiftUI

struct {{ name }}View: View {
    @StateObject private var presenter: {{ name }}Presenter

    init(presenter: {{ name }}Presenter) {
        _presenter = StateObject(wrappedValue: presenter)
    }

    var body: some View {
        List(presenter.items) { item in
            Text(item.title)
        }
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

        "mvpListPresenter.stencil": """
import Combine
import Foundation

@MainActor
final class {{ name }}Presenter: ObservableObject {
    @Published private(set) var items: [{{ name }}Item] = []

    private let model: {{ name }}Model

    init(model: {{ name }}Model) {
        self.model = model
    }

    func load() async {
        // Load items
    }
}

struct {{ name }}Item: Identifiable {
    let id: UUID
    let title: String
}

""",

        "cleanMvpDependencyContainer.stencil": """
import SwiftUI

enum {{ name }}DependencyContainer {
{% if hasView %}
    @MainActor
    static func makeView() -> {{ name }}View {
        {{ name }}View(presenter: makePresenter())
    }
{% endif %}
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
{% if isForm %}
    @Published var field1 = ""
    @Published var field2 = ""
{% else %}
{% if isList %}
    @Published private(set) var items: [{{ name }}Item] = []
{% else %}
    @Published private(set) var title = "{{ name }}"
{% endif %}
{% endif %}

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

{% if isForm %}
    func submit() {
        // Handle form submission.
    }
{% else %}
    func load() async {
        do {
{% if hasNoDomain %}
            let response = try await repository.fetch{{ name }}()
{% if isList %}
            items = [{{ name }}Item(id: response.id, title: response.title)]
{% else %}
            title = response.title
{% endif %}
{% else %}
            let entity = try await useCase.execute()
{% if isList %}
            items = [{{ name }}Item(id: entity.id, title: entity.title)]
{% else %}
            title = entity.title
{% endif %}
{% endif %}
        } catch {
{% if isList %}
            items = []
{% else %}
            title = model.title
{% endif %}
        }
    }
{% endif %}
}
{% if isList %}

struct {{ name }}Item: Identifiable {
    let id: UUID
    let title: String
}
{% endif %}

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

        // MARK: TCA Form

        "tcaFormView.stencil": """
import ComposableArchitecture
import SwiftUI

struct {{ name }}View: View {
    let store: StoreOf<{{ name }}Feature>

    var body: some View {
        WithPerceptionTracking {
            Form {
                TextField("Field 1", text: $store.field1)
                TextField("Field 2", text: $store.field2)
                Button("Submit") {
                    store.send(.submit)
                }
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

        "tcaFormFeature.stencil": """
import ComposableArchitecture
import Foundation

@Reducer
struct {{ name }}Feature {
    @ObservableState
    struct State: Equatable {
        var field1 = ""
        var field2 = ""
    }

    enum Action: Equatable {
        case submit
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .submit:
                // Handle form submission
                return .none
            }
        }
    }
}

""",

        // MARK: TCA List

        "tcaListView.stencil": """
import ComposableArchitecture
import SwiftUI

struct {{ name }}View: View {
    let store: StoreOf<{{ name }}Feature>

    var body: some View {
        WithPerceptionTracking {
            List(store.items) { item in
                Text(item.title)
            }
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

        "tcaListFeature.stencil": """
import ComposableArchitecture
import Foundation

@Reducer
struct {{ name }}Feature {
    @ObservableState
    struct State: Equatable {
        var items: [{{ name }}Item] = []
    }

    enum Action: Equatable {
        case onAppear
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // Load items
                return .none
            }
        }
    }
}

struct {{ name }}Item: Equatable, Identifiable {
    let id: UUID
    let title: String
}

""",
    ].merging(TestTemplateContent.files) { _, testTemplate in testTemplate }
}
