import Foundation

public actor ExternalPackageResolver {
    private static let maxSearchDepth = 5
    private let packageParser: PackageParser
    private var packageCache: [String: ExternalPackage] = [:]
    
    public init() {
        self.packageParser = PackageParser()
    }
    
    public func resolveExternalPackages(for packageInfo: PackageInfo) async throws -> [ExternalPackage] {
        var externalPackages: [ExternalPackage] = []
        
        // Find .build/checkouts directory
        let checkoutsPath = findCheckoutsDirectory(from: packageInfo.path)
        
        guard let checkoutsDir = checkoutsPath,
              FileManager.default.fileExists(atPath: checkoutsDir) else {
            // No checkouts directory found - packages may not be resolved yet
            return externalPackages
        }
        
        // Process each external dependency
        for dependency in packageInfo.externalDependencies {
            if let externalPackage = try await resolveExternalPackage(dependency: dependency, checkoutsPath: checkoutsDir) {
                externalPackages.append(externalPackage)
            }
        }
        
        return externalPackages
    }
    
    private func findCheckoutsDirectory(from packagePath: String) -> String? {
        // Look for .build/checkouts relative to the package directory
        let packageURL = URL(fileURLWithPath: packagePath)
        let buildURL = packageURL.appendingPathComponent(".build")
        let checkoutsURL = buildURL.appendingPathComponent("checkouts")
        
        if FileManager.default.fileExists(atPath: checkoutsURL.path) {
            return checkoutsURL.path
        }
        
        // Try parent directories (in case we're in a subdirectory)
        var currentURL = packageURL.deletingLastPathComponent()
        for _ in 0..<Self.maxSearchDepth { // Limit search depth
            let buildURL = currentURL.appendingPathComponent(".build")
            let checkoutsURL = buildURL.appendingPathComponent("checkouts")
            
            if FileManager.default.fileExists(atPath: checkoutsURL.path) {
                return checkoutsURL.path
            }
            
            currentURL = currentURL.deletingLastPathComponent()
        }
        
        return nil
    }
    
    private func resolveExternalPackage(dependency: ExternalPackageDependency, checkoutsPath: String) async throws -> ExternalPackage? {
        // Check cache first
        if let cachedPackage = packageCache[dependency.packageName] {
            return cachedPackage
        }
        
        // Find the package directory in checkouts
        let packageCheckoutPath = findPackageInCheckouts(packageName: dependency.packageName, checkoutsPath: checkoutsPath)
        
        guard let checkoutPath = packageCheckoutPath else {
            // Package not found in checkouts
            return nil
        }
        
        // Parse the external package
        let packageSwiftPath = URL(fileURLWithPath: checkoutPath).appendingPathComponent("Package.swift").path
        
        guard FileManager.default.fileExists(atPath: packageSwiftPath) else {
            return nil
        }
        
        do {
            let externalPackageInfo = try await packageParser.parsePackage(at: packageSwiftPath)
            let externalPackage = ExternalPackage(
                name: externalPackageInfo.name,
                products: externalPackageInfo.products,
                path: checkoutPath
            )
            
            // Cache the result
            packageCache[dependency.packageName] = externalPackage
            
            return externalPackage
        } catch {
            // Failed to parse external package
            return nil
        }
    }
    
    private func findPackageInCheckouts(packageName: String, checkoutsPath: String) -> String? {
        let checkoutsURL = URL(fileURLWithPath: checkoutsPath)
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: checkoutsPath)
            
            var caseInsensitiveMatch: String?
            var partialMatch: String?
            
            // Single pass with prioritized matching
            for item in contents {
                // Exact match (highest priority) - return immediately
                if item == packageName {
                    return checkoutsURL.appendingPathComponent(item).path
                }
                
                // Store first case-insensitive match (medium priority)
                if caseInsensitiveMatch == nil && item.lowercased() == packageName.lowercased() {
                    caseInsensitiveMatch = item
                }
                
                // Store first partial match (lowest priority)
                if partialMatch == nil && (item.contains(packageName) || packageName.contains(item)) {
                    partialMatch = item
                }
            }
            
            // Return best available match
            if let match = caseInsensitiveMatch {
                return checkoutsURL.appendingPathComponent(match).path
            }
            if let match = partialMatch {
                return checkoutsURL.appendingPathComponent(match).path
            }
            
        } catch {
            // Failed to read checkouts directory
            return nil
        }
        
        return nil
    }
    
    public func buildProductToTargetMapping(from externalPackages: [ExternalPackage]) -> [String: [String]] {
        var mapping: [String: [String]] = [:]
        
        for package in externalPackages {
            for product in package.products {
                mapping[product.name] = product.targets
            }
        }
        
        return mapping
    }
}