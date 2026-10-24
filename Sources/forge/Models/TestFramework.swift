import Foundation

/// The unit testing framework used for generated test files.
enum TestFramework: String, CaseIterable, Equatable, Sendable {
    /// Apple's traditional XCTest framework (`import XCTest`, `XCTestCase`).
    case xctest
    /// Apple's modern Swift Testing framework (`import Testing`, `@Suite`, `@Test`, `#expect`).
    case swiftTesting = "swift-testing"

    /// Parses a string into a `TestFramework`, supporting aliases.
    static func from(string: String) -> TestFramework? {
        let normalized = string.trimmingCharacters(in: .whitespaces).lowercased()
        switch normalized {
        case "xctest":
            return .xctest
        case "swift-testing", "swift_testing", "swift-test", "swift_test", "testing":
            return .swiftTesting
        default:
            return nil
        }
    }
}
