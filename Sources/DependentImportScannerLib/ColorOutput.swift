import Foundation

public struct ColorOutput {
    private static let terminalSupportsColor: Bool = {
        guard let term = ProcessInfo.processInfo.environment["TERM"],
            !term.isEmpty,
            term != "dumb"
        else {
            return false
        }
        return isatty(STDOUT_FILENO) != 0
    }()
    
    nonisolated(unsafe) public static var colorEnabled: Bool = terminalSupportsColor

    private enum ANSIColor: String {
        case reset = "\u{001B}[0m"
        case bold = "\u{001B}[1m"
        case red = "\u{001B}[31m"
        case green = "\u{001B}[32m"
        case yellow = "\u{001B}[33m"
        case blue = "\u{001B}[34m"
        case magenta = "\u{001B}[35m"
        case cyan = "\u{001B}[36m"
        case white = "\u{001B}[37m"
        case brightRed = "\u{001B}[91m"
        case brightGreen = "\u{001B}[92m"
        case brightYellow = "\u{001B}[93m"
        case brightBlue = "\u{001B}[94m"
    }

    private static func colorize(_ text: String, with color: ANSIColor) -> String {
        guard colorEnabled else { return text }
        return "\(color.rawValue)\(text)\(ANSIColor.reset.rawValue)"
    }

    public static func success(_ text: String) -> String {
        colorize("✅ \(text)", with: .brightGreen)
    }

    public static func error(_ text: String) -> String {
        colorize("❌ \(text)", with: .brightRed)
    }

    public static func warning(_ text: String) -> String {
        colorize("⚠️  \(text)", with: .brightYellow)
    }

    public static func info(_ text: String) -> String {
        colorize("🔍 \(text)", with: .brightBlue)
    }

    public static func bold(_ text: String) -> String {
        guard colorEnabled else { return text }
        return "\(ANSIColor.bold.rawValue)\(text)\(ANSIColor.reset.rawValue)"
    }

    public static func dim(_ text: String) -> String {
        colorize(text, with: .white)
    }

    public static func targetName(_ text: String) -> String {
        colorize(text, with: .cyan)
    }

    public static func dependencyName(_ text: String) -> String {
        colorize(text, with: .magenta)
    }
}
