import Foundation

struct StackTemplates {
    let config: StackConfig
    let directory: URL

    func render(role: String, builtIn: String?, context: [String: Any]) throws -> String {
        guard let file = config.files[role] else {
            guard let builtIn else { throw ForgeError.invalidArguments("No template configured for '\(role)'.") }
            return try TemplateRenderer.render(builtIn + ".stencil", context: context)
        }
        let url = directory.appendingPathComponent(file.template)
        guard resolvedPath(url).hasPrefix(resolvedPath(directory) + "/"),
              resolvedPath(directory) == resolvedPath(directory.deletingLastPathComponent()) + "/.templates" else {
            throw ForgeError.invalidArguments("Template '\(url.path)' escapes .templates/. Move it into the project template directory.")
        }
        guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
              let source = try? String(contentsOf: url, encoding: .utf8) else {
            throw ForgeError.invalidArguments("Cannot read template '\(url.path)' for '\(role)'. Restore the template or correct its path in stack.files.")
        }

        var values = TemplateRenderer.values(for: context)
        var required: Set<String> = []
        if let owner = Self.observableOwner(for: role), let builtIn {
            let prefix = "forge." + role
            let model = try TemplateRenderer.render(builtIn + ".stencil", context: context)
            // The built-in state owner uses one top-level final class, followed by supporting types.
            // Only split the trusted built-in output. Team templates declare their own insertion points.
            guard let declaration = model.range(of: "\nfinal class " + (context["name"] as? String ?? "") + owner),
                  let opening = model[declaration.upperBound...].range(of: " {\n"),
                  let closing = model[opening.upperBound...].range(of: "\n}") else {
                throw ForgeError.invalidArguments("The built-in '\(role)' template is missing its composition boundaries.")
            }
            values[prefix + "Members"] = String(model[opening.upperBound..<closing.lowerBound])
            let supportingTypes = String(model[closing.upperBound...])
            values[prefix + "Types"] = supportingTypes
            required.insert(prefix + "Members")
            if !supportingTypes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                required.insert(prefix + "Types")
            }
        }
        let isMVVM = values["isMVVM"] as? Bool == true
        let isMVI = values["isMVI"] as? Bool == true
        if role == FeatureFile.view.rawValue, isMVVM || isMVI {
            for index in 1...2 {
                let key = "forge.field\(index)Binding"
                values[key] = isMVVM ? "$viewModel.field\(index)" :
                    "Binding(get: { store.state.field\(index) }, set: { store.updateField\(index)($0) })"
                if values["isForm"] as? Bool == true { required.insert(key) }
            }
            values["forge.listItems"] = isMVVM ? "viewModel.items" : "store.state.items"
            if values["isList"] as? Bool == true { required.insert("forge.listItems") }
        }
        let category = values["isForm"] as? Bool == true ? "form" : (values["isList"] as? Bool == true ? "list" : "default")
        return try TemplateRenderer.renderSource(source, context: values, name: url.path, required: required, category: category)
    }

    private static func observableOwner(for role: String) -> String? {
        switch FeatureFile(rawValue: role) {
        case .viewModel: return "ViewModel"
        case .store: return "Store"
        default: return nil
        }
    }

    static func starter(for architecture: PresentationArchitecture) -> [String: String] {
        var files: [String: String] = [:]
        func source(role: String, clean: Bool, category: FeatureCategory?) -> String {
            let type = FeatureType.resolve(presentation: architecture, clean: clean)
            let specs = type.templateSpecs(for: category) + type.testTemplateSpecs
            guard let spec = specs.first(where: { $0.file.rawValue == role }) else { return "" }
            let template = TemplateContent.files[spec.templateName + ".stencil"]!
            guard role == FeatureFile.view.rawValue, architecture == .mvvm || architecture == .mvi else { return template }
            var view = template
            for index in 1...2 {
                let binding = architecture == .mvvm ? "$viewModel.field\(index)" :
                    """
                    Binding(
                                    get: { store.state.field\(index) },
                                    set: { store.updateField\(index)($0) }
                                )
                    """
                view = view.replacingOccurrences(of: binding, with: "{{ forge.field\(index)Binding }}")
            }
            let items = architecture == .mvvm ? "viewModel.items" : "store.state.items"
            return view.replacingOccurrences(of: "List(\(items))", with: "List({{ forge.listItems }})")
        }
        func branch(_ key: String, _ yes: String, _ no: String) -> String {
            if yes == no { return yes }
            // Keep template directives adjacent to content so they introduce no new Swift lines.
            return "{% if \(key) %}\(yes){% else %}\(no){% endif %}"
        }
        for role in StackConfig.roles(for: architecture) {
            let name = role + ".swift.stencil"
            if let owner = observableOwner(for: role) {
                files[name] = """
                import Foundation
                {% if isConcurrency %}
                import Observation

                @Observable
                @MainActor
                final class {{ name }}\(owner) {
                {% else %}
                import Combine

                @MainActor
                final class {{ name }}\(owner): ObservableObject {
                {% endif %}{{ forge.\(role)Members }}
                }
                {{ forge.\(role)Types }}

                """
                continue
            }
            func variants(clean: Bool) -> String {
                branch("isForm", source(role: role, clean: clean, category: .form),
                       branch("isList", source(role: role, clean: clean, category: .list),
                              source(role: role, clean: clean, category: nil)))
            }
            files[name] = branch("isClean", variants(clean: true), variants(clean: false))
        }
        return files
    }
}
