import Foundation

/// Parser backend selection
public enum ParserBackend: String, CaseIterable, Sendable {
    case swiftSyntax = "swiftsyntax"
    case regex = "regex"
    case auto = "auto"
    
    public var description: String {
        switch self {
        case .swiftSyntax:
            return "SwiftSyntax (AST-based parsing)"
        case .regex:
            return "Regex (pattern-based parsing)"
        case .auto:
            return "Auto (SwiftSyntax with regex fallback)"
        }
    }
}

/// Unified package parser that supports multiple backends with automatic fallback
public final class UnifiedPackageParser: Sendable {
    private let backend: ParserBackend
    private let swiftSyntaxParser: SwiftSyntaxPackageParser
    private let regexParser: PackageParser
    private let verbose: Bool
    
    public init(backend: ParserBackend = .auto, verbose: Bool = false) {
        self.backend = backend
        self.verbose = verbose
        self.swiftSyntaxParser = SwiftSyntaxPackageParser()
        self.regexParser = PackageParser()
    }
    
    public func parsePackage(at path: String) async throws -> PackageInfo {
        switch backend {
        case .swiftSyntax:
            if verbose {
                print("Using SwiftSyntax parser")
            }
            return try await swiftSyntaxParser.parsePackage(at: path)
            
        case .regex:
            if verbose {
                print("Using regex parser")
            }
            return try await regexParser.parsePackage(at: path)
            
        case .auto:
            do {
                if verbose {
                    print("Attempting SwiftSyntax parser...")
                }
                let result = try await swiftSyntaxParser.parsePackage(at: path)
                if verbose {
                    print("✅ SwiftSyntax parser succeeded")
                }
                return result
            } catch {
                if verbose {
                    print("⚠️ SwiftSyntax parser failed, falling back to regex parser: \(error)")
                }
                return try await regexParser.parsePackage(at: path)
            }
        }
    }
    
    public func parseContent(_ content: String, packageDirectory: String) async throws -> PackageInfo {
        switch backend {
        case .swiftSyntax:
            if verbose {
                print("Using SwiftSyntax parser")
            }
            return try await swiftSyntaxParser.parseContent(content, packageDirectory: packageDirectory)
            
        case .regex:
            if verbose {
                print("Using regex parser")
            }
            return try await regexParser.parseContent(content, packageDirectory: packageDirectory)
            
        case .auto:
            do {
                if verbose {
                    print("Attempting SwiftSyntax parser...")
                }
                let result = try await swiftSyntaxParser.parseContent(content, packageDirectory: packageDirectory)
                if verbose {
                    print("✅ SwiftSyntax parser succeeded")
                }
                return result
            } catch {
                if verbose {
                    print("⚠️ SwiftSyntax parser failed, falling back to regex parser: \(error)")
                }
                return try await regexParser.parseContent(content, packageDirectory: packageDirectory)
            }
        }
    }
}