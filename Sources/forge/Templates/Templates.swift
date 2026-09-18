import Foundation

/// Builds the boolean context dictionary consumed by template `{% if key %}` blocks.
extension FeatureFileSelection {
    /// Produces `hasView`, `hasViewModel`, … flags based on which files are included.
    var contextMap: [String: Any] {
        [
            "hasView":                contains(.view),
            "hasViewModel":           contains(.viewModel),
            "hasPresenter":           contains(.presenter),
            "hasInteractor":          contains(.interactor),
            "hasRouter":              contains(.router),
            "hasStore":               contains(.store),
            "hasUseCase":             contains(.useCase),
            "hasRepository":          contains(.repository),
            "hasRemoteDataSource":    contains(.remoteDataSource),
            "hasWorker":              contains(.worker),
            "hasDependencyContainer": contains(.dependencyContainer),
            "isForm":                 false,
            "isList":                 false,
        ]
    }
}

/// High-level rendering entry points. Wraps `TemplateRenderer` with name and context setup.
enum Templates {

    /// Renders a template by name with the feature's `name` and selection-derived boolean flags.
    /// - Parameter templateName: Template key (without `.stencil` suffix).
    /// - Parameter name: Feature type name injected as `{{ name }}`.
    /// - Parameter selection: Used to populate `hasView`, `hasViewModel`, etc. in the context.
    static func render(
        _ templateName: String,
        name: String,
        selection: FeatureFileSelection = FeatureFileSelection(including: [])
    ) throws -> String {
        var context = selection.contextMap
        context["name"] = name
        return try TemplateRenderer.render("\(templateName).stencil", context: context)
    }

    /// Renders the standard file-header comment block with project/author/date metadata.
    static func fileHeader(fileName: String, context: FileHeaderContext) throws -> String {
        let ctx: [String: Any] = [
            "fileName":    fileName,
            "projectName": context.projectName,
            "authorName":  context.authorName,
            "createdDate": context.createdDate,
        ]
        return try TemplateRenderer.render("fileHeader.stencil", context: ctx)
    }
}
