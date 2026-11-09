import Foundation

/// Validates explicit target names before they become paths or Swift source.
enum PackageTargetName {
    // These tokens cannot be used unescaped in the generated import declaration.
    private static let reservedNames: Set<String> = [
        "_", "associatedtype", "class", "deinit", "enum", "extension", "fileprivate", "func",
        "import", "init", "inout", "internal", "let", "open", "operator", "private", "precedencegroup",
        "protocol", "public", "rethrows", "static", "struct", "subscript", "typealias", "var",
        "break", "case", "catch", "continue", "default", "defer", "do", "else", "fallthrough",
        "for", "guard", "if", "in", "repeat", "return", "throw", "switch", "where", "while",
        "as", "Any", "false", "is", "nil", "self", "Self", "super", "throws", "true", "try"
    ]

    static func validate(_ name: String) throws {
        let letters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_")
        let allowed = letters.union(CharacterSet(charactersIn: "0123456789-"))
        guard let first = name.unicodeScalars.first,
              letters.contains(first),
              !reservedNames.contains(name),
              name.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw ForgeError.invalidArguments(
                "Invalid package target '\(name)': use letters, digits, underscores, or hyphens, starting with a letter or underscore, and avoid Swift reserved names."
            )
        }
    }
}
