import Foundation

/// UI pattern category selected via CLI flags (`-form`, `-list`).
/// Determines the View and ViewModel/Presenter template content.
enum FeatureCategory: String, CaseIterable, CustomStringConvertible {
    case form
    case list

    var description: String {
        rawValue.capitalized
    }

    static var validFlags: String {
        allCases.map { "-\($0.rawValue)" }.joined(separator: ", ")
    }

    static func from(flag: String) -> FeatureCategory? {
        let name: String
        if flag.hasPrefix("--") {
            name = String(flag.dropFirst(2))
        } else if flag.hasPrefix("-") {
            name = String(flag.dropFirst())
        } else {
            name = flag
        }
        return FeatureCategory(rawValue: name)
    }
}
