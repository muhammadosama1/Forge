import Foundation

/// A rendered file ready to be written to disk.
struct GeneratedFile {
    /// Target filesystem path.
    let url: URL
    /// Full file contents (header + body).
    let content: String
}

/// Maps a `FeatureFile` role to the concrete template name used during rendering.
struct TemplateSpec {
    /// The logical file role (view, viewModel, interactor, etc.).
    let file: FeatureFile
    /// Name of the template without the `.stencil` extension, e.g. `"viewModel"`.
    let templateName: String
}

/// Context values injected into the `fileHeader.stencil` template.
struct FileHeaderContext {
    /// Name of the Xcode project or the parent folder.
    let projectName: String
    /// Full user name (from the system account), falling back to `$USER`.
    let authorName: String
    /// Current date formatted as `M/d/yy`.
    let createdDate: String

    /// Shared formatter — DateFormatter is expensive; initialise once.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "M/d/yy"
        return formatter
    }()

    /// Derives project name, author, and date from the environment.
    /// - Parameter projectPath: Target directory (used as fallback project name).
    /// - Parameter xcodeProject: Optional `.xcodeproj` URL for a better project name.
    init(projectPath: URL, xcodeProject: URL?) {
        if let xcodeProject {
            projectName = xcodeProject.deletingPathExtension().lastPathComponent
        } else {
            projectName = projectPath.lastPathComponent
        }

        let fullUserName = NSFullUserName()
        authorName = fullUserName.isEmpty
            ? (ProcessInfo.processInfo.environment["USER"] ?? "User")
            : fullUserName

        createdDate = FileHeaderContext.dateFormatter.string(from: Date())
    }
}
