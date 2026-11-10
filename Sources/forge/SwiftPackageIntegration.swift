import Foundation

/// Plans conservative edits to an existing Swift package manifest.
/// Dynamic target lists or dependency expressions are left for the package owner to edit.
enum SwiftPackageIntegration {
    struct Update {
        let manifestURL: URL
        let original: String
        let updated: String

        var changed: Bool { original != updated }
    }

    private struct Edit {
        let range: Range<String.Index>
        let replacement: String
    }

    static func plan(at root: URL, target: String, tests: Bool, factory: Bool) throws -> Update {
        let url = root.appendingPathComponent("Package.swift")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ForgeError.invalidArguments("No Package.swift found at '\(root.path)' for --target '\(target)'. Set --path or paths.root to the package directory, or pass --package to create a standalone package.")
        }
        let source = try String(contentsOf: url, encoding: .utf8)
        guard let packageCall = source.range(of: #"\bPackage\s*\("#, options: .regularExpression),
              let packageBody = body(of: packageCall, in: source),
              let targets = argument("targets", in: packageBody, source: source),
              let targetArray = arrayBody(of: targets, in: source) else {
            throw unsupported("literal Package(targets: [...])")
        }

        var foundTarget = false
        var availableTargets: [String] = []
        var foundTestTarget = false
        var targetBody: Range<String.Index>?
        var testBody: Range<String.Index>?
        for item in splitTopLevel(targetArray, source: source) {
            let text = source[item].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            guard let kind = source[item].range(of: #"\.(target|executableTarget|testTarget)\s*\("#, options: .regularExpression),
                  let bodyRange = body(of: kind, in: source),
                  let nameRange = argument("name", in: bodyRange, source: source),
                  let name = quotedString(source[nameRange]) else {
                throw unsupported("literal target declarations")
            }
            let isTest = source[kind].hasPrefix(".testTarget")
            if !isTest { availableTargets.append(name) }
            if name == target && !isTest {
                foundTarget = true
                targetBody = bodyRange
            }
            if name == "\(target)Tests" && isTest {
                foundTestTarget = true
                testBody = bodyRange
            }
        }
        guard foundTarget, let targetBody else {
            let available = availableTargets.sorted().map { "'\($0)'" }.joined(separator: ", ")
            let hint = available.isEmpty ? "The manifest has no supported source targets." : "Choose a source target from: \(available)."
            throw ForgeError.invalidArguments("No Swift package source target named '\(target)' in '\(url.path)'. \(hint)")
        }
        if argument("path", in: targetBody, source: source) != nil {
            throw unsupported("a target without a custom path for '\(target)'")
        }

        var edits: [Edit] = []
        if tests && !foundTestTarget {
            edits.append(append(".testTarget(name: \"\(target)Tests\", dependencies: [\"\(target)\"])", to: targetArray, in: source, indentation: "        "))
        } else if tests, let testBody {
            if argument("path", in: testBody, source: source) != nil {
                throw unsupported("a test target without a custom path for '\(target)Tests'")
            }
            if let dependency = argument("dependencies", in: testBody, source: source) {
                guard let array = arrayBody(of: dependency, in: source) else {
                    throw unsupported("a literal dependencies array for test target '\(target)Tests'")
                }
                if !source[array].contains("\"\(target)\"") {
                    edits.append(append("\"\(target)\"", to: array, in: source, indentation: "            "))
                }
            } else {
                let existing = source[testBody].trimmingCharacters(in: .whitespacesAndNewlines)
                let comma = existing.hasSuffix(",") ? "" : ","
                edits.append(Edit(range: testBody.upperBound..<testBody.upperBound,
                    replacement: "\(comma) dependencies: [\"\(target)\"]"))
            }
        }
        if factory {
            let product = #".product(name: "Factory", package: "Factory")"#
            if let dependency = argument("dependencies", in: targetBody, source: source) {
                guard let dependencyArray = arrayBody(of: dependency, in: source) else {
                    throw unsupported("a literal dependencies array for target '\(target)'")
                }
                if source[dependencyArray].range(
                    of: #"(?:\.product\s*\(\s*name\s*:\s*)?"Factory""#,
                    options: .regularExpression
                ) == nil {
                    edits.append(append(product, to: dependencyArray, in: source, indentation: "            "))
                }
            } else {
                let existing = source[targetBody].trimmingCharacters(in: .whitespacesAndNewlines)
                let comma = existing.hasSuffix(",") ? "" : ","
                edits.append(Edit(range: targetBody.upperBound..<targetBody.upperBound,
                    replacement: "\(comma) dependencies: [\(product)]"))
            }

            if let dependencies = argument("dependencies", in: packageBody, source: source) {
                guard let array = arrayBody(of: dependencies, in: source) else {
                    throw unsupported("a literal package dependencies array")
                }
                if !source[array].contains("github.com/hmlongco/Factory") {
                    edits.append(append(#".package(url: "https://github.com/hmlongco/Factory.git", from: "2.4.0")"#, to: array, in: source, indentation: "        "))
                }
            } else {
                guard let targetsSegment = argumentSegment("targets", in: packageBody, source: source) else {
                    throw unsupported("literal Package(targets: [...])")
                }
                guard let label = source[targetsSegment].range(of: #"\btargets\s*:"#, options: .regularExpression) else {
                    throw unsupported("literal Package(targets: [...])")
                }
                edits.append(Edit(range: label.lowerBound..<label.lowerBound,
                    replacement: "dependencies: [\n        .package(url: \"https://github.com/hmlongco/Factory.git\", from: \"2.4.0\"),\n    ],\n    "))
            }
        }
        var updated = source
        for edit in edits.sorted(by: { $0.range.lowerBound > $1.range.lowerBound }) {
            updated.replaceSubrange(edit.range, with: edit.replacement)
        }
        return Update(manifestURL: url, original: source, updated: updated)
    }

    private static func unsupported(_ requirement: String) -> ForgeError {
        .invalidArguments("Cannot safely update Package.swift: Forge requires \(requirement).")
    }

    private static func quotedString(_ text: Substring) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.first == "\"", value.last == "\"", value.count >= 2 else { return nil }
        return String(value.dropFirst().dropLast())
    }

    private static func append(_ item: String, to body: Range<String.Index>, in source: String, indentation: String) -> Edit {
        let existing = source[body].trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = existing.isEmpty || existing.hasSuffix(",") ? "" : ","
        let insertion = source[body].lastIndex(where: { !$0.isWhitespace })
            .map { source.index(after: $0) } ?? body.lowerBound
        let suffix = insertion < body.upperBound ? "," : ""
        return Edit(range: insertion..<insertion, replacement: "\(prefix)\n\(indentation)\(item)\(suffix)")
    }

    private static func argument(_ name: String, in body: Range<String.Index>, source: String) -> Range<String.Index>? {
        for part in splitTopLevel(body, source: source) {
            let text = source[part]
            if let match = text.range(of: "^\\s*\(name)\\s*:", options: .regularExpression) {
                return match.upperBound..<part.upperBound
            }
        }
        return nil
    }

    private static func argumentSegment(_ name: String, in body: Range<String.Index>, source: String) -> Range<String.Index>? {
        splitTopLevel(body, source: source).first {
            source[$0].range(of: "^\\s*\(name)\\s*:", options: .regularExpression) != nil
        }
    }

    private static func arrayBody(of value: Range<String.Index>, in source: String) -> Range<String.Index>? {
        guard let open = source[value].firstIndex(of: "["),
              source[value.lowerBound..<open].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let close = closingDelimiter(from: open, in: source),
              source.index(after: close) <= value.upperBound,
              source[source.index(after: close)..<value.upperBound]
                .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return source.index(after: open)..<close
    }

    private static func body(of call: Range<String.Index>, in source: String) -> Range<String.Index>? {
        guard let open = source[call].lastIndex(of: "("), let close = closingDelimiter(from: open, in: source) else { return nil }
        return source.index(after: open)..<close
    }

    /// Balances Swift delimiters while ignoring quoted strings and comments.
    private static func closingDelimiter(from open: String.Index, in source: String) -> String.Index? {
        let pairs: [Character: Character] = ["(": ")", "[": "]", "{": "}"]
        var stack: [Character] = []
        var index = open
        var quoted = false
        var escaped = false
        var lineComment = false
        while index < source.endIndex {
            let character = source[index]
            let next = source.index(after: index)
            if lineComment {
                if character == "\n" { lineComment = false }
            } else if quoted {
                if escaped { escaped = false }
                else if character == "\\" { escaped = true }
                else if character == "\"" { quoted = false }
            } else if character == "/", next < source.endIndex, source[next] == "/" {
                lineComment = true
            } else if character == "\"" {
                quoted = true
            } else if let close = pairs[character] {
                stack.append(close)
            } else if character == stack.last {
                stack.removeLast()
                if stack.isEmpty { return index }
            }
            index = next
        }
        return nil
    }

    private static func splitTopLevel(_ body: Range<String.Index>, source: String) -> [Range<String.Index>] {
        var parts: [Range<String.Index>] = []
        var start = body.lowerBound
        var index = start
        while index < body.upperBound {
            if source[index] == "(" || source[index] == "[" || source[index] == "{" {
                if let end = closingDelimiter(from: index, in: source) { index = source.index(after: end); continue }
            }
            if source[index] == "\"" {
                var cursor = source.index(after: index)
                var escaped = false
                while cursor < body.upperBound {
                    let char = source[cursor]
                    if escaped { escaped = false }
                    else if char == "\\" { escaped = true }
                    else if char == "\"" { break }
                    cursor = source.index(after: cursor)
                }
                if cursor < body.upperBound { index = source.index(after: cursor); continue }
            }
            if source[index] == "/" {
                let next = source.index(after: index)
                if next < body.upperBound && source[next] == "/" {
                    if let newline = source[next..<body.upperBound].firstIndex(of: "\n") {
                        index = source.index(after: newline)
                        continue
                    }
                    break
                }
            }
            if source[index] == "," {
                parts.append(start..<index)
                start = source.index(after: index)
            }
            index = source.index(after: index)
        }
        parts.append(start..<body.upperBound)
        return parts
    }
}
