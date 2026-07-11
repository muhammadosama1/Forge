import Foundation

/// All user-facing errors that the tool can produce.
enum ForgeError: Error {
    /// Invalid CLI arguments; associated value is the specific error message.
    case invalidArguments(String)
    /// Feature name failed validation; associated value is the raw user input.
    case invalidFeatureName(String)
    /// Refusing to overwrite an existing file; associated value is the file path.
    case fileAlreadyExists(String)
    /// User cancelled an interactive prompt (Ctrl+C or 'q').
    case cancelled

    /// Human-readable error message suitable for stderr output.
    var message: String {
        switch self {
        case .invalidArguments(let message):
            return message
        case .invalidFeatureName(let name):
            return "'\(name)' is not a valid feature name. Use letters, numbers, spaces, dashes, or underscores."
        case .fileAlreadyExists(let path):
            return "Refusing to overwrite existing file: \(path)"
        case .cancelled:
            return "Cancelled."
        }
    }
}

