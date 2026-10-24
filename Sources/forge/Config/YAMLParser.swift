import Foundation

/// A lightweight, zero-dependency YAML parser for dictionary structures.
///
/// Supports:
/// - Key-value pairs (`key: value`)
/// - Nested mappings using indentation (spaces)
/// - Quoted (`"..."`, `'...'`) and unquoted strings
/// - Booleans (`true`, `false`, `yes`, `no`)
/// - Integers
/// - Line comments (`# ...`) and inline comments
enum YAMLParser {

    enum ParserError: Error, Equatable, LocalizedError {
        case invalidSyntax(line: Int, message: String)

        var errorDescription: String? {
            switch self {
            case .invalidSyntax(let line, let message):
                return "YAML syntax error at line \(line): \(message)"
            }
        }
    }

    private struct Line {
        let lineNumber: Int
        let indent: Int
        let key: String
        let rawValue: String?
    }

    /// Parses YAML string content into a nested Swift dictionary.
    static func parse(_ yaml: String) throws -> [String: Any] {
        let lines = try tokenize(yaml)
        var index = 0
        return try parseMapping(lines: lines, currentIndex: &index, expectedIndent: 0)
    }

    // MARK: - Tokenization

    private static func tokenize(_ yaml: String) throws -> [Line] {
        var tokenized: [Line] = []
        let normalized = yaml
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let rawLines = normalized.components(separatedBy: "\n")

        for (zeroIdx, rawLine) in rawLines.enumerated() {
            let lineNumber = zeroIdx + 1

            // Reject tabs used for indentation
            let indentPrefix = rawLine.prefix(while: { $0 == " " || $0 == "\t" })
            if indentPrefix.contains("\t") {
                throw ParserError.invalidSyntax(line: lineNumber, message: "Tabs are not allowed for indentation in YAML")
            }

            let strippedComment = stripTrailingComment(from: rawLine)
            let trimmed = strippedComment.trimmingCharacters(in: .whitespaces)

            // Skip empty lines or pure comment lines
            if trimmed.isEmpty { continue }

            let indent = rawLine.prefix(while: { $0 == " " }).count

            guard let colonIndex = findColonSeparator(in: trimmed) else {
                throw ParserError.invalidSyntax(line: lineNumber, message: "Expected key-value pair with ':'")
            }

            let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else {
                throw ParserError.invalidSyntax(line: lineNumber, message: "Missing key before ':'")
            }

            let valuePart = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            let rawValue: String? = valuePart.isEmpty ? nil : valuePart

            tokenized.append(Line(
                lineNumber: lineNumber,
                indent: indent,
                key: unquote(key),
                rawValue: rawValue
            ))
        }

        return tokenized
    }

    private static func parseMapping(
        lines: [Line],
        currentIndex: inout Int,
        expectedIndent: Int
    ) throws -> [String: Any] {
        var mapping: [String: Any] = [:]

        while currentIndex < lines.count {
            let line = lines[currentIndex]

            // If indentation drops below what this block expects, exit back to parent
            if line.indent < expectedIndent {
                break
            }

            // Check if indentation matches expected block indent
            if line.indent != expectedIndent {
                throw ParserError.invalidSyntax(
                    line: line.lineNumber,
                    message: "Unexpected indentation level (got \(line.indent), expected \(expectedIndent))"
                )
            }

            // Reject duplicate keys in the same mapping
            if mapping[line.key] != nil {
                throw ParserError.invalidSyntax(
                    line: line.lineNumber,
                    message: "Duplicate key '\(line.key)'"
                )
            }

            currentIndex += 1

            if let rawVal = line.rawValue {
                // Scalar value on the same line
                mapping[line.key] = parseScalar(rawVal)
            } else {
                // Nested mapping: peek at next line to determine child indentation
                if currentIndex < lines.count && lines[currentIndex].indent > line.indent {
                    let childIndent = lines[currentIndex].indent
                    let nested = try parseMapping(
                        lines: lines,
                        currentIndex: &currentIndex,
                        expectedIndent: childIndent
                    )
                    mapping[line.key] = nested
                } else {
                    // Empty mapping or nil
                    mapping[line.key] = [String: Any]()
                }
            }
        }

        return mapping
    }

    // MARK: - Scalar Parsing

    private static func parseScalar(_ text: String) -> Any {
        let trimmed = text.trimmingCharacters(in: .whitespaces)

        // Quoted strings
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") && trimmed.count >= 2) ||
           (trimmed.hasPrefix("'") && trimmed.hasSuffix("'") && trimmed.count >= 2) {
            return String(trimmed.dropFirst().dropLast())
        }

        // Booleans
        let lower = trimmed.lowercased()
        if lower == "true" || lower == "yes" || lower == "on" {
            return true
        }
        if lower == "false" || lower == "no" || lower == "off" {
            return false
        }

        // Integers
        if let intVal = Int(trimmed) {
            return intVal
        }

        // Default to unquoted string
        return trimmed
    }

    private static func unquote(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") && trimmed.count >= 2) ||
           (trimmed.hasPrefix("'") && trimmed.hasSuffix("'") && trimmed.count >= 2) {
            return String(trimmed.dropFirst().dropLast())
        }
        return trimmed
    }

    /// Strips comments (`# ...`) unless the hash is inside quotes.
    /// In YAML, `#` starts a comment only if it is at the start of a line or preceded by whitespace.
    private static func stripTrailingComment(from line: String) -> String {
        var inSingleQuote = false
        var inDoubleQuote = false

        for (index, char) in line.enumerated() {
            if char == "'" && !inDoubleQuote {
                inSingleQuote.toggle()
            } else if char == "\"" && !inSingleQuote {
                inDoubleQuote.toggle()
            } else if char == "#" && !inSingleQuote && !inDoubleQuote {
                // Check that '#' is preceded by whitespace or is at the start of the line
                let isPrecededByWhitespace: Bool
                if index == 0 {
                    isPrecededByWhitespace = true
                } else {
                    let prevIdx = line.index(line.startIndex, offsetBy: index - 1)
                    isPrecededByWhitespace = line[prevIdx] == " " || line[prevIdx] == "\t"
                }

                if isPrecededByWhitespace {
                    let stringIdx = line.index(line.startIndex, offsetBy: index)
                    return String(line[..<stringIdx])
                }
            }
        }

        return line
    }

    /// Finds the colon that separates the key from the value, ignoring colons inside quotes.
    private static func findColonSeparator(in line: String) -> String.Index? {
        var inSingleQuote = false
        var inDoubleQuote = false

        for (index, char) in line.enumerated() {
            if char == "'" && !inDoubleQuote {
                inSingleQuote.toggle()
            } else if char == "\"" && !inSingleQuote {
                inDoubleQuote.toggle()
            } else if char == ":" && !inSingleQuote && !inDoubleQuote {
                return line.index(line.startIndex, offsetBy: index)
            }
        }

        return nil
    }
}
