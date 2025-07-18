import Foundation

public struct XcodeOutput {
    
    public static func error(file: String, line: Int? = nil, message: String) -> String {
        if let line = line {
            return "\(file):\(line): error: \(message)"
        } else {
            return "\(file): error: \(message)"
        }
    }
    
    public static func warning(file: String, line: Int? = nil, message: String) -> String {
        if let line = line {
            return "\(file):\(line): warning: \(message)"
        } else {
            return "\(file): warning: \(message)"
        }
    }
    
    public static func note(file: String, line: Int? = nil, message: String) -> String {
        if let line = line {
            return "\(file):\(line): note: \(message)"
        } else {
            return "\(file): note: \(message)"
        }
    }
    
    public static func missingDependencyError(dependency: String, file: String, line: Int? = nil) -> String {
        return error(
            file: file,
            line: line,
            message: "Missing dependency '\(dependency)' is imported but not declared in Package.swift"
        )
    }
    
    public static func unusedDependencyWarning(dependency: String, targetName: String, packageFile: String, line: Int? = nil) -> String {
        return warning(
            file: packageFile,
            line: line,
            message: "Unused dependency '\(dependency)' is declared but never imported into \(targetName) target"
        )
    }
}