import Foundation

/// Forge template contract v1: variables and nested boolean if/else blocks only.
enum TemplateRenderer {
    enum RendererError: Error { case templateNotFound(String) }
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
                             required: Set<String> = [], category: String? = nil) throws -> String {
        let regex = try NSRegularExpression(pattern: #"\{\{[\s\S]*?\}\}|\{%[\s\S]*?%\}"#)
        var result = ""
        var cursor = raw.startIndex
        var stack: [(parent: Bool, condition: Bool, sawElse: Bool)] = []
        var active = true
        var occurrences: [String: Int] = [:]
        var firstLine: [String: Int] = [:]
        var line = 1
        func invalid(_ detail: String) -> ForgeError {
            .invalidArguments("\(name):\(line): \(detail)")
        }
        func appendLiteral(_ literal: Substring) throws {
            guard !literal.contains("{{"), !literal.contains("{%") else {
                throw invalid("unterminated template tag")
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
                if required.contains(body) {
                    firstLine[body] = firstLine[body] ?? line
                    if active {
                        occurrences[body, default: 0] += 1
                        guard occurrences[body] == 1 else {
                            throw invalid("'{{ \(body) }}' is repeated for \(category ?? "this screen"). Keep one active insertion point.")
                        }
                    }
                }
                if active { result += String(describing: value) }
            } else if body.hasPrefix("if ") {
                let key = String(body.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                guard let condition = context[key] as? Bool else { throw invalid("unknown boolean '\(key)'") }
                stack.append((active, condition, false))
                active = active && condition
            } else if body == "else" {
                guard var frame = stack.popLast(), !frame.sawElse else { throw invalid("unexpected else") }
                frame.sawElse = true
                stack.append(frame)
                active = frame.parent && !frame.condition
            } else if body == "endif" {
                guard let frame = stack.popLast() else { throw invalid("unexpected endif") }
                active = frame.parent
            } else {
                throw invalid("unsupported tag '\(body)'")
            }
            line += token.filter(\.isNewline).count
            cursor = range.upperBound
        }
        try appendLiteral(raw[cursor...])
        guard stack.isEmpty else { throw invalid("missing endif") }
        for key in required.sorted() where occurrences[key] == nil {
            line = firstLine[key] ?? 1
            throw invalid("Missing active '{{ \(key) }}' for \(category ?? "this screen"). Restore it in the exported position and outside any condition that excludes this screen.")
        }
        return result
    }
}
