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
//

""",

        "swiftPackage.stencil": """
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "{{ name }}",
    platforms: [{% if isConcurrency %}.iOS(.v17), .macOS(.v14){% else %}{% if isSwiftTesting %}.iOS(.v16), .macOS(.v13){% else %}.iOS(.v15), .macOS(.v12){% endif %}{% endif %}],
    products: [
        .library(
            name: "{{ name }}",
            targets: ["{{ name }}"]
        ),
    ],
{% if isFactory %}
    dependencies: [
        .package(url: "https://github.com/hmlongco/Factory.git", from: "2.4.0"),
    ],
{% endif %}
    targets: [
        .target(
            name: "{{ name }}"{% if isFactory %},
            dependencies: [
                .product(name: "Factory", package: "Factory"),
            ]{% endif %}
        ),
{% if hasTests %}
        .testTarget(
            name: "{{ name }}Tests",
            dependencies: [{% if isFactory %}"{{ name }}", .product(name: "Factory", package: "Factory"){% else %}"{{ name }}"{% endif %}]
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
    private let fetch: () async throws -> {{ name }}Response
    private let submit: (String, String) async throws -> Void

    init(
        fetch: @escaping () async throws -> {{ name }}Response = {
            throw URLError(.unsupportedURL) // Supply your application's API client.
        },
        submit: @escaping (String, String) async throws -> Void = { _, _ in
            throw URLError(.unsupportedURL) // Supply your application's submission operation.
        }
    ) {
        self.fetch = fetch
        self.submit = submit
    }

    func fetch{{ name }}() async throws -> {{ name }}Response {
        try Task.checkCancellation()
        return try await fetch()
    }

    func submit{{ name }}(field1: String, field2: String) async throws {
        try Task.checkCancellation()
        try await submit(field1, field2)
    }

    /// Deterministic fixtures; never used by the live dependency container.
    static var preview: {{ name }}RemoteDataSource {
        {{ name }}RemoteDataSource(fetch: {
            {{ name }}Response(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, title: "{{ name }}")
        }, submit: { _, _ in })
    }
}
""",

        "repository.stencil": """
import Foundation

protocol {{ name }}Repository {
    func submit{{ name }}(field1: String, field2: String) async throws
    func fetch{{ name }}() async throws -> {{ name }}Entity
}


// Existing repositories can adopt submission when the feature needs it.
extension {{ name }}Repository {
    func submit{{ name }}(field1: String, field2: String) async throws {
        throw URLError(.unsupportedURL)
    }
}

""",

        "repositoryImpl.stencil": """
import Foundation

final class {{ name }}RepositoryImpl{% if hasRepository %}: {{ name }}Repository{% endif %} {
    private let remoteDataSource: {{ name }}RemoteDataSource

    init(remoteDataSource: {{ name }}RemoteDataSource) {
        self.remoteDataSource = remoteDataSource
    }

    func submit{{ name }}(field1: String, field2: String) async throws {
        try await remoteDataSource.submit{{ name }}(field1: field1, field2: field2)
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

    func submit(field1: String, field2: String) async throws {
        try await repository.submit{{ name }}(field1: field1, field2: field2)
    }

    func execute() async throws -> {{ name }}Entity {
        try await repository.fetch{{ name }}()
    }
}

""",

        // MARK: MVVM

        "cleanMvvmDependencyContainer.stencil": """
{% if isFactory %}
import Factory
import SwiftUI

extension Container {
{% if hasView %}
    var {{ propertyName }}View: Factory<{{ name }}View> {
        self { @MainActor in
            {{ name }}View(viewModel: self.{{ propertyName }}ViewModel())
        }
    }
{% endif %}
{% if hasViewModel %}
    var {{ propertyName }}ViewModel: Factory<{{ name }}ViewModel> {
        self { @MainActor in
{% if hasNoDomain %}
            {{ name }}ViewModel(repository: self.{{ propertyName }}Repository())
{% else %}
            {{ name }}ViewModel(useCase: self.{{ propertyName }}UseCase())
{% endif %}
        }
    }
{% endif %}
{% if hasNoDomain %}
    var {{ propertyName }}Repository: Factory<{{ name }}RepositoryImpl> {
        self {
            {{ name }}RepositoryImpl(remoteDataSource: self.{{ propertyName }}RemoteDataSource())
        }
    }
{% endif %}
{% if hasUseCase %}
    var {{ propertyName }}UseCase: Factory<{{ name }}UseCase> {
        self {
            {{ name }}UseCase(repository: self.{{ propertyName }}Repository())
        }
    }
{% endif %}
{% if hasRepository %}
    var {{ propertyName }}Repository: Factory<{{ name }}Repository> {
        self {
            {{ name }}RepositoryImpl(remoteDataSource: self.{{ propertyName }}RemoteDataSource())
        }
    }
{% endif %}
{% if hasRemoteDataSource %}
    var {{ propertyName }}RemoteDataSource: Factory<{{ name }}RemoteDataSource> {
        self {
            {{ name }}RemoteDataSource()
        }
    }
{% endif %}
}

enum {{ name }}DependencyContainer {
{% if hasView %}
    @MainActor
    static func makeView() -> {{ name }}View {
        Container.shared.{{ propertyName }}View()
    }
{% endif %}
{% if hasViewModel %}
    @MainActor
    static func makeViewModel() -> {{ name }}ViewModel {
        Container.shared.{{ propertyName }}ViewModel()
    }
{% endif %}
{% if hasNoDomain %}
    static func makeRepository() -> {{ name }}RepositoryImpl {
        Container.shared.{{ propertyName }}Repository()
    }
{% endif %}
{% if hasUseCase %}
    static func makeUseCase() -> {{ name }}UseCase {
        Container.shared.{{ propertyName }}UseCase()
    }
{% endif %}
{% if hasRepository %}
    static func makeRepository() -> {{ name }}Repository {
        Container.shared.{{ propertyName }}Repository()
    }
{% endif %}
{% if hasRemoteDataSource %}
    static func makeRemoteDataSource() -> {{ name }}RemoteDataSource {
        Container.shared.{{ propertyName }}RemoteDataSource()
    }
{% endif %}
}
{% else %}
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
{% endif %}

{% if isPackage %}
{% if hasView %}
/// Public feature entry point; presentation and data types remain internal.
@MainActor
public enum {{ name }}Feature {
    public static func makeView() -> some View {
        {{ name }}DependencyContainer.makeView()
    }
}
{% endif %}
{% endif %}

// Isolated preview fixtures; never consults Container.shared.
enum {{ name }}Preview {

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
        {{ name }}RemoteDataSource.preview
    }
{% endif %}
}

""",

        "mvvmDependencyContainer.stencil": """
{% if isFactory %}
import Factory
import SwiftUI

extension Container {
{% if hasView %}
    var {{ propertyName }}View: Factory<{{ name }}View> {
        self { @MainActor in
            {{ name }}View(viewModel: self.{{ propertyName }}ViewModel())
        }
    }
{% endif %}
{% if hasViewModel %}
    var {{ propertyName }}ViewModel: Factory<{{ name }}ViewModel> {
        self { @MainActor in
            {{ name }}ViewModel()
        }
    }
{% endif %}
}

enum {{ name }}DependencyContainer {
{% if hasView %}
    @MainActor
    static func makeView() -> {{ name }}View {
        Container.shared.{{ propertyName }}View()
    }
{% endif %}
{% if hasViewModel %}
    @MainActor
    static func makeViewModel() -> {{ name }}ViewModel {
        Container.shared.{{ propertyName }}ViewModel()
    }
{% endif %}
}
{% else %}
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
{% endif %}

{% if isPackage %}
{% if hasView %}
/// Public feature entry point; presentation and data types remain internal.
@MainActor
public enum {{ name }}Feature {
    public static func makeView() -> some View {
        {{ name }}DependencyContainer.makeView()
    }
}
{% endif %}
{% endif %}

// Isolated preview fixtures; never consults Container.shared.
enum {{ name }}Preview {

    {% if hasView %}
        @MainActor
        static func makeView() -> {{ name }}View {
            {{ name }}View(viewModel: makeViewModel())
        }
    {% endif %}
    {% if hasViewModel %}
        @MainActor
        static func makeViewModel() -> {{ name }}ViewModel {
            {% if isForm %}{{ name }}ViewModel(submitAction: { _, _ in }){% else %}{% if isList %}{{ name }}ViewModel(loadItems: { [{{ name }}Item(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, title: "{{ name }}")] }){% else %}{{ name }}ViewModel(){% endif %}{% endif %}
        }
    {% endif %}
}

""",

        "mvvmSwiftUIView.stencil": """
import SwiftUI

struct {{ name }}View: View {
{% if isConcurrency %}
    @State private var viewModel: {{ name }}ViewModel

    @State private var reloadID = 0

    init(viewModel: {{ name }}ViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }
{% else %}
    @StateObject private var viewModel: {{ name }}ViewModel

    @State private var reloadID = 0

    init(viewModel: {{ name }}ViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
{% endif %}

    var body: some View {
        VStack {
            Text(viewModel.title)
            if viewModel.isLoading { ProgressView() }
            if let message = viewModel.errorMessage {
                Text(message).foregroundStyle(.red)
                Button("Retry") { reloadID += 1 }
            }
        }
            .task(id: reloadID) {
                await viewModel.load()
            }
    }
}
        {% if hasDependencyContainer %}
#Preview {
    {{ name }}Preview.makeView()
}
{% endif %}

""",

        "mvvmViewModel.stencil": """
{% if isConcurrency %}
import Foundation
import Observation

@Observable
@MainActor
final class {{ name }}ViewModel {
    private(set) var title = "{{ name }}"
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }

        errorMessage = nil
    }
}
{% else %}
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
{% endif %}

""",

        "cleanMvvmView.stencil": """
import SwiftUI

struct {{ name }}View: View {
{% if isConcurrency %}
    @State private var viewModel: {{ name }}ViewModel

    @State private var reloadID = 0

    init(viewModel: {{ name }}ViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }
{% else %}
    @StateObject private var viewModel: {{ name }}ViewModel

    @State private var reloadID = 0

    init(viewModel: {{ name }}ViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
{% endif %}

    var body: some View {
        VStack {
            Text(viewModel.{% if hasNoDomain %}response?.title ?? ""{% else %}entity?.title ?? ""{% endif %})
            if viewModel.isLoading { ProgressView() }
            if let message = viewModel.errorMessage {
                Text(message).foregroundStyle(.red)
                Button("Retry") { reloadID += 1 }
            }
        }
            .task(id: reloadID) {
                await viewModel.load()
            }
    }
}
{% if hasDependencyContainer %}
#Preview {
    {{ name }}Preview.makeView()
}
{% endif %}

""",

        "cleanMvvmViewModel.stencil": """
{% if isConcurrency %}
import Foundation
import Observation

@Observable
@MainActor
final class {{ name }}ViewModel {
    private(set) var {% if hasNoDomain %}response{% else %}entity{% endif %}: {% if hasNoDomain %}{{ name }}Response?{% else %}{{ name }}Entity?{% endif %}
    private(set) var isLoading = false
    private(set) var errorMessage: String?
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
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try Task.checkCancellation()
{% if hasNoDomain %}
            let loaded = try await repository.fetch{{ name }}()
            try Task.checkCancellation()
            response = loaded
{% else %}
            let loaded = try await useCase.execute()
            try Task.checkCancellation()
            entity = loaded
{% endif %}
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }
}
{% else %}
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
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try Task.checkCancellation()
{% if hasNoDomain %}
            let loaded = try await repository.fetch{{ name }}()
            try Task.checkCancellation()
            response = loaded
{% else %}
            let loaded = try await useCase.execute()
            try Task.checkCancellation()
            entity = loaded
{% endif %}
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }
}
{% endif %}

""",

        // MARK: MVVM Form

        "mvvmFormView.stencil": """
import SwiftUI

struct {{ name }}View: View {
{% if isConcurrency %}
    @State private var viewModel: {{ name }}ViewModel

    @State private var submissionRequested = false

    init(viewModel: {{ name }}ViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        Form {
            TextField("Field 1", text: $viewModel.field1)
            TextField("Field 2", text: $viewModel.field2)
            Button("Submit") {
                submissionRequested = true
            }
            .disabled(submissionRequested || viewModel.isSubmitting)
            if viewModel.isSubmitting { ProgressView() }
            if viewModel.didSubmit { Text("Submitted") }
            if let message = viewModel.errorMessage { Text(message).foregroundStyle(.red) }
        }
        .task(id: submissionRequested) {
            guard submissionRequested else { return }
            await viewModel.submit()
            submissionRequested = false
        }
    }
{% else %}
    @StateObject private var viewModel: {{ name }}ViewModel

    @State private var submissionRequested = false

    init(viewModel: {{ name }}ViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Form {
            TextField("Field 1", text: $viewModel.field1)
            TextField("Field 2", text: $viewModel.field2)
            Button("Submit") {
                submissionRequested = true
            }
            .disabled(submissionRequested || viewModel.isSubmitting)
            if viewModel.isSubmitting { ProgressView() }
            if viewModel.didSubmit { Text("Submitted") }
            if let message = viewModel.errorMessage { Text(message).foregroundStyle(.red) }
        }
        .task(id: submissionRequested) {
            guard submissionRequested else { return }
            await viewModel.submit()
            submissionRequested = false
        }
    }
{% endif %}
}
        {% if hasDependencyContainer %}
#Preview {
    {{ name }}Preview.makeView()
}
{% endif %}

""",

        "mvvmFormViewModel.stencil": """
{% if isConcurrency %}
import Foundation
import Observation

@Observable
@MainActor
final class {{ name }}ViewModel {
    var field1 = ""
    var field2 = ""
    private(set) var didSubmit = false
    private(set) var isSubmitting = false
    private(set) var errorMessage: String?
    private let submitAction: (String, String) async throws -> Void

    init(submitAction: @escaping (String, String) async throws -> Void = { _, _ in
        throw URLError(.unsupportedURL) // Inject the application's submission operation.
    }) {
        self.submitAction = submitAction
    }
{% if isClean %}
{% if hasNoDomain %}
    convenience init(repository: {{ name }}RepositoryImpl) {
        self.init { first, second in try await repository.submit{{ name }}(field1: first, field2: second) }
    }
{% else %}
    convenience init(useCase: {{ name }}UseCase) {
        self.init { first, second in try await useCase.submit(field1: first, field2: second) }
    }
{% endif %}
{% endif %}

    func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        didSubmit = false
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try Task.checkCancellation()
            try await submitAction(field1, field2)
            try Task.checkCancellation()
            didSubmit = true
        } catch is CancellationError {
            // Leaving the screen is not a failed submission.
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }
}
{% else %}
import Combine
import Foundation

@MainActor
final class {{ name }}ViewModel: ObservableObject {
    @Published var field1 = ""
    @Published var field2 = ""
    @Published private(set) var didSubmit = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var errorMessage: String?
    private let submitAction: (String, String) async throws -> Void

    init(submitAction: @escaping (String, String) async throws -> Void = { _, _ in
        throw URLError(.unsupportedURL) // Inject the application's submission operation.
    }) {
        self.submitAction = submitAction
    }
{% if isClean %}
{% if hasNoDomain %}
    convenience init(repository: {{ name }}RepositoryImpl) {
        self.init { first, second in try await repository.submit{{ name }}(field1: first, field2: second) }
    }
{% else %}
    convenience init(useCase: {{ name }}UseCase) {
        self.init { first, second in try await useCase.submit(field1: first, field2: second) }
    }
{% endif %}
{% endif %}

    func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        didSubmit = false
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try Task.checkCancellation()
            try await submitAction(field1, field2)
            try Task.checkCancellation()
            didSubmit = true
        } catch is CancellationError {
            // Leaving the screen is not a failed submission.
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }
}
{% endif %}
""",

        // MARK: MVVM List

        "mvvmListView.stencil": """
import SwiftUI

struct {{ name }}View: View {
{% if isConcurrency %}
    @State private var viewModel: {{ name }}ViewModel

    @State private var reloadID = 0

    init(viewModel: {{ name }}ViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }
{% else %}
    @StateObject private var viewModel: {{ name }}ViewModel

    @State private var reloadID = 0

    init(viewModel: {{ name }}ViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
{% endif %}

    var body: some View {
        VStack {
            if viewModel.isLoading { ProgressView() }
            if let message = viewModel.errorMessage {
                Text(message).foregroundStyle(.red)
            }
            if viewModel.items.isEmpty && !viewModel.isLoading && viewModel.errorMessage == nil {
                Text("No items yet")
            }
            List(viewModel.items) { item in
                Text(item.title)
            }
            Button("Reload") { reloadID += 1 }
                .disabled(viewModel.isLoading)
        }
        .task(id: reloadID) {
            await viewModel.load()
        }
    }
}
        {% if hasDependencyContainer %}
#Preview {
    {{ name }}Preview.makeView()
}
{% endif %}

""",

        "mvvmListViewModel.stencil": """
{% if isConcurrency %}
import Foundation
import Observation

@Observable
@MainActor
final class {{ name }}ViewModel {
    private(set) var items: [{{ name }}Item] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private let loadItems: () async throws -> [{{ name }}Item]

    init(loadItems: @escaping () async throws -> [{{ name }}Item] = { [] }) {
        self.loadItems = loadItems
    }
{% if isClean %}
{% if hasNoDomain %}
    convenience init(repository: {{ name }}RepositoryImpl) {
        self.init {
            let value = try await repository.fetch{{ name }}()
            return [{{ name }}Item(id: value.id, title: value.title)]
        }
    }
{% else %}
    convenience init(useCase: {{ name }}UseCase) {
        self.init {
            let value = try await useCase.execute()
            return [{{ name }}Item(id: value.id, title: value.title)]
        }
    }
{% endif %}
{% endif %}

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try Task.checkCancellation()
            let loaded = try await loadItems()
            try Task.checkCancellation()
            items = loaded
        } catch is CancellationError {
            // Keep the last successful data when the view disappears.
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }
}

struct {{ name }}Item: Equatable, Identifiable {
    let id: UUID
    let title: String
}
{% else %}
import Combine
import Foundation

@MainActor
final class {{ name }}ViewModel: ObservableObject {
    @Published private(set) var items: [{{ name }}Item] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    private let loadItems: () async throws -> [{{ name }}Item]

    init(loadItems: @escaping () async throws -> [{{ name }}Item] = { [] }) {
        self.loadItems = loadItems
    }
{% if isClean %}
{% if hasNoDomain %}
    convenience init(repository: {{ name }}RepositoryImpl) {
        self.init {
            let value = try await repository.fetch{{ name }}()
            return [{{ name }}Item(id: value.id, title: value.title)]
        }
    }
{% else %}
    convenience init(useCase: {{ name }}UseCase) {
        self.init {
            let value = try await useCase.execute()
            return [{{ name }}Item(id: value.id, title: value.title)]
        }
    }
{% endif %}
{% endif %}

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try Task.checkCancellation()
            let loaded = try await loadItems()
            try Task.checkCancellation()
            items = loaded
        } catch is CancellationError {
            // Keep the last successful data when the view disappears.
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }
}

struct {{ name }}Item: Equatable, Identifiable {
    let id: UUID
    let title: String
}
{% endif %}
""",

        // MARK: Clean MVVM Form

        "cleanMvvmFormView.stencil": """
import SwiftUI

struct {{ name }}View: View {
{% if isConcurrency %}
    @State private var viewModel: {{ name }}ViewModel

    @State private var submissionRequested = false

    init(viewModel: {{ name }}ViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        Form {
            TextField("Field 1", text: $viewModel.field1)
            TextField("Field 2", text: $viewModel.field2)
            Button("Submit") {
                submissionRequested = true
            }
            .disabled(submissionRequested || viewModel.isSubmitting)
            if viewModel.isSubmitting { ProgressView() }
            if viewModel.didSubmit { Text("Submitted") }
            if let message = viewModel.errorMessage { Text(message).foregroundStyle(.red) }
        }
        .task(id: submissionRequested) {
            guard submissionRequested else { return }
            await viewModel.submit()
            submissionRequested = false
        }
    }
{% else %}
    @StateObject private var viewModel: {{ name }}ViewModel

    @State private var submissionRequested = false

    init(viewModel: {{ name }}ViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Form {
            TextField("Field 1", text: $viewModel.field1)
            TextField("Field 2", text: $viewModel.field2)
            Button("Submit") {
                submissionRequested = true
            }
            .disabled(submissionRequested || viewModel.isSubmitting)
            if viewModel.isSubmitting { ProgressView() }
            if viewModel.didSubmit { Text("Submitted") }
            if let message = viewModel.errorMessage { Text(message).foregroundStyle(.red) }
        }
        .task(id: submissionRequested) {
            guard submissionRequested else { return }
            await viewModel.submit()
            submissionRequested = false
        }
    }
{% endif %}
}
{% if hasDependencyContainer %}
#Preview {
    {{ name }}Preview.makeView()
}
{% endif %}

""",

        "cleanMvvmFormViewModel.stencil": """
{% if isConcurrency %}
import Foundation
import Observation

@Observable
@MainActor
final class {{ name }}ViewModel {
    var field1 = ""
    var field2 = ""
    private(set) var didSubmit = false
    private(set) var isSubmitting = false
    private(set) var errorMessage: String?
    private let submitAction: (String, String) async throws -> Void

    init(submitAction: @escaping (String, String) async throws -> Void = { _, _ in
        throw URLError(.unsupportedURL) // Inject the application's submission operation.
    }) {
        self.submitAction = submitAction
    }
{% if isClean %}
{% if hasNoDomain %}
    convenience init(repository: {{ name }}RepositoryImpl) {
        self.init { first, second in try await repository.submit{{ name }}(field1: first, field2: second) }
    }
{% else %}
    convenience init(useCase: {{ name }}UseCase) {
        self.init { first, second in try await useCase.submit(field1: first, field2: second) }
    }
{% endif %}
{% endif %}

    func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        didSubmit = false
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try Task.checkCancellation()
            try await submitAction(field1, field2)
            try Task.checkCancellation()
            didSubmit = true
        } catch is CancellationError {
            // Leaving the screen is not a failed submission.
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }
}
{% else %}
import Combine
import Foundation

@MainActor
final class {{ name }}ViewModel: ObservableObject {
    @Published var field1 = ""
    @Published var field2 = ""
    @Published private(set) var didSubmit = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var errorMessage: String?
    private let submitAction: (String, String) async throws -> Void

    init(submitAction: @escaping (String, String) async throws -> Void = { _, _ in
        throw URLError(.unsupportedURL) // Inject the application's submission operation.
    }) {
        self.submitAction = submitAction
    }
{% if isClean %}
{% if hasNoDomain %}
    convenience init(repository: {{ name }}RepositoryImpl) {
        self.init { first, second in try await repository.submit{{ name }}(field1: first, field2: second) }
    }
{% else %}
    convenience init(useCase: {{ name }}UseCase) {
        self.init { first, second in try await useCase.submit(field1: first, field2: second) }
    }
{% endif %}
{% endif %}

    func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        didSubmit = false
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try Task.checkCancellation()
            try await submitAction(field1, field2)
            try Task.checkCancellation()
            didSubmit = true
        } catch is CancellationError {
            // Leaving the screen is not a failed submission.
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }
}
{% endif %}
""",

        // MARK: Clean MVVM List

        "cleanMvvmListView.stencil": """
import SwiftUI

struct {{ name }}View: View {
{% if isConcurrency %}
    @State private var viewModel: {{ name }}ViewModel

    @State private var reloadID = 0

    init(viewModel: {{ name }}ViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }
{% else %}
    @StateObject private var viewModel: {{ name }}ViewModel

    @State private var reloadID = 0

    init(viewModel: {{ name }}ViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
{% endif %}

    var body: some View {
        VStack {
            if viewModel.isLoading { ProgressView() }
            if let message = viewModel.errorMessage {
                Text(message).foregroundStyle(.red)
            }
            if viewModel.items.isEmpty && !viewModel.isLoading && viewModel.errorMessage == nil {
                Text("No items yet")
            }
            List(viewModel.items) { item in
                Text(item.title)
            }
            Button("Reload") { reloadID += 1 }
                .disabled(viewModel.isLoading)
        }
        .task(id: reloadID) {
            await viewModel.load()
        }
    }
}
{% if hasDependencyContainer %}
#Preview {
    {{ name }}Preview.makeView()
}
{% endif %}

""",

        "cleanMvvmListViewModel.stencil": """
{% if isConcurrency %}
import Foundation
import Observation

@Observable
@MainActor
final class {{ name }}ViewModel {
    private(set) var items: [{{ name }}Item] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private let loadItems: () async throws -> [{{ name }}Item]

    init(loadItems: @escaping () async throws -> [{{ name }}Item] = { [] }) {
        self.loadItems = loadItems
    }
{% if isClean %}
{% if hasNoDomain %}
    convenience init(repository: {{ name }}RepositoryImpl) {
        self.init {
            let value = try await repository.fetch{{ name }}()
            return [{{ name }}Item(id: value.id, title: value.title)]
        }
    }
{% else %}
    convenience init(useCase: {{ name }}UseCase) {
        self.init {
            let value = try await useCase.execute()
            return [{{ name }}Item(id: value.id, title: value.title)]
        }
    }
{% endif %}
{% endif %}

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try Task.checkCancellation()
            let loaded = try await loadItems()
            try Task.checkCancellation()
            items = loaded
        } catch is CancellationError {
            // Keep the last successful data when the view disappears.
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }
}

struct {{ name }}Item: Equatable, Identifiable {
    let id: UUID
    let title: String
}
{% else %}
import Combine
import Foundation

@MainActor
final class {{ name }}ViewModel: ObservableObject {
    @Published private(set) var items: [{{ name }}Item] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    private let loadItems: () async throws -> [{{ name }}Item]

    init(loadItems: @escaping () async throws -> [{{ name }}Item] = { [] }) {
        self.loadItems = loadItems
    }
{% if isClean %}
{% if hasNoDomain %}
    convenience init(repository: {{ name }}RepositoryImpl) {
        self.init {
            let value = try await repository.fetch{{ name }}()
            return [{{ name }}Item(id: value.id, title: value.title)]
        }
    }
{% else %}
    convenience init(useCase: {{ name }}UseCase) {
        self.init {
            let value = try await useCase.execute()
            return [{{ name }}Item(id: value.id, title: value.title)]
        }
    }
{% endif %}
{% endif %}

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try Task.checkCancellation()
            let loaded = try await loadItems()
            try Task.checkCancellation()
            items = loaded
        } catch is CancellationError {
            // Keep the last successful data when the view disappears.
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }
}

struct {{ name }}Item: Equatable, Identifiable {
    let id: UUID
    let title: String
}
{% endif %}
""",

        // MARK: MVI

        "mviDependencyContainer.stencil": """
{% if isFactory %}
import Factory
import SwiftUI

extension Container {
{% if hasView %}
    var {{ propertyName }}View: Factory<{{ name }}View> {
        self { @MainActor in
            {{ name }}View(store: self.{{ propertyName }}Store())
        }
    }
{% endif %}
{% if hasStore %}
    var {{ propertyName }}Store: Factory<{{ name }}Store> {
        self { @MainActor in
            {{ name }}Store(reducer: {{ name }}Reducer())
        }
    }
{% endif %}
}

enum {{ name }}DependencyContainer {
{% if hasView %}
    @MainActor
    static func makeView() -> {{ name }}View {
        Container.shared.{{ propertyName }}View()
    }
{% endif %}
{% if hasStore %}
    @MainActor
    static func makeStore() -> {{ name }}Store {
        Container.shared.{{ propertyName }}Store()
    }
{% endif %}
}
{% else %}
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
{% endif %}

{% if isPackage %}
{% if hasView %}
/// Public feature entry point; presentation and data types remain internal.
@MainActor
public enum {{ name }}Feature {
    public static func makeView() -> some View {
        {{ name }}DependencyContainer.makeView()
    }
}
{% endif %}
{% endif %}

// Isolated preview fixtures; never consults Container.shared.
enum {{ name }}Preview {

{% if hasView %}
    @MainActor
    static func makeView() -> {{ name }}View {
        {{ name }}View(store: makeStore())
    }
{% endif %}
{% if hasStore %}
    @MainActor
    static func makeStore() -> {{ name }}Store {
        {{ name }}Store(reducer: {{ name }}Reducer(){% if isForm %}, submitAction: { _, _ in }{% else %}{% if isList %}, loadValue: { [{{ name }}Item(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, title: "{{ name }}")] }{% endif %}{% endif %})
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
    case didSubmit
    case didFail(String)
    case cancelled
}

""",

        // MARK: MVI List Intent

        "mviListIntent.stencil": """
import Foundation

enum {{ name }}Intent: Equatable {
    case onAppear
    case didFail(String)
    case cancelled
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
            state.isSubmitting = true
            state.didSubmit = false
            state.errorMessage = nil
        case .didSubmit:
            state.isSubmitting = false
            state.didSubmit = true
        case .didFail(let message):
            state.isSubmitting = false
            state.errorMessage = message
        case .cancelled:
            state.isSubmitting = false
{% else %}
        case .onAppear:
{% if isList %}
            state.isLoading = true
            state.errorMessage = nil
        case .didFail(let message):
            state.errorMessage = message
            state.isLoading = false
        case .cancelled:
            state.isLoading = false
        case .didLoad(let items):
            state.items = items
            state.isLoading = false
{% else %}
            state.isLoading = false
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
{% if isConcurrency %}
import Foundation
import Observation

@Observable
@MainActor
final class {{ name }}Store {
    private(set) var state: {{ name }}State

    private let reducer: {{ name }}Reducer

    init(state: {{ name }}State = {{ name }}State(), reducer: {{ name }}Reducer) {
        self.state = state
        self.reducer = reducer
    }

    func send(_ intent: {{ name }}Intent) async {
        reducer.reduce(state: &state, intent: intent)
    }
}
{% else %}
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
{% endif %}

""",

        "mviView.stencil": """
import SwiftUI

struct {{ name }}View: View {
{% if isConcurrency %}
    @State private var store: {{ name }}Store

    init(store: {{ name }}Store) {
        _store = State(wrappedValue: store)
    }
{% else %}
    @StateObject private var store: {{ name }}Store

    init(store: {{ name }}Store) {
        _store = StateObject(wrappedValue: store)
    }
{% endif %}

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
    {{ name }}Preview.makeView()
}
{% endif %}

""",

        "cleanMviDependencyContainer.stencil": """
{% if isFactory %}
import Factory
import SwiftUI

extension Container {
{% if hasView %}
    var {{ propertyName }}View: Factory<{{ name }}View> {
        self { @MainActor in
            {{ name }}View(store: self.{{ propertyName }}Store())
        }
    }
{% endif %}
{% if hasStore %}
    var {{ propertyName }}Store: Factory<{{ name }}Store> {
        self { @MainActor in
{% if hasNoDomain %}
            {{ name }}Store(repository: self.{{ propertyName }}Repository(), reducer: {{ name }}Reducer())
{% else %}
            {{ name }}Store(useCase: self.{{ propertyName }}UseCase(), reducer: {{ name }}Reducer())
{% endif %}
        }
    }
{% endif %}
{% if hasNoDomain %}
    var {{ propertyName }}Repository: Factory<{{ name }}RepositoryImpl> {
        self {
            {{ name }}RepositoryImpl(remoteDataSource: self.{{ propertyName }}RemoteDataSource())
        }
    }
{% endif %}
{% if hasUseCase %}
    var {{ propertyName }}UseCase: Factory<{{ name }}UseCase> {
        self {
            {{ name }}UseCase(repository: self.{{ propertyName }}Repository())
        }
    }
{% endif %}
{% if hasRepository %}
    var {{ propertyName }}Repository: Factory<{{ name }}Repository> {
        self {
            {{ name }}RepositoryImpl(remoteDataSource: self.{{ propertyName }}RemoteDataSource())
        }
    }
{% endif %}
{% if hasRemoteDataSource %}
    var {{ propertyName }}RemoteDataSource: Factory<{{ name }}RemoteDataSource> {
        self {
            {{ name }}RemoteDataSource()
        }
    }
{% endif %}
}

enum {{ name }}DependencyContainer {
{% if hasView %}
    @MainActor
    static func makeView() -> {{ name }}View {
        Container.shared.{{ propertyName }}View()
    }
{% endif %}
{% if hasStore %}
    @MainActor
    static func makeStore() -> {{ name }}Store {
        Container.shared.{{ propertyName }}Store()
    }
{% endif %}
{% if hasNoDomain %}
    static func makeRepository() -> {{ name }}RepositoryImpl {
        Container.shared.{{ propertyName }}Repository()
    }
{% endif %}
{% if hasUseCase %}
    static func makeUseCase() -> {{ name }}UseCase {
        Container.shared.{{ propertyName }}UseCase()
    }
{% endif %}
{% if hasRepository %}
    static func makeRepository() -> {{ name }}Repository {
        Container.shared.{{ propertyName }}Repository()
    }
{% endif %}
{% if hasRemoteDataSource %}
    static func makeRemoteDataSource() -> {{ name }}RemoteDataSource {
        Container.shared.{{ propertyName }}RemoteDataSource()
    }
{% endif %}
}
{% else %}
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
{% endif %}

{% if isPackage %}
{% if hasView %}
/// Public feature entry point; presentation and data types remain internal.
@MainActor
public enum {{ name }}Feature {
    public static func makeView() -> some View {
        {{ name }}DependencyContainer.makeView()
    }
}
{% endif %}
{% endif %}

// Isolated preview fixtures; never consults Container.shared.
enum {{ name }}Preview {

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
        {{ name }}RemoteDataSource.preview
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
    case didSubmit
    case submissionCancelled
{% endif %}
    case onAppear
    case didLoad({% if hasNoDomain %}{{ name }}Response{% else %}{{ name }}Entity{% endif %})
    case didFail(String)
    case cancelled
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
            state.isSubmitting = true
            state.didSubmit = false
            state.errorMessage = nil
        case .didSubmit:
            state.isSubmitting = false
            state.didSubmit = true
        case .submissionCancelled:
            state.isSubmitting = false
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
        case .cancelled:
            state.isLoading = false
        case .didFail(let message):
{% if isForm %}
            state.isSubmitting = false
{% endif %}
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
    var isSubmitting = false
    var didSubmit = false
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
{% if isConcurrency %}
import Foundation
import Observation

@Observable
@MainActor
final class {{ name }}Store {
    private(set) var state: {{ name }}State
    private let reducer: {{ name }}Reducer
    private let loadValue: () async throws -> {% if hasNoDomain %}{{ name }}Response{% else %}{{ name }}Entity{% endif %}
{% if isForm %}
    private let submitAction: (String, String) async throws -> Void
{% endif %}

    init(state: {{ name }}State = {{ name }}State(), reducer: {{ name }}Reducer = {{ name }}Reducer(), loadValue: @escaping () async throws -> {% if hasNoDomain %}{{ name }}Response{% else %}{{ name }}Entity{% endif %}{% if isForm %}, submitAction: @escaping (String, String) async throws -> Void = { _, _ in throw URLError(.unsupportedURL) }{% endif %}) {
        self.state = state
        self.reducer = reducer
        self.loadValue = loadValue
{% if isForm %}
        self.submitAction = submitAction
{% endif %}
    }
{% if hasNoDomain %}
    convenience init(state: {{ name }}State = {{ name }}State(), repository: {{ name }}RepositoryImpl, reducer: {{ name }}Reducer) {
        self.init(state: state, reducer: reducer, loadValue: { try await repository.fetch{{ name }}() }{% if isForm %}, submitAction: { first, second in try await repository.submit{{ name }}(field1: first, field2: second) }{% endif %})
    }
{% else %}
    convenience init(state: {{ name }}State = {{ name }}State(), useCase: {{ name }}UseCase, reducer: {{ name }}Reducer) {
        self.init(state: state, reducer: reducer, loadValue: { try await useCase.execute() }{% if isForm %}, submitAction: { first, second in try await useCase.submit(field1: first, field2: second) }{% endif %})
    }
{% endif %}
{% if isForm %}
    func updateField1(_ value: String) { reducer.reduce(state: &state, intent: .field1Changed(value)) }
    func updateField2(_ value: String) { reducer.reduce(state: &state, intent: .field2Changed(value)) }
{% endif %}

    func send(_ intent: {{ name }}Intent) async {
{% if isForm %}
        if case .submit = intent {
            guard !state.isSubmitting else { return }
            reducer.reduce(state: &state, intent: intent)
            do {
                try Task.checkCancellation()
                try await submitAction(state.field1, state.field2)
                try Task.checkCancellation()
                reducer.reduce(state: &state, intent: .didSubmit)
            } catch is CancellationError {
                reducer.reduce(state: &state, intent: .submissionCancelled)
            } catch {
                reducer.reduce(state: &state, intent: Task.isCancelled ? .submissionCancelled : .didFail(error.localizedDescription))
            }
            return
        }
{% endif %}
        if case .onAppear = intent {
            guard !state.isLoading else { return }
            reducer.reduce(state: &state, intent: intent)
            do {
                try Task.checkCancellation()
                let value = try await loadValue()
                try Task.checkCancellation()
                reducer.reduce(state: &state, intent: .didLoad(value))
            } catch is CancellationError {
                reducer.reduce(state: &state, intent: .cancelled)
            } catch {
                reducer.reduce(state: &state, intent: Task.isCancelled ? .cancelled : .didFail(error.localizedDescription))
            }
            return
        }
        reducer.reduce(state: &state, intent: intent)
    }
}
{% else %}
import Combine
import Foundation

@MainActor
final class {{ name }}Store: ObservableObject {
    @Published private(set) var state: {{ name }}State
    private let reducer: {{ name }}Reducer
    private let loadValue: () async throws -> {% if hasNoDomain %}{{ name }}Response{% else %}{{ name }}Entity{% endif %}
{% if isForm %}
    private let submitAction: (String, String) async throws -> Void
{% endif %}

    init(state: {{ name }}State = {{ name }}State(), reducer: {{ name }}Reducer = {{ name }}Reducer(), loadValue: @escaping () async throws -> {% if hasNoDomain %}{{ name }}Response{% else %}{{ name }}Entity{% endif %}{% if isForm %}, submitAction: @escaping (String, String) async throws -> Void = { _, _ in throw URLError(.unsupportedURL) }{% endif %}) {
        self.state = state
        self.reducer = reducer
        self.loadValue = loadValue
{% if isForm %}
        self.submitAction = submitAction
{% endif %}
    }
{% if hasNoDomain %}
    convenience init(state: {{ name }}State = {{ name }}State(), repository: {{ name }}RepositoryImpl, reducer: {{ name }}Reducer) {
        self.init(state: state, reducer: reducer, loadValue: { try await repository.fetch{{ name }}() }{% if isForm %}, submitAction: { first, second in try await repository.submit{{ name }}(field1: first, field2: second) }{% endif %})
    }
{% else %}
    convenience init(state: {{ name }}State = {{ name }}State(), useCase: {{ name }}UseCase, reducer: {{ name }}Reducer) {
        self.init(state: state, reducer: reducer, loadValue: { try await useCase.execute() }{% if isForm %}, submitAction: { first, second in try await useCase.submit(field1: first, field2: second) }{% endif %})
    }
{% endif %}
{% if isForm %}
    func updateField1(_ value: String) { reducer.reduce(state: &state, intent: .field1Changed(value)) }
    func updateField2(_ value: String) { reducer.reduce(state: &state, intent: .field2Changed(value)) }
{% endif %}

    func send(_ intent: {{ name }}Intent) async {
{% if isForm %}
        if case .submit = intent {
            guard !state.isSubmitting else { return }
            reducer.reduce(state: &state, intent: intent)
            do {
                try Task.checkCancellation()
                try await submitAction(state.field1, state.field2)
                try Task.checkCancellation()
                reducer.reduce(state: &state, intent: .didSubmit)
            } catch is CancellationError {
                reducer.reduce(state: &state, intent: .submissionCancelled)
            } catch {
                reducer.reduce(state: &state, intent: Task.isCancelled ? .submissionCancelled : .didFail(error.localizedDescription))
            }
            return
        }
{% endif %}
        if case .onAppear = intent {
            guard !state.isLoading else { return }
            reducer.reduce(state: &state, intent: intent)
            do {
                try Task.checkCancellation()
                let value = try await loadValue()
                try Task.checkCancellation()
                reducer.reduce(state: &state, intent: .didLoad(value))
            } catch is CancellationError {
                reducer.reduce(state: &state, intent: .cancelled)
            } catch {
                reducer.reduce(state: &state, intent: Task.isCancelled ? .cancelled : .didFail(error.localizedDescription))
            }
            return
        }
        reducer.reduce(state: &state, intent: intent)
    }
}
{% endif %}
""",

        // MARK: MVI Form

        "mviFormView.stencil": """
import SwiftUI

struct {{ name }}View: View {
{% if isConcurrency %}
    @State private var store: {{ name }}Store

    @State private var submissionRequested = false

    init(store: {{ name }}Store) {
        _store = State(wrappedValue: store)
    }
{% else %}
    @StateObject private var store: {{ name }}Store

    @State private var submissionRequested = false

    init(store: {{ name }}Store) {
        _store = StateObject(wrappedValue: store)
    }
{% endif %}

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
                submissionRequested = true
            }
            .disabled(submissionRequested || store.state.isSubmitting)
            if store.state.isSubmitting { ProgressView() }
            if store.state.didSubmit { Text("Submitted") }
            if let message = store.state.errorMessage { Text(message).foregroundStyle(.red) }
        }
        .task(id: submissionRequested) {
            guard submissionRequested else { return }
            await store.send(.submit)
            submissionRequested = false
        }
    }
}
        {% if hasDependencyContainer %}
#Preview {
    {{ name }}Preview.makeView()
}
{% endif %}

""",

        "mviFormStore.stencil": """
{% if isConcurrency %}
import Foundation
import Observation

@Observable
@MainActor
final class {{ name }}Store {
    private(set) var state: {{ name }}State
    private let reducer: {{ name }}Reducer
    private let submitAction: (String, String) async throws -> Void

    init(state: {{ name }}State = {{ name }}State(), reducer: {{ name }}Reducer = {{ name }}Reducer(), submitAction: @escaping (String, String) async throws -> Void = { _, _ in throw URLError(.unsupportedURL) }) {
        self.state = state
        self.reducer = reducer
        self.submitAction = submitAction
    }
    func updateField1(_ value: String) { reducer.reduce(state: &state, intent: .field1Changed(value)) }
    func updateField2(_ value: String) { reducer.reduce(state: &state, intent: .field2Changed(value)) }

    func send(_ intent: {{ name }}Intent) async {
        if case .submit = intent {
            guard !state.isSubmitting else { return }
            reducer.reduce(state: &state, intent: intent)
            do {
                try Task.checkCancellation()
                try await submitAction(state.field1, state.field2)
                try Task.checkCancellation()
                reducer.reduce(state: &state, intent: .didSubmit)
            } catch is CancellationError {
                reducer.reduce(state: &state, intent: .cancelled)
            } catch {
                reducer.reduce(state: &state, intent: Task.isCancelled ? .cancelled : .didFail(error.localizedDescription))
            }
            return
        }
        reducer.reduce(state: &state, intent: intent)
    }
}
{% else %}
import Combine
import Foundation

@MainActor
final class {{ name }}Store: ObservableObject {
    @Published private(set) var state: {{ name }}State
    private let reducer: {{ name }}Reducer
    private let submitAction: (String, String) async throws -> Void

    init(state: {{ name }}State = {{ name }}State(), reducer: {{ name }}Reducer = {{ name }}Reducer(), submitAction: @escaping (String, String) async throws -> Void = { _, _ in throw URLError(.unsupportedURL) }) {
        self.state = state
        self.reducer = reducer
        self.submitAction = submitAction
    }
    func updateField1(_ value: String) { reducer.reduce(state: &state, intent: .field1Changed(value)) }
    func updateField2(_ value: String) { reducer.reduce(state: &state, intent: .field2Changed(value)) }

    func send(_ intent: {{ name }}Intent) async {
        if case .submit = intent {
            guard !state.isSubmitting else { return }
            reducer.reduce(state: &state, intent: intent)
            do {
                try Task.checkCancellation()
                try await submitAction(state.field1, state.field2)
                try Task.checkCancellation()
                reducer.reduce(state: &state, intent: .didSubmit)
            } catch is CancellationError {
                reducer.reduce(state: &state, intent: .cancelled)
            } catch {
                reducer.reduce(state: &state, intent: Task.isCancelled ? .cancelled : .didFail(error.localizedDescription))
            }
            return
        }
        reducer.reduce(state: &state, intent: intent)
    }
}
{% endif %}
""",

        "mviFormState.stencil": """
import Foundation

struct {{ name }}State: Equatable {
    var isLoading = false
    var errorMessage: String?
    var isSubmitting = false
    var didSubmit = false
    var field1 = ""
    var field2 = ""
}


""",

        // MARK: MVI List

        "mviListView.stencil": """
import SwiftUI

struct {{ name }}View: View {
{% if isConcurrency %}
    @State private var store: {{ name }}Store

    @State private var reloadID = 0

    init(store: {{ name }}Store) {
        _store = State(wrappedValue: store)
    }
{% else %}
    @StateObject private var store: {{ name }}Store

    @State private var reloadID = 0

    init(store: {{ name }}Store) {
        _store = StateObject(wrappedValue: store)
    }
{% endif %}

    var body: some View {
        VStack {
            if store.state.isLoading { ProgressView() }
            if let message = store.state.errorMessage { Text(message).foregroundStyle(.red) }
            if store.state.items.isEmpty && !store.state.isLoading && store.state.errorMessage == nil {
                Text("No items yet")
            }
            List(store.state.items) { item in
                Text(item.title)
            }
            Button("Reload") { reloadID += 1 }.disabled(store.state.isLoading)
        }
        .task(id: reloadID) {
            await store.send(.onAppear)
        }
    }
}
        {% if hasDependencyContainer %}
#Preview {
    {{ name }}Preview.makeView()
}
{% endif %}

""",

        "mviListStore.stencil": """
{% if isConcurrency %}
import Foundation
import Observation

@Observable
@MainActor
final class {{ name }}Store {
    private(set) var state: {{ name }}State
    private let reducer: {{ name }}Reducer
    private let loadValue: () async throws -> [{{ name }}Item]

    init(state: {{ name }}State = {{ name }}State(), reducer: {{ name }}Reducer = {{ name }}Reducer(), loadValue: @escaping () async throws -> [{{ name }}Item] = { [] }) {
        self.state = state
        self.reducer = reducer
        self.loadValue = loadValue
    }

    func send(_ intent: {{ name }}Intent) async {
        if case .onAppear = intent {
            guard !state.isLoading else { return }
            reducer.reduce(state: &state, intent: intent)
            do {
                try Task.checkCancellation()
                let value = try await loadValue()
                try Task.checkCancellation()
                reducer.reduce(state: &state, intent: .didLoad(value))
            } catch is CancellationError {
                reducer.reduce(state: &state, intent: .cancelled)
            } catch {
                reducer.reduce(state: &state, intent: Task.isCancelled ? .cancelled : .didFail(error.localizedDescription))
            }
            return
        }
        reducer.reduce(state: &state, intent: intent)
    }
}
{% else %}
import Combine
import Foundation

@MainActor
final class {{ name }}Store: ObservableObject {
    @Published private(set) var state: {{ name }}State
    private let reducer: {{ name }}Reducer
    private let loadValue: () async throws -> [{{ name }}Item]

    init(state: {{ name }}State = {{ name }}State(), reducer: {{ name }}Reducer = {{ name }}Reducer(), loadValue: @escaping () async throws -> [{{ name }}Item] = { [] }) {
        self.state = state
        self.reducer = reducer
        self.loadValue = loadValue
    }

    func send(_ intent: {{ name }}Intent) async {
        if case .onAppear = intent {
            guard !state.isLoading else { return }
            reducer.reduce(state: &state, intent: intent)
            do {
                try Task.checkCancellation()
                let value = try await loadValue()
                try Task.checkCancellation()
                reducer.reduce(state: &state, intent: .didLoad(value))
            } catch is CancellationError {
                reducer.reduce(state: &state, intent: .cancelled)
            } catch {
                reducer.reduce(state: &state, intent: Task.isCancelled ? .cancelled : .didFail(error.localizedDescription))
            }
            return
        }
        reducer.reduce(state: &state, intent: intent)
    }
}
{% endif %}
""",

        "mviListState.stencil": """
import Foundation

struct {{ name }}State: Equatable {
    var items: [{{ name }}Item] = []
    var isLoading = false
    var errorMessage: String?
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
    func load() async throws -> {{ name }}Entity
}

protocol {{ name }}RouterInput {}


""",

        "viperDependencyContainer.stencil": """
{% if isFactory %}
import Factory
import SwiftUI

extension Container {
{% if hasView %}
    var {{ propertyName }}View: Factory<{{ name }}View> {
        self { @MainActor in
            {{ name }}View(presenter: self.{{ propertyName }}Presenter())
        }
    }
{% endif %}
{% if hasPresenter %}
    var {{ propertyName }}Presenter: Factory<{{ name }}Presenter> {
        self { @MainActor in
            {{ name }}Presenter(interactor: self.{{ propertyName }}Interactor(), router: self.{{ propertyName }}Router())
        }
    }
{% endif %}
{% if hasInteractor %}
    var {{ propertyName }}Interactor: Factory<{{ name }}Interactor> {
        self {
            {{ name }}Interactor()
        }
    }
{% endif %}
{% if hasRouter %}
    var {{ propertyName }}Router: Factory<{{ name }}Router> {
        self {
            {{ name }}Router()
        }
    }
{% endif %}
}

enum {{ name }}DependencyContainer {
{% if hasView %}
    @MainActor
    static func makeView() -> {{ name }}View {
        Container.shared.{{ propertyName }}View()
    }
{% endif %}
{% if hasPresenter %}
    @MainActor
    static func makePresenter() -> {{ name }}Presenter {
        Container.shared.{{ propertyName }}Presenter()
    }
{% endif %}
{% if hasInteractor %}
    static func makeInteractor() -> {{ name }}Interactor {
        Container.shared.{{ propertyName }}Interactor()
    }
{% endif %}
{% if hasRouter %}
    static func makeRouter() -> {{ name }}Router {
        Container.shared.{{ propertyName }}Router()
    }
{% endif %}
}
{% else %}
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
{% endif %}

{% if isPackage %}
{% if hasView %}
/// Public feature entry point; presentation and data types remain internal.
@MainActor
public enum {{ name }}Feature {
    public static func makeView() -> some View {
        {{ name }}DependencyContainer.makeView()
    }
}
{% endif %}
{% endif %}

// Isolated preview fixtures; never consults Container.shared.
enum {{ name }}Preview {

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
    func load() async throws -> {{ name }}Entity {
        {{ name }}Entity(title: "{{ name }}")
    }
}

""",

        "viperPresenter.stencil": """
{% if isConcurrency %}
import Foundation
import Observation

@Observable
@MainActor
final class {{ name }}Presenter: {{ name }}PresenterInput {
    private(set) var title = "{{ name }}"

    {% if isConcurrency %}{% else %}@Published {% endif %}private(set) var errorMessage: String?

    private let interactor: {{ name }}Interactor
    private let router: {{ name }}Router

    init(interactor: {{ name }}Interactor, router: {{ name }}Router) {
        self.interactor = interactor
        self.router = router
    }

    func viewDidLoad() async {
        errorMessage = nil
        do {
            try Task.checkCancellation()
        let entity = try await interactor.load()
        title = entity.title
        } catch is CancellationError {
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }
}
{% else %}
import Combine
import Foundation

@MainActor
final class {{ name }}Presenter: ObservableObject, {{ name }}PresenterInput {
    @Published private(set) var title = "{{ name }}"

    {% if isConcurrency %}{% else %}@Published {% endif %}private(set) var errorMessage: String?

    private let interactor: {{ name }}Interactor
    private let router: {{ name }}Router

    init(interactor: {{ name }}Interactor, router: {{ name }}Router) {
        self.interactor = interactor
        self.router = router
    }

    func viewDidLoad() async {
        errorMessage = nil
        do {
            try Task.checkCancellation()
        let entity = try await interactor.load()
        title = entity.title
        } catch is CancellationError {
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }
}
{% endif %}

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
{% if isConcurrency %}
    @State private var presenter: {{ name }}Presenter

    init(presenter: {{ name }}Presenter) {
        _presenter = State(wrappedValue: presenter)
    }
{% else %}
    @StateObject private var presenter: {{ name }}Presenter

    init(presenter: {{ name }}Presenter) {
        _presenter = StateObject(wrappedValue: presenter)
    }
{% endif %}

    var body: some View {
        VStack {
            Text(presenter.title)
            if let message = presenter.errorMessage { Text(message).foregroundStyle(.red) }
        }
            .task {
                await presenter.viewDidLoad()
            }
    }
}
{% if hasDependencyContainer %}
#Preview {
    {{ name }}Preview.makeView()
}
{% endif %}

""",

        // MARK: VIPER Form

        "viperFormView.stencil": """
import SwiftUI

struct {{ name }}View: View {
{% if isConcurrency %}
    @State private var presenter: {{ name }}Presenter

    init(presenter: {{ name }}Presenter) {
        _presenter = State(wrappedValue: presenter)
    }

    var body: some View {
        @Bindable var presenter = presenter
        Form {
            TextField("Field 1", text: $presenter.field1)
            TextField("Field 2", text: $presenter.field2)
            Button("Submit") {
                presenter.submit()
            }
        }
    }
{% else %}
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
{% endif %}
}
{% if hasDependencyContainer %}
#Preview {
    {{ name }}Preview.makeView()
}
{% endif %}

""",

        "viperFormPresenter.stencil": """
{% if isConcurrency %}
import Foundation
import Observation

@Observable
@MainActor
final class {{ name }}Presenter {
    var field1 = ""
    var field2 = ""

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
{% else %}
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
{% endif %}

""",

        // MARK: VIPER List

        "viperListView.stencil": """
import SwiftUI

struct {{ name }}View: View {
{% if isConcurrency %}
    @State private var presenter: {{ name }}Presenter

    init(presenter: {{ name }}Presenter) {
        _presenter = State(wrappedValue: presenter)
    }
{% else %}
    @StateObject private var presenter: {{ name }}Presenter

    init(presenter: {{ name }}Presenter) {
        _presenter = StateObject(wrappedValue: presenter)
    }
{% endif %}

    var body: some View {
        VStack {
            if let message = presenter.errorMessage { Text(message).foregroundStyle(.red) }
            List(presenter.items) { item in Text(item.title) }
        }
        .task {
            await presenter.viewDidLoad()
        }
    }
}
{% if hasDependencyContainer %}
#Preview {
    {{ name }}Preview.makeView()
}
{% endif %}

""",

        "viperListPresenter.stencil": """
{% if isConcurrency %}
import Foundation
import Observation

@Observable
@MainActor
final class {{ name }}Presenter {
    private(set) var items: [{{ name }}Item] = []

    {% if isConcurrency %}{% else %}@Published {% endif %}private(set) var errorMessage: String?

    private let interactor: {{ name }}Interactor
    private let router: {{ name }}Router

    init(interactor: {{ name }}Interactor, router: {{ name }}Router) {
        self.interactor = interactor
        self.router = router
    }

    func viewDidLoad() async {
        errorMessage = nil
        do {
            try Task.checkCancellation()
        // Load items
        } catch is CancellationError {
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }
}

struct {{ name }}Item: Identifiable {
    let id: UUID
    let title: String
}
{% else %}
import Combine
import Foundation

@MainActor
final class {{ name }}Presenter: ObservableObject {
    @Published private(set) var items: [{{ name }}Item] = []

    {% if isConcurrency %}{% else %}@Published {% endif %}private(set) var errorMessage: String?

    private let interactor: {{ name }}Interactor
    private let router: {{ name }}Router

    init(interactor: {{ name }}Interactor, router: {{ name }}Router) {
        self.interactor = interactor
        self.router = router
    }

    func viewDidLoad() async {
        errorMessage = nil
        do {
            try Task.checkCancellation()
        // Load items
        } catch is CancellationError {
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }
}

struct {{ name }}Item: Identifiable {
    let id: UUID
    let title: String
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
    func load() async throws -> {{ name }}Response
{% else %}
    func load() async throws -> {{ name }}Entity
{% endif %}
}

protocol {{ name }}RouterInput {}


""",

        "cleanViperDependencyContainer.stencil": """
{% if isFactory %}
import Factory
import SwiftUI

extension Container {
{% if hasView %}
    var {{ propertyName }}View: Factory<{{ name }}View> {
        self { @MainActor in
            {{ name }}View(presenter: self.{{ propertyName }}Presenter())
        }
    }
{% endif %}
{% if hasPresenter %}
    var {{ propertyName }}Presenter: Factory<{{ name }}Presenter> {
        self { @MainActor in
            {{ name }}Presenter(interactor: self.{{ propertyName }}Interactor(), router: self.{{ propertyName }}Router())
        }
    }
{% endif %}
{% if hasInteractor %}
    var {{ propertyName }}Interactor: Factory<{{ name }}Interactor> {
        self {
{% if hasNoDomain %}
            {{ name }}Interactor(repository: self.{{ propertyName }}Repository())
{% else %}
            {{ name }}Interactor(useCase: self.{{ propertyName }}UseCase())
{% endif %}
        }
    }
{% endif %}
{% if hasRouter %}
    var {{ propertyName }}Router: Factory<{{ name }}Router> {
        self {
            {{ name }}Router()
        }
    }
{% endif %}
{% if hasNoDomain %}
    var {{ propertyName }}Repository: Factory<{{ name }}RepositoryImpl> {
        self {
            {{ name }}RepositoryImpl(remoteDataSource: self.{{ propertyName }}RemoteDataSource())
        }
    }
{% endif %}
{% if hasUseCase %}
    var {{ propertyName }}UseCase: Factory<{{ name }}UseCase> {
        self {
            {{ name }}UseCase(repository: self.{{ propertyName }}Repository())
        }
    }
{% endif %}
{% if hasRepository %}
    var {{ propertyName }}Repository: Factory<{{ name }}Repository> {
        self {
            {{ name }}RepositoryImpl(remoteDataSource: self.{{ propertyName }}RemoteDataSource())
        }
    }
{% endif %}
{% if hasRemoteDataSource %}
    var {{ propertyName }}RemoteDataSource: Factory<{{ name }}RemoteDataSource> {
        self {
            {{ name }}RemoteDataSource()
        }
    }
{% endif %}
}

enum {{ name }}DependencyContainer {
{% if hasView %}
    @MainActor
    static func makeView() -> {{ name }}View {
        Container.shared.{{ propertyName }}View()
    }
{% endif %}
{% if hasPresenter %}
    @MainActor
    static func makePresenter() -> {{ name }}Presenter {
        Container.shared.{{ propertyName }}Presenter()
    }
{% endif %}
{% if hasInteractor %}
    static func makeInteractor() -> {{ name }}Interactor {
        Container.shared.{{ propertyName }}Interactor()
    }
{% endif %}
{% if hasRouter %}
    static func makeRouter() -> {{ name }}Router {
        Container.shared.{{ propertyName }}Router()
    }
{% endif %}
{% if hasNoDomain %}
    static func makeRepository() -> {{ name }}RepositoryImpl {
        Container.shared.{{ propertyName }}Repository()
    }
{% endif %}
{% if hasUseCase %}
    static func makeUseCase() -> {{ name }}UseCase {
        Container.shared.{{ propertyName }}UseCase()
    }
{% endif %}
{% if hasRepository %}
    static func makeRepository() -> {{ name }}Repository {
        Container.shared.{{ propertyName }}Repository()
    }
{% endif %}
{% if hasRemoteDataSource %}
    static func makeRemoteDataSource() -> {{ name }}RemoteDataSource {
        Container.shared.{{ propertyName }}RemoteDataSource()
    }
{% endif %}
}
{% else %}
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
{% endif %}

{% if isPackage %}
{% if hasView %}
/// Public feature entry point; presentation and data types remain internal.
@MainActor
public enum {{ name }}Feature {
    public static func makeView() -> some View {
        {{ name }}DependencyContainer.makeView()
    }
}
{% endif %}
{% endif %}

// Isolated preview fixtures; never consults Container.shared.
enum {{ name }}Preview {

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
        {{ name }}RemoteDataSource.preview
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

    func load() async throws -> {{ name }}Response {
        try await repository.fetch{{ name }}()
    }
{% else %}
    private let useCase: {{ name }}UseCase

    init(useCase: {{ name }}UseCase) {
        self.useCase = useCase
    }

    func load() async throws -> {{ name }}Entity {
        try await useCase.execute()
    }
{% endif %}
}


""",

        // MARK: VIP

        "vipDependencyContainer.stencil": """
{% if isFactory %}
import Factory
import SwiftUI

extension Container {
{% if hasView %}
    var {{ propertyName }}View: Factory<{{ name }}View> {
        self { @MainActor in
            {{ name }}View(interactor: self.{{ propertyName }}Interactor())
        }
    }
{% endif %}
{% if hasInteractor %}
    var {{ propertyName }}Interactor: Factory<{{ name }}Interactor> {
        self { @MainActor in
            {{ name }}Interactor(presenter: self.{{ propertyName }}Presenter(), worker: self.{{ propertyName }}Worker())
        }
    }
{% endif %}
{% if hasPresenter %}
    var {{ propertyName }}Presenter: Factory<{{ name }}Presenter> {
        self { @MainActor in
            {{ name }}Presenter()
        }
    }
{% endif %}
{% if hasWorker %}
    var {{ propertyName }}Worker: Factory<{{ name }}Worker> {
        self {
            {{ name }}Worker()
        }
    }
{% endif %}
}

enum {{ name }}DependencyContainer {
{% if hasView %}
    @MainActor
    static func makeView() -> {{ name }}View {
        Container.shared.{{ propertyName }}View()
    }
{% endif %}
{% if hasInteractor %}
    @MainActor
    static func makeInteractor() -> {{ name }}Interactor {
        Container.shared.{{ propertyName }}Interactor()
    }
{% endif %}
{% if hasPresenter %}
    @MainActor
    static func makePresenter() -> {{ name }}Presenter {
        Container.shared.{{ propertyName }}Presenter()
    }
{% endif %}
{% if hasWorker %}
    static func makeWorker() -> {{ name }}Worker {
        Container.shared.{{ propertyName }}Worker()
    }
{% endif %}
}
{% else %}
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
{% endif %}

{% if isPackage %}
{% if hasView %}
/// Public feature entry point; presentation and data types remain internal.
@MainActor
public enum {{ name }}Feature {
    public static func makeView() -> some View {
        {{ name }}DependencyContainer.makeView()
    }
}
{% endif %}
{% endif %}

// Isolated preview fixtures; never consults Container.shared.
enum {{ name }}Preview {

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
{% if isConcurrency %}
import Foundation
import Observation

@Observable
@MainActor
final class {{ name }}Interactor {
    private(set) var viewModel = {{ name }}.ViewModel(title: "{{ name }}")
{% if isForm %}
    var field1 = ""
    var field2 = ""

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
{% else %}
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
{% endif %}

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
{% if isConcurrency %}
    @State private var interactor: {{ name }}Interactor

    init(interactor: {{ name }}Interactor) {
        _interactor = State(wrappedValue: interactor)
    }
{% else %}
    @StateObject private var interactor: {{ name }}Interactor

    init(interactor: {{ name }}Interactor) {
        _interactor = StateObject(wrappedValue: interactor)
    }
{% endif %}

    var body: some View {
        Text(interactor.viewModel.title)
            .task {
                await interactor.load()
            }
    }
}
        {% if hasDependencyContainer %}
#Preview {
    {{ name }}Preview.makeView()
}
{% endif %}

""",

        // MARK: VIP Form

        "vipFormView.stencil": """
import SwiftUI

struct {{ name }}View: View {
{% if isConcurrency %}
    @State private var interactor: {{ name }}Interactor

    init(interactor: {{ name }}Interactor) {
        _interactor = State(wrappedValue: interactor)
    }

    var body: some View {
        @Bindable var interactor = interactor
        Form {
            TextField("Field 1", text: $interactor.field1)
            TextField("Field 2", text: $interactor.field2)
            Button("Submit") {
                interactor.submit()
            }
        }
    }
{% else %}
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
{% endif %}
}
        {% if hasDependencyContainer %}
#Preview {
    {{ name }}Preview.makeView()
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
{% if isConcurrency %}
    @State private var interactor: {{ name }}Interactor

    init(interactor: {{ name }}Interactor) {
        _interactor = State(wrappedValue: interactor)
    }
{% else %}
    @StateObject private var interactor: {{ name }}Interactor

    init(interactor: {{ name }}Interactor) {
        _interactor = StateObject(wrappedValue: interactor)
    }
{% endif %}

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
    {{ name }}Preview.makeView()
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
{% if isFactory %}
import Factory
import SwiftUI

extension Container {
{% if hasView %}
    var {{ propertyName }}View: Factory<{{ name }}View> {
        self { @MainActor in
            {{ name }}View(interactor: self.{{ propertyName }}Interactor())
        }
    }
{% endif %}
{% if hasInteractor %}
    var {{ propertyName }}Interactor: Factory<{{ name }}Interactor> {
        self { @MainActor in
{% if hasNoDomain %}
            {{ name }}Interactor(presenter: self.{{ propertyName }}Presenter(), repository: self.{{ propertyName }}Repository())
{% else %}
            {{ name }}Interactor(presenter: self.{{ propertyName }}Presenter(), useCase: self.{{ propertyName }}UseCase())
{% endif %}
        }
    }
{% endif %}
{% if hasPresenter %}
    var {{ propertyName }}Presenter: Factory<{{ name }}Presenter> {
        self { @MainActor in
            {{ name }}Presenter()
        }
    }
{% endif %}
{% if hasNoDomain %}
    var {{ propertyName }}Repository: Factory<{{ name }}RepositoryImpl> {
        self {
            {{ name }}RepositoryImpl(remoteDataSource: self.{{ propertyName }}RemoteDataSource())
        }
    }
{% endif %}
{% if hasUseCase %}
    var {{ propertyName }}UseCase: Factory<{{ name }}UseCase> {
        self {
            {{ name }}UseCase(repository: self.{{ propertyName }}Repository())
        }
    }
{% endif %}
{% if hasRepository %}
    var {{ propertyName }}Repository: Factory<{{ name }}Repository> {
        self {
            {{ name }}RepositoryImpl(remoteDataSource: self.{{ propertyName }}RemoteDataSource())
        }
    }
{% endif %}
{% if hasRemoteDataSource %}
    var {{ propertyName }}RemoteDataSource: Factory<{{ name }}RemoteDataSource> {
        self {
            {{ name }}RemoteDataSource()
        }
    }
{% endif %}
}

enum {{ name }}DependencyContainer {
{% if hasView %}
    @MainActor
    static func makeView() -> {{ name }}View {
        Container.shared.{{ propertyName }}View()
    }
{% endif %}
{% if hasInteractor %}
    @MainActor
    static func makeInteractor() -> {{ name }}Interactor {
        Container.shared.{{ propertyName }}Interactor()
    }
{% endif %}
{% if hasPresenter %}
    @MainActor
    static func makePresenter() -> {{ name }}Presenter {
        Container.shared.{{ propertyName }}Presenter()
    }
{% endif %}
{% if hasNoDomain %}
    static func makeRepository() -> {{ name }}RepositoryImpl {
        Container.shared.{{ propertyName }}Repository()
    }
{% endif %}
{% if hasUseCase %}
    static func makeUseCase() -> {{ name }}UseCase {
        Container.shared.{{ propertyName }}UseCase()
    }
{% endif %}
{% if hasRepository %}
    static func makeRepository() -> {{ name }}Repository {
        Container.shared.{{ propertyName }}Repository()
    }
{% endif %}
{% if hasRemoteDataSource %}
    static func makeRemoteDataSource() -> {{ name }}RemoteDataSource {
        Container.shared.{{ propertyName }}RemoteDataSource()
    }
{% endif %}
}
{% else %}
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
{% endif %}

{% if isPackage %}
{% if hasView %}
/// Public feature entry point; presentation and data types remain internal.
@MainActor
public enum {{ name }}Feature {
    public static func makeView() -> some View {
        {{ name }}DependencyContainer.makeView()
    }
}
{% endif %}
{% endif %}

// Isolated preview fixtures; never consults Container.shared.
enum {{ name }}Preview {

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
        {{ name }}RemoteDataSource.preview
    }
{% endif %}
}

""",

        "cleanVipInteractor.stencil": """
{% if isConcurrency %}
import Foundation
import Observation

@Observable
@MainActor
final class {{ name }}Interactor {
    private(set) var viewModel = {{ name }}.ViewModel(title: "{{ name }}")
{% if isForm %}
    var field1 = ""
    var field2 = ""

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
            try Task.checkCancellation()
{% if hasNoDomain %}
            let response = try await repository.fetch{{ name }}()
            try Task.checkCancellation()
            viewModel = presenter.present(response: response)
{% else %}
            let entity = try await useCase.execute()
            try Task.checkCancellation()
            viewModel = presenter.present(entity: entity)
{% endif %}
        } catch is CancellationError {
        } catch {
            guard !Task.isCancelled else { return }
            viewModel = {{ name }}.ViewModel(title: error.localizedDescription)
        }
    }
}
{% else %}
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
            try Task.checkCancellation()
{% if hasNoDomain %}
            let response = try await repository.fetch{{ name }}()
            try Task.checkCancellation()
            viewModel = presenter.present(response: response)
{% else %}
            let entity = try await useCase.execute()
            try Task.checkCancellation()
            viewModel = presenter.present(entity: entity)
{% endif %}
        } catch is CancellationError {
        } catch {
            guard !Task.isCancelled else { return }
            viewModel = {{ name }}.ViewModel(title: error.localizedDescription)
        }
    }
}
{% endif %}

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
{% if isFactory %}
import Factory
import SwiftUI

extension Container {
{% if hasView %}
    var {{ propertyName }}View: Factory<{{ name }}View> {
        self { @MainActor in
            {{ name }}View(presenter: self.{{ propertyName }}Presenter())
        }
    }
{% endif %}
{% if hasPresenter %}
    var {{ propertyName }}Presenter: Factory<{{ name }}Presenter> {
        self { @MainActor in
            {{ name }}Presenter(model: {{ name }}Model(title: "{{ name }}"))
        }
    }
{% endif %}
}

enum {{ name }}DependencyContainer {
{% if hasView %}
    @MainActor
    static func makeView() -> {{ name }}View {
        Container.shared.{{ propertyName }}View()
    }
{% endif %}
{% if hasPresenter %}
    @MainActor
    static func makePresenter() -> {{ name }}Presenter {
        Container.shared.{{ propertyName }}Presenter()
    }
{% endif %}
}
{% else %}
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
{% endif %}

{% if isPackage %}
{% if hasView %}
/// Public feature entry point; presentation and data types remain internal.
@MainActor
public enum {{ name }}Feature {
    public static func makeView() -> some View {
        {{ name }}DependencyContainer.makeView()
    }
}
{% endif %}
{% endif %}

// Isolated preview fixtures; never consults Container.shared.
enum {{ name }}Preview {

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
{% if isConcurrency %}
import Foundation
import Observation

@Observable
@MainActor
final class {{ name }}Presenter {
    private(set) var title = "{{ name }}"

    private let model: {{ name }}Model

    init(model: {{ name }}Model) {
        self.model = model
    }

    func load() async {
        title = model.title
    }
}
{% else %}
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
{% endif %}

""",

        "mvpView.stencil": """
import SwiftUI

struct {{ name }}View: View {
{% if isConcurrency %}
    @State private var presenter: {{ name }}Presenter

    init(presenter: {{ name }}Presenter) {
        _presenter = State(wrappedValue: presenter)
    }
{% else %}
    @StateObject private var presenter: {{ name }}Presenter

    init(presenter: {{ name }}Presenter) {
        _presenter = StateObject(wrappedValue: presenter)
    }
{% endif %}

    var body: some View {
        VStack {
            Text(presenter.title)
{% if isClean %}
            if let message = presenter.errorMessage { Text(message).foregroundStyle(.red) }
{% endif %}
        }
            .task {
                await presenter.load()
            }
    }
}
        {% if hasDependencyContainer %}
#Preview {
    {{ name }}Preview.makeView()
}
{% endif %}

""",

        // MARK: MVP Form

        "mvpFormView.stencil": """
import SwiftUI

struct {{ name }}View: View {
{% if isConcurrency %}
    @State private var presenter: {{ name }}Presenter

    init(presenter: {{ name }}Presenter) {
        _presenter = State(wrappedValue: presenter)
    }

    var body: some View {
        @Bindable var presenter = presenter
        Form {
            TextField("Field 1", text: $presenter.field1)
            TextField("Field 2", text: $presenter.field2)
            Button("Submit") {
                presenter.submit()
            }
        }
    }
{% else %}
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
{% endif %}
}
        {% if hasDependencyContainer %}
#Preview {
    {{ name }}Preview.makeView()
}
{% endif %}

""",

        "mvpFormPresenter.stencil": """
{% if isConcurrency %}
import Foundation
import Observation

@Observable
@MainActor
final class {{ name }}Presenter {
    var field1 = ""
    var field2 = ""

    private let model: {{ name }}Model

    init(model: {{ name }}Model) {
        self.model = model
    }

    func submit() {
        // Handle form submission
    }
}
{% else %}
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
{% endif %}

""",

        // MARK: MVP List

        "mvpListView.stencil": """
import SwiftUI

struct {{ name }}View: View {
{% if isConcurrency %}
    @State private var presenter: {{ name }}Presenter

    init(presenter: {{ name }}Presenter) {
        _presenter = State(wrappedValue: presenter)
    }
{% else %}
    @StateObject private var presenter: {{ name }}Presenter

    init(presenter: {{ name }}Presenter) {
        _presenter = StateObject(wrappedValue: presenter)
    }
{% endif %}

    var body: some View {
        VStack {
{% if isClean %}
            if let message = presenter.errorMessage { Text(message).foregroundStyle(.red) }
{% endif %}
            List(presenter.items) { item in Text(item.title) }
        }
        .task {
            await presenter.load()
        }
    }
}
        {% if hasDependencyContainer %}
#Preview {
    {{ name }}Preview.makeView()
}
{% endif %}

""",

        "mvpListPresenter.stencil": """
{% if isConcurrency %}
import Foundation
import Observation

@Observable
@MainActor
final class {{ name }}Presenter {
    private(set) var items: [{{ name }}Item] = []

    private let model: {{ name }}Model

    init(model: {{ name }}Model) {
        self.model = model
    }

    func load() async {
        // Load items
    }
}
{% else %}
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
{% endif %}

struct {{ name }}Item: Identifiable {
    let id: UUID
    let title: String
}

""",

        "cleanMvpDependencyContainer.stencil": """
{% if isFactory %}
import Factory
import SwiftUI

extension Container {
{% if hasView %}
    var {{ propertyName }}View: Factory<{{ name }}View> {
        self { @MainActor in
            {{ name }}View(presenter: self.{{ propertyName }}Presenter())
        }
    }
{% endif %}
{% if hasPresenter %}
    var {{ propertyName }}Presenter: Factory<{{ name }}Presenter> {
        self { @MainActor in
{% if hasNoDomain %}
            {{ name }}Presenter(model: {{ name }}Model(title: "{{ name }}"), repository: self.{{ propertyName }}Repository())
{% else %}
            {{ name }}Presenter(model: {{ name }}Model(title: "{{ name }}"), useCase: self.{{ propertyName }}UseCase())
{% endif %}
        }
    }
{% endif %}
{% if hasNoDomain %}
    var {{ propertyName }}Repository: Factory<{{ name }}RepositoryImpl> {
        self {
            {{ name }}RepositoryImpl(remoteDataSource: self.{{ propertyName }}RemoteDataSource())
        }
    }
{% endif %}
{% if hasUseCase %}
    var {{ propertyName }}UseCase: Factory<{{ name }}UseCase> {
        self {
            {{ name }}UseCase(repository: self.{{ propertyName }}Repository())
        }
    }
{% endif %}
{% if hasRepository %}
    var {{ propertyName }}Repository: Factory<{{ name }}Repository> {
        self {
            {{ name }}RepositoryImpl(remoteDataSource: self.{{ propertyName }}RemoteDataSource())
        }
    }
{% endif %}
{% if hasRemoteDataSource %}
    var {{ propertyName }}RemoteDataSource: Factory<{{ name }}RemoteDataSource> {
        self {
            {{ name }}RemoteDataSource()
        }
    }
{% endif %}
}

enum {{ name }}DependencyContainer {
{% if hasView %}
    @MainActor
    static func makeView() -> {{ name }}View {
        Container.shared.{{ propertyName }}View()
    }
{% endif %}
{% if hasPresenter %}
    @MainActor
    static func makePresenter() -> {{ name }}Presenter {
        Container.shared.{{ propertyName }}Presenter()
    }
{% endif %}
{% if hasNoDomain %}
    static func makeRepository() -> {{ name }}RepositoryImpl {
        Container.shared.{{ propertyName }}Repository()
    }
{% endif %}
{% if hasUseCase %}
    static func makeUseCase() -> {{ name }}UseCase {
        Container.shared.{{ propertyName }}UseCase()
    }
{% endif %}
{% if hasRepository %}
    static func makeRepository() -> {{ name }}Repository {
        Container.shared.{{ propertyName }}Repository()
    }
{% endif %}
{% if hasRemoteDataSource %}
    static func makeRemoteDataSource() -> {{ name }}RemoteDataSource {
        Container.shared.{{ propertyName }}RemoteDataSource()
    }
{% endif %}
}
{% else %}
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
{% endif %}

{% if isPackage %}
{% if hasView %}
/// Public feature entry point; presentation and data types remain internal.
@MainActor
public enum {{ name }}Feature {
    public static func makeView() -> some View {
        {{ name }}DependencyContainer.makeView()
    }
}
{% endif %}
{% endif %}

// Isolated preview fixtures; never consults Container.shared.
enum {{ name }}Preview {

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
        {{ name }}RemoteDataSource.preview
    }
{% endif %}
}

""",

        "cleanMvpPresenter.stencil": """
{% if isConcurrency %}
import Foundation
import Observation

@Observable
@MainActor
final class {{ name }}Presenter {
{% if isForm %}
    var field1 = ""
    var field2 = ""
{% else %}
{% if isList %}
    private(set) var items: [{{ name }}Item] = []
{% else %}
    private(set) var title = "{{ name }}"
{% endif %}
{% endif %}

    {% if isConcurrency %}{% else %}@Published {% endif %}private(set) var errorMessage: String?

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
        errorMessage = nil
        do {
            try Task.checkCancellation()
{% if hasNoDomain %}
            let response = try await repository.fetch{{ name }}()
            try Task.checkCancellation()
{% if isList %}
            items = [{{ name }}Item(id: response.id, title: response.title)]
{% else %}
            title = response.title
{% endif %}
{% else %}
            let entity = try await useCase.execute()
            try Task.checkCancellation()
{% if isList %}
            items = [{{ name }}Item(id: entity.id, title: entity.title)]
{% else %}
            title = entity.title
{% endif %}
{% endif %}
        } catch is CancellationError {
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
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
{% else %}
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

    {% if isConcurrency %}{% else %}@Published {% endif %}private(set) var errorMessage: String?

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
        errorMessage = nil
        do {
            try Task.checkCancellation()
{% if hasNoDomain %}
            let response = try await repository.fetch{{ name }}()
            try Task.checkCancellation()
{% if isList %}
            items = [{{ name }}Item(id: response.id, title: response.title)]
{% else %}
            title = response.title
{% endif %}
{% else %}
            let entity = try await useCase.execute()
            try Task.checkCancellation()
{% if isList %}
            items = [{{ name }}Item(id: entity.id, title: entity.title)]
{% else %}
            title = entity.title
{% endif %}
{% endif %}
        } catch is CancellationError {
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
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
{% endif %}

""",
    ].merging(TestTemplateContent.files) { _, testTemplate in testTemplate }
}
