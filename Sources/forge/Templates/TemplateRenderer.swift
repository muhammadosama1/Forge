import Foundation

/// Lightweight template renderer supporting `{{ variable }}` substitution
/// and `{% if key %}...{% endif %}` conditional blocks.
///
/// This covers 100% of the syntax used by the project's `.stencil` files
/// without pulling in any external dependency.
enum TemplateRenderer {

    /// Errors produced during template rendering.
    enum RendererError: Error {
        /// No template found for the given key in `TemplateContent.files`.
        case templateNotFound(String)
        /// Template was found but could not be read.
        case unreadableTemplate(String)
    }

    /// Renders `templateName` by first processing conditionals, then substituting variables.
    /// - Parameter templateName: Template dictionary key (e.g. `"viewModel.stencil"`).
    /// - Parameter context: Variable and flag values for substitution and conditional evaluation.
    static func render(
        _ templateName: String,
        context: [String: Any]
    ) throws -> String {
        guard let raw = TemplateContent.files[templateName] else {
            throw RendererError.templateNotFound(templateName)
        }
        let stripped = processConditionals(raw, context: context)
        return substituteVariables(stripped, context: context)
    }

    // MARK: - Conditional block processing

    /// Matches innermost `{% if key %}...{% else %}...{% endif %}` blocks.
    /// The body capture uses a negative lookahead to reject nested `{% if` inside the match,
    /// ensuring innermost blocks are resolved first on each iteration.
    private static let conditionalRegex: NSRegularExpression = {
        let body = #"((?:(?!\{%\s*if\s+)[\s\S])*?)"#
        let pattern = #"\{%\s*if\s+(\w+)\s*%\}"# + body + #"(?:\{%\s*else\s*%\}"# + body + #")?\{%\s*endif\s*%\}"#
        return try! NSRegularExpression(pattern: pattern, options: [])
    }()

    /// Iteratively removes `{% if key %}…{% else %}…{% endif %}` blocks,
    /// keeping only the content of the branch that matches the context.
    /// Multiple passes handle nested and sibling blocks.
    private static func processConditionals(_ text: String, context: [String: Any]) -> String {
        var result = text
        let regex = Self.conditionalRegex

        // Loop until no matching conditional tags remain in the template text
        while true {
            let range = NSRange(result.startIndex..., in: result)
            // Find the first innermost matching block
            guard let match = regex.firstMatch(in: result, range: range) else { break }

            let fullRange   = Range(match.range(at: 0), in: result)!
            let keyRange    = Range(match.range(at: 1), in: result)!
            let ifBodyRange = Range(match.range(at: 2), in: result)!

            let key    = String(result[keyRange])
            // Evaluate truthiness in the context map
            let isTrue = (context[key] as? Bool) == true

            let replacement: String
            if isTrue {
                // If condition is true, substitute with the 'if' body
                replacement = String(result[ifBodyRange])
            } else if match.range(at: 3).location != NSNotFound {
                // If condition is false and an 'else' block exists, substitute with the 'else' body
                let elseBodyRange = Range(match.range(at: 3), in: result)!
                replacement = String(result[elseBodyRange])
            } else {
                // If condition is false without an 'else' block, remove the whole block
                replacement = ""
            }

            // Replace the entire matched {% if %}...{% endif %} range with the selected branch
            result.replaceSubrange(fullRange, with: replacement)
        }

        return result
    }

    // MARK: - Variable substitution

    /// Replaces `{{ variable }}` placeholders with their context values.
    /// Keys are sorted longest-first to avoid partial collisions (e.g. `hasNoDomain`
    /// should match before `hasDomain`).
    private static func substituteVariables(_ text: String, context: [String: Any]) -> String {
        var result = text
        // Sorting longest-first prevents substring replacement collisions
        let sortedKeys = context.keys.sorted { $0.count > $1.count }
        for key in sortedKeys {
            guard let value = context[key] else { continue }
            // Support both spaced {{ key }} and unspaced {{key}} syntax
            result = result
                .replacingOccurrences(of: "{{ \(key) }}", with: "\(value)")
                .replacingOccurrences(of: "{{\(key)}}", with: "\(value)")
        }
        return result
    }
}
