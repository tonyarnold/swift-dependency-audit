import Foundation

public struct GitHubActionsOutput {
    
    public static func error(file: String, line: Int? = nil, message: String) -> String {
        var parameters = "file=\(file)"
        if let line = line {
            parameters += ",line=\(line)"
        }
        return "::\("error") \(parameters)::\(message)"
    }
    
    public static func warning(file: String, line: Int? = nil, message: String) -> String {
        var parameters = "file=\(file)"
        if let line = line {
            parameters += ",line=\(line)"
        }
        return "::\("warning") \(parameters)::\(message)"
    }
    
    public static func notice(file: String, line: Int? = nil, message: String) -> String {
        var parameters = "file=\(file)"
        if let line = line {
            parameters += ",line=\(line)"
        }
        return "::\("notice") \(parameters)::\(message)"
    }
    
    public static func missingDependencyError(dependency: String, file: String, line: Int? = nil) -> String {
        return error(
            file: file,
            line: line,
            message: "Missing dependency '\(dependency)' is imported but not declared in Package.swift"
        )
    }
    
    public static func unusedDependencyWarning(dependency: String, packageFile: String) -> String {
        return warning(
            file: packageFile,
            message: "Unused dependency '\(dependency)' is declared but never imported"
        )
    }
}