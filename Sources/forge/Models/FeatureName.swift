import Foundation

/// Validates and normalizes a user-supplied feature name into PascalCase.
struct FeatureName {
    /// PascalCase name used for all generated Swift types, e.g. `"Search"`.
    let typeName: String
    /// Directory name for the feature (same as `typeName`).
    let folderName: String

    /// Parses and validates `rawValue` into a PascalCase feature name.
    /// - Parameter rawValue: User-supplied name (may contain spaces, dashes, underscores).
    /// - Throws: `ForgeError.invalidFeatureName` if the input is empty or contains
    ///   disallowed characters, or if the resulting name starts with a non-letter.
    init(rawValue: String) throws {
        // Define allowable separator and alphanumeric character sets
        let separators = CharacterSet(charactersIn: " _-")
        let allowed = CharacterSet.alphanumerics.union(separators)

        // Ensure input contains only letters, digits, spaces, dashes, and underscores
        guard rawValue.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw ForgeError.invalidFeatureName(rawValue)
        }

        // Split input by separators and filter out empty strings caused by consecutive separators
        let words = rawValue
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }

        // Must have at least one non-empty word token
        guard !words.isEmpty else {
            throw ForgeError.invalidFeatureName(rawValue)
        }

        // Capitalize the first letter of each word token to form PascalCase
        let typeName = words
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst()
            }
            .joined()

        // Feature names in Swift must start with a letter (cannot start with a digit)
        guard typeName.first?.isLetter == true else {
            throw ForgeError.invalidFeatureName(rawValue)
        }

        self.typeName = typeName
        self.folderName = typeName
    }
}

