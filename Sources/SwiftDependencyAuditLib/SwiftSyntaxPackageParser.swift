import Foundation
import SwiftParser
import SwiftSyntax

/// SwiftSyntax-based Package.swift parser that replaces the regex-based approach
/// with proper AST parsing for improved robustness and accuracy.
public actor SwiftSyntaxPackageParser {

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
        // Parse the Swift source code into an AST
        let sourceFile = Parser.parse(source: content)

        // Create a visitor to extract package information
        let visitor = PackageVisitor(sourceText: content)
        visitor.walk(sourceFile)

        // Extract package name
        guard let packageName = visitor.packageName else {
            throw ScannerError.invalidPackageFile("Could not find package name")
        }

        // Extract targets with proper line number information
        let targets = visitor.targets

        // Extract dependencies
        let dependencies = visitor.packageDependencies

        // Extract products
        let products = visitor.products.map { productInfo in
            Product(
                name: productInfo.name,
                type: productInfo.type,
                targets: productInfo.targets,
                packageName: packageName
            )
        }

        // Extract external dependencies
        let externalDependencies = visitor.externalDependencies

        return PackageInfo(
            name: packageName,
            targets: targets,
            dependencies: dependencies,
            products: products,
            externalDependencies: externalDependencies,
            path: packageDirectory
        )
    }
}

/// Syntax visitor that traverses the AST to extract package information
private class PackageVisitor: SyntaxVisitor {
    private let sourceText: String
    private let sourceLocationConverter: SourceLocationConverter

    // Collected information
    var packageName: String?
    var targets: [Target] = []
    var packageDependencies: [String] = []
    var products: [ProductInfo] = []
    var externalDependencies: [ExternalPackageDependency] = []

    // Variable resolution
    private var stringVariables: [String: String] = [:]
    private var dependencyConstants: [String: DependencyInfo] = [:]

    init(sourceText: String) {
        self.sourceText = sourceText
        self.sourceLocationConverter = SourceLocationConverter(
            fileName: "Package.swift", tree: Parser.parse(source: sourceText))
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        // Handle variable declarations like: let name = "PackageName"
        if let patternBinding = node.bindings.first,
            let identifier = patternBinding.pattern.as(IdentifierPatternSyntax.self),
            let initializer = patternBinding.initializer,
            let stringLiteral = initializer.value.as(StringLiteralExprSyntax.self)
        {

            let variableName = identifier.identifier.text
            let value = extractStringLiteralValue(stringLiteral)
            stringVariables[variableName] = value
        }

        // Handle dependency constants like: let TCA = Target.Dependency.product(...)
        if let patternBinding = node.bindings.first,
            let identifier = patternBinding.pattern.as(IdentifierPatternSyntax.self),
            let initializer = patternBinding.initializer,
            let functionCall = initializer.value.as(FunctionCallExprSyntax.self)
        {

            let constantName = identifier.identifier.text
            if let dependencyInfo = extractDependencyConstant(functionCall) {
                dependencyConstants[constantName] = dependencyInfo
            }
        }

        return .visitChildren
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        // Handle Package(...) constructor
        if let memberAccess = node.calledExpression.as(DeclReferenceExprSyntax.self),
            memberAccess.baseName.text == "Package"
        {
            extractPackageInfo(from: node)
        }

        // Handle .target(), .executableTarget(), etc. only in Package targets context
        if let memberAccess = node.calledExpression.as(MemberAccessExprSyntax.self) {
            switch memberAccess.declName.baseName.text {
            case "target", "executableTarget", "testTarget", "macro", "systemLibrary", "binaryTarget":
                if isTargetContext(functionCall: node),
                    let target = extractTarget(from: node, type: memberAccess.declName.baseName.text)
                {
                    targets.append(target)
                }
            case "plugin":
                // Plugin can be either a target or a product - check the context
                if isProductContext(functionCall: node) {
                    if let product = extractProduct(from: node, type: memberAccess.declName.baseName.text) {
                        products.append(product)
                    }
                } else if isTargetContext(functionCall: node) {
                    if let target = extractTarget(from: node, type: memberAccess.declName.baseName.text) {
                        targets.append(target)
                    }
                }
            case "library", "executable":
                if let product = extractProduct(from: node, type: memberAccess.declName.baseName.text) {
                    products.append(product)
                }
            case "package":
                if let externalDep = extractExternalDependency(from: node) {
                    externalDependencies.append(externalDep)
                }
            default:
                break
            }
        }

        return .visitChildren
    }

    private func extractPackageInfo(from functionCall: FunctionCallExprSyntax) {
        for argument in functionCall.arguments {
            if argument.label?.text == "name" {
                if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self) {
                    packageName = extractStringLiteralValue(stringLiteral)
                } else if let identifier = argument.expression.as(DeclReferenceExprSyntax.self) {
                    // Handle variable reference
                    packageName = stringVariables[identifier.baseName.text]
                }
            }
        }
    }

    private func extractTarget(from functionCall: FunctionCallExprSyntax, type: String) -> Target? {
        var name: String?
        var customPath: String?
        var dependencyInfos: [DependencyInfo] = []

        let targetType: Target.TargetType = {
            switch type {
            case "executableTarget": return .executable
            case "testTarget": return .test
            case "macro": return .library  // Treat macros as library targets
            case "plugin": return .plugin
            case "systemLibrary": return .systemLibrary
            case "binaryTarget": return .binaryTarget
            default: return .library
            }
        }()

        for argument in functionCall.arguments {
            switch argument.label?.text {
            case "name":
                if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self) {
                    name = extractStringLiteralValue(stringLiteral)
                }
            case "path":
                if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self) {
                    customPath = extractStringLiteralValue(stringLiteral)
                }
            case "dependencies":
                dependencyInfos = extractDependencies(from: argument.expression)
            default:
                break
            }
        }

        guard let targetName = name else { return nil }

        return Target(name: targetName, type: targetType, dependencyInfo: dependencyInfos, path: customPath)
    }

    private func extractDependencies(from expression: ExprSyntax) -> [DependencyInfo] {
        var dependencies: [DependencyInfo] = []

        if let arrayExpr = expression.as(ArrayExprSyntax.self) {
            for element in arrayExpr.elements {
                if let functionCall = element.expression.as(FunctionCallExprSyntax.self),
                    let memberAccess = functionCall.calledExpression.as(MemberAccessExprSyntax.self)
                {
                    switch memberAccess.declName.baseName.text {
                    case "product":
                        // Extract .product(name: "...", package: "...")
                        var productName: String?
                        var packageName: String?

                        for argument in functionCall.arguments {
                            switch argument.label?.text {
                            case "name":
                                if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self) {
                                    productName = extractStringLiteralValue(stringLiteral)
                                }
                            case "package":
                                if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self) {
                                    packageName = extractStringLiteralValue(stringLiteral)
                                }
                            default:
                                break
                            }
                        }

                        if let prodName = productName, let pkgName = packageName {
                            let lineNumber = getLineNumber(for: functionCall)
                            dependencies.append(
                                DependencyInfo(
                                    name: prodName,
                                    type: .product(packageName: pkgName),
                                    lineNumber: lineNumber
                                ))
                        }
                    case "target", "byName":
                        // Extract .target(name: "...") or .byName(name: "...")
                        var dependencyTargetName: String?
                        for argument in functionCall.arguments {
                            if argument.label?.text == "name",
                                let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self)
                            {
                                dependencyTargetName = extractStringLiteralValue(stringLiteral)
                            }
                        }

                        if let name = dependencyTargetName {
                            let lineNumber = getLineNumber(for: functionCall)
                            dependencies.append(
                                DependencyInfo(
                                    name: name,
                                    type: .target,
                                    lineNumber: lineNumber
                                ))
                        }
                    default:
                        break
                    }
                } else if let stringLiteral = element.expression.as(StringLiteralExprSyntax.self) {
                    // Simple string dependency
                    let depName = extractStringLiteralValue(stringLiteral)
                    let lineNumber = getLineNumber(for: stringLiteral)
                    dependencies.append(
                        DependencyInfo(
                            name: depName,
                            type: .target,
                            lineNumber: lineNumber
                        ))
                } else if let identifier = element.expression.as(DeclReferenceExprSyntax.self) {
                    // Constant reference
                    let constantName = identifier.baseName.text
                    if let constantInfo = dependencyConstants[constantName] {
                        let lineNumber = getLineNumber(for: identifier)
                        dependencies.append(
                            DependencyInfo(
                                name: constantInfo.name,
                                type: constantInfo.type,
                                lineNumber: lineNumber
                            ))
                    }
                }
            }
        }

        return dependencies
    }

    private func extractProduct(from functionCall: FunctionCallExprSyntax, type: String) -> ProductInfo? {
        var name: String?
        var targets: [String] = []

        let productType: Product.ProductType = {
            switch type {
            case "executable": return .executable
            case "plugin": return .plugin
            default: return .library
            }
        }()

        for argument in functionCall.arguments {
            switch argument.label?.text {
            case "name":
                if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self) {
                    name = extractStringLiteralValue(stringLiteral)
                }
            case "targets":
                if let arrayExpr = argument.expression.as(ArrayExprSyntax.self) {
                    for element in arrayExpr.elements {
                        if let stringLiteral = element.expression.as(StringLiteralExprSyntax.self) {
                            targets.append(extractStringLiteralValue(stringLiteral))
                        }
                    }
                }
            default:
                break
            }
        }

        guard let productName = name else { return nil }

        return ProductInfo(name: productName, type: productType, targets: targets)
    }

    private func extractExternalDependency(from functionCall: FunctionCallExprSyntax) -> ExternalPackageDependency? {
        var url: String?
        var path: String?

        for argument in functionCall.arguments {
            switch argument.label?.text {
            case "url":
                if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self) {
                    url = extractStringLiteralValue(stringLiteral)
                }
            case "path":
                if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self) {
                    path = extractStringLiteralValue(stringLiteral)
                }
            default:
                break
            }
        }

        let packageName: String
        if let urlString = url {
            packageName = extractPackageNameFromURL(urlString)
        } else if let pathString = path {
            packageName = extractPackageNameFromPath(pathString)
        } else {
            return nil
        }

        return ExternalPackageDependency(packageName: packageName, url: url, path: path)
    }

    private func extractDependencyConstant(_ functionCall: FunctionCallExprSyntax) -> DependencyInfo? {
        // Check if this is Target.Dependency.product(...)
        guard let memberAccess = functionCall.calledExpression.as(MemberAccessExprSyntax.self),
            memberAccess.declName.baseName.text == "product"
        else {
            return nil
        }

        var productName: String?
        var packageName: String?

        for argument in functionCall.arguments {
            switch argument.label?.text {
            case "name":
                if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self) {
                    productName = extractStringLiteralValue(stringLiteral)
                }
            case "package":
                if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self) {
                    packageName = extractStringLiteralValue(stringLiteral)
                }
            default:
                break
            }
        }

        if let prodName = productName, let pkgName = packageName {
            return DependencyInfo(name: prodName, type: .product(packageName: pkgName), lineNumber: nil)
        }

        return nil
    }

    private func extractStringLiteralValue(_ stringLiteral: StringLiteralExprSyntax) -> String {
        // Extract the content from string literal, handling escape sequences
        return stringLiteral.segments.compactMap { segment in
            if case .stringSegment(let stringSegment) = segment {
                return stringSegment.content.text
            }
            return nil
        }.joined()
    }

    private func getLineNumber(for node: SyntaxProtocol) -> Int? {
        let location = sourceLocationConverter.location(for: node.positionAfterSkippingLeadingTrivia)
        return location.line
    }

    private func extractPackageNameFromURL(_ url: String) -> String {
        let components = url.components(separatedBy: "/")
        guard let lastComponent = components.last else {
            return url
        }
        return lastComponent.replacingOccurrences(of: ".git", with: "")
    }

    private func extractPackageNameFromPath(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.lastPathComponent
    }

    private func isProductContext(functionCall: FunctionCallExprSyntax) -> Bool {
        // Walk up the AST to determine if this plugin call is within a products array
        var current: SyntaxProtocol? = functionCall.parent
        while let node = current {
            if let arrayExpr = node.as(ArrayExprSyntax.self) {
                // Check if this array is the argument to a "products" parameter
                if let argumentExpr = arrayExpr.parent?.as(LabeledExprSyntax.self),
                    argumentExpr.label?.text == "products"
                {
                    return true
                }
            }
            current = node.parent
        }
        return false
    }

    private func isTargetContext(functionCall: FunctionCallExprSyntax) -> Bool {
        // Walk up the AST to determine if this call is a direct element of a targets array
        var current: SyntaxProtocol? = functionCall.parent
        while let node = current {
            if let arrayExpr = node.as(ArrayExprSyntax.self) {
                if let argumentExpr = arrayExpr.parent?.as(LabeledExprSyntax.self) {
                    return argumentExpr.label?.text == "targets"
                }
                return false
            }
            current = node.parent
        }
        return false
    }
}

// Helper struct for product information during parsing
private struct ProductInfo {
    let name: String
    let type: Product.ProductType
    let targets: [String]
}
