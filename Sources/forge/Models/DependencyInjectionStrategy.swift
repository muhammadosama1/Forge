import Foundation

/// The dependency injection container strategy used for generated features.
enum DependencyInjectionStrategy: String, CaseIterable, Equatable, Sendable {
    /// Native Swift dependency injection using static factory methods on an enum container.
    case native
    /// Third-party Factory DI library (https://github.com/hmlong/Factory) extending `Container`.
    case factory

    /// Parses a string into a `DependencyInjectionStrategy`, supporting aliases.
    static func from(string: String) -> DependencyInjectionStrategy? {
        let normalized = string.trimmingCharacters(in: .whitespaces).lowercased()
        switch normalized {
        case "native":
            return .native
        case "factory":
            return .factory
        default:
            return nil
        }
    }
}
