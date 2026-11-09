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

            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let indent = rawLine.prefix(while: { $0 == " " }).count

            let key: String
            let valuePart: String
            if trimmed.first == "\"" || trimmed.first == "'" {
                let quoted = try parseQuoted(trimmed, line: lineNumber)
                let remainder = quoted.remainder.trimmingCharacters(in: .whitespaces)
                guard remainder.hasPrefix(":") else {
                    throw ParserError.invalidSyntax(line: lineNumber, message: "Expected ':' after quoted key")
                }
                key = quoted.value
                valuePart = String(remainder.dropFirst()).trimmingCharacters(in: .whitespaces)
            } else {
                guard let colon = trimmed.firstIndex(of: ":"),
                      stripPlainComment(String(trimmed[..<colon])) == String(trimmed[..<colon]).trimmingCharacters(in: .whitespaces) else {
                    throw ParserError.invalidSyntax(line: lineNumber, message: "Expected key-value pair with ':'")
                }
                key = String(trimmed[..<colon]).trimmingCharacters(in: .whitespaces)
                valuePart = String(trimmed[trimmed.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            }
            guard !key.isEmpty else {
                throw ParserError.invalidSyntax(line: lineNumber, message: "Missing key before ':'")
            }
            // Comments inside quoted values belong to the value. Plain values have no quote state.
            let value = valuePart.first == "\"" || valuePart.first == "'"
                ? valuePart : stripPlainComment(valuePart)
            let rawValue: String? = value.isEmpty ? nil : value

            tokenized.append(Line(
                lineNumber: lineNumber,
                indent: indent,
                key: key,
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
                mapping[line.key] = try parseScalar(rawVal, line: line.lineNumber)
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

    private static func parseScalar(_ text: String, line: Int) throws -> Any {
        if text.first == "\"" || text.first == "'" {
            let quoted = try parseQuoted(text, line: line)
            let remainder = quoted.remainder
            let trimmed = remainder.trimmingCharacters(in: .whitespaces)
            guard trimmed.isEmpty || (remainder.first?.isWhitespace == true && trimmed.hasPrefix("#")) else {
                throw ParserError.invalidSyntax(line: line, message: "Unexpected text after quoted string")
            }
            return quoted.value
        }

        let lower = text.lowercased()
        if ["true", "yes", "on"].contains(lower) { return true }
        if ["false", "no", "off"].contains(lower) { return false }
        if let value = Int(text) { return value }
        return text
    }

    /// Parses a single-line YAML quoted scalar, leaving delimiters/comments for its caller.
    private static func parseQuoted(_ text: String, line: Int) throws -> (value: String, remainder: String) {
        let characters = Array(text)
        let quote = characters[0]
        var index = 1
        var value = ""
        let escapes: [Character: String] = [
            "0": "\0", "a": "\u{7}", "b": "\u{8}", "t": "\t", "\t": "\t",
            "n": "\n", "v": "\u{B}", "f": "\u{C}", "r": "\r", "e": "\u{1B}",
            " ": " ", "\"": "\"", "/": "/", "\\": "\\",
            "N": "\u{85}", "_": "\u{A0}", "L": "\u{2028}", "P": "\u{2029}"
        ]

        while index < characters.count {
            let character = characters[index]
            index += 1
            if character == quote {
                if quote == "'", index < characters.count, characters[index] == "'" {
                    value.append("'")
                    index += 1
                    continue
                }
                return (value, String(characters[index...]))
            }
            if quote == "\"", character == "\\" {
                guard index < characters.count else { break }
                let escape = characters[index]
                index += 1
                if let decoded = escapes[escape] {
                    value += decoded
                } else if let length = ["x": 2, "u": 4, "U": 8][String(escape)] {
                    guard index + length <= characters.count else {
                        throw ParserError.invalidSyntax(line: line, message: "Incomplete Unicode escape")
                    }
                    let digits = String(characters[index..<(index + length)])
                    guard digits.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "0123456789abcdefABCDEF").contains($0) }),
                          let number = UInt32(digits, radix: 16), let scalar = UnicodeScalar(number) else {
                        throw ParserError.invalidSyntax(line: line, message: "Invalid Unicode escape")
                    }
                    value.unicodeScalars.append(scalar)
                    index += length
                } else {
                    throw ParserError.invalidSyntax(line: line, message: "Unsupported escape '\(escape)'")
                }
            } else {
                value.append(character)
            }
        }
        throw ParserError.invalidSyntax(line: line, message: "Unterminated quoted string; multiline quoted strings are not supported")
    }

    /// Quotes embedded in a plain scalar (e.g. O'Brien) are literal characters.
    private static func stripPlainComment(_ text: String) -> String {
        var previous: Character?
        for index in text.indices {
            let character = text[index]
            if character == "#", previous == nil || previous?.isWhitespace == true {
                return String(text[..<index]).trimmingCharacters(in: .whitespaces)
            }
            previous = character
        }
        return text.trimmingCharacters(in: .whitespaces)
    }
}
