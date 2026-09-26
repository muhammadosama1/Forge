/// XCTest templates matched to the selected architecture and feature category.
enum TestTemplateContent {
    static let files: [String: String] = [
        "viewModelTests.stencil": """
import XCTest
@testable import {{ moduleName }}

final class {{ name }}ViewModelTests: XCTestCase {
    @MainActor
{% if isForm %}
    func testFormFieldsCanBeEdited() {
        let sut = {{ name }}DependencyContainer.makeViewModel()

        sut.field1 = "First value"
        sut.field2 = "Second value"

        XCTAssertEqual(sut.field1, "First value")
        XCTAssertEqual(sut.field2, "Second value")
    }
{% else %}
{% if isList %}
    func testListStartsEmpty() {
        let sut = {{ name }}DependencyContainer.makeViewModel()
        XCTAssertTrue(sut.items.isEmpty)
    }
{% else %}
    func testLoadFinishesWithoutAnError() async {
        let sut = {{ name }}DependencyContainer.makeViewModel()
{% if isClean %}
{% if hasNoDomain %}
        XCTAssertNil(sut.response)
{% else %}
        XCTAssertNil(sut.entity)
{% endif %}
{% endif %}

        await sut.load()

{% if isClean %}
{% if hasNoDomain %}
        XCTAssertEqual(sut.response?.title, "{{ name }}")
{% else %}
        XCTAssertEqual(sut.entity?.title, "{{ name }}")
{% endif %}
{% else %}
        XCTAssertEqual(sut.title, "{{ name }}")
{% endif %}
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }
{% endif %}
{% endif %}
}

""",

        "storeTests.stencil": """
import XCTest
@testable import {{ moduleName }}

final class {{ name }}StoreTests: XCTestCase {
    @MainActor
{% if isForm %}
    func testFieldUpdatesReachState() {
        let sut = {{ name }}DependencyContainer.makeStore()

        sut.updateField1("First value")
        sut.updateField2("Second value")

        XCTAssertEqual(sut.state.field1, "First value")
        XCTAssertEqual(sut.state.field2, "Second value")
    }
{% else %}
{% if isList %}
{% if isClean %}
    func testOnAppearLoadsItems() async {
        let sut = {{ name }}DependencyContainer.makeStore()
        XCTAssertTrue(sut.state.items.isEmpty)

        await sut.send(.onAppear)

        XCTAssertEqual(sut.state.items.count, 1)
        XCTAssertEqual(sut.state.items.first?.title, "{{ name }}")
        XCTAssertFalse(sut.state.isLoading)
        XCTAssertNil(sut.state.errorMessage)
    }
{% else %}
    func testDidLoadReplacesItems() async {
        let sut = {{ name }}DependencyContainer.makeStore()
        let item = {{ name }}Item(id: UUID(), title: "Loaded item")

        await sut.send(.didLoad([item]))

        XCTAssertEqual(sut.state.items, [item])
        XCTAssertFalse(sut.state.isLoading)
    }
{% endif %}
{% else %}
    func testOnAppearFinishesLoading() async {
        let sut = {{ name }}DependencyContainer.makeStore()

        await sut.send(.onAppear)

        XCTAssertEqual(sut.state.title, "{{ name }}")
        XCTAssertFalse(sut.state.isLoading)
        XCTAssertNil(sut.state.errorMessage)
{% if isClean %}
{% if hasNoDomain %}
        XCTAssertEqual(sut.state.response?.title, "{{ name }}")
{% else %}
        XCTAssertEqual(sut.state.entity?.title, "{{ name }}")
{% endif %}
{% endif %}
    }
{% endif %}
{% endif %}
}

""",

        "reducerTests.stencil": """
import XCTest
@testable import {{ moduleName }}

final class {{ name }}ReducerTests: XCTestCase {
{% if isForm %}
    func testFieldChangesUpdateOnlyTheirField() {
        let sut = {{ name }}Reducer()
        var state = {{ name }}State()

        sut.reduce(state: &state, intent: .field1Changed("First value"))
        XCTAssertEqual(state.field1, "First value")
        XCTAssertEqual(state.field2, "")

        sut.reduce(state: &state, intent: .field2Changed("Second value"))
        XCTAssertEqual(state.field1, "First value")
        XCTAssertEqual(state.field2, "Second value")
    }
{% else %}
    func testOnAppearResetsLoadingState() {
        let sut = {{ name }}Reducer()
        var state = {{ name }}State()
        state.isLoading = true
{% if isClean %}
        state.errorMessage = "Previous error"
{% else %}
{% if isList %}
{% else %}
        state.errorMessage = "Previous error"
{% endif %}
{% endif %}

        sut.reduce(state: &state, intent: .onAppear)

{% if isClean %}
        XCTAssertTrue(state.isLoading)
        XCTAssertNil(state.errorMessage)
{% else %}
        XCTAssertFalse(state.isLoading)
{% if isList %}
{% else %}
        XCTAssertNil(state.errorMessage)
{% endif %}
{% endif %}
    }
{% endif %}
{% if isClean %}

    func testDidLoadStoresValueAndFinishesLoading() {
        let sut = {{ name }}Reducer()
        var state = {{ name }}State()
        state.isLoading = true
{% if hasNoDomain %}
        let value = {{ name }}Response(id: UUID(), title: "Loaded value")
{% else %}
        let value = {{ name }}Entity(id: UUID(), title: "Loaded value")
{% endif %}

        sut.reduce(state: &state, intent: .didLoad(value))

{% if hasNoDomain %}
        XCTAssertEqual(state.response, value)
{% else %}
        XCTAssertEqual(state.entity, value)
{% endif %}
        XCTAssertEqual(state.title, "Loaded value")
        XCTAssertFalse(state.isLoading)
{% if isList %}
        XCTAssertEqual(state.items.count, 1)
        XCTAssertEqual(state.items.first?.id, value.id)
        XCTAssertEqual(state.items.first?.title, value.title)
{% endif %}
    }

    func testDidFailRecordsErrorAndFinishesLoading() {
        let sut = {{ name }}Reducer()
        var state = {{ name }}State()
        state.isLoading = true

        sut.reduce(state: &state, intent: .didFail("Request failed"))

        XCTAssertEqual(state.errorMessage, "Request failed")
        XCTAssertFalse(state.isLoading)
    }
{% else %}
{% if isList %}

    func testDidLoadReplacesItemsAndFinishesLoading() {
        let sut = {{ name }}Reducer()
        var state = {{ name }}State()
        state.items = [{{ name }}Item(id: UUID(), title: "Old item")]
        state.isLoading = true
        let item = {{ name }}Item(id: UUID(), title: "New item")

        sut.reduce(state: &state, intent: .didLoad([item]))

        XCTAssertEqual(state.items, [item])
        XCTAssertFalse(state.isLoading)
    }
{% endif %}
{% endif %}
}

""",

        "presenterTests.stencil": """
import XCTest
@testable import {{ moduleName }}

final class {{ name }}PresenterTests: XCTestCase {
    @MainActor
{% if isVIP %}
    func testPresentMapsTitleToViewModel() {
        let sut = {{ name }}DependencyContainer.makePresenter()
{% if isClean %}
{% if hasNoDomain %}
        let response = {{ name }}Response(id: UUID(), title: "Presented title")
        let viewModel = sut.present(response: response)
{% else %}
        let entity = {{ name }}Entity(id: UUID(), title: "Presented title")
        let viewModel = sut.present(entity: entity)
{% endif %}
{% else %}
        let response = {{ name }}.Response(title: "Presented title")
        let viewModel = sut.present(response: response)
{% endif %}

        XCTAssertEqual(viewModel.title, "Presented title")
    }
{% else %}
{% if isForm %}
    func testFormFieldsCanBeEdited() {
        let sut = {{ name }}DependencyContainer.makePresenter()

        sut.field1 = "First value"
        sut.field2 = "Second value"

        XCTAssertEqual(sut.field1, "First value")
        XCTAssertEqual(sut.field2, "Second value")
    }
{% else %}
{% if isList %}
{% if isMVP %}
{% if isClean %}
    func testLoadPopulatesItems() async {
        let sut = {{ name }}DependencyContainer.makePresenter()
        XCTAssertTrue(sut.items.isEmpty)

        await sut.load()

        XCTAssertEqual(sut.items.count, 1)
        XCTAssertEqual(sut.items.first?.title, "{{ name }}")
    }
{% else %}
    func testListStartsEmpty() {
        let sut = {{ name }}DependencyContainer.makePresenter()
        XCTAssertTrue(sut.items.isEmpty)
    }
{% endif %}
{% else %}
    func testListStartsEmpty() {
        let sut = {{ name }}DependencyContainer.makePresenter()
        XCTAssertTrue(sut.items.isEmpty)
    }
{% endif %}
{% else %}
{% if isMVP %}
{% if isClean %}
    func testLoadUsesRepositoryTitle() async {
        let sut = {{ name }}DependencyContainer.makePresenter()

        await sut.load()

        XCTAssertEqual(sut.title, "{{ name }}")
    }
{% else %}
    func testLoadUsesModelTitle() async {
        let sut = {{ name }}Presenter(model: {{ name }}Model(title: "Model title"))

        await sut.load()

        XCTAssertEqual(sut.title, "Model title")
    }
{% endif %}
{% else %}
    func testViewDidLoadUsesInteractorTitle() async {
        let sut = {{ name }}DependencyContainer.makePresenter()

        await sut.viewDidLoad()

        XCTAssertEqual(sut.title, "{{ name }}")
    }
{% endif %}
{% endif %}
{% endif %}
{% endif %}
}

""",

        "interactorTests.stencil": """
import XCTest
@testable import {{ moduleName }}

final class {{ name }}InteractorTests: XCTestCase {
    @MainActor
{% if isVIP %}
{% if isForm %}
    func testFormFieldsCanBeEdited() {
        let sut = {{ name }}DependencyContainer.makeInteractor()

        sut.field1 = "First value"
        sut.field2 = "Second value"

        XCTAssertEqual(sut.field1, "First value")
        XCTAssertEqual(sut.field2, "Second value")
    }
{% else %}
    func testLoadUpdatesViewModel() async {
        let sut = {{ name }}DependencyContainer.makeInteractor()

        await sut.load()

        XCTAssertEqual(sut.viewModel.title, "{{ name }}")
{% if isList %}
        XCTAssertEqual(sut.items.count, 1)
        XCTAssertEqual(sut.items.first?.title, "{{ name }}")
{% endif %}
    }
{% endif %}
{% else %}
    func testLoadReturnsFeatureData() async {
        let sut = {{ name }}DependencyContainer.makeInteractor()

        let value = await sut.load()

        XCTAssertEqual(value.title, "{{ name }}")
    }
{% endif %}
}

""",

        "featureTests.stencil": """
import ComposableArchitecture
import XCTest
@testable import {{ moduleName }}

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
@testable import {{ moduleName }}

final class {{ name }}UseCaseTests: XCTestCase {
    func testExecuteReturnsRepositoryValue() async throws {
        let expected = {{ name }}Entity(id: UUID(), title: "Repository value")
        let repository = {{ name }}UseCaseRepositoryStub(result: .success(expected))
        let sut = {{ name }}UseCase(repository: repository)

        let entity = try await sut.execute()

        XCTAssertEqual(entity, expected)
        XCTAssertEqual(repository.fetchCount, 1)
    }

    func testExecutePropagatesRepositoryError() async {
        let repository = {{ name }}UseCaseRepositoryStub(result: .failure(.unavailable))
        let sut = {{ name }}UseCase(repository: repository)

        do {
            _ = try await sut.execute()
            XCTFail("Expected the repository error to be thrown")
        } catch {
            XCTAssertEqual(error as? {{ name }}UseCaseRepositoryStub.Failure, .unavailable)
        }
        XCTAssertEqual(repository.fetchCount, 1)
    }
}

private final class {{ name }}UseCaseRepositoryStub: {{ name }}Repository {
    enum Failure: Error, Equatable {
        case unavailable
    }

    private let result: Result<{{ name }}Entity, Failure>
    private(set) var fetchCount = 0

    init(result: Result<{{ name }}Entity, Failure>) {
        self.result = result
    }

    func fetch{{ name }}() async throws -> {{ name }}Entity {
        fetchCount += 1
        return try result.get()
    }
}

""",

        "repositoryTests.stencil": """
import XCTest
@testable import {{ moduleName }}

final class {{ name }}RepositoryTests: XCTestCase {
    func testFetchReturnsDataSourceTitle() async throws {
        let dataSource = {{ name }}RemoteDataSource()
        let sut = {{ name }}RepositoryImpl(remoteDataSource: dataSource)

        let value = try await sut.fetch{{ name }}()

        XCTAssertEqual(value.title, "{{ name }}")
    }
}

""",
    ]
}
