import Foundation
import Darwin

/// Raw byte values for special terminal input characters.
private enum TermChar {
    static let ctrlC   : UInt8 = 3
    static let quit     : UInt8 = 113
    static let newline  : UInt8 = 10
    static let carriage : UInt8 = 13
    static let space    : UInt8 = 32
    static let esc      : UInt8 = 27
    static let lbracket : UInt8 = 91
    static let up       : UInt8 = 65
    static let down     : UInt8 = 66
    static let y        : UInt8 = 121
    static let Y        : UInt8 = 89
    static let n        : UInt8 = 110
    static let N        : UInt8 = 78
}

/// Parsed terminal key event returned by `Terminal.readKey()`.
enum TerminalKey {
    case up
    case down
    case space
    case enter
    case quit
    case unknown
}

/// Interactive terminal utilities: raw mode, keyboard input, selection prompts.
enum Terminal {
    /// Temporarily switches stdin to raw (non-canonical) mode, executes `work`,
    /// then restores the original terminal settings.
    static func withRawMode<T>(_ work: () throws -> T) throws -> T {
        let fd = STDIN_FILENO
        var original = termios()

        guard tcgetattr(fd, &original) == 0 else {
            throw ForgeError.invalidArguments("Unable to read terminal settings.")
        }

        var raw = original
        raw.c_lflag &= ~tcflag_t(ECHO | ICANON)
        // VMIN = at least 1 byte before returning
        raw.c_cc.16 = 1
        // VTIME = no timeout
        raw.c_cc.17 = 0

        guard tcsetattr(fd, TCSAFLUSH, &raw) == 0 else {
            throw ForgeError.invalidArguments("Unable to enable interactive terminal mode.")
        }

        defer {
            _ = tcsetattr(fd, TCSAFLUSH, &original)
            showCursor()
        }

        return try work()
    }

    /// Reads one byte from stdin and interprets it as a `TerminalKey`.
    /// Supports arrow keys (esc + `[` + A/B), Enter, Space, Ctrl+C, and 'q'.
    static func readKey() throws -> TerminalKey {
        guard let byte = readByte() else {
            return .unknown
        }

        switch byte {
        case TermChar.ctrlC, TermChar.quit:
            return .quit
        case TermChar.newline, TermChar.carriage:
            return .enter
        case TermChar.space:
            return .space
        case TermChar.esc:
            guard readByte() == TermChar.lbracket, let arrow = readByte() else {
                return .unknown
            }

            switch arrow {
            case TermChar.up:
                return .up
            case TermChar.down:
                return .down
            default:
                return .unknown
            }
        default:
            return .unknown
        }
    }

    /// Clears the terminal screen and moves the cursor to the top-left.
    static func clearScreen() {
        print("\u{001B}[2J\u{001B}[H", terminator: "")
        fflush(stdout)
    }

    /// Hides the cursor via ANSI escape sequence `?25l`.
    static func hideCursor() {
        print("\u{001B}[?25l", terminator: "")
        fflush(stdout)
    }

    /// Shows the cursor via ANSI escape sequence `?25h`.
    static func showCursor() {
        print("\u{001B}[?25h", terminator: "")
        fflush(stdout)
    }

    /// Renders an interactive arrow-key menu and returns the selected option.
    /// - Parameter title: Prompt text displayed above the list.
    /// - Parameter options: Items to choose from.
    /// - Throws: `ForgeError.cancelled` if the user presses Ctrl+C or 'q'.
    static func promptSelection<T: CustomStringConvertible>(title: String, options: [T]) throws -> T {
        var cursorIndex = 0
        let totalLines = options.count + 2

        return try withRawMode {
            hideCursor()

            var needsReposition = false

            while true {
                if needsReposition {
                    print("\u{001B}[\(totalLines)A", terminator: "")
                }
                needsReposition = true

                print("? \(title) (Use ↑/↓ arrows, Enter to confirm, q to cancel)\n", terminator: "")

                for (index, option) in options.enumerated() {
                    let cursor = index == cursorIndex ? ">" : " "
                    print("  \(cursor) \(option.description)")
                }

                fflush(stdout)

                switch try readKey() {
                case .up:
                    cursorIndex = max(0, cursorIndex - 1)
                case .down:
                    cursorIndex = min(options.count - 1, cursorIndex + 1)
                case .enter:
                    showCursor()
                    return options[cursorIndex]
                case .quit:
                    throw ForgeError.cancelled
                default:
                    continue
                }
            }
        }
    }

    /// Asks a yes/no question and returns the boolean answer.
    /// - Parameter title: Prompt text.
    /// - Parameter defaultIsYes: Whether Enter alone defaults to `true`.
    /// - Throws: `ForgeError.cancelled` on Ctrl+C or 'q'.
    static func promptYesNo(title: String, defaultIsYes: Bool = false) throws -> Bool {
        return try withRawMode {
            hideCursor()

            while true {
                let hint = defaultIsYes ? "(Y/n)" : "(y/N)"
                print("? \(title) \(hint)\n", terminator: "")

                guard let byte = readByte() else { continue }

                print("\u{001B}[2A", terminator: "")
                fflush(stdout)

                if byte == TermChar.y || byte == TermChar.Y {
                    showCursor()
                    return true
                } else if byte == TermChar.n || byte == TermChar.N {
                    showCursor()
                    return false
                } else if byte == TermChar.newline || byte == TermChar.carriage {
                    showCursor()
                    return defaultIsYes
                } else if byte == TermChar.ctrlC || byte == TermChar.quit {
                    throw ForgeError.cancelled
                }
            }
        }
    }

    /// Reads a single raw byte from stdin using the `read()` syscall.
    private static func readByte() -> UInt8? {
        var byte: UInt8 = 0
        let count = read(STDIN_FILENO, &byte, 1)
        return count == 1 ? byte : nil
    }
}

