import Foundation

public actor DependencyAnalyzer {
    private let importScanner = ImportScanner()
    
    public init() {}
    
    public func analyzeTarget(_ target: Target, in packageInfo: PackageInfo, customWhitelist: Set<String> = []) async throws -> AnalysisResult {
        // Scan source files for imports
        let sourceFiles = try await importScanner.scanDirectory(at: packageInfo.path, targetName: target.name, customWhitelist: customWhitelist)
        
        // Collect all unique imports from source files
        var allImports = Set<String>()
        for sourceFile in sourceFiles {
            for importInfo in sourceFile.imports {
                allImports.insert(importInfo.moduleName)
            }
        }
        
        // Convert declared dependencies to a set for comparison
        let declaredDependencies = Set(target.dependencies)
        
        // Find missing dependencies (imports without declarations)
        let missingDependencies = allImports.subtracting(declaredDependencies)
            .subtracting(getInternalModules(from: packageInfo, excluding: target))
        
        // Find unused dependencies (declarations without imports)
        let unusedDependencies = declaredDependencies.subtracting(allImports)
        
        // Find correct dependencies (both declared and used)
        let correctDependencies = declaredDependencies.intersection(allImports)
        
        return AnalysisResult(
            target: target,
            missingDependencies: missingDependencies,
            unusedDependencies: unusedDependencies,
            correctDependencies: correctDependencies,
            sourceFiles: sourceFiles
        )
    }
    
    public func analyzePackage(_ packageInfo: PackageInfo, targetFilter: String? = nil, excludeTests: Bool = false, customWhitelist: Set<String> = []) async throws -> [AnalysisResult] {
        var results: [AnalysisResult] = []
        
        for target in packageInfo.targets {
            // Apply filters
            if let targetFilter = targetFilter, target.name != targetFilter {
                continue
            }
            
            if excludeTests && target.type == .test {
                continue
            }
            
            do {
                let result = try await analyzeTarget(target, in: packageInfo, customWhitelist: customWhitelist)
                results.append(result)
            } catch ScannerError.sourceDirectoryNotFound {
                // Skip targets without source directories (might be system targets)
                continue
            }
        }
        
        return results
    }
    
    private func getInternalModules(from packageInfo: PackageInfo, excluding currentTarget: Target) -> Set<String> {
        // Get names of other targets in the same package that can be imported
        return Set(packageInfo.targets
            .filter { $0.name != currentTarget.name && $0.type != .test }
            .map { $0.name })
    }
    
    public func generateReport(for results: [AnalysisResult], packageName: String, verbose: Bool = false) async -> String {
        var output: [String] = []
        
        output.append(ColorOutput.bold("📦 Package: \(packageName)"))
        output.append("")
        
        let totalIssues = results.reduce(0) { $0 + ($1.hasIssues ? 1 : 0) }
        let totalMissing = results.reduce(0) { $0 + $1.missingDependencies.count }
        let totalUnused = results.reduce(0) { $0 + $1.unusedDependencies.count }
        
        if totalIssues == 0 {
            output.append(ColorOutput.success("All dependencies are correctly declared! ✨"))
        } else {
            output.append(ColorOutput.info("Found \(totalIssues) target(s) with dependency issues"))
            output.append(ColorOutput.info("Total missing: \(totalMissing), unused: \(totalUnused)"))
        }
        output.append("")
        
        for result in results {
            output.append(await generateTargetReport(result, verbose: verbose))
            output.append("")
        }
        
        return output.joined(separator: "\n")
    }
    
    private func generateTargetReport(_ result: AnalysisResult, verbose: Bool) async -> String {
        var output: [String] = []
        
        let targetTypeIcon = switch result.target.type {
        case .executable: "🔧"
        case .library: "📚"
        case .test: "🧪"
        }
        
        output.append("\(targetTypeIcon) Target: \(ColorOutput.targetName(result.target.name))")
        
        if !result.hasIssues {
            let successMessage = ColorOutput.success("All dependencies correct")
            output.append("  " + successMessage)
            if verbose {
                if !result.correctDependencies.isEmpty {
                    output.append("  Correct dependencies:")
                    for dep in result.correctDependencies.sorted() {
                        let depName = ColorOutput.dependencyName(dep)
                        output.append("    • \(depName)")
                    }
                }
            }
            return output.joined(separator: "\n")
        }
        
        // Missing dependencies
        if !result.missingDependencies.isEmpty {
            let errorMessage = ColorOutput.error("Missing dependencies (\(result.missingDependencies.count)):")
            output.append("  " + errorMessage)
            for dep in result.missingDependencies.sorted() {
                let depName = ColorOutput.dependencyName(dep)
                output.append("    • \(depName)")
            }
        }
        
        // Unused dependencies
        if !result.unusedDependencies.isEmpty {
            let warningMessage = ColorOutput.warning("Unused dependencies (\(result.unusedDependencies.count)):")
            output.append("  " + warningMessage)
            for dep in result.unusedDependencies.sorted() {
                let depName = ColorOutput.dependencyName(dep)
                output.append("    • \(depName)")
            }
        }
        
        // Correct dependencies (only in verbose mode)
        if verbose && !result.correctDependencies.isEmpty {
            let successMessage = ColorOutput.success("Correct dependencies (\(result.correctDependencies.count)):")
            output.append("  " + successMessage)
            for dep in result.correctDependencies.sorted() {
                let depName = ColorOutput.dependencyName(dep)
                output.append("    • \(depName)")
            }
        }
        
        if verbose {
            let dimMessage = ColorOutput.dim("Source files: \(result.sourceFiles.count)")
            output.append("  " + dimMessage)
        }
        
        return output.joined(separator: "\n")
    }
    
    public func generateJSONReport(for results: [AnalysisResult], packageName: String) async throws -> String {
        let analysis = PackageAnalysis(
            packageName: packageName,
            targets: results.map { PackageAnalysis.TargetAnalysis(from: $0) }
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(analysis)
        
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw ScannerError.invalidPackageFile("Failed to encode JSON")
        }
        
        return jsonString
    }
}
