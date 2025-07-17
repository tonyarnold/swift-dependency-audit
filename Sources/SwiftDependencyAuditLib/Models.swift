import Foundation

public struct DependencyInfo: Sendable {
    public let name: String
    public let lineNumber: Int?
    
    public init(name: String, lineNumber: Int? = nil) {
        self.name = name
        self.lineNumber = lineNumber
    }
}

public struct Target: Sendable {
    public let name: String
    public let type: TargetType
    public let dependencies: [String]
    public let dependencyInfo: [DependencyInfo]
    public let path: String?
    
    public init(name: String, type: TargetType, dependencies: [String], path: String?) {
        self.name = name
        self.type = type
        self.dependencies = dependencies
        self.dependencyInfo = dependencies.map { DependencyInfo(name: $0) }
        self.path = path
    }
    
    public init(name: String, type: TargetType, dependencyInfo: [DependencyInfo], path: String?) {
        self.name = name
        self.type = type
        self.dependencies = dependencyInfo.map { $0.name }
        self.dependencyInfo = dependencyInfo
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

public struct Product: Sendable {
    public let name: String
    public let type: ProductType
    public let targets: [String]
    public let packageName: String
    
    public init(name: String, type: ProductType, targets: [String], packageName: String) {
        self.name = name
        self.type = type
        self.targets = targets
        self.packageName = packageName
    }
    
    public enum ProductType: Sendable {
        case library
        case executable
        case plugin
    }
}

public struct ExternalPackageDependency: Sendable {
    public let packageName: String
    public let url: String?
    public let path: String?
    
    public init(packageName: String, url: String? = nil, path: String? = nil) {
        self.packageName = packageName
        self.url = url
        self.path = path
    }
}

public struct ExternalPackage: Sendable {
    public let name: String
    public let products: [Product]
    public let path: String
    
    public init(name: String, products: [Product], path: String) {
        self.name = name
        self.products = products
        self.path = path
    }
}

public struct PackageInfo: Sendable {
    public let name: String
    public let targets: [Target]
    public let dependencies: [String]
    public let products: [Product]
    public let externalDependencies: [ExternalPackageDependency]
    public let path: String
    
    public init(name: String, targets: [Target], dependencies: [String], products: [Product] = [], externalDependencies: [ExternalPackageDependency] = [], path: String) {
        self.name = name
        self.targets = targets
        self.dependencies = dependencies
        self.products = products
        self.externalDependencies = externalDependencies
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

public struct ProductSatisfiedDependency: Sendable {
    public let importName: String
    public let productName: String
    public let packageName: String
    
    public init(importName: String, productName: String, packageName: String) {
        self.importName = importName
        self.productName = productName
        self.packageName = packageName
    }
}

public struct AnalysisResult: Sendable {
    public let target: Target
    public let missingDependencies: Set<String>
    public let unusedDependencies: Set<String>
    public let correctDependencies: Set<String>
    public let productSatisfiedDependencies: [ProductSatisfiedDependency]
    public let redundantDirectDependencies: Set<String>
    public let sourceFiles: [SourceFile]
    
    public var hasIssues: Bool {
        !missingDependencies.isEmpty || !unusedDependencies.isEmpty || !redundantDirectDependencies.isEmpty
    }
    
    public init(target: Target, missingDependencies: Set<String>, unusedDependencies: Set<String>, correctDependencies: Set<String>, productSatisfiedDependencies: [ProductSatisfiedDependency] = [], redundantDirectDependencies: Set<String> = [], sourceFiles: [SourceFile]) {
        self.target = target
        self.missingDependencies = missingDependencies
        self.unusedDependencies = unusedDependencies
        self.correctDependencies = correctDependencies
        self.productSatisfiedDependencies = productSatisfiedDependencies
        self.redundantDirectDependencies = redundantDirectDependencies
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
        public let productSatisfiedDependencies: [ProductSatisfiedDependencyInfo]
        public let redundantDirectDependencies: [String]
        
        public init(from result: AnalysisResult) {
            self.name = result.target.name
            self.missingDependencies = Array(result.missingDependencies).sorted()
            self.unusedDependencies = Array(result.unusedDependencies).sorted()
            self.correctDependencies = Array(result.correctDependencies).sorted()
            self.productSatisfiedDependencies = result.productSatisfiedDependencies.map { ProductSatisfiedDependencyInfo(from: $0) }.sorted { $0.importName < $1.importName }
            self.redundantDirectDependencies = Array(result.redundantDirectDependencies).sorted()
        }
    }
    
    public struct ProductSatisfiedDependencyInfo: Sendable, Codable {
        public let importName: String
        public let productName: String
        public let packageName: String
        
        public init(from dependency: ProductSatisfiedDependency) {
            self.importName = dependency.importName
            self.productName = dependency.productName
            self.packageName = dependency.packageName
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