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
        let separators = CharacterSet(charactersIn: " _-")
        let allowed = CharacterSet.alphanumerics.union(separators)

        guard rawValue.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw ForgeError.invalidFeatureName(rawValue)
        }

        let words = rawValue
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }

        guard !words.isEmpty else {
            throw ForgeError.invalidFeatureName(rawValue)
        }

        let typeName = words
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst()
            }
            .joined()

        guard typeName.first?.isLetter == true else {
            throw ForgeError.invalidFeatureName(rawValue)
        }

        self.typeName = typeName
        self.folderName = typeName
    }
}

