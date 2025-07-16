import Foundation

public struct Target: Sendable {
    public let name: String
    public let type: TargetType
    public let dependencies: [String]
    public let path: String?
    
    public init(name: String, type: TargetType, dependencies: [String], path: String?) {
        self.name = name
        self.type = type
        self.dependencies = dependencies
        self.path = path
    }
    
    public enum TargetType: Sendable {
        case executable
        case library
        case test
        case systemLibrary
        case binaryTarget
        case plugin
    }
}

public struct PackageInfo: Sendable {
    public let name: String
    public let targets: [Target]
    public let dependencies: [String]
    public let path: String
    
    public init(name: String, targets: [Target], dependencies: [String], path: String) {
        self.name = name
        self.targets = targets
        self.dependencies = dependencies
        self.path = path
    }
}

public struct ImportInfo: Sendable, Hashable {
    public let moduleName: String
    public let isTestable: Bool
    public let lineNumber: Int?
    
    public init(moduleName: String, isTestable: Bool = false, lineNumber: Int? = nil) {
        self.moduleName = moduleName
        self.isTestable = isTestable
        self.lineNumber = lineNumber
    }
}

public struct SourceFile: Sendable {
    public let path: String
    public let imports: Set<ImportInfo>
    
    public init(path: String, imports: Set<ImportInfo>) {
        self.path = path
        self.imports = imports
    }
}

public struct AnalysisResult: Sendable {
    public let target: Target
    public let missingDependencies: Set<String>
    public let unusedDependencies: Set<String>
    public let correctDependencies: Set<String>
    public let sourceFiles: [SourceFile]
    
    public var hasIssues: Bool {
        !missingDependencies.isEmpty || !unusedDependencies.isEmpty
    }
    
    public init(target: Target, missingDependencies: Set<String>, unusedDependencies: Set<String>, correctDependencies: Set<String>, sourceFiles: [SourceFile]) {
        self.target = target
        self.missingDependencies = missingDependencies
        self.unusedDependencies = unusedDependencies
        self.correctDependencies = correctDependencies
        self.sourceFiles = sourceFiles
    }
}

public struct PackageAnalysis: Sendable, Codable {
    public let packageName: String
    public let targets: [TargetAnalysis]
    
    public init(packageName: String, targets: [TargetAnalysis]) {
        self.packageName = packageName
        self.targets = targets
    }
    
    public struct TargetAnalysis: Sendable, Codable {
        public let name: String
        public let missingDependencies: [String]
        public let unusedDependencies: [String]
        public let correctDependencies: [String]
        
        public init(from result: AnalysisResult) {
            self.name = result.target.name
            self.missingDependencies = Array(result.missingDependencies).sorted()
            self.unusedDependencies = Array(result.unusedDependencies).sorted()
            self.correctDependencies = Array(result.correctDependencies).sorted()
        }
    }
}

public enum ScannerError: Error, LocalizedError {
    case packageNotFound(String)
    case invalidPackageFile(String)
    case sourceDirectoryNotFound(String)
    case fileReadError(String, Error)
    
    public var errorDescription: String? {
        switch self {
        case .packageNotFound(let path):
            return "Package.swift not found at path: \(path)"
        case .invalidPackageFile(let reason):
            return "Invalid Package.swift: \(reason)"
        case .sourceDirectoryNotFound(let path):
            return "Source directory not found: \(path)"
        case .fileReadError(let path, let error):
            return "Failed to read file at \(path): \(error.localizedDescription)"
        }
    }
}