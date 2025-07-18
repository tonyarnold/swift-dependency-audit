import Foundation

public actor DependencyAnalyzer {
    private let importScanner = ImportScanner()
    private let externalPackageResolver = ExternalPackageResolver()
    
    public init() {}
    
    public func analyzeTarget(_ target: Target, in packageInfo: PackageInfo, customWhitelist: Set<String> = []) async throws -> AnalysisResult {
        // Skip source scanning for target types that don't have Swift source files
        if target.type == .systemLibrary || target.type == .binaryTarget {
            return AnalysisResult(
                target: target,
                missingDependencies: [],
                unusedDependencies: [],
                correctDependencies: [],
                sourceFiles: []
            )
        }
        
        // Scan source files for imports
        let sourceFiles = try await importScanner.scanDirectory(at: packageInfo.path, targetName: target.name, customWhitelist: customWhitelist)
        
        // Collect all unique imports from source files
        var allImports = Set<String>()
        for sourceFile in sourceFiles {
            for importInfo in sourceFile.imports {
                allImports.insert(importInfo.moduleName)
            }
        }
        
        // Resolve external packages to build product-to-target mappings
        let externalPackages = try await externalPackageResolver.resolveExternalPackages(for: packageInfo)
        let productToTargetMapping = await externalPackageResolver.buildProductToTargetMapping(from: externalPackages)
        
        // Enhanced dependency analysis with product support
        let analysisResult = analyzeWithProductSupport(
            target: target,
            allImports: allImports,
            packageInfo: packageInfo,
            externalPackages: externalPackages,
            productToTargetMapping: productToTargetMapping,
            sourceFiles: sourceFiles,
            customWhitelist: customWhitelist
        )
        
        return analysisResult
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
    
    public func analyzeWithProductSupport(
        target: Target,
        allImports: Set<String>,
        packageInfo: PackageInfo,
        externalPackages: [ExternalPackage],
        productToTargetMapping: [String: [String]],
        sourceFiles: [SourceFile],
        customWhitelist: Set<String> = []
    ) -> AnalysisResult {
        
        let internalModules = getInternalModules(from: packageInfo, excluding: target)
        
        // Find which imports are satisfied by products
        var productSatisfiedDependencies: [ProductSatisfiedDependency] = []
        var productSatisfiedImports = Set<String>()
        var redundantDirectDependencies: [RedundantDirectDependency] = []
        
        // Check for redundant direct dependencies - target dependencies that are also covered by product dependencies
        let productDependencies = Set(target.dependencyInfo.compactMap { dep in
            if case .product = dep.type {
                return dep.name
            }
            return nil
        })
        
        let targetDependencies = Set(target.dependencyInfo.compactMap { dep in
            if case .target = dep.type {
                return dep.name
            }
            return nil
        })
        
        // For each product dependency, check if we also have redundant target dependencies
        for productDep in productDependencies {
            if let targets = productToTargetMapping[productDep] {
                // Check if any of these targets are also directly declared as target dependencies
                let redundantTargets = Set(targets).intersection(targetDependencies)
                
                // Find the package that provides this product
                if let package = externalPackages.first(where: { pkg in
                    pkg.products.contains { $0.name == productDep }
                }) {
                    // Create detailed redundant dependency entries
                    for redundantTarget in redundantTargets {
                        redundantDirectDependencies.append(
                            RedundantDirectDependency(
                                targetName: redundantTarget,
                                providingProduct: productDep,
                                packageName: package.name
                            )
                        )
                    }
                }
            }
        }
        
        // Check each import to see if it's satisfied by a product
        // Note: imports have already been filtered through the whitelist in ImportScanner
        // so we don't need to apply whitelist filtering again here
        for importName in allImports {
            // Skip if it's an internal module
            if internalModules.contains(importName) {
                continue
            }
            
            // Check if this import is satisfied by any declared product dependency
            for productDep in productDependencies {
                if let targets = productToTargetMapping[productDep], targets.contains(importName) {
                    // Find the package that provides this product
                    if let package = externalPackages.first(where: { pkg in
                        pkg.products.contains { $0.name == productDep }
                    }) {
                        productSatisfiedDependencies.append(
                            ProductSatisfiedDependency(
                                importName: importName,
                                productName: productDep,
                                packageName: package.name
                            )
                        )
                        productSatisfiedImports.insert(importName)
                        break
                    }
                }
            }
        }
        
        // Calculate dependencies as before, but exclude product-satisfied imports from missing deps
        let importsNotSatisfiedByProducts = allImports.subtracting(productSatisfiedImports)
        
        let missingDependencies = importsNotSatisfiedByProducts
            .subtracting(targetDependencies)
            .subtracting(productDependencies)
            .subtracting(internalModules)
        
        // For unused dependencies, exclude redundant direct dependencies (those covered by products)
        // and also exclude whitelisted dependencies
        let redundantTargetNames = Set(redundantDirectDependencies.map { $0.targetName })
        let nonRedundantTargetDependencies = targetDependencies.subtracting(redundantTargetNames)
        let unusedTargetDependencies = nonRedundantTargetDependencies.subtracting(allImports).subtracting(customWhitelist)
        let unusedProductDependencies = productDependencies.subtracting(allImports).subtracting(productSatisfiedImports).subtracting(customWhitelist)
        let unusedDependencies = unusedTargetDependencies.union(unusedProductDependencies)
        
        // Correct dependencies include both target dependencies and product dependencies that are actually used
        let usedProductDependencies = productDependencies.intersection(allImports)
        let correctDependencies = nonRedundantTargetDependencies.intersection(allImports).union(usedProductDependencies)
        
        return AnalysisResult(
            target: target,
            missingDependencies: missingDependencies,
            unusedDependencies: unusedDependencies,
            correctDependencies: correctDependencies,
            productSatisfiedDependencies: productSatisfiedDependencies,
            redundantDirectDependencies: redundantDirectDependencies,
            sourceFiles: sourceFiles
        )
    }

    private func getInternalModules(from packageInfo: PackageInfo, excluding currentTarget: Target) -> Set<String> {
        // Get names of other targets in the same package that can be imported
        // Exclude test targets, system libraries, and binary targets from being considered as importable modules
        return Set(packageInfo.targets
            .filter { $0.name != currentTarget.name && $0.type != .test && $0.type != .systemLibrary && $0.type != .binaryTarget }
            .map { $0.name })
    }
    
    public func generateReport(for results: [AnalysisResult], packageName: String, verbose: Bool = false, quiet: Bool = false) async -> String {
        var output: [String] = []
        
        output.append(ColorOutput.bold("📦 Package: \(packageName)"))
        output.append("")
        
        let totalIssues = results.reduce(0) { $0 + ($1.hasIssues ? 1 : 0) }
        let totalWarnings = results.reduce(0) { $0 + ($1.hasWarnings ? 1 : 0) }
        let totalMissing = results.reduce(0) { $0 + $1.missingDependencies.count }
        let totalUnused = results.reduce(0) { $0 + $1.unusedDependencies.count }
        let totalRedundant = results.reduce(0) { $0 + $1.redundantDirectDependencies.count }
        let totalProductSatisfied = results.reduce(0) { $0 + $1.productSatisfiedDependencies.count }
        
        if totalIssues == 0 && totalWarnings == 0 {
            if !quiet {
                output.append(ColorOutput.success("All dependencies are correctly declared! ✨"))
                if totalProductSatisfied > 0 {
                    output.append(ColorOutput.info("Found \(totalProductSatisfied) import(s) satisfied by product dependencies"))
                }
            }
        } else if totalIssues > 0 {
            output.append(ColorOutput.info("Found \(totalIssues) target(s) with dependency issues"))
            output.append(ColorOutput.info("Total missing: \(totalMissing), unused: \(totalUnused)"))
            if totalRedundant > 0 {
                output.append(ColorOutput.info("Total redundant direct dependencies: \(totalRedundant)"))
            }
        } else if totalWarnings > 0 {
            output.append(ColorOutput.warning("Found \(totalWarnings) target(s) with warnings"))
            if totalRedundant > 0 {
                output.append(ColorOutput.warning("Total redundant direct dependencies: \(totalRedundant)"))
            }
        }
        
        if !quiet || totalIssues > 0 || totalWarnings > 0 {
            output.append("")
        }
        
        for result in results {
            let targetReport = await generateTargetReport(result, verbose: verbose, quiet: quiet)
            if !targetReport.isEmpty {
                output.append(targetReport)
                output.append("")
            }
        }
        
        return output.joined(separator: "\n")
    }
    
    private func generateTargetReport(_ result: AnalysisResult, verbose: Bool, quiet: Bool = false) async -> String {
        var output: [String] = []
        
        let targetTypeIcon = switch result.target.type {
        case .executable: "🔧"
        case .library: "📚"
        case .test: "🧪"
        case .systemLibrary: "🏛️"
        case .binaryTarget: "📦"
        case .plugin: "🔌"
        }
        
        if !result.hasIssues && !result.hasWarnings && quiet {
            // In quiet mode, don't show targets with no issues or warnings
            return ""
        }
        
        output.append("\(targetTypeIcon) Target: \(ColorOutput.targetName(result.target.name))")
        
        if !result.hasIssues && !result.hasWarnings {
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
        
        // Redundant direct dependencies
        if !result.redundantDirectDependencies.isEmpty {
            let warningMessage = ColorOutput.warning("Redundant direct dependencies (\(result.redundantDirectDependencies.count)):")
            output.append("  " + warningMessage)
            for dep in result.redundantDirectDependencies.sorted(by: { $0.targetName < $1.targetName }) {
                let targetName = ColorOutput.dependencyName(dep.targetName)
                let productName = ColorOutput.dependencyName(dep.providingProduct)
                let packageName = ColorOutput.dim(dep.packageName)
                output.append("    • \(targetName) (available through \(productName) from \(packageName))")
            }
        }
        
        // Product satisfied dependencies (in verbose mode)
        if verbose && !result.productSatisfiedDependencies.isEmpty {
            let infoMessage = ColorOutput.info("Product-satisfied imports (\(result.productSatisfiedDependencies.count)):")
            output.append("  " + infoMessage)
            for dependency in result.productSatisfiedDependencies.sorted(by: { $0.importName < $1.importName }) {
                let importName = ColorOutput.dependencyName(dependency.importName)
                let productName = ColorOutput.dependencyName(dependency.productName)
                let packageName = ColorOutput.dim(dependency.packageName)
                output.append("    • \(importName) → \(productName) (\(packageName))")
            }
        }
        
        // Correct dependencies (only in verbose mode and not in quiet mode)
        if verbose && !quiet && !result.correctDependencies.isEmpty {
            let successMessage = ColorOutput.success("Correct dependencies (\(result.correctDependencies.count)):")
            output.append("  " + successMessage)
            for dep in result.correctDependencies.sorted() {
                let depName = ColorOutput.dependencyName(dep)
                output.append("    • \(depName)")
            }
        }
        
        if verbose && !quiet {
            let dimMessage = ColorOutput.dim("Source files: \(result.sourceFiles.count)")
            output.append("  " + dimMessage)
        }
        
        return output.joined(separator: "\n")
    }
    
    public func generateJSONReport(for results: [AnalysisResult], packageName: String, quiet: Bool = false) async throws -> String {
        let filteredResults = quiet ? results.filter { $0.hasIssues } : results
        let analysis = PackageAnalysis(
            packageName: packageName,
            targets: filteredResults.map { PackageAnalysis.TargetAnalysis(from: $0) }
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(analysis)
        
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw ScannerError.invalidPackageFile("Failed to encode JSON")
        }
        
        return jsonString
    }
    
    public func generateXcodeReport(for results: [AnalysisResult], packagePath: String) async -> String {
        var output: [String] = []
        
        for result in results {
            // Generate errors for missing dependencies
            for missingDep in result.missingDependencies.sorted() {
                // Find all source files and line numbers where this dependency is imported
                for sourceFile in result.sourceFiles {
                    for importInfo in sourceFile.imports {
                        if importInfo.moduleName == missingDep {
                            let message = XcodeOutput.missingDependencyError(
                                dependency: missingDep,
                                file: sourceFile.path,
                                line: importInfo.lineNumber
                            )
                            output.append(message)
                        }
                    }
                }
            }
            
            // Generate warnings for unused dependencies
            for unusedDep in result.unusedDependencies.sorted() {
                let packageFile = URL(fileURLWithPath: packagePath).appendingPathComponent("Package.swift").path
                let lineNumber = result.target.dependencyInfo.first { $0.name == unusedDep }?.lineNumber
                let message = XcodeOutput.unusedDependencyWarning(
                    dependency: unusedDep,
                    packageFile: packageFile,
                    line: lineNumber
                )
                output.append(message)
            }
        }
        
        return output.joined(separator: "\n")
    }
    
    public func generateGitHubActionsReport(for results: [AnalysisResult], packagePath: String) async -> String {
        var output: [String] = []
        
        for result in results {
            // Generate errors for missing dependencies
            for missingDep in result.missingDependencies.sorted() {
                // Find all source files and line numbers where this dependency is imported
                for sourceFile in result.sourceFiles {
                    for importInfo in sourceFile.imports {
                        if importInfo.moduleName == missingDep {
                            let message = GitHubActionsOutput.missingDependencyError(
                                dependency: missingDep,
                                file: sourceFile.path,
                                line: importInfo.lineNumber
                            )
                            output.append(message)
                        }
                    }
                }
            }
            
            // Generate warnings for unused dependencies
            for unusedDep in result.unusedDependencies.sorted() {
                let packageFile = URL(fileURLWithPath: packagePath).appendingPathComponent("Package.swift").path
                let lineNumber = result.target.dependencyInfo.first { $0.name == unusedDep }?.lineNumber
                let message = GitHubActionsOutput.unusedDependencyWarning(
                    dependency: unusedDep,
                    packageFile: packageFile,
                    line: lineNumber
                )
                output.append(message)
            }
        }
        
        return output.joined(separator: "\n")
    }
}
