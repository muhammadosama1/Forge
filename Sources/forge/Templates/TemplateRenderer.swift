import Foundation

/// Forge template contract v1: variables and nested boolean if/else blocks only.
enum TemplateRenderer {
    enum RendererError: Error { case templateNotFound(String) }
    struct Block {
        let text: String
        let baseIndent: Int

        func indented(after prefix: Substring) -> String {
            guard !prefix.isEmpty, prefix.allSatisfy({ $0 == " " || $0 == "\t" }) else { return text }
            let margin = String(repeating: " ", count: baseIndent)
            return text.components(separatedBy: "\n").enumerated().map { index, line in
                let body = line.hasPrefix(margin) ? String(line.dropFirst(baseIndent)) : line
                return index == 0 || body.isEmpty ? body : String(prefix) + body
            }.joined(separator: "\n")
        }
    }

    private struct ConditionalBranch {
        let key: String
        let condition: Bool
        let parentIsActive: Bool
        let ifLine: Int
        var elseLine: Int?

        var isActive: Bool { condition != (elseLine != nil) }

        var reason: String {
            if let elseLine {
                return "The insertion point is in the else branch on line \(elseLine). 'if \(key)' on line \(ifLine) is true for this screen."
            }
            return "'if \(key)' on line \(ifLine) is false for this screen, so Forge skips the insertion point."
        }
    }

    static let booleanKeys = "hasDependencyContainer hasInteractor hasNoDomain hasPresenter hasRemoteDataSource hasRepository hasRouter hasStore hasTests hasUseCase hasView hasViewModel hasWorker isClean isConcurrency isFactory isForm isList isMVVM isMVI isMVP isSwiftTesting isVIP isVIPER isPackage".split(separator: " ").map(String.init)
    static func render(_ templateName: String, context: [String: Any], overrides: URL? = nil) throws -> String {
        guard TemplateContent.files[templateName] != nil else { throw RendererError.templateNotFound(templateName) }
        let raw = try TemplateCatalog.source(templateName, overrides: overrides)
        return try renderSource(raw, context: values(for: context), name: templateName)
    }

    static func values(for context: [String: Any]) -> [String: Any] {
        var values: [String: Any] = Dictionary(uniqueKeysWithValues: booleanKeys.map { ($0, false as Any) })
        values.merge(context) { _, supplied in supplied }
        if let name = context["name"] as? String {
            if values["moduleName"] == nil { values["moduleName"] = name }
            if values["propertyName"] == nil { values["propertyName"] = name.prefix(1).lowercased() + name.dropFirst() }
        }
        return values
    }

    static func renderSource(_ raw: String, context: [String: Any], name: String,
                             required: Set<String> = [], layouts: [Set<String>] = [], category: String? = nil) throws -> String {
        let regex = try NSRegularExpression(pattern: #"\{\{(?:(?!\{[\{%])[\s\S])*?\}\}|\{%(?:(?!\{[\{%])[\s\S])*?%\}"#)
        var result = ""
        var cursor = raw.startIndex
        var stack: [ConditionalBranch] = []
        var active = true
        var activeLines: [String: Int] = [:]
        var skippedBranches: [String: ConditionalBranch] = [:]
        var firstLine: [String: Int] = [:]
        let checkedKeys = layouts.reduce(required) { $0.union($1) }
        var line = 1
        func invalid(_ detail: String) -> ForgeError {
            .invalidArguments("\(name):\(line): \(detail)")
        }
        func appendLiteral(_ literal: Substring) throws {
            if let opening = literal.range(of: #"\{[\{%]"#, options: .regularExpression) {
                line += literal[..<opening.lowerBound].filter(\.isNewline).count
                let closing = literal[opening] == "{{" ? "}}" : "%}"
                throw invalid("unterminated template tag. Forge cannot render this template. Close the tag with '\(closing)'.")
            }
            if active { result += literal }
        }
        for match in regex.matches(in: raw, range: NSRange(raw.startIndex..., in: raw)) {
            let range = Range(match.range, in: raw)!
            try appendLiteral(raw[cursor..<range.lowerBound])
            line += raw[cursor..<range.lowerBound].filter(\.isNewline).count
            let token = String(raw[range])
            let body = token.dropFirst(2).dropLast(2).trimmingCharacters(in: .whitespacesAndNewlines)
            if token.hasPrefix("{{") {
                guard let value = context[body] else { throw invalid("unknown variable '\(body)'") }
                if checkedKeys.contains(body) {
                    firstLine[body] = firstLine[body] ?? line
                    if active {
                        if let original = activeLines[body] {
                            throw invalid("'{{ \(body) }}' is repeated for \(category ?? "this screen"). It was already active on line \(original). Keep one active insertion point.")
                        }
                        activeLines[body] = line
                    } else if skippedBranches[body] == nil {
                        skippedBranches[body] = stack.first { !$0.isActive }
                    }
                }
                if active, let block = value as? Block {
                    let preceding = raw[..<range.lowerBound]
                    let lineStart = preceding.lastIndex(where: \.isNewline).map { raw.index(after: $0) } ?? raw.startIndex
                    result += block.indented(after: raw[lineStart..<range.lowerBound])
                } else if active {
                    result += String(describing: value)
                }
            } else if body.hasPrefix("if ") {
                let key = String(body.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                guard let condition = context[key] as? Bool else { throw invalid("unknown boolean '\(key)'") }
                stack.append(ConditionalBranch(key: key, condition: condition, parentIsActive: active, ifLine: line))
                active = active && condition
            } else if body == "else" {
                guard var frame = stack.popLast(), frame.elseLine == nil else { throw invalid("unexpected else") }
                frame.elseLine = line
                stack.append(frame)
                active = frame.parentIsActive && frame.isActive
            } else if body == "endif" {
                guard let frame = stack.popLast() else { throw invalid("unexpected endif") }
                active = frame.parentIsActive
            } else {
                throw invalid("unsupported tag '\(body)'")
            }
            line += token.filter(\.isNewline).count
            cursor = range.upperBound
        }
        try appendLiteral(raw[cursor...])
        guard stack.isEmpty else { throw invalid("missing endif") }
        let usedLayoutKeys = Set(activeLines.keys).subtracting(required)
        let knownLayoutKeys = Set(firstLine.keys)
        let layout = layouts.first { usedLayoutKeys == $0 }
            ?? layouts.filter { usedLayoutKeys.isSubset(of: $0) }.max {
                $0.intersection(knownLayoutKeys).count < $1.intersection(knownLayoutKeys).count
            }
        if !layouts.isEmpty, layout == nil {
            line = usedLayoutKeys.compactMap { firstLine[$0] }.min() ?? 1
            throw invalid("Mixed model insertion points for \(category ?? "this screen"). Use the members block, the default initializer block, or one parameter insertion point and its assignments.")
        }
        for key in required.union(layout ?? []).sorted() where activeLines[key] == nil {
            line = firstLine[key] ?? 1
            let screen = category ?? "this screen"
            let reason = skippedBranches[key].map { " \($0.reason)" } ?? ""
            let consequence: String
            switch key {
            case "forge.field1Binding", "forge.field2Binding":
                consequence = " The form needs this binding to update its model."
            case "forge.listItems":
                consequence = " The list needs this collection to display the model's items."
            case let key where key.hasSuffix("Properties"):
                consequence = " The generated screen needs these model properties."
            case let key where key.hasSuffix("Actions"):
                consequence = " The generated screen needs these model actions."
            case let key where key.contains("Initializer"):
                consequence = " The generated model needs this insertion point for dependency initialization."
            default:
                consequence = ""
            }
            throw invalid("Missing active '{{ \(key) }}' for \(screen).\(reason)\(consequence) Restore it in the exported position outside the blocking condition, or add it to the branch that runs for \(screen).")
        }
        return result
    }
}
