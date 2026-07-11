import Foundation

/// Entry point for the `forge` CLI tool.
@main
struct Forge {
    /// Parses CLI arguments, runs the feature generator, and prints results.
    /// Exits with code 1 on any error.
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())

        if args.isEmpty || args.contains(where: Command.isHelpFlag) {
            print(Command.help)
            return
        }

        do {
            let command = try Command.parse(arguments: args)
            try command.run()
        } catch let error as ForgeError {
            if case .cancelled = error {
                fputs("\(error.message)\n", stderr)
            } else {
                fputs("Error: \(error.message)\n\n\(Command.usage)\n", stderr)
            }
            Foundation.exit(1)
        } catch {
            fputs("Error: \(error.localizedDescription)\n", stderr)
            Foundation.exit(1)
        }
    }
}
