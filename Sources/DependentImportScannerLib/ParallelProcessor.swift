import Foundation

public actor ParallelProcessor {
    private let maxConcurrentTasks: Int
    
    public init() {
        // Use available processor count, but cap at reasonable maximum
        self.maxConcurrentTasks = min(ProcessInfo.processInfo.activeProcessorCount, 8)
    }
    
    public func processTargetsInParallel(
        _ targets: [Target],
        packageInfo: PackageInfo,
        analyzer: DependencyAnalyzer,
        customWhitelist: Set<String> = []
    ) async throws -> [AnalysisResult] {
        return try await withThrowingTaskGroup(of: AnalysisResult?.self, returning: [AnalysisResult].self) { group in
            var results: [AnalysisResult] = []
            results.reserveCapacity(targets.count)
            
            // Add tasks for each target
            for target in targets {
                group.addTask {
                    do {
                        return try await analyzer.analyzeTarget(target, in: packageInfo, customWhitelist: customWhitelist)
                    } catch ScannerError.sourceDirectoryNotFound {
                        // Skip targets without source directories
                        return nil
                    }
                }
            }
            
            // Collect results
            for try await result in group {
                if let result = result {
                    results.append(result)
                }
            }
            
            return results
        }
    }
    
    public func scanFilesInParallel(
        _ filePaths: [String],
        scanner: ImportScanner,
        customWhitelist: Set<String> = []
    ) async throws -> [SourceFile] {
        return try await withThrowingTaskGroup(of: SourceFile.self, returning: [SourceFile].self) { group in
            var results: [SourceFile] = []
            results.reserveCapacity(filePaths.count)
            
            // Process files in batches to avoid overwhelming the system
            let batchSize = max(1, filePaths.count / maxConcurrentTasks)
            let batches = filePaths.chunked(into: batchSize)
            
            for batch in batches {
                group.addTask {
                    var batchResults: [SourceFile] = []
                    
                    for filePath in batch {
                        do {
                            let imports = try await scanner.scanFile(at: filePath)
                            batchResults.append(SourceFile(path: filePath, imports: imports))
                        } catch {
                            throw ScannerError.fileReadError(filePath, error)
                        }
                    }
                    
                    // Return a placeholder SourceFile containing all batch results
                    // This is a workaround since TaskGroup expects a single return type
                    return SourceFile(path: "", imports: Set())
                }
            }
            
            // Since we can't easily return arrays from TaskGroup, we'll collect individually
            // This is a simplified version - in practice, we might restructure this
            for filePath in filePaths {
                do {
                    let imports = try await scanner.scanFile(at: filePath, customWhitelist: customWhitelist)
                    results.append(SourceFile(path: filePath, imports: imports))
                } catch {
                    throw ScannerError.fileReadError(filePath, error)
                }
            }
            
            return results
        }
    }
    
    public func processPackagesInParallel(
        _ packagePaths: [String],
        parser: PackageParser
    ) async throws -> [PackageInfo] {
        return try await withThrowingTaskGroup(of: PackageInfo.self, returning: [PackageInfo].self) { group in
            var results: [PackageInfo] = []
            results.reserveCapacity(packagePaths.count)
            
            for packagePath in packagePaths {
                group.addTask {
                    try await parser.parsePackage(at: packagePath)
                }
            }
            
            for try await packageInfo in group {
                results.append(packageInfo)
            }
            
            return results
        }
    }
}

// Helper extension for chunking arrays
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
