import Foundation

/// The reactive state-binding mechanism used in generated presentation templates.
enum BindingStrategy: String, CaseIterable, Equatable, Sendable {
    /// Traditional Combine binding using `ObservableObject`, `@Published`, and `@StateObject`.
    case combine
    /// Modern Swift Observation binding using `@Observable`, `@State`, and `import Observation`.
    case concurrency

    /// Parses a string into a `BindingStrategy`, supporting aliases like `observation` and `swift-concurrency`.
    static func from(string: String) -> BindingStrategy? {
        let normalized = string.trimmingCharacters(in: .whitespaces).lowercased()
        switch normalized {
        case "combine":
            return .combine
        case "concurrency", "swift_concurrency", "swift-concurrency", "observation":
            return .concurrency
        default:
            return nil
        }
    }
}
