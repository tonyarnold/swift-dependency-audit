import Foundation
import RegexBuilder

public actor PackageParser {
    
    // MARK: - RegexBuilder DSL Components
    
    // Basic building blocks using RegexBuilder DSL
    private var identifier: Regex<Substring> {
        Regex {
            /[a-zA-Z_]/
            ZeroOrMore {
                /[a-zA-Z0-9_]/
            }
        }
    }
    
    private var quotedStringContent: Regex<(Substring, Substring)> {
        Regex {
            "\""
            Capture {
                ZeroOrMore {
                    /[^"\\]/
                }
            }
            "\""
        }
    }
    
    private var whitespace: Regex<Substring> {
        Regex {
            ZeroOrMore(.whitespace)
        }
    }
    
    // MARK: - Package.swift Specific Components
    
    // Target type patterns using RegexBuilder
    private var targetTypePattern: Regex<(Substring, Substring)> {
        Regex {
            "."
            Capture {
                ChoiceOf {
                    "executableTarget"
                    "testTarget"
                    "macro"
                    "plugin"
                    "systemLibrary"
                    "binaryTarget"
                    "target"
                }
            }
            whitespace
            "("
        }
    }
    
    // Quoted identifier (name: "TargetName")
    private var nameParameter: Regex<(Substring, Substring, Substring)> {
        Regex {
            whitespace
            "name"
            whitespace
            ":"
            whitespace
            Capture {
                quotedStringContent
            }
        }
    }
    
    // Dependencies array pattern (simplified for now)
    private var dependenciesParameter: Regex<(Substring, Substring)> {
        Regex {
            whitespace
            "dependencies"
            whitespace
            ":"
            whitespace
            "["
            Capture {
                ZeroOrMore(.reluctant) {
                    /[^\[\]]/
                }
            }
            "]"
        }
    }
    
    // Section extraction pattern (e.g., "targets: [...]") - simplified for now
    private func sectionPattern(sectionName: String) -> Regex<(Substring, Substring)> {
        Regex {
            sectionName
            whitespace
            ":"
            whitespace
            "["
            Capture {
                ZeroOrMore(.reluctant) {
                    /[^\[\]]/
                }
            }
            "]"
        }
    }
    
    // Package declaration pattern
    private var packagePattern: Regex<Substring> {
        Regex {
            "Package"
            whitespace
            "("
        }
    }
    
    // Target parsing using RegexBuilder DSL patterns
    private func parseTargetsFromSection(_ targetsSection: String, packageContent: String) -> [Target] {
        var targets: [Target] = []
        
        // Find all target declarations using RegexBuilder patterns
        let targetDeclarations = findTargetDeclarationsWithRegexBuilder(in: targetsSection)
        
        for declaration in targetDeclarations {
            if let target = parseTargetDeclarationWithRegexBuilder(declaration, packageContent: packageContent) {
                targets.append(target)
            }
        }
        
        return targets
    }
    
    // RegexBuilder-based target declaration finder
    private func findTargetDeclarationsWithRegexBuilder(in content: String) -> [String] {
        var declarations: [String] = []
        var searchRange = content.startIndex..<content.endIndex
        
        // Find each target declaration using RegexBuilder pattern
        while let match = content[searchRange].firstMatch(of: targetTypePattern) {
            // Calculate the absolute start position
            let absoluteStart = content.index(content.startIndex, offsetBy: content.distance(from: content.startIndex, to: match.range.lowerBound))
            
            // Find the matching closing parenthesis for this target declaration
            if let endIndex = findMatchingClosingParenthesis(in: content, startingAfter: match.range.upperBound) {
                let fullDeclaration = content[absoluteStart...endIndex]
                declarations.append(String(fullDeclaration))
                
                // Move search range past this match
                searchRange = content.index(after: endIndex)..<content.endIndex
            } else {
                break
            }
        }
        
        return declarations
    }
    
    // Helper function to find matching closing parenthesis
    private func findMatchingClosingParenthesis(in content: String, startingAfter: String.Index) -> String.Index? {
        var depth = 1
        var currentIndex = startingAfter
        
        while currentIndex < content.endIndex && depth > 0 {
            let char = content[currentIndex]
            if char == "(" {
                depth += 1
            } else if char == ")" {
                depth -= 1
            }
            
            if depth == 0 {
                return currentIndex
            }
            
            currentIndex = content.index(after: currentIndex)
        }
        
        return nil
    }
    
    // RegexBuilder-based target declaration parser
    private func parseTargetDeclarationWithRegexBuilder(_ declaration: String, packageContent: String) -> Target? {
        // Extract target type using RegexBuilder pattern
        guard let typeMatch = declaration.firstMatch(of: targetTypePattern) else {
            return nil
        }
        
        let targetTypeStr = String(typeMatch.1)
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
        case "systemLibrary":
            targetType = .systemLibrary
        case "binaryTarget":
            targetType = .binaryTarget
        default: // "target"
            targetType = .library
        }
        
        // Extract name using RegexBuilder pattern
        guard let nameMatch = declaration.firstMatch(of: nameParameter) else {
            return nil
        }
        
        // Extract the quoted content from the captured group (nameMatch.1 contains the quotedStringContent)
        // nameMatch.1 is the full quoted string capture, nameMatch.2 is the content inside quotes
        let name = String(nameMatch.2)
        
        // Extract dependencies if present using RegexBuilder pattern
        if let dependenciesMatch = declaration.firstMatch(of: dependenciesParameter) {
            let dependenciesStr = String(dependenciesMatch.1)
            let dependencyInfo = parseDependencyListWithLineNumbers(dependenciesStr, targetName: name, packageContent: packageContent)
            
            return Target(name: name, type: targetType, dependencyInfo: dependencyInfo, path: nil)
        } else {
            // No dependencies
            return Target(name: name, type: targetType, dependencies: [], path: nil)
        }
    }
    
    private func extractQuotedContent(from quotedString: String) -> String {
        if let match = quotedString.firstMatch(of: quotedStringContent) {
            return String(match.1)
        }
        return quotedString.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }
    
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
        
        
        
        // Use the new step-by-step target parsing approach
        targets = parseTargetsFromSection(targetsSection, packageContent: packageContent)
        
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
            return extractTargetsSectionWithRegexBuilder(from: content)
        }
        
        // For other sections, use RegexBuilder approach
        guard let match = content.firstMatch(of: sectionPattern(sectionName: sectionName)) else {
            return ""
        }
        
        return String(match.1)
    }
    
    // RegexBuilder-based targets section extraction
    private func extractTargetsSectionWithRegexBuilder(from content: String) -> String {
        // Find Package( first using RegexBuilder pattern
        guard let packageMatch = content.firstMatch(of: packagePattern) else {
            return ""
        }
        
        let searchContent = content[packageMatch.range.upperBound...]
        
        // Look for targets: [balanced brackets] within the Package declaration using RegexBuilder
        let targetsPattern = sectionPattern(sectionName: "targets")
        
        // Find the last occurrence of targets: in the Package declaration
        var lastMatch: Regex<(Substring, Substring)>.Match?
        for match in searchContent.matches(of: targetsPattern) {
            lastMatch = match
        }
        
        guard let match = lastMatch else {
            return ""
        }
        
        return String(match.1)
    }
    
    // RegexBuilder-based variable targets section extraction
    private func extractVariableTargetsSection(from content: String) -> String {
        // Look for: let targets: [Target] = [balanced brackets] using RegexBuilder
        let variableTargetsPattern = Regex {
            "let"
            whitespace
            "targets"
            whitespace
            ":"
            whitespace
            "["
            whitespace
            "Target"
            whitespace
            "]"
            whitespace
            "="
            whitespace
            "["
            Capture {
                ZeroOrMore(.reluctant) {
                    /[^\[\]]/
                }
            }
            "]"
        }
        
        guard let match = content.firstMatch(of: variableTargetsPattern) else {
            return ""
        }
        
        return String(match.1)
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