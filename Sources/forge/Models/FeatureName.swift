import Foundation

/// Validates and normalizes a user-supplied feature name into PascalCase.
struct FeatureName {
    /// PascalCase name used for all generated Swift types, e.g. `"Search"`.
    let typeName: String
    /// Directory name for the feature (derived from the base feature name with folder prefix/suffix rules applied).
    let folderName: String

    /// Parses and validates `rawValue` into a PascalCase feature name, applying optional naming rules.
    /// - Parameters:
    ///   - rawValue: User-supplied name (may contain spaces, dashes, underscores).
    ///   - naming: Optional naming configuration from `.forge.yml`.
    /// - Throws: `ForgeError.invalidFeatureName` if the input is empty or contains
    ///   disallowed characters, or if the resulting name starts with a non-letter.
    init(rawValue: String, naming: NamingConfig = NamingConfig()) throws {
        // Validate naming rules if provided
        if !naming.typePrefix.isEmpty {
            guard naming.typePrefix.allSatisfy({ $0.isLetter || $0.isNumber }) else {
                throw ForgeError.invalidArguments("Invalid type_prefix '\(naming.typePrefix)': must contain only alphanumeric characters.")
            }
            guard naming.typePrefix.first?.isLetter == true else {
                throw ForgeError.invalidArguments("Invalid type_prefix '\(naming.typePrefix)': must start with a letter.")
            }
        }
        if !naming.typeSuffix.isEmpty {
            guard naming.typeSuffix.allSatisfy({ $0.isLetter || $0.isNumber }) else {
                throw ForgeError.invalidArguments("Invalid type_suffix '\(naming.typeSuffix)': must contain only alphanumeric characters.")
            }
        }

        let invalidFolderChars = CharacterSet(charactersIn: "/:\0")
        if !naming.folderPrefix.isEmpty && naming.folderPrefix.rangeOfCharacter(from: invalidFolderChars) != nil {
            throw ForgeError.invalidArguments("Invalid folder_prefix '\(naming.folderPrefix)': contains invalid filesystem characters.")
        }
        if !naming.folderSuffix.isEmpty && naming.folderSuffix.rangeOfCharacter(from: invalidFolderChars) != nil {
            throw ForgeError.invalidArguments("Invalid folder_suffix '\(naming.folderSuffix)': contains invalid filesystem characters.")
        }

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
        let baseTypeName = words
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst()
            }
            .joined()

        // Feature names in Swift must start with a letter (cannot start with a digit)
        guard baseTypeName.first?.isLetter == true else {
            throw ForgeError.invalidFeatureName(rawValue)
        }

        // Apply type naming conventions
        var resolvedType = baseTypeName
        if !naming.typeSuffix.isEmpty {
            if naming.stripRedundantSuffix && Self.hasDistinctSuffix(resolvedType, suffix: naming.typeSuffix) {
                // Suffix already present, do not duplicate
            } else {
                resolvedType += naming.typeSuffix
            }
        }
        if !naming.typePrefix.isEmpty {
            if naming.stripRedundantPrefix && Self.hasDistinctPrefix(resolvedType, prefix: naming.typePrefix) {
                // Prefix already present, do not duplicate
            } else {
                resolvedType = naming.typePrefix + resolvedType
            }
        }

        // Apply folder naming conventions
        var resolvedFolder = baseTypeName
        if !naming.folderSuffix.isEmpty {
            if naming.stripRedundantSuffix && Self.hasDistinctSuffix(resolvedFolder, suffix: naming.folderSuffix) {
                // Suffix already present, do not duplicate
            } else {
                resolvedFolder += naming.folderSuffix
            }
        }
        if !naming.folderPrefix.isEmpty {
            if naming.stripRedundantPrefix && Self.hasDistinctPrefix(resolvedFolder, prefix: naming.folderPrefix) {
                // Prefix already present, do not duplicate
            } else {
                resolvedFolder = naming.folderPrefix + resolvedFolder
            }
        }

        guard resolvedType.first?.isLetter == true else {
            throw ForgeError.invalidFeatureName(resolvedType)
        }

        self.typeName = resolvedType
        self.folderName = resolvedFolder
    }

    /// camelCase property name, e.g. `"login"`, `"userProfile"`.
    var propertyName: String {
        guard let first = typeName.first else { return "" }
        return first.lowercased() + typeName.dropFirst()
    }

    /// Determines if `text` already has `prefix` as a distinct PascalCase word or prefix component.
    private static func hasDistinctPrefix(_ text: String, prefix: String) -> Bool {
        guard text.hasPrefix(prefix) else { return false }
        if text.count == prefix.count { return true }
        guard let nextChar = text.dropFirst(prefix.count).first else { return true }
        // If prefix ends with a non-alphanumeric separator (e.g. "feature-"), any continuation is distinct
        if let lastPrefixChar = prefix.last, !lastPrefixChar.isLetter && !lastPrefixChar.isNumber {
            return true
        }
        // If the next character is not a lowercase letter (e.g. uppercase letter or digit),
        // it marks a word boundary in PascalCase (e.g. AppLogin vs Appointments).
        return !nextChar.isLowercase
    }

    /// Determines if `text` already has `suffix` as a distinct PascalCase word or suffix component.
    private static func hasDistinctSuffix(_ text: String, suffix: String) -> Bool {
        guard text.hasSuffix(suffix) else { return false }
        if text.count == suffix.count { return true }
        // Check the boundary before the suffix
        let prefixPart = text.dropLast(suffix.count)
        guard let precedingChar = prefixPart.last else { return true }
        // If suffix starts with a non-alphanumeric separator (e.g. "-feature"), it's distinct
        if let firstSuffixChar = suffix.first, !firstSuffixChar.isLetter && !firstSuffixChar.isNumber {
            return true
        }
        // If the first character of suffix is uppercase, it marks a PascalCase word boundary
        if let firstSuffixChar = suffix.first, firstSuffixChar.isUppercase {
            return true
        }
        // If suffix is lowercase, the preceding character should be a separator or uppercase
        return !precedingChar.isLowercase
    }
}

