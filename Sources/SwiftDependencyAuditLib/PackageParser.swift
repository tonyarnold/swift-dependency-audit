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

    // Target type patterns using RegexBuilder with multiline support
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
            ZeroOrMore(.whitespace)
            "("
        }
        .dotMatchesNewlines()
    }

    // Quoted identifier (name: "TargetName") with multiline support
    private var nameParameter: Regex<(Substring, Substring, Substring)> {
        Regex {
            ZeroOrMore(.whitespace)
            "name"
            ZeroOrMore(.whitespace)
            ":"
            ZeroOrMore(.whitespace)
            Capture {
                quotedStringContent
            }
        }
        .dotMatchesNewlines()
    }

    // Path parameter pattern (path: "Custom/Path")
    private var pathParameter: Regex<(Substring, Substring, Substring)> {
        Regex {
            ZeroOrMore(.whitespace)
            "path"
            ZeroOrMore(.whitespace)
            ":"
            ZeroOrMore(.whitespace)
            Capture {
                quotedStringContent
            }
        }
        .dotMatchesNewlines()
    }

    // Dependencies array pattern with proper nested bracket handling
    private var dependenciesParameter: Regex<(Substring, Substring)> {
        /dependencies\s*:\s*\[([^\]]*(?:\[[^\]]*\][^\]]*)*)\]/.dotMatchesNewlines()
    }

    // Section extraction pattern with proper nested bracket handling
    private func sectionPattern(sectionName: String) -> Regex<(Substring, Substring)> {
        // Use a more robust pattern that can handle deeply nested structures
        try! Regex("\(sectionName)\\s*:\\s*\\[([\\s\\S]*?)\\](?=\\s*[,)])")
    }

    // Package declaration pattern
    private var packagePattern: Regex<Substring> {
        Regex {
            "Package"
            whitespace
            "("
        }
    }

    // MARK: - Variable Declaration Patterns

    // Variable declaration pattern for let name = "value"
    private var stringVariablePattern: Regex<(Substring, Substring, Substring)> {
        Regex {
            "let"
            OneOrMore(.whitespace)
            Capture {
                identifier
            }
            ZeroOrMore(.whitespace)
            "="
            ZeroOrMore(.whitespace)
            "\""
            Capture {
                ZeroOrMore {
                    /[^"\\]/
                }
            }
            "\""
        }
    }

    // Variable declaration pattern for let targets: [Target] = [...]
    private var targetsVariablePattern: Regex<Substring> {
        Regex {
            "let"
            OneOrMore(.whitespace)
            "targets"
            ZeroOrMore(.whitespace)
            ":"
            ZeroOrMore(.whitespace)
            "["
            ZeroOrMore(.whitespace)
            "Target"
            ZeroOrMore(.whitespace)
            "]"
            ZeroOrMore(.whitespace)
            "="
            ZeroOrMore(.whitespace)
            "["
        }
        .dotMatchesNewlines()
    }

    // Variable declaration pattern for let products: [Product] = [...]
    private var productsVariablePattern: Regex<Substring> {
        Regex {
            "let"
            OneOrMore(.whitespace)
            "products"
            ZeroOrMore(.whitespace)
            ":"
            ZeroOrMore(.whitespace)
            "["
            ZeroOrMore(.whitespace)
            "Product"
            ZeroOrMore(.whitespace)
            "]"
            ZeroOrMore(.whitespace)
            "="
            ZeroOrMore(.whitespace)
            "["
        }
        .dotMatchesNewlines()
    }

    // Variable declaration pattern for let dependencies: [Package.Dependency] = [...]
    private var dependenciesVariablePattern: Regex<Substring> {
        Regex {
            "let"
            OneOrMore(.whitespace)
            "dependencies"
            ZeroOrMore(.whitespace)
            ":"
            ZeroOrMore(.whitespace)
            "["
            ZeroOrMore(.whitespace)
            "Package.Dependency"
            ZeroOrMore(.whitespace)
            "]"
            ZeroOrMore(.whitespace)
            "="
            ZeroOrMore(.whitespace)
            "["
        }
        .dotMatchesNewlines()
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
            let absoluteStart = content.index(
                content.startIndex, offsetBy: content.distance(from: content.startIndex, to: match.range.lowerBound))

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
            targetType = .library  // Treat macros as library targets for dependency analysis
        case "plugin":
            targetType = .plugin
        case "systemLibrary":
            targetType = .systemLibrary
        case "binaryTarget":
            targetType = .binaryTarget
        default:  // "target"
            targetType = .library
        }

        // Extract name using RegexBuilder pattern
        guard let nameMatch = declaration.firstMatch(of: nameParameter) else {
            return nil
        }

        // Extract the quoted content from the captured group (nameMatch.1 contains the quotedStringContent)
        // nameMatch.1 is the full quoted string capture, nameMatch.2 is the content inside quotes
        let name = String(nameMatch.2)

        // Extract custom path if present
        var customPath: String? = nil
        if let pathMatch = declaration.firstMatch(of: pathParameter) {
            // pathMatch.1 contains the quotedStringContent, pathMatch.2 contains the content inside quotes
            customPath = String(pathMatch.2)  // Extract content inside quotes
        }

        // Extract dependencies if present using RegexBuilder pattern
        if let dependenciesMatch = declaration.firstMatch(of: dependenciesParameter) {
            let dependenciesStr = String(dependenciesMatch.1)
            let dependencyInfo = parseDependencyListWithLineNumbers(
                dependenciesStr, targetName: name, packageContent: packageContent)

            return Target(name: name, type: targetType, dependencyInfo: dependencyInfo, path: customPath)
        } else {
            // No dependencies
            return Target(name: name, type: targetType, dependencies: [], path: customPath)
        }
    }

    private func extractQuotedContent(from quotedString: String) -> String {
        if let match = quotedString.firstMatch(of: quotedStringContent) {
            return String(match.1)
        }
        return quotedString.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }

    // MARK: - Variable Resolution Methods

    // Resolve string variables like let name = "DataLayer"
    private func resolveStringVariable(named variableName: String, in content: String) -> String? {
        for match in content.matches(of: stringVariablePattern) {
            let varName = String(match.1)
            if varName == variableName {
                // match.2 contains the content inside quotes
                return String(match.2)
            }
        }
        return nil
    }

    // Extract content from variable array declarations using bracket counting
    private func extractVariableArrayContent(pattern: Regex<Substring>, in content: String) -> String? {
        guard let match = content.firstMatch(of: pattern) else {
            return nil
        }

        // Start counting brackets from after the opening bracket
        var currentIndex = match.range.upperBound
        var bracketDepth = 1

        while currentIndex < content.endIndex && bracketDepth > 0 {
            let char = content[currentIndex]
            if char == "[" {
                bracketDepth += 1
            } else if char == "]" {
                bracketDepth -= 1
            }

            if bracketDepth == 0 {
                // Found the matching closing bracket
                let arrayContent = content[match.range.upperBound..<currentIndex]
                return String(arrayContent)
            }

            currentIndex = content.index(after: currentIndex)
        }

        return nil
    }

    // Resolve targets variable content
    private func resolveTargetsVariable(in content: String) -> String? {
        return extractVariableArrayContent(pattern: targetsVariablePattern, in: content)
    }

    // Resolve products variable content
    private func resolveProductsVariable(in content: String) -> String? {
        return extractVariableArrayContent(pattern: productsVariablePattern, in: content)
    }

    // Resolve dependencies variable content
    private func resolveDependenciesVariable(in content: String) -> String? {
        return extractVariableArrayContent(pattern: dependenciesVariablePattern, in: content)
    }

    // MARK: - ForEach Processing Support

    // Pattern to find targets.forEach blocks using RegexBuilder
    private var targetsForEachPattern: Regex<(Substring, Substring)> {
        Regex {
            "targets"
            ZeroOrMore(.whitespace)
            "."
            ZeroOrMore(.whitespace)
            "forEach"
            ZeroOrMore(.whitespace)
            "{"
            ZeroOrMore(.whitespace)
            "target"
            ZeroOrMore(.whitespace)
            "in"
            Capture {
                // Capture the forEach body using a greedy approach
                // This will capture everything until we find a balanced closing brace
                /.+/
            }
        }
        .dotMatchesNewlines()
    }

    // Apply forEach modifications to targets
    private func applyForEachModifications(to targets: [Target], from content: String) -> [Target] {
        // Find forEach blocks
        guard let forEachMatch = content.firstMatch(of: targetsForEachPattern) else {
            return targets  // No forEach modifications found
        }

        // Find the actual closing brace for the forEach block using bracket counting
        let fullMatch = String(forEachMatch.0)
        guard let _ = findMatchingClosingBrace(in: fullMatch, startingAfter: fullMatch.firstIndex(of: "{")!) else {
            return targets  // Could not find matching closing brace
        }

        // For now, we'll implement basic forEach processing
        // In a real implementation, we would need to parse and apply the modifications
        // The complex Package.swift example mainly sets Swift settings which don't affect dependency analysis
        // so we can return the targets unchanged for dependency analysis purposes

        return targets
    }

    // Helper to find matching closing brace
    private func findMatchingClosingBrace(in content: String, startingAfter: String.Index) -> String.Index? {
        var depth = 1
        var currentIndex = content.index(after: startingAfter)

        while currentIndex < content.endIndex && depth > 0 {
            let char = content[currentIndex]
            if char == "{" {
                depth += 1
            } else if char == "}" {
                depth -= 1
            }

            if depth == 0 {
                return currentIndex
            }

            currentIndex = content.index(after: currentIndex)
        }

        return nil
    }

    public init() {}

    public func parseContent(_ content: String, packageDirectory: String) async throws -> PackageInfo {
        return try await parsePackageContent(content, packageDirectory: packageDirectory)
    }

    public func parsePackage(at path: String) async throws -> PackageInfo {
        let packagePath = resolvePackagePath(path)

        guard FileManager.default.fileExists(atPath: packagePath) else {
            throw ScannerError.packageNotFound(packagePath)
        }

        let content = try String(contentsOfFile: packagePath, encoding: .utf8)
        return try await parsePackageContent(
            content, packageDirectory: URL(fileURLWithPath: packagePath).deletingLastPathComponent().path)
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

        // Extract products
        let products = try extractProducts(from: content, packageName: packageName)

        // Extract external package dependencies
        let externalDependencies = try extractExternalDependencies(from: content)

        return PackageInfo(
            name: packageName,
            targets: targets,
            dependencies: dependencies,
            products: products,
            externalDependencies: externalDependencies,
            path: packageDirectory
        )
    }

    private func extractPackageName(from content: String) throws -> String {
        // Try different patterns for package name:
        // 1. Variable declaration: let name = "PackageName"
        // 2. Package constructor: Package(name: "PackageName", ...)
        // 3. Package constructor with variable: Package(name: name, ...)
        // 4. Inline name: name: "PackageName"

        // First try variable declaration using our RegexBuilder pattern
        if let variableName = resolveStringVariable(named: "name", in: content) {
            return variableName
        }

        // Then try Package constructor parameter
        let packageConstructorRegex = /Package\s*\(\s*name:\s*"([^"]+)"/
        if let match = content.firstMatch(of: packageConstructorRegex) {
            return String(match.1)
        }

        // Try Package constructor with variable reference: Package(name: name, ...)
        let packageConstructorVarRegex = /Package\s*\(\s*name:\s*([a-zA-Z_][a-zA-Z0-9_]*)/
        if let match = content.firstMatch(of: packageConstructorVarRegex) {
            let varName = String(match.1)
            if let resolvedName = resolveStringVariable(named: varName, in: content) {
                return resolvedName
            }
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

        // Try to get dependencies from variable declaration first
        var dependenciesSection = resolveDependenciesVariable(in: content)

        // If no variable found, look for dependencies array in Package constructor
        if dependenciesSection == nil {
            dependenciesSection = extractSection(from: content, sectionName: "dependencies")
        }

        guard let section = dependenciesSection, !section.isEmpty else {
            return dependencies
        }

        // Extract package URLs and convert to likely module names
        let urlRegex = /\.package\s*\(\s*url:\s*"[^"]*\/([^\/]+?)(?:\.git)?"\s*,/

        for match in section.matches(of: urlRegex) {
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
        var targetsSection: String = ""

        // First try variable declaration using our enhanced method
        if let variableTargets = resolveTargetsVariable(in: content) {
            targetsSection = variableTargets
        } else {
            // Fall back to inline declaration
            targetsSection = extractSection(from: content, sectionName: "targets")
        }

        // Use the step-by-step target parsing approach
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
                    targetType = .library  // Treat macros as library targets for dependency analysis
                case "plugin":
                    targetType = .plugin
                default:  // "target"
                    targetType = .library
                }

                targets.append(
                    Target(
                        name: name,
                        type: targetType,
                        dependencies: [],
                        path: nil
                    ))
            }
        }

        // Apply forEach modifications if present
        targets = applyForEachModifications(to: targets, from: content)

        return targets
    }

    private func extractSection(from content: String, sectionName: String) -> String {
        // For targets section, we need to find the Package(..., targets: [...], ...) pattern
        // not the products section that might also contain targets: [...]
        if sectionName == "targets" {
            return extractTargetsSectionWithRegexBuilder(from: content)
        }

        // For other sections, use a more robust bracket counting approach
        return extractSectionWithBracketCounting(from: content, sectionName: sectionName)
    }

    // Robust section extraction using bracket counting
    private func extractSectionWithBracketCounting(from content: String, sectionName: String) -> String {
        // Find the section start pattern: sectionName: [
        let sectionStartPattern = Regex {
            sectionName
            ZeroOrMore(.whitespace)
            ":"
            ZeroOrMore(.whitespace)
            "["
        }
        .dotMatchesNewlines()

        guard let match = content.firstMatch(of: sectionStartPattern) else {
            return ""
        }

        // Start counting brackets from after the opening bracket
        var currentIndex = match.range.upperBound
        var bracketDepth = 1

        while currentIndex < content.endIndex && bracketDepth > 0 {
            let char = content[currentIndex]
            if char == "[" {
                bracketDepth += 1
            } else if char == "]" {
                bracketDepth -= 1
            }

            if bracketDepth == 0 {
                // Found the matching closing bracket
                let sectionContent = content[match.range.upperBound..<currentIndex]
                return String(sectionContent)
            }

            currentIndex = content.index(after: currentIndex)
        }

        return ""
    }

    // RegexBuilder-based targets section extraction
    private func extractTargetsSectionWithRegexBuilder(from content: String) -> String {
        // Find Package( first using RegexBuilder pattern
        guard let packageMatch = content.firstMatch(of: packagePattern) else {
            return ""
        }

        // Search for targets section starting from after Package(
        let searchContent = content[packageMatch.range.upperBound...]

        // Find ALL occurrences of "targets:" and take the last one (main targets section)
        let targetsStartPattern = Regex {
            "targets"
            ZeroOrMore(.whitespace)
            ":"
            ZeroOrMore(.whitespace)
            "["
        }
        .dotMatchesNewlines()

        var lastMatch: Regex<Substring>.Match?
        for match in searchContent.matches(of: targetsStartPattern) {
            lastMatch = match
        }

        guard let match = lastMatch else {
            return ""
        }

        // Extract content from the last targets section using bracket counting
        let startIndex = match.range.upperBound
        var currentIndex = startIndex
        var bracketDepth = 1

        while currentIndex < searchContent.endIndex && bracketDepth > 0 {
            let char = searchContent[currentIndex]
            if char == "[" {
                bracketDepth += 1
            } else if char == "]" {
                bracketDepth -= 1
            }

            if bracketDepth == 0 {
                // Found the matching closing bracket
                let sectionContent = searchContent[startIndex..<currentIndex]
                return String(sectionContent)
            }

            currentIndex = searchContent.index(after: currentIndex)
        }

        return ""
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

    private func parseDependencyListWithLineNumbers(
        _ dependenciesStr: String, targetName: String, packageContent: String
    ) -> [DependencyInfo] {
        var dependencyInfos: [DependencyInfo] = []

        // Parse product dependencies with their package information
        let productRegex = /\.product\s*\(\s*name:\s*"([^"]+)".*?package:\s*"([^"]+)"/
        for match in dependenciesStr.matches(of: productRegex) {
            let productName = String(match.1)
            let packageName = String(match.2)
            let lineNumber = findDependencyLineNumber(
                dependency: productName, targetName: targetName, in: packageContent)
            dependencyInfos.append(
                DependencyInfo(name: productName, type: .product(packageName: packageName), lineNumber: lineNumber))
        }

        // Parse simple quoted dependencies (not inside .product() calls)
        let components = dependenciesStr.components(separatedBy: ",")
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
            // Match simple quoted strings that aren't part of .product() calls
            if trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") && !trimmed.contains(".product") {
                let quoted = String(trimmed.dropFirst().dropLast())
                let lineNumber = findDependencyLineNumber(
                    dependency: quoted, targetName: targetName, in: packageContent)
                dependencyInfos.append(DependencyInfo(name: quoted, type: .target, lineNumber: lineNumber))
            }
        }

        return dependencyInfos
    }

    private func findDependencyLineNumber(dependency: String, targetName: String, in content: String) -> Int? {
        let lines = content.components(separatedBy: .newlines)

        // Find the target by name first, then look for dependencies within reasonable distance
        var targetNameLine: Int?

        // First pass: find the line with our target name declaration
        for (index, line) in lines.enumerated() {
            if line.contains("name: \"\(targetName)\"") {
                // Verify this is actually a target declaration by checking the previous line
                if index > 0 {
                    let previousLine = lines[index - 1]
                    if previousLine.contains(".target(") || previousLine.contains(".executableTarget(")
                        || previousLine.contains(".testTarget(")
                    {
                        targetNameLine = index
                        break
                    }
                }
            }
        }

        // If we found the target name, look for dependencies in the following lines
        if let targetLine = targetNameLine {
            // Search in a reasonable range after the target name (usually within 50 lines)
            let searchStart = targetLine
            let searchEnd = min(lines.count, targetLine + 50)

            for lineIndex in searchStart..<searchEnd {
                let line = lines[lineIndex]

                // Look for .product(name: "DependencyName") format
                if line.contains("name: \"\(dependency)\"") && line.contains(".product") {
                    return lineIndex + 1
                }
                // Look for simple quoted format "DependencyName" within target references
                else if line.contains("\"\(dependency)\"") && line.contains(".target") {
                    return lineIndex + 1
                }

                // Stop if we hit another target declaration (indicates we've gone too far)
                if lineIndex > targetLine
                    && (line.contains(".target(") || line.contains(".executableTarget(")
                        || line.contains(".testTarget("))
                {
                    break
                }
            }
        }

        // Fallback: search for the dependency near the target name (broader search)
        for (index, line) in lines.enumerated() {
            if line.contains("name: \"\(targetName)\"") {
                // Search within 50 lines after this target name mention
                let searchStart = index
                let searchEnd = min(lines.count, index + 50)

                for lineIndex in searchStart..<searchEnd {
                    let searchLine = lines[lineIndex]
                    if searchLine.contains("name: \"\(dependency)\"") && searchLine.contains(".product") {
                        return lineIndex + 1
                    }

                    // Stop if we hit another target name (different target)
                    if lineIndex > index && searchLine.contains("name: \"")
                        && !searchLine.contains("name: \"\(targetName)\"")
                        && (searchLine.contains(".target") || searchLine.contains("name: \"\(dependency)\""))
                    {
                        break
                    }
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
        let cleanedName =
            repoName
            .replacingOccurrences(of: "swift-", with: "")
            .replacingOccurrences(of: "-swift", with: "")

        // Convert kebab-case to PascalCase for module names
        let components = cleanedName.components(separatedBy: "-")
        let pascalCase = components.map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }.joined()

        return pascalCase
    }

    // MARK: - Product Extraction Methods

    private func extractProducts(from content: String, packageName: String) throws -> [Product] {
        var products: [Product] = []

        // Try to get products from variable declaration first
        var productsSection = resolveProductsVariable(in: content)

        // If no variable found, look for products array in Package constructor
        if productsSection == nil {
            productsSection = extractSection(from: content, sectionName: "products")
        }

        guard let section = productsSection, !section.isEmpty else {
            return products
        }

        // Parse product declarations using RegexBuilder
        products = parseProductsFromSection(section, packageName: packageName)

        return products
    }

    private func parseProductsFromSection(_ productsSection: String, packageName: String) -> [Product] {
        var products: [Product] = []

        // Find all product declarations
        let productDeclarations = findProductDeclarations(in: productsSection)

        for declaration in productDeclarations {
            if let product = parseProductDeclaration(declaration, packageName: packageName) {
                products.append(product)
            }
        }

        return products
    }

    private func findProductDeclarations(in content: String) -> [String] {
        var declarations: [String] = []
        var searchRange = content.startIndex..<content.endIndex

        let productTypePattern = Regex {
            "."
            ChoiceOf {
                "library"
                "executable"
                "plugin"
            }
            ZeroOrMore(.whitespace)
            "("
        }
        .dotMatchesNewlines()

        // Find each product declaration
        while let match = content[searchRange].firstMatch(of: productTypePattern) {
            // Calculate the absolute start position
            let absoluteStart = content.index(
                content.startIndex, offsetBy: content.distance(from: content.startIndex, to: match.range.lowerBound))

            // Find the matching closing parenthesis for this product declaration
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

    public func parseProductDeclaration(_ declaration: String, packageName: String) -> Product? {
        // Extract product type
        let productTypePattern = Regex {
            "."
            Capture {
                ChoiceOf {
                    "library"
                    "executable"
                    "plugin"
                }
            }
            ZeroOrMore(.whitespace)
            "("
        }
        .dotMatchesNewlines()

        guard let typeMatch = declaration.firstMatch(of: productTypePattern) else {
            return nil
        }

        let productTypeStr = String(typeMatch.1)
        let productType: Product.ProductType

        switch productTypeStr {
        case "library":
            productType = .library
        case "executable":
            productType = .executable
        case "plugin":
            productType = .plugin
        default:
            productType = .library
        }

        // Extract name using RegexBuilder pattern
        guard let nameMatch = declaration.firstMatch(of: nameParameter) else {
            return nil
        }

        let name = String(nameMatch.2)

        // Extract targets array
        let targets = parseProductTargets(from: declaration)

        return Product(name: name, type: productType, targets: targets, packageName: packageName)
    }

    public func parseProductTargets(from declaration: String) -> [String] {
        var targets: [String] = []

        // Simpler regex approach - look for targets: followed by array content
        let targetsRegex = /targets:\s*\[([^\]]+)\]/

        guard let match = declaration.firstMatch(of: targetsRegex) else {
            return targets
        }

        let targetsContent = String(match.1)

        // Extract quoted target names
        let targetNameRegex = /"([^"]+)"/
        for targetMatch in targetsContent.matches(of: targetNameRegex) {
            targets.append(String(targetMatch.1))
        }

        return targets
    }

    // MARK: - External Package Dependency Extraction

    private func extractExternalDependencies(from content: String) throws -> [ExternalPackageDependency] {
        var externalDependencies: [ExternalPackageDependency] = []

        // Try to get dependencies from variable declaration first
        var dependenciesSection = resolveDependenciesVariable(in: content)

        // If no variable found, look for dependencies array in Package constructor
        if dependenciesSection == nil {
            dependenciesSection = extractSection(from: content, sectionName: "dependencies")
        }

        guard let section = dependenciesSection, !section.isEmpty else {
            return externalDependencies
        }

        // Extract package URLs
        let urlRegex = /\.package\s*\(\s*url:\s*"([^"]+)"/
        for match in section.matches(of: urlRegex) {
            let url = String(match.1)
            let packageName = extractPackageNameFromURL(url)
            externalDependencies.append(ExternalPackageDependency(packageName: packageName, url: url))
        }

        // Extract package paths
        let pathRegex = /\.package\s*\(\s*path:\s*"([^"]+)"\s*\)/
        for match in section.matches(of: pathRegex) {
            let path = String(match.1)
            let packageName = extractPackageNameFromPath(path)
            externalDependencies.append(ExternalPackageDependency(packageName: packageName, path: path))
        }

        return externalDependencies
    }

    private func extractPackageNameFromURL(_ url: String) -> String {
        // Extract package name from URL like "https://github.com/apple/swift-algorithms.git"
        let components = url.components(separatedBy: "/")
        guard let lastComponent = components.last else {
            return url
        }

        let packageName = lastComponent.replacingOccurrences(of: ".git", with: "")
        return packageName
    }

    private func extractPackageNameFromPath(_ path: String) -> String {
        // Extract package name from path like "../DataLayer"
        let url = URL(fileURLWithPath: path)
        return url.lastPathComponent
    }
}
