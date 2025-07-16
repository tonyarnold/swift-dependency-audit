import Foundation
import RegexBuilder

public actor ImportScanner {
    
    private let importRegex = Regex {
        Anchor.startOfLine
        ZeroOrMore(.whitespace)
        // Handle optional attributes like @testable, @preconcurrency, @_exported, etc.
        ZeroOrMore {
            "@"
            OneOrMore(.word)
            OneOrMore(.whitespace)
        }
        // Handle optional access level modifiers like private, internal, public, etc.
        Optionally {
            ChoiceOf {
                "private"
                "internal"
                "public"
                "open"
                "fileprivate"
            }
            OneOrMore(.whitespace)
        }
        "import"
        OneOrMore(.whitespace)
        Capture {
            OneOrMore(.word)
        }
        Optionally {
            ZeroOrMore {
                "."
                OneOrMore(.word)
            }
        }
        ZeroOrMore(.whitespace)
        Anchor.endOfLine
    }
    
    public init() {}
    
    public func scanFile(at path: String, customWhitelist: Set<String> = []) async throws -> Set<ImportInfo> {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        return await scanContent(content, customWhitelist: customWhitelist)
    }
    
    public func scanContent(_ content: String, customWhitelist: Set<String> = []) async -> Set<ImportInfo> {
        var imports = Set<ImportInfo>()
        
        let lines = content.components(separatedBy: .newlines)
        
        for (lineIndex, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Skip comments and empty lines
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("//") || trimmedLine.hasPrefix("/*") {
                continue
            }
            
            if let match = trimmedLine.firstMatch(of: importRegex) {
                let moduleName = String(match.1)
                let isTestable = trimmedLine.contains("@testable")
                let lineNumber = lineIndex + 1 // Convert to 1-based line numbering
                
                // Skip standard library, platform imports, and custom whitelist items
                if !isStandardLibraryModule(moduleName) && !customWhitelist.contains(moduleName) {
                    imports.insert(ImportInfo(moduleName: moduleName, isTestable: isTestable, lineNumber: lineNumber))
                }
            }
        }
        
        return imports
    }
    
    public func scanDirectory(at path: String, targetName: String, customWhitelist: Set<String> = []) async throws -> [SourceFile] {
        let fileManager = FileManager.default
        
        // Try Sources directory first
        var sourcePath = URL(fileURLWithPath: path).appendingPathComponent("Sources").appendingPathComponent(targetName)
        
        // If not found in Sources, try Tests directory for test targets
        if !fileManager.fileExists(atPath: sourcePath.path) {
            sourcePath = URL(fileURLWithPath: path).appendingPathComponent("Tests").appendingPathComponent(targetName)
        }
        
        guard fileManager.fileExists(atPath: sourcePath.path) else {
            throw ScannerError.sourceDirectoryNotFound(sourcePath.path)
        }
        
        let swiftFiles = try await findSwiftFiles(in: sourcePath.path)
        var sourceFiles: [SourceFile] = []
        
        for filePath in swiftFiles {
            do {
                let imports = try await scanFile(at: filePath, customWhitelist: customWhitelist)
                sourceFiles.append(SourceFile(path: filePath, imports: imports))
            } catch {
                throw ScannerError.fileReadError(filePath, error)
            }
        }
        
        return sourceFiles
    }
    
    private func findSwiftFiles(in directory: String) async throws -> [String] {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                let fileManager = FileManager.default
                let directoryURL = URL(fileURLWithPath: directory)
                
                guard let enumerator = fileManager.enumerator(
                    at: directoryURL,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) else {
                    continuation.resume(returning: [])
                    return
                }
                
                var swiftFiles: [String] = []
                
                while let fileURL = enumerator.nextObject() as? URL {
                    do {
                        let fileAttributes = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                        if fileAttributes.isRegularFile == true && fileURL.pathExtension == "swift" {
                            swiftFiles.append(fileURL.path)
                        }
                    } catch {
                        // Skip files we can't read attributes for
                        continue
                    }
                }
                
                continuation.resume(returning: swiftFiles)
            }
        }
    }
    
    private func isStandardLibraryModule(_ moduleName: String) -> Bool {
        // Common Swift standard library and platform modules that don't require explicit dependencies
        let standardModules: Set<String> = [
            "Swift",
            "Foundation",
            "Dispatch",
            "CoreFoundation",
            "Darwin",
            "Glibc",
            "WinSDK",
            "XCTest",
            "SwiftUI",
            "UIKit",
            "AppKit",
            "Cocoa",
            "CoreData",
            "CoreGraphics",
            "CoreImage",
            "CoreLocation",
            "CoreText",
            "QuartzCore",
            "Metal",
            "MetalKit",
            "AVFoundation",
            "Network",
            "Combine",
            "CryptoKit",
            "OSLog",
            "os",
            "RegexBuilder"
        ]
        
        return standardModules.contains(moduleName)
    }
}