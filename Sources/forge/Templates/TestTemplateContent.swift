/// XCTest templates matched to the selected architecture and feature category.
enum TestTemplateContent {
    static let files: [String: String] = [
        "viewModelTests.stencil": """
{% if isForm %}
{% if isSwiftTesting %}
import Foundation
import Testing
@testable import {{ moduleName }}

@Suite struct {{ name }}ViewModelTests {
    @Test @MainActor
    func liveViewCanBeConstructed() {
        _ = {{ name }}DependencyContainer.makeView()
    }

    @Test @MainActor
    func SubmissionPassesFieldsAndCanRetry() async {
        var calls = 0
        var received: [String] = []
        let sut = {{ name }}ViewModel(submitAction: { first, second in
            calls += 1
            received = [first, second]
            if calls == 1 { throw URLError(.notConnectedToInternet) }
        })
        sut.field1 = "First"
        sut.field2 = "Second"
        await sut.submit()
        #expect(sut.errorMessage != nil)
        await sut.submit()
        #expect(sut.didSubmit && sut.errorMessage == nil)
        {% if isSwiftTesting %}#expect(received == ["First", "Second"] && calls == 2){% else %}XCTAssertTrue(received == ["First", "Second"] && calls == 2){% endif %}
        #expect(!sut.isSubmitting)
    }
    @Test @MainActor
    func CancellationIsNotFailure() async {
        let sut = {{ name }}ViewModel(submitAction: { _, _ in throw CancellationError() })
        await sut.submit()
        #expect(sut.errorMessage == nil && !sut.didSubmit && !sut.isSubmitting)
    }
    @Test @MainActor
    func DuplicateSubmissionIsIgnored() async {
        var calls = 0
        var resume: CheckedContinuation<Void, Never>?
        let sut = {{ name }}ViewModel(submitAction: { _, _ in
            calls += 1
            await withCheckedContinuation { resume = $0 }
        })
        let first = Task { await sut.submit() }
        while resume == nil { await Task.yield() }
        await sut.submit()
        #expect(calls == 1)
        resume?.resume()
        await first.value
        #expect(sut.didSubmit && !sut.isSubmitting)
    }
}
{% else %}
import Foundation
import XCTest
@testable import {{ moduleName }}

final class {{ name }}ViewModelTests: XCTestCase {
    @MainActor
    func testLiveViewCanBeConstructed() {
        _ = {{ name }}DependencyContainer.makeView()
    }

    @MainActor
    func testSubmissionPassesFieldsAndCanRetry() async {
        var calls = 0
        var received: [String] = []
        let sut = {{ name }}ViewModel(submitAction: { first, second in
            calls += 1
            received = [first, second]
            if calls == 1 { throw URLError(.notConnectedToInternet) }
        })
        sut.field1 = "First"
        sut.field2 = "Second"
        await sut.submit()
        XCTAssertTrue(sut.errorMessage != nil)
        await sut.submit()
        XCTAssertTrue(sut.didSubmit && sut.errorMessage == nil)
        {% if isSwiftTesting %}#expect(received == ["First", "Second"] && calls == 2){% else %}XCTAssertTrue(received == ["First", "Second"] && calls == 2){% endif %}
        XCTAssertTrue(!sut.isSubmitting)
    }
    @MainActor
    func testCancellationIsNotFailure() async {
        let sut = {{ name }}ViewModel(submitAction: { _, _ in throw CancellationError() })
        await sut.submit()
        XCTAssertTrue(sut.errorMessage == nil && !sut.didSubmit && !sut.isSubmitting)
    }
    @MainActor
    func testDuplicateSubmissionIsIgnored() async {
        var calls = 0
        var resume: CheckedContinuation<Void, Never>?
        let sut = {{ name }}ViewModel(submitAction: { _, _ in
            calls += 1
            await withCheckedContinuation { resume = $0 }
        })
        let first = Task { await sut.submit() }
        while resume == nil { await Task.yield() }
        await sut.submit()
        XCTAssertTrue(calls == 1)
        resume?.resume()
        await first.value
        XCTAssertTrue(sut.didSubmit && !sut.isSubmitting)
    }
}
{% endif %}
{% else %}
{% if isList %}
{% if isSwiftTesting %}
import Foundation
import Testing
@testable import {{ moduleName }}

@Suite struct {{ name }}ViewModelTests {
    @Test @MainActor
    func liveViewCanBeConstructed() {
        _ = {{ name }}DependencyContainer.makeView()
    }

    @Test @MainActor
    func LoadFailureThenRetryPreservesIdentity() async {
        let id = UUID()
        var calls = 0
        let sut = {{ name }}ViewModel(loadItems: {
            calls += 1
            if calls == 1 { throw URLError(.notConnectedToInternet) }
            return [{{ name }}Item(id: id, title: "Loaded")]
        })
        await sut.load()
        #expect(sut.errorMessage != nil && !sut.isLoading)
        await sut.load()
        #expect(sut.items.first?.id == id && calls == 2)
        #expect(sut.errorMessage == nil && !sut.isLoading)
    }
    @Test @MainActor
    func CancellationIsNotFailure() async {
        let sut = {{ name }}ViewModel(loadItems: { throw CancellationError() })
        await sut.load()
        #expect(sut.errorMessage == nil && !sut.isLoading && sut.items.isEmpty)
    }
    @Test @MainActor
    func CancelledTaskDoesNotPublishLateResults() async {
        let id = UUID()
        var resume: CheckedContinuation<Void, Never>?
        let sut = {{ name }}ViewModel(loadItems: {
            await withCheckedContinuation { resume = $0 }
            return [{{ name }}Item(id: id, title: "Loaded")]
        })
        let request = Task { await sut.load() }
        while resume == nil { await Task.yield() }
        request.cancel()
        resume?.resume()
        await request.value
        #expect(sut.items.isEmpty && sut.errorMessage == nil && !sut.isLoading)
    }
}
{% else %}
import Foundation
import XCTest
@testable import {{ moduleName }}

final class {{ name }}ViewModelTests: XCTestCase {
    @MainActor
    func testLiveViewCanBeConstructed() {
        _ = {{ name }}DependencyContainer.makeView()
    }

    @MainActor
    func testLoadFailureThenRetryPreservesIdentity() async {
        let id = UUID()
        var calls = 0
        let sut = {{ name }}ViewModel(loadItems: {
            calls += 1
            if calls == 1 { throw URLError(.notConnectedToInternet) }
            return [{{ name }}Item(id: id, title: "Loaded")]
        })
        await sut.load()
        XCTAssertTrue(sut.errorMessage != nil && !sut.isLoading)
        await sut.load()
        XCTAssertTrue(sut.items.first?.id == id && calls == 2)
        XCTAssertTrue(sut.errorMessage == nil && !sut.isLoading)
    }
    @MainActor
    func testCancellationIsNotFailure() async {
        let sut = {{ name }}ViewModel(loadItems: { throw CancellationError() })
        await sut.load()
        XCTAssertTrue(sut.errorMessage == nil && !sut.isLoading && sut.items.isEmpty)
    }
    @MainActor
    func testCancelledTaskDoesNotPublishLateResults() async {
        let id = UUID()
        var resume: CheckedContinuation<Void, Never>?
        let sut = {{ name }}ViewModel(loadItems: {
            await withCheckedContinuation { resume = $0 }
            return [{{ name }}Item(id: id, title: "Loaded")]
        })
        let request = Task { await sut.load() }
        while resume == nil { await Task.yield() }
        request.cancel()
        resume?.resume()
        await request.value
        XCTAssertTrue(sut.items.isEmpty && sut.errorMessage == nil && !sut.isLoading)
    }
}
{% endif %}
{% else %}
{% if isSwiftTesting %}
import Foundation
import Testing
@testable import {{ moduleName }}

@Suite struct {{ name }}ViewModelTests {
    @Test @MainActor
    func liveViewCanBeConstructed() {
        _ = {{ name }}DependencyContainer.makeView()
    }

    @Test @MainActor
{% if isForm %}
    func formFieldsCanBeEdited() {
        let sut = {{ name }}Preview.makeViewModel()

        sut.field1 = "First value"
        sut.field2 = "Second value"

        #expect(sut.field1 == "First value")
        #expect(sut.field2 == "Second value")
    }
{% else %}
{% if isList %}
    func listStartsEmpty() {
        let sut = {{ name }}Preview.makeViewModel()
        #expect(sut.items.isEmpty)
    }
{% else %}
    func loadFinishesWithoutAnError() async throws {
        let sut = {{ name }}Preview.makeViewModel()
{% if isClean %}
{% if hasNoDomain %}
        #expect(sut.response == nil)
{% else %}
        #expect(sut.entity == nil)
{% endif %}
{% endif %}

        await sut.load()

{% if isClean %}
{% if hasNoDomain %}
        #expect(sut.response?.title == "{{ name }}")
{% else %}
        #expect(sut.entity?.title == "{{ name }}")
{% endif %}
{% else %}
        #expect(sut.title == "{{ name }}")
{% endif %}
        #expect(!sut.isLoading)
        #expect(sut.errorMessage == nil)
    }
{% endif %}
{% endif %}
}
{% else %}
import XCTest
@testable import {{ moduleName }}

final class {{ name }}ViewModelTests: XCTestCase {
    @MainActor
    func testLiveViewCanBeConstructed() {
        _ = {{ name }}DependencyContainer.makeView()
    }

    @MainActor
{% if isForm %}
    func testFormFieldsCanBeEdited() {
        let sut = {{ name }}Preview.makeViewModel()

        sut.field1 = "First value"
        sut.field2 = "Second value"

        XCTAssertEqual(sut.field1, "First value")
        XCTAssertEqual(sut.field2, "Second value")
    }
{% else %}
{% if isList %}
    func testListStartsEmpty() {
        let sut = {{ name }}Preview.makeViewModel()
        XCTAssertTrue(sut.items.isEmpty)
    }
{% else %}
    func testLoadFinishesWithoutAnError() async throws {
        let sut = {{ name }}Preview.makeViewModel()
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
{% endif %}

{% endif %}
{% endif %}
""",

        "storeTests.stencil": """
{% if isForm %}
{% if isSwiftTesting %}
import Foundation
import Testing
@testable import {{ moduleName }}

@Suite struct {{ name }}StoreTests {
    @Test @MainActor
    func liveViewCanBeConstructed() {
        _ = {{ name }}DependencyContainer.makeView()
    }

    @Test @MainActor
    func SubmissionPassesFieldsAndCanRetry() async {
        var calls = 0
        var received: [String] = []
        let sut = {{ name }}Store({% if isClean %}loadValue: { throw URLError(.unsupportedURL) }, {% endif %}submitAction: { first, second in
            calls += 1
            received = [first, second]
            if calls == 1 { throw URLError(.notConnectedToInternet) }
        })
        sut.updateField1("First")
        sut.updateField2("Second")
        await sut.send(.submit)
        #expect(sut.state.errorMessage != nil)
        await sut.send(.submit)
        #expect(sut.state.didSubmit && sut.state.errorMessage == nil)
        {% if isSwiftTesting %}#expect(received == ["First", "Second"] && calls == 2){% else %}XCTAssertTrue(received == ["First", "Second"] && calls == 2){% endif %}
        #expect(!sut.state.isSubmitting)
    }
    @Test @MainActor
    func CancellationIsNotFailure() async {
        let sut = {{ name }}Store({% if isClean %}loadValue: { throw URLError(.unsupportedURL) }, {% endif %}submitAction: { _, _ in throw CancellationError() })
        await sut.send(.submit)
        #expect(sut.state.errorMessage == nil && !sut.state.didSubmit && !sut.state.isSubmitting)
    }
    @Test @MainActor
    func DuplicateSubmissionIsIgnored() async {
        var calls = 0
        var resume: CheckedContinuation<Void, Never>?
        let sut = {{ name }}Store({% if isClean %}loadValue: { throw URLError(.unsupportedURL) }, {% endif %}submitAction: { _, _ in
            calls += 1
            await withCheckedContinuation { resume = $0 }
        })
        let first = Task { await sut.send(.submit) }
        while resume == nil { await Task.yield() }
        await sut.send(.submit)
        #expect(calls == 1)
        resume?.resume()
        await first.value
        #expect(sut.state.didSubmit && !sut.state.isSubmitting)
    }
}
{% else %}
import Foundation
import XCTest
@testable import {{ moduleName }}

final class {{ name }}StoreTests: XCTestCase {
    @MainActor
    func testLiveViewCanBeConstructed() {
        _ = {{ name }}DependencyContainer.makeView()
    }

    @MainActor
    func testSubmissionPassesFieldsAndCanRetry() async {
        var calls = 0
        var received: [String] = []
        let sut = {{ name }}Store({% if isClean %}loadValue: { throw URLError(.unsupportedURL) }, {% endif %}submitAction: { first, second in
            calls += 1
            received = [first, second]
            if calls == 1 { throw URLError(.notConnectedToInternet) }
        })
        sut.updateField1("First")
        sut.updateField2("Second")
        await sut.send(.submit)
        XCTAssertTrue(sut.state.errorMessage != nil)
        await sut.send(.submit)
        XCTAssertTrue(sut.state.didSubmit && sut.state.errorMessage == nil)
        {% if isSwiftTesting %}#expect(received == ["First", "Second"] && calls == 2){% else %}XCTAssertTrue(received == ["First", "Second"] && calls == 2){% endif %}
        XCTAssertTrue(!sut.state.isSubmitting)
    }
    @MainActor
    func testCancellationIsNotFailure() async {
        let sut = {{ name }}Store({% if isClean %}loadValue: { throw URLError(.unsupportedURL) }, {% endif %}submitAction: { _, _ in throw CancellationError() })
        await sut.send(.submit)
        XCTAssertTrue(sut.state.errorMessage == nil && !sut.state.didSubmit && !sut.state.isSubmitting)
    }
    @MainActor
    func testDuplicateSubmissionIsIgnored() async {
        var calls = 0
        var resume: CheckedContinuation<Void, Never>?
        let sut = {{ name }}Store({% if isClean %}loadValue: { throw URLError(.unsupportedURL) }, {% endif %}submitAction: { _, _ in
            calls += 1
            await withCheckedContinuation { resume = $0 }
        })
        let first = Task { await sut.send(.submit) }
        while resume == nil { await Task.yield() }
        await sut.send(.submit)
        XCTAssertTrue(calls == 1)
        resume?.resume()
        await first.value
        XCTAssertTrue(sut.state.didSubmit && !sut.state.isSubmitting)
    }
}
{% endif %}
{% else %}
{% if isList %}
{% if isSwiftTesting %}
import Foundation
import Testing
@testable import {{ moduleName }}

@Suite struct {{ name }}StoreTests {
    @Test @MainActor
    func liveViewCanBeConstructed() {
        _ = {{ name }}DependencyContainer.makeView()
    }

    @Test @MainActor
    func LoadFailureThenRetryPreservesIdentity() async {
        let id = UUID()
        var calls = 0
        let sut = {{ name }}Store(loadValue: {
            calls += 1
            if calls == 1 { throw URLError(.notConnectedToInternet) }
            return {% if isClean %}{% if hasNoDomain %}{{ name }}Response{% else %}{{ name }}Entity{% endif %}(id: id, title: "Loaded"){% else %}[{{ name }}Item(id: id, title: "Loaded")]{% endif %}
        })
        await sut.send(.onAppear)
        #expect(sut.state.errorMessage != nil && !sut.state.isLoading)
        await sut.send(.onAppear)
        #expect(sut.state.items.first?.id == id && calls == 2)
        #expect(sut.state.errorMessage == nil && !sut.state.isLoading)
    }
    @Test @MainActor
    func CancellationIsNotFailure() async {
        let sut = {{ name }}Store(loadValue: { throw CancellationError() })
        await sut.send(.onAppear)
        #expect(sut.state.errorMessage == nil && !sut.state.isLoading && sut.state.items.isEmpty)
    }
    @Test @MainActor
    func CancelledTaskDoesNotPublishLateResults() async {
        let id = UUID()
        var resume: CheckedContinuation<Void, Never>?
        let sut = {{ name }}Store(loadValue: {
            await withCheckedContinuation { resume = $0 }
            return {% if isClean %}{% if hasNoDomain %}{{ name }}Response{% else %}{{ name }}Entity{% endif %}(id: id, title: "Loaded"){% else %}[{{ name }}Item(id: id, title: "Loaded")]{% endif %}
        })
        let request = Task { await sut.send(.onAppear) }
        while resume == nil { await Task.yield() }
        request.cancel()
        resume?.resume()
        await request.value
        #expect(sut.state.items.isEmpty && sut.state.errorMessage == nil && !sut.state.isLoading)
    }
}
{% else %}
import Foundation
import XCTest
@testable import {{ moduleName }}

final class {{ name }}StoreTests: XCTestCase {
    @MainActor
    func testLiveViewCanBeConstructed() {
        _ = {{ name }}DependencyContainer.makeView()
    }

    @MainActor
    func testLoadFailureThenRetryPreservesIdentity() async {
        let id = UUID()
        var calls = 0
        let sut = {{ name }}Store(loadValue: {
            calls += 1
            if calls == 1 { throw URLError(.notConnectedToInternet) }
            return {% if isClean %}{% if hasNoDomain %}{{ name }}Response{% else %}{{ name }}Entity{% endif %}(id: id, title: "Loaded"){% else %}[{{ name }}Item(id: id, title: "Loaded")]{% endif %}
        })
        await sut.send(.onAppear)
        XCTAssertTrue(sut.state.errorMessage != nil && !sut.state.isLoading)
        await sut.send(.onAppear)
        XCTAssertTrue(sut.state.items.first?.id == id && calls == 2)
        XCTAssertTrue(sut.state.errorMessage == nil && !sut.state.isLoading)
    }
    @MainActor
    func testCancellationIsNotFailure() async {
        let sut = {{ name }}Store(loadValue: { throw CancellationError() })
        await sut.send(.onAppear)
        XCTAssertTrue(sut.state.errorMessage == nil && !sut.state.isLoading && sut.state.items.isEmpty)
    }
    @MainActor
    func testCancelledTaskDoesNotPublishLateResults() async {
        let id = UUID()
        var resume: CheckedContinuation<Void, Never>?
        let sut = {{ name }}Store(loadValue: {
            await withCheckedContinuation { resume = $0 }
            return {% if isClean %}{% if hasNoDomain %}{{ name }}Response{% else %}{{ name }}Entity{% endif %}(id: id, title: "Loaded"){% else %}[{{ name }}Item(id: id, title: "Loaded")]{% endif %}
        })
        let request = Task { await sut.send(.onAppear) }
        while resume == nil { await Task.yield() }
        request.cancel()
        resume?.resume()
        await request.value
        XCTAssertTrue(sut.state.items.isEmpty && sut.state.errorMessage == nil && !sut.state.isLoading)
    }
}
{% endif %}
{% else %}
{% if isSwiftTesting %}
import Foundation
import Testing
@testable import {{ moduleName }}

@Suite struct {{ name }}StoreTests {
    @Test @MainActor
    func liveViewCanBeConstructed() {
        _ = {{ name }}DependencyContainer.makeView()
    }

    @Test @MainActor
{% if isForm %}
    func fieldUpdatesReachState() {
        let sut = {{ name }}Preview.makeStore()

        sut.updateField1("First value")
        sut.updateField2("Second value")

        #expect(sut.state.field1 == "First value")
        #expect(sut.state.field2 == "Second value")
    }
{% else %}
{% if isList %}
{% if isClean %}
    func onAppearLoadsItems() async throws {
        let sut = {{ name }}Preview.makeStore()
        #expect(sut.state.items.isEmpty)

        await sut.send(.onAppear)

        #expect(sut.state.items.count == 1)
        #expect(sut.state.items.first?.title == "{{ name }}")
        #expect(!sut.state.isLoading)
        #expect(sut.state.errorMessage == nil)
    }
{% else %}
    func didLoadReplacesItems() async throws {
        let sut = {{ name }}Preview.makeStore()
        let item = {{ name }}Item(id: UUID(), title: "Loaded item")

        await sut.send(.didLoad([item]))

        #expect(sut.state.items == [item])
        #expect(!sut.state.isLoading)
    }
{% endif %}
{% else %}
    func onAppearFinishesLoading() async throws {
        let sut = {{ name }}Preview.makeStore()

        await sut.send(.onAppear)

        #expect(sut.state.title == "{{ name }}")
        #expect(!sut.state.isLoading)
        #expect(sut.state.errorMessage == nil)
{% if isClean %}
{% if hasNoDomain %}
        #expect(sut.state.response?.title == "{{ name }}")
{% else %}
        #expect(sut.state.entity?.title == "{{ name }}")
{% endif %}
{% endif %}
    }
{% endif %}
{% endif %}
}
{% else %}
import XCTest
@testable import {{ moduleName }}

final class {{ name }}StoreTests: XCTestCase {
    @MainActor
    func testLiveViewCanBeConstructed() {
        _ = {{ name }}DependencyContainer.makeView()
    }

    @MainActor
{% if isForm %}
    func testFieldUpdatesReachState() {
        let sut = {{ name }}Preview.makeStore()

        sut.updateField1("First value")
        sut.updateField2("Second value")

        XCTAssertEqual(sut.state.field1, "First value")
        XCTAssertEqual(sut.state.field2, "Second value")
    }
{% else %}
{% if isList %}
{% if isClean %}
    func testOnAppearLoadsItems() async throws {
        let sut = {{ name }}Preview.makeStore()
        XCTAssertTrue(sut.state.items.isEmpty)

        await sut.send(.onAppear)

        XCTAssertEqual(sut.state.items.count, 1)
        XCTAssertEqual(sut.state.items.first?.title, "{{ name }}")
        XCTAssertFalse(sut.state.isLoading)
        XCTAssertNil(sut.state.errorMessage)
    }
{% else %}
    func testDidLoadReplacesItems() async throws {
        let sut = {{ name }}Preview.makeStore()
        let item = {{ name }}Item(id: UUID(), title: "Loaded item")

        await sut.send(.didLoad([item]))

        XCTAssertEqual(sut.state.items, [item])
        XCTAssertFalse(sut.state.isLoading)
    }
{% endif %}
{% else %}
    func testOnAppearFinishesLoading() async throws {
        let sut = {{ name }}Preview.makeStore()

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
{% endif %}

{% endif %}
{% endif %}
""",

        "reducerTests.stencil": """
{% if isSwiftTesting %}
import Foundation
import Testing
@testable import {{ moduleName }}

@Suite struct {{ name }}ReducerTests {
{% if isForm %}
    @Test func fieldChangesUpdateOnlyTheirField() {
        let sut = {{ name }}Reducer()
        var state = {{ name }}State()

        sut.reduce(state: &state, intent: .field1Changed("First value"))
        #expect(state.field1 == "First value")
        #expect(state.field2 == "")

        sut.reduce(state: &state, intent: .field2Changed("Second value"))
        #expect(state.field1 == "First value")
        #expect(state.field2 == "Second value")
    }
{% else %}
    @Test func onAppearResetsLoadingState() {
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
        #expect(state.isLoading)
        #expect(state.errorMessage == nil)
{% else %}
{% if isList %}
        #expect(state.isLoading)
{% else %}
        #expect(!state.isLoading)
{% endif %}
{% if isList %}
{% else %}
        #expect(state.errorMessage == nil)
{% endif %}
{% endif %}
    }
{% endif %}
{% if isClean %}

    @Test func didLoadStoresValueAndFinishesLoading() {
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
        #expect(state.response == value)
{% else %}
        #expect(state.entity == value)
{% endif %}
        #expect(state.title == "Loaded value")
        #expect(!state.isLoading)
{% if isList %}
        #expect(state.items.count == 1)
        #expect(state.items.first?.id == value.id)
        #expect(state.items.first?.title == value.title)
{% endif %}
    }

    @Test func didFailRecordsErrorAndFinishesLoading() {
        let sut = {{ name }}Reducer()
        var state = {{ name }}State()
        state.isLoading = true

        sut.reduce(state: &state, intent: .didFail("Request failed"))

        #expect(state.errorMessage == "Request failed")
        #expect(!state.isLoading)
    }
{% else %}
{% if isList %}

    @Test func didLoadReplacesItemsAndFinishesLoading() {
        let sut = {{ name }}Reducer()
        var state = {{ name }}State()
        state.items = [{{ name }}Item(id: UUID(), title: "Old item")]
        state.isLoading = true
        let item = {{ name }}Item(id: UUID(), title: "New item")

        sut.reduce(state: &state, intent: .didLoad([item]))

        #expect(state.items == [item])
        #expect(!state.isLoading)
    }
{% endif %}
{% endif %}
}
{% else %}
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
{% if isList %}
        XCTAssertTrue(state.isLoading)
{% else %}
        XCTAssertFalse(state.isLoading)
{% endif %}
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
{% endif %}

""",

        "presenterTests.stencil": """
{% if isSwiftTesting %}
import Foundation
import Testing
@testable import {{ moduleName }}

@Suite struct {{ name }}PresenterTests {
    @Test @MainActor
{% if isVIP %}
    func presentMapsTitleToViewModel() {
        let sut = {{ name }}Preview.makePresenter()
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

        #expect(viewModel.title == "Presented title")
    }
{% else %}
{% if isForm %}
    func formFieldsCanBeEdited() {
        let sut = {{ name }}Preview.makePresenter()

        sut.field1 = "First value"
        sut.field2 = "Second value"

        #expect(sut.field1 == "First value")
        #expect(sut.field2 == "Second value")
    }
{% else %}
{% if isList %}
{% if isMVP %}
{% if isClean %}
    func loadPopulatesItems() async throws {
        let sut = {{ name }}Preview.makePresenter()
        #expect(sut.items.isEmpty)

        await sut.load()

        #expect(sut.items.count == 1)
        #expect(sut.items.first?.title == "{{ name }}")
    }
{% else %}
    func listStartsEmpty() {
        let sut = {{ name }}Preview.makePresenter()
        #expect(sut.items.isEmpty)
    }
{% endif %}
{% else %}
    func listStartsEmpty() {
        let sut = {{ name }}Preview.makePresenter()
        #expect(sut.items.isEmpty)
    }
{% endif %}
{% else %}
{% if isMVP %}
{% if isClean %}
    func loadUsesRepositoryTitle() async throws {
        let sut = {{ name }}Preview.makePresenter()

        await sut.load()

        #expect(sut.title == "{{ name }}")
    }
{% else %}
    func loadUsesModelTitle() async throws {
        let sut = {{ name }}Presenter(model: {{ name }}Model(title: "Model title"))

        await sut.load()

        #expect(sut.title == "Model title")
    }
{% endif %}
{% else %}
    func viewDidLoadUsesInteractorTitle() async throws {
        let sut = {{ name }}Preview.makePresenter()

        await sut.viewDidLoad()

        #expect(sut.title == "{{ name }}")
    }
{% endif %}
{% endif %}
{% endif %}
{% endif %}
}
{% else %}
import XCTest
@testable import {{ moduleName }}

final class {{ name }}PresenterTests: XCTestCase {
    @MainActor
{% if isVIP %}
    func testPresentMapsTitleToViewModel() {
        let sut = {{ name }}Preview.makePresenter()
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
        let sut = {{ name }}Preview.makePresenter()

        sut.field1 = "First value"
        sut.field2 = "Second value"

        XCTAssertEqual(sut.field1, "First value")
        XCTAssertEqual(sut.field2, "Second value")
    }
{% else %}
{% if isList %}
{% if isMVP %}
{% if isClean %}
    func testLoadPopulatesItems() async throws {
        let sut = {{ name }}Preview.makePresenter()
        XCTAssertTrue(sut.items.isEmpty)

        await sut.load()

        XCTAssertEqual(sut.items.count, 1)
        XCTAssertEqual(sut.items.first?.title, "{{ name }}")
    }
{% else %}
    func testListStartsEmpty() {
        let sut = {{ name }}Preview.makePresenter()
        XCTAssertTrue(sut.items.isEmpty)
    }
{% endif %}
{% else %}
    func testListStartsEmpty() {
        let sut = {{ name }}Preview.makePresenter()
        XCTAssertTrue(sut.items.isEmpty)
    }
{% endif %}
{% else %}
{% if isMVP %}
{% if isClean %}
    func testLoadUsesRepositoryTitle() async throws {
        let sut = {{ name }}Preview.makePresenter()

        await sut.load()

        XCTAssertEqual(sut.title, "{{ name }}")
    }
{% else %}
    func testLoadUsesModelTitle() async throws {
        let sut = {{ name }}Presenter(model: {{ name }}Model(title: "Model title"))

        await sut.load()

        XCTAssertEqual(sut.title, "Model title")
    }
{% endif %}
{% else %}
    func testViewDidLoadUsesInteractorTitle() async throws {
        let sut = {{ name }}Preview.makePresenter()

        await sut.viewDidLoad()

        XCTAssertEqual(sut.title, "{{ name }}")
    }
{% endif %}
{% endif %}
{% endif %}
{% endif %}
}
{% endif %}

""",

        "interactorTests.stencil": """
{% if isSwiftTesting %}
import Foundation
import Testing
@testable import {{ moduleName }}

@Suite struct {{ name }}InteractorTests {
{% if isVIPER %}
{% if isClean %}
    @Test @MainActor
    func loadPropagatesFailure() async throws {
        let source = {{ name }}RemoteDataSource(fetch: { throw URLError(.notConnectedToInternet) })
        let repository = {{ name }}RepositoryImpl(remoteDataSource: source)
{% if hasNoDomain %}
        let sut = {{ name }}Interactor(repository: repository)
{% else %}
        let sut = {{ name }}Interactor(useCase: {{ name }}UseCase(repository: repository))
{% endif %}
        do {
            _ = try await sut.load()
            Issue.record("Expected loading failure")
        } catch let error as URLError {
            #expect(error.code == .notConnectedToInternet)
        }
    }
{% endif %}
{% endif %}

    @Test @MainActor
{% if isVIP %}
{% if isForm %}
    func formFieldsCanBeEdited() {
        let sut = {{ name }}Preview.makeInteractor()

        sut.field1 = "First value"
        sut.field2 = "Second value"

        #expect(sut.field1 == "First value")
        #expect(sut.field2 == "Second value")
    }
{% else %}
    func loadUpdatesViewModel() async throws {
        let sut = {{ name }}Preview.makeInteractor()

        await sut.load()

        #expect(sut.viewModel.title == "{{ name }}")
{% if isList %}
        #expect(sut.items.count == 1)
        #expect(sut.items.first?.title == "{{ name }}")
{% endif %}
    }
{% endif %}
{% else %}
    func loadReturnsFeatureData() async throws {
        let sut = {{ name }}Preview.makeInteractor()

        let value = try await sut.load()

        #expect(value.title == "{{ name }}")
    }
{% endif %}
}
{% else %}
import XCTest
@testable import {{ moduleName }}

final class {{ name }}InteractorTests: XCTestCase {
{% if isVIPER %}
{% if isClean %}
    @MainActor
    func testLoadPropagatesFailure() async throws {
        let source = {{ name }}RemoteDataSource(fetch: { throw URLError(.notConnectedToInternet) })
        let repository = {{ name }}RepositoryImpl(remoteDataSource: source)
{% if hasNoDomain %}
        let sut = {{ name }}Interactor(repository: repository)
{% else %}
        let sut = {{ name }}Interactor(useCase: {{ name }}UseCase(repository: repository))
{% endif %}
        do {
            _ = try await sut.load()
            XCTFail("Expected loading failure")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .notConnectedToInternet)
        }
    }
{% endif %}
{% endif %}

    @MainActor
{% if isVIP %}
{% if isForm %}
    func testFormFieldsCanBeEdited() {
        let sut = {{ name }}Preview.makeInteractor()

        sut.field1 = "First value"
        sut.field2 = "Second value"

        XCTAssertEqual(sut.field1, "First value")
        XCTAssertEqual(sut.field2, "Second value")
    }
{% else %}
    func testLoadUpdatesViewModel() async throws {
        let sut = {{ name }}Preview.makeInteractor()

        await sut.load()

        XCTAssertEqual(sut.viewModel.title, "{{ name }}")
{% if isList %}
        XCTAssertEqual(sut.items.count, 1)
        XCTAssertEqual(sut.items.first?.title, "{{ name }}")
{% endif %}
    }
{% endif %}
{% else %}
    func testLoadReturnsFeatureData() async throws {
        let sut = {{ name }}Preview.makeInteractor()

        let value = try await sut.load()

        XCTAssertEqual(value.title, "{{ name }}")
    }
{% endif %}
}
{% endif %}

""",

        "useCaseTests.stencil": """
{% if isSwiftTesting %}
import Foundation
import Testing
@testable import {{ moduleName }}

@Suite struct {{ name }}UseCaseTests {
    @Test func executeReturnsRepositoryValue() async throws {
        let expected = {{ name }}Entity(id: UUID(), title: "Repository value")
        let repository = {{ name }}UseCaseRepositoryStub(result: .success(expected))
        let sut = {{ name }}UseCase(repository: repository)

        let entity = try await sut.execute()

        #expect(entity == expected)
        #expect(repository.fetchCount == 1)
    }

    @Test func executePropagatesRepositoryError() async throws {
        let repository = {{ name }}UseCaseRepositoryStub(result: .failure(.unavailable))
        let sut = {{ name }}UseCase(repository: repository)

        await #expect(throws: {{ name }}UseCaseRepositoryStub.Failure.unavailable) {
            try await sut.execute()
        }
        #expect(repository.fetchCount == 1)
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
{% else %}
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

    func testExecutePropagatesRepositoryError() async throws {
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
{% endif %}

""",

        "repositoryTests.stencil": """
{% if isSwiftTesting %}
import Foundation
import Testing
@testable import {{ moduleName }}

@Suite struct {{ name }}RepositoryTests {
    @Test func fetchPropagatesFailure() async throws {
        let source = {{ name }}RemoteDataSource(fetch: { throw URLError(.notConnectedToInternet) })
        let sut = {{ name }}RepositoryImpl(remoteDataSource: source)
        do {
            _ = try await sut.fetch{{ name }}()
            Issue.record("Expected loading failure")
        } catch let error as URLError {
            #expect(error.code == .notConnectedToInternet)
        }
    }

    @Test func fetchReturnsDataSourceTitle() async throws {
        let dataSource = {{ name }}RemoteDataSource.preview
        let sut = {{ name }}RepositoryImpl(remoteDataSource: dataSource)

        let value = try await sut.fetch{{ name }}()

        #expect(value.title == "{{ name }}")
    }
}
{% else %}
import XCTest
@testable import {{ moduleName }}

final class {{ name }}RepositoryTests: XCTestCase {
    func testFetchPropagatesFailure() async throws {
        let source = {{ name }}RemoteDataSource(fetch: { throw URLError(.notConnectedToInternet) })
        let sut = {{ name }}RepositoryImpl(remoteDataSource: source)
        do {
            _ = try await sut.fetch{{ name }}()
            XCTFail("Expected loading failure")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .notConnectedToInternet)
        }
    }

    func testFetchReturnsDataSourceTitle() async throws {
        let dataSource = {{ name }}RemoteDataSource.preview
        let sut = {{ name }}RepositoryImpl(remoteDataSource: dataSource)

        let value = try await sut.fetch{{ name }}()

        XCTAssertEqual(value.title, "{{ name }}")
    }
}
{% endif %}

""",
    ]
}
