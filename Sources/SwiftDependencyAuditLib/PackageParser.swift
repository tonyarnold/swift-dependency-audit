import Foundation

public actor PackageParser {
    
    public init() {}
    
    public func parsePackage(at path: String) async throws -> PackageInfo {
        let packagePath = resolvePackagePath(path)
        
        guard FileManager.default.fileExists(atPath: packagePath) else {
            throw ScannerError.packageNotFound(packagePath)
        }
        
        let content = try String(contentsOfFile: packagePath, encoding: .utf8)
        return try await parsePackageContent(content, packageDirectory: URL(fileURLWithPath: packagePath).deletingLastPathComponent().path)
    }
    
    private func resolvePackagePath(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        
        if url.lastPathComponent == "Package.swift" {
            return path
        } else {
            return url.appendingPathComponent("Package.swift").path
        }
    }
    
    private func parsePackageContent(_ content: String, packageDirectory: String) async throws -> PackageInfo {
        // Extract package name
        let packageName = try extractPackageName(from: content)
        
        // Extract dependencies
        let dependencies = try extractDependencies(from: content)
        
        // Extract targets
        let targets = try extractTargets(from: content)
        
        return PackageInfo(
            name: packageName,
            targets: targets,
            dependencies: dependencies,
            path: packageDirectory
        )
    }
    
    private func extractPackageName(from content: String) throws -> String {
        // Try different patterns for package name:
        // 1. Variable declaration: let name = "PackageName"
        // 2. Package constructor: Package(name: "PackageName", ...)
        // 3. Inline name: name: "PackageName"
        
        // First try variable declaration
        let variableNameRegex = /let\s+name\s*=\s*"([^"]+)"/
        if let match = content.firstMatch(of: variableNameRegex) {
            return String(match.1)
        }
        
        // Then try Package constructor parameter
        let packageConstructorRegex = /Package\s*\(\s*name:\s*"([^"]+)"/
        if let match = content.firstMatch(of: packageConstructorRegex) {
            return String(match.1)
        }
        
        // Finally try any name: pattern (fallback)
        let nameRegex = /name:\s*"([^"]+)"/
        guard let match = content.firstMatch(of: nameRegex) else {
            throw ScannerError.invalidPackageFile("Could not find package name")
        }
        
        return String(match.1)
    }
    
    private func extractDependencies(from content: String) throws -> [String] {
        var dependencies: [String] = []
        
        // Look for dependencies array
        let dependenciesSection = extractSection(from: content, sectionName: "dependencies")
        
        // Extract package URLs and convert to likely module names
        let urlRegex = /\.package\s*\(\s*url:\s*"[^"]*\/([^\/]+?)(?:\.git)?"\s*,/
        
        for match in dependenciesSection.matches(of: urlRegex) {
            let repoName = String(match.1)
            // Convert repository names to likely module names
            let moduleName = repoNameToModuleName(repoName)
            dependencies.append(moduleName)
        }
        
        return dependencies
    }
    
    private func extractTargets(from content: String) throws -> [Target] {
        var targets: [Target] = []
        
        // Try to extract targets from both patterns:
        // 1. Variable: let targets: [Target] = [...] (try this first for modern Swift packages)
        // 2. Inline: Package(..., targets: [...], ...)
        var targetsSection = extractVariableTargetsSection(from: content)
        
        // If variable targets section is empty, try to find inline declaration
        if targetsSection.isEmpty {
            targetsSection = extractSection(from: content, sectionName: "targets")
        }
        
        // Match different target types with more specific patterns to avoid cross-target matching
        // Match only within the same target declaration by being more restrictive
        let executableRegex = /\.executableTarget\s*\(\s*name:\s*"([^"]+)"[^.]*?dependencies:\s*\[([^\]]*(?:\[[^\]]*\][^\]]*)*)\]/
        let libraryRegex = /\.target\s*\(\s*name:\s*"([^"]+)"[^.]*?dependencies:\s*\[([^\]]*(?:\[[^\]]*\][^\]]*)*)\]/
        let testRegex = /\.testTarget\s*\(\s*name:\s*"([^"]+)"[^.]*?dependencies:\s*\[([^\]]*(?:\[[^\]]*\][^\]]*)*)\]/
        
        // Parse executable targets
        for match in targetsSection.matches(of: executableRegex) {
            let name = String(match.1)
            let dependenciesStr = String(match.2)
            let dependencies = parseDependencyList(dependenciesStr)
            
            targets.append(Target(
                name: name,
                type: .executable,
                dependencies: dependencies,
                path: nil
            ))
        }
        
        // Parse library targets
        for match in targetsSection.matches(of: libraryRegex) {
            let name = String(match.1)
            let dependenciesStr = String(match.2)
            let dependencies = parseDependencyList(dependenciesStr)
            
            targets.append(Target(
                name: name,
                type: .library,
                dependencies: dependencies,
                path: nil
            ))
        }
        
        // Parse test targets
        for match in targetsSection.matches(of: testRegex) {
            let name = String(match.1)
            let dependenciesStr = String(match.2)
            let dependencies = parseDependencyList(dependenciesStr)
            
            targets.append(Target(
                name: name,
                type: .test,
                dependencies: dependencies,
                path: nil
            ))
        }
        
        // Parse targets without dependencies by looking for all target declarations
        // and seeing which ones don't have dependency arrays
        let allTargetRegex = /\.(target|executableTarget|testTarget)\s*\(\s*name:\s*"([^"]+)"([^)]*)\)/
        var targetNamesWithDeps = Set<String>()
        for target in targets {
            targetNamesWithDeps.insert(target.name)
        }
        
        for match in targetsSection.matches(of: allTargetRegex) {
            let targetTypeStr = String(match.1)
            let name = String(match.2)
            let content = String(match.3)
            
            // Skip if we already parsed this target with dependencies
            if targetNamesWithDeps.contains(name) {
                continue
            }
            
            // Check if this target declaration contains dependencies
            if !content.contains("dependencies:") {
                let targetType: Target.TargetType
                switch targetTypeStr {
                case "executableTarget":
                    targetType = .executable
                case "testTarget":
                    targetType = .test
                default: // "target"
                    targetType = .library
                }
                
                targets.append(Target(
                    name: name,
                    type: targetType,
                    dependencies: [],
                    path: nil
                ))
            }
        }
        
        return targets
    }
    
    private func extractSection(from content: String, sectionName: String) -> String {
        // Find the section start
        guard let sectionStart = content.range(of: "\(sectionName): [") else {
            return ""
        }
        
        let startIndex = sectionStart.upperBound
        var depth = 1
        var currentIndex = startIndex
        
        // Find the matching closing bracket
        while currentIndex < content.endIndex && depth > 0 {
            let char = content[currentIndex]
            if char == "[" {
                depth += 1
            } else if char == "]" {
                depth -= 1
            }
            currentIndex = content.index(after: currentIndex)
        }
        
        guard depth == 0 else {
            return ""
        }
        
        return String(content[startIndex..<content.index(before: currentIndex)])
    }
    
    private func extractVariableTargetsSection(from content: String) -> String {
        // Look for: let targets: [Target] = [
        let regex = /let\s+targets:\s*\[\s*Target\s*\]\s*=\s*\[/
        
        guard let match = content.firstMatch(of: regex) else {
            return ""
        }
        
        let startIndex = match.range.upperBound
        var depth = 1
        var currentIndex = startIndex
        
        // Find the matching closing bracket
        while currentIndex < content.endIndex && depth > 0 {
            let char = content[currentIndex]
            if char == "[" {
                depth += 1
            } else if char == "]" {
                depth -= 1
            }
            currentIndex = content.index(after: currentIndex)
        }
        
        guard depth == 0 else {
            return ""
        }
        
        return String(content[startIndex..<content.index(before: currentIndex)])
    }
    
    private func parseDependencyList(_ dependenciesStr: String) -> [String] {
        var dependencies: [String] = []
        
        // First, match .product() dependencies to get product names
        let productRegex = /\.product\s*\(\s*name:\s*"([^"]+)"/
        for match in dependenciesStr.matches(of: productRegex) {
            dependencies.append(String(match.1))
        }
        
        // Then match simple quoted dependencies (not inside .product() calls)
        // Split by commas and look for standalone quoted strings
        let components = dependenciesStr.components(separatedBy: ",")
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
            // Match simple quoted strings that aren't part of .product() calls
            if trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") && !trimmed.contains(".product") {
                let quoted = String(trimmed.dropFirst().dropLast())
                dependencies.append(quoted)
            }
        }
        
        return dependencies
    }
    
    private func repoNameToModuleName(_ repoName: String) -> String {
        // Convert common repository naming patterns to module names
        let cleanedName = repoName
            .replacingOccurrences(of: "swift-", with: "")
            .replacingOccurrences(of: "-swift", with: "")
        
        // Convert kebab-case to PascalCase for module names
        let components = cleanedName.components(separatedBy: "-")
        let pascalCase = components.map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }.joined()
        
        return pascalCase
    }
}