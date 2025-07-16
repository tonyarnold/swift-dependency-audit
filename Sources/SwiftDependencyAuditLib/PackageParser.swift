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
        let targets = try extractTargets(from: content, packageContent: content)
        
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
    
    private func extractTargets(from content: String, packageContent: String) throws -> [Target] {
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
        let macroRegex = /\.macro\s*\(\s*name:\s*"([^"]+)"[^.]*?dependencies:\s*\[([^\]]*(?:\[[^\]]*\][^\]]*)*)\]/
        let systemLibraryRegex = /\.systemLibrary\s*\(\s*name:\s*"([^"]+)"[^)]*\)/
        let binaryTargetRegex = /\.binaryTarget\s*\(\s*name:\s*"([^"]+)"[^)]*\)/
        let pluginRegex = /\.plugin\s*\(\s*name:\s*"([^"]+)"[^.]*?dependencies:\s*\[([^\]]*(?:\[[^\]]*\][^\]]*)*)\]/
        
        // Parse executable targets
        for match in targetsSection.matches(of: executableRegex) {
            let name = String(match.1)
            let dependenciesStr = String(match.2)
            let dependencyInfo = parseDependencyListWithLineNumbers(dependenciesStr, targetName: name, packageContent: packageContent)
            
            targets.append(Target(
                name: name,
                type: .executable,
                dependencyInfo: dependencyInfo,
                path: nil
            ))
        }
        
        // Parse library targets
        for match in targetsSection.matches(of: libraryRegex) {
            let name = String(match.1)
            let dependenciesStr = String(match.2)
            let dependencyInfo = parseDependencyListWithLineNumbers(dependenciesStr, targetName: name, packageContent: packageContent)
            
            targets.append(Target(
                name: name,
                type: .library,
                dependencyInfo: dependencyInfo,
                path: nil
            ))
        }
        
        // Parse test targets
        for match in targetsSection.matches(of: testRegex) {
            let name = String(match.1)
            let dependenciesStr = String(match.2)
            let dependencyInfo = parseDependencyListWithLineNumbers(dependenciesStr, targetName: name, packageContent: packageContent)
            
            targets.append(Target(
                name: name,
                type: .test,
                dependencyInfo: dependencyInfo,
                path: nil
            ))
        }
        
        // Parse macro targets
        for match in targetsSection.matches(of: macroRegex) {
            let name = String(match.1)
            let dependenciesStr = String(match.2)
            let dependencyInfo = parseDependencyListWithLineNumbers(dependenciesStr, targetName: name, packageContent: packageContent)
            
            targets.append(Target(
                name: name,
                type: .library, // Treat macros as library targets for dependency analysis
                dependencyInfo: dependencyInfo,
                path: nil
            ))
        }
        
        // Parse system library targets (no dependencies to parse)
        for match in targetsSection.matches(of: systemLibraryRegex) {
            let name = String(match.1)
            
            targets.append(Target(
                name: name,
                type: .systemLibrary,
                dependencies: [], // System libraries don't have Swift dependencies
                path: nil
            ))
        }
        
        // Parse binary targets (no dependencies to parse)
        for match in targetsSection.matches(of: binaryTargetRegex) {
            let name = String(match.1)
            
            targets.append(Target(
                name: name,
                type: .binaryTarget,
                dependencies: [], // Binary targets don't have Swift dependencies
                path: nil
            ))
        }
        
        // Parse plugin targets
        for match in targetsSection.matches(of: pluginRegex) {
            let name = String(match.1)
            let dependenciesStr = String(match.2)
            let dependencyInfo = parseDependencyListWithLineNumbers(dependenciesStr, targetName: name, packageContent: packageContent)
            
            targets.append(Target(
                name: name,
                type: .plugin,
                dependencyInfo: dependencyInfo,
                path: nil
            ))
        }
        
        // Parse targets without dependencies by looking for all target declarations
        // and seeing which ones don't have dependency arrays
        let allTargetRegex = /\.(target|executableTarget|testTarget|macro|plugin)\s*\(\s*name:\s*"([^"]+)"([^)]*)\)/
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
                case "macro":
                    targetType = .library // Treat macros as library targets for dependency analysis
                case "plugin":
                    targetType = .plugin
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
        // For targets section, we need to find the Package(..., targets: [...], ...) pattern
        // not the products section that might also contain targets: [...]
        if sectionName == "targets" {
            // Find the Package( declaration first
            guard let packageStart = content.range(of: "Package(") else {
                return ""
            }
            
            // Search for targets: [ after the Package( declaration
            let searchRange = packageStart.upperBound..<content.endIndex
            let searchContent = content[searchRange]
            
            // Find all occurrences of "targets: [" in the Package declaration
            var lastTargetsRange: Range<String.Index>?
            var searchIndex = searchContent.startIndex
            
            while let range = searchContent.range(of: "targets: [", range: searchIndex..<searchContent.endIndex) {
                lastTargetsRange = range
                searchIndex = range.upperBound
            }
            
            guard let targetsRange = lastTargetsRange else {
                return ""
            }
            
            // Extract the targets array content
            let startIndex = targetsRange.upperBound
            var depth = 1
            var currentIndex = startIndex
            
            // Find the matching closing bracket
            while currentIndex < searchContent.endIndex && depth > 0 {
                let char = searchContent[currentIndex]
                if char == "[" {
                    depth += 1
                } else if char == "]" {
                    depth -= 1
                }
                currentIndex = searchContent.index(after: currentIndex)
            }
            
            guard depth == 0 else {
                return ""
            }
            
            return String(searchContent[startIndex..<searchContent.index(before: currentIndex)])
        }
        
        // For other sections, use the original logic
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
    
    private func parseDependencyListWithLineNumbers(_ dependenciesStr: String, targetName: String, packageContent: String) -> [DependencyInfo] {
        var dependencyInfos: [DependencyInfo] = []
        
        // Get the line numbers for dependencies by searching in the full package content
        let dependencies = parseDependencyList(dependenciesStr)
        
        for dependency in dependencies {
            if let lineNumber = findDependencyLineNumber(dependency: dependency, targetName: targetName, in: packageContent) {
                dependencyInfos.append(DependencyInfo(name: dependency, lineNumber: lineNumber))
            } else {
                dependencyInfos.append(DependencyInfo(name: dependency, lineNumber: nil))
            }
        }
        
        return dependencyInfos
    }
    
    private func findDependencyLineNumber(dependency: String, targetName: String, in content: String) -> Int? {
        let lines = content.components(separatedBy: .newlines)
        
        // Find the target declaration first - handle multi-line declarations
        var targetStartLine: Int?
        var targetEndLine: Int?
        var braceDepth = 0
        var inTarget = false
        var lookingForTargetName = false
        var targetTypeIndex: Int?
        
        for (index, line) in lines.enumerated() {
            // Check if we find a target type declaration
            if line.contains(".target(") || line.contains(".executableTarget(") || line.contains(".testTarget(") || line.contains(".macro(") || line.contains(".plugin(") {
                targetTypeIndex = index
                lookingForTargetName = true
                braceDepth = 0
                // Count opening parentheses on this line
                for char in line {
                    if char == "(" {
                        braceDepth += 1
                    } else if char == ")" {
                        braceDepth -= 1
                    }
                }
            }
            
            // If we're looking for a target name and found it, check if it matches
            if lookingForTargetName && line.contains("name: \"\(targetName)\"") {
                // Found the target we're looking for
                targetStartLine = (targetTypeIndex ?? index) + 1
                inTarget = true
                lookingForTargetName = false
                
                // Continue counting braces from the target name line
                for char in line {
                    if char == "(" {
                        braceDepth += 1
                    } else if char == ")" {
                        braceDepth -= 1
                        if braceDepth == 0 {
                            targetEndLine = index + 1
                            break
                        }
                    }
                }
                
                if targetEndLine != nil {
                    break
                }
            }
            
            // If we're in a target, continue counting braces
            if inTarget {
                for char in line {
                    if char == "(" {
                        braceDepth += 1
                    } else if char == ")" {
                        braceDepth -= 1
                        if braceDepth == 0 {
                            targetEndLine = index + 1
                            break
                        }
                    }
                }
                
                if targetEndLine != nil {
                    break
                }
            }
            
            // Reset if we found a target type but then encounter another target type before finding the name
            if lookingForTargetName && !inTarget && (line.contains(".target(") || line.contains(".executableTarget(") || line.contains(".testTarget(") || line.contains(".macro(") || line.contains(".plugin(")) {
                targetTypeIndex = index
                braceDepth = 0
                for char in line {
                    if char == "(" {
                        braceDepth += 1
                    } else if char == ")" {
                        braceDepth -= 1
                    }
                }
            }
        }
        
        // Search for the dependency within the target declaration
        if let startLine = targetStartLine, let endLine = targetEndLine {
            for lineIndex in (startLine - 1)..<min(endLine, lines.count) {
                let line = lines[lineIndex]
                // Look for the dependency name in quotes or as a product name
                if line.contains("\"\(dependency)\"") {
                    // Check if this is a simple quoted dependency or a product name
                    // Both cases: "DependencyName" or .product(name: "DependencyName", ...)
                    return lineIndex + 1
                }
            }
        }
        
        return nil
    }
    
    private func findLineNumber(for range: Range<String.Index>, in content: String) -> Int? {
        let prefix = content[..<range.lowerBound]
        let lineNumber = prefix.components(separatedBy: .newlines).count
        return lineNumber
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