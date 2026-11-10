import Foundation

/// Entry point for the `forge` CLI tool.
@main
struct Forge {
    /// Parses CLI arguments, runs the feature generator, and prints results.
    /// Exits with code 1 on any error.
    static func main() {
        // Strip executable path; keep only user-supplied CLI arguments
        let args = Array(CommandLine.arguments.dropFirst())

        // The bare word 'help' is a command only when supplied on its own.
        if args.isEmpty || (args.count == 1 && Command.isHelpFlag(args[0])) ||
            args.contains("-h") || args.contains("--help") {
            print(Command.help)
            return
        }

        // Print version string and exit if -v / --version was passed
        if args.count == 1 && Command.isVersionFlag(args[0]) {
            print("forge \(Command.version)")
            return
        }

        do {
            // Scaffold project configuration standard
            if args.first == "init" {
                try Command.runInit(arguments: args)
                return
            }

            // Parse arguments into a structured command (prompts interactively if flags are missing)
            let command = try Command.parse(arguments: args)
            // Execute feature generation and file creation
            try command.run()
        } catch let error as ForgeError {
            switch error {
            case .cancelled:
                // User intentionally cancelled an interactive prompt (Ctrl+C or 'q')
                fputs("\(error.message)\n", stderr)
            case .invalidArguments(let message):
                fputs("Error: \(message)\n", stderr)
            case .invalidFeatureName, .fileAlreadyExists:
                // Validation or file conflict errors: print clear error without dumping full usage
                fputs("Error: \(error.message)\n", stderr)
            }
            Foundation.exit(1)
        } catch {
            // Unexpected runtime or filesystem error
            fputs("Error: \(error.localizedDescription)\n", stderr)
            Foundation.exit(1)
        }
    }
}
