import Foundation

/// Entry point for the `forge` CLI tool.
@main
struct Forge {
    /// Parses CLI arguments, runs the feature generator, and prints results.
    /// Exits with code 1 on any error.
    static func main() {
        // Strip executable path; keep only user-supplied CLI arguments
        let args = Array(CommandLine.arguments.dropFirst())

        // Display help screen if no arguments provided or if help flag passed (-h, --help, help)
        if args.isEmpty || args.contains(where: Command.isHelpFlag) {
            print(Command.help)
            return
        }

        do {
            // Parse arguments into a structured command (prompts interactively if flags are missing)
            let command = try Command.parse(arguments: args)
            // Execute feature generation and file creation
            try command.run()
        } catch let error as ForgeError {
            // User intentionally cancelled an interactive prompt (Ctrl+C or 'q')
            if case .cancelled = error {
                fputs("\(error.message)\n", stderr)
            } else {
                // Command syntax or file conflict errors: print actionable error message and usage guide
                fputs("Error: \(error.message)\n\n\(Command.usage)\n", stderr)
            }
            Foundation.exit(1)
        } catch {
            // Unexpected runtime or filesystem error
            fputs("Error: \(error.localizedDescription)\n", stderr)
            Foundation.exit(1)
        }
    }
}
