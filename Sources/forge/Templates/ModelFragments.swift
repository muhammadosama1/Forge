import Foundation

/// Composes trusted built-in Swift only. Team code is rendered as a template, never parsed here.
struct ModelFragments {
    let members: String
    let types: String
    let properties: String
    let initializers: String
    let actions: String
    let parameters: String
    let assignments: String

    init(model: String, owner: String, role: String) throws {
        let error = ForgeError.invalidArguments("The built-in '\(role)' template is missing its composition boundaries.")
        guard let declaration = model.range(of: "\nfinal class " + owner),
              let opening = model[declaration.upperBound...].range(of: " {\n"),
              let closing = model[opening.upperBound...].range(of: "\n}") else {
            throw error
        }
        let members = String(model[opening.upperBound..<closing.lowerBound])
        self.members = members
        types = String(model[closing.upperBound...])
        guard let firstAction = members.range(of: #"(?m)^    func "#, options: .regularExpression) else {
            throw error
        }
        actions = String(members[firstAction.lowerBound...])
        let setup = members[..<firstAction.lowerBound]
        guard let initializer = setup.range(of: #"(?m)^    init\("#, options: .regularExpression) else {
            properties = setup.trimmingCharacters(in: .newlines)
            initializers = ""
            parameters = ""
            assignments = ""
            return
        }
        properties = setup[..<initializer.lowerBound].trimmingCharacters(in: .newlines)
        initializers = setup[initializer.lowerBound...].trimmingCharacters(in: .newlines)

        // A built-in initializer's closing brace is at member indentation. Its signature
        // can include nested closure defaults and can span multiple lines.
        let initBody = setup[initializer.upperBound...]
        guard let end = initBody.range(of: #"(?m)^    }$"#, options: .regularExpression),
              let signatureEnd = initBody[..<end.lowerBound].range(of: ") {\n", options: .backwards) else {
            throw error
        }
        parameters = String(initBody[..<signatureEnd.lowerBound])
        assignments = initBody[signatureEnd.upperBound..<end.lowerBound].trimmingCharacters(in: .newlines)
    }

    func add(to values: inout [String: Any], prefix: String) {
        values[prefix + "Members"] = members
        values[prefix + "Types"] = types
        values[prefix + "Properties"] = TemplateRenderer.Block(text: properties, baseIndent: 4)
        values[prefix + "Initializers"] = TemplateRenderer.Block(text: initializers, baseIndent: 4)
        values[prefix + "Actions"] = TemplateRenderer.Block(text: actions, baseIndent: 4)
        values[prefix + "InitializerParameters"] = parameters
        values[prefix + "InitializerParametersAfterComma"] = parameters.isEmpty ? "" : ", " + parameters
        values[prefix + "InitializerAssignments"] = TemplateRenderer.Block(text: assignments, baseIndent: 8)
    }

    static func layouts(prefix: String) -> [Set<String>] {
        let common = [prefix + "Properties", prefix + "Actions"]
        return [
            [prefix + "Members"],
            Set(common + [prefix + "Initializers"]),
            Set(common + [prefix + "InitializerParameters", prefix + "InitializerAssignments"]),
            Set(common + [prefix + "InitializerParametersAfterComma", prefix + "InitializerAssignments"]),
        ]
    }
}
