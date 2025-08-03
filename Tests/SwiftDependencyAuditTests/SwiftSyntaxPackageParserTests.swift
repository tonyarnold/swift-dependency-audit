import Foundation
import Testing

@testable import SwiftDependencyAuditLib

@Suite("SwiftSyntaxPackageParser Tests")
struct SwiftSyntaxPackageParserTests {

    @Test("Parse basic Package.swift with line numbers")
    func testBasicPackageParsingWithLineNumbers() async throws {
        let packageContent = """
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "TestPackage",
    products: [
        .library(name: "TestLibrary", targets: ["TestTarget"]),
        .executable(name: "TestExec", targets: ["TestExec"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "TestTarget",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "SomeOtherTarget"
            ]
        ),
        .executableTarget(
            name: "TestExec",
            dependencies: ["TestTarget"]
        ),
        .testTarget(
            name: "TestTargetTests",
            dependencies: ["TestTarget"]
        )
    ]
)
"""

        let parser = SwiftSyntaxPackageParser()
        let packageInfo = try await parser.parseContent(packageContent, packageDirectory: "/tmp")

        // Verify basic parsing
        #expect(packageInfo.name == "TestPackage")
        #expect(packageInfo.targets.count == 3)
        #expect(packageInfo.products.count == 2)
        #expect(packageInfo.externalDependencies.count == 1)

        // Verify target details
        let testTarget = packageInfo.targets.first { $0.name == "TestTarget" }
        #expect(testTarget != nil)
        #expect(testTarget?.type == .library)
        #expect(testTarget?.dependencies.count == 2)

        // Verify dependency line numbers are captured
        let argumentParserDep = testTarget?.dependencyInfo.first { $0.name == "ArgumentParser" }
        #expect(argumentParserDep != nil)
        #expect(argumentParserDep?.lineNumber != nil)
        if let lineNumber = argumentParserDep?.lineNumber {
            #expect(lineNumber > 0)
        }

        let otherTargetDep = testTarget?.dependencyInfo.first { $0.name == "SomeOtherTarget" }
        #expect(otherTargetDep != nil)
        #expect(otherTargetDep?.lineNumber != nil)
        if let lineNumber = otherTargetDep?.lineNumber {
            #expect(lineNumber > 0)
        }

        // Verify products
        let library = packageInfo.products.first { $0.name == "TestLibrary" }
        #expect(library?.type == .library)
        #expect(library?.targets == ["TestTarget"])

        let executable = packageInfo.products.first { $0.name == "TestExec" }
        #expect(executable?.type == .executable)
        #expect(executable?.targets == ["TestExec"])

        // Verify external dependencies
        let externalDep = packageInfo.externalDependencies.first
        #expect(externalDep?.packageName == "swift-argument-parser")
        #expect(externalDep?.url == "https://github.com/apple/swift-argument-parser.git")
    }

    @Test("Parse package with dependency constants")
    func testDependencyConstants() async throws {
        let packageContent = """
// swift-tools-version: 6.1
import PackageDescription

let ArgumentParser = Target.Dependency.product(name: "ArgumentParser", package: "swift-argument-parser")

let package = Package(
    name: "TestPackage",
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "TestTarget",
            dependencies: [
                ArgumentParser
            ]
        )
    ]
)
"""

        let parser = SwiftSyntaxPackageParser()
        let packageInfo = try await parser.parseContent(packageContent, packageDirectory: "/tmp")

        #expect(packageInfo.name == "TestPackage")
        #expect(packageInfo.targets.count == 1)

        let target = packageInfo.targets.first!
        #expect(target.name == "TestTarget")
        #expect(target.dependencies.count == 1)
        #expect(target.dependencies.first == "ArgumentParser")

        // Verify the constant was resolved correctly
        let dep = target.dependencyInfo.first!
        #expect(dep.name == "ArgumentParser")
        #expect(dep.type.isProduct)
        #expect(dep.lineNumber != nil)
    }

    @Test("SwiftSyntax parser handles conditional dependencies correctly - Fixes regex parser bug")
    func testConditionalDependenciesFix() async throws {
        let testBundle = Bundle.module
        let fixtureURL = testBundle.url(
            forResource: "ConditionalBugPackage", withExtension: "swift", subdirectory: "Fixtures")!
        let packageContent = try String(contentsOf: fixtureURL)

        // Test SwiftSyntax parser
        let syntaxParser = SwiftSyntaxPackageParser()
        let syntaxResult = try await syntaxParser.parseContent(packageContent, packageDirectory: "/tmp")

        // Test regex parser (should demonstrate the bug)
        let regexParser = PackageParser()
        let regexResult = try await regexParser.parseContent(packageContent, packageDirectory: "/tmp")

        #expect(syntaxResult.name == "ConditionalBugPackage")
        #expect(syntaxResult.targets.count == 1)

        let syntaxTarget = syntaxResult.targets.first!
        let regexTarget = regexResult.targets.first!

        // SwiftSyntax should correctly parse ALL dependencies including conditional ones
        #expect(syntaxTarget.dependencies.count == 3, "SwiftSyntax should find all 3 dependencies")
        #expect(syntaxTarget.dependencies.contains("MyModuleTV"))
        #expect(syntaxTarget.dependencies.contains("RxSwift"))
        #expect(syntaxTarget.dependencies.contains("AnotherProduct"))

        // Demonstrate the regex parser bug (this shows why SwiftSyntax migration is valuable)
        #expect(regexTarget.dependencies.count == 1, "Regex parser bug: only finds 1 dependency due to conditional parsing issue")
        
        print("SwiftSyntax parser found \(syntaxTarget.dependencies.count) dependencies: \(syntaxTarget.dependencies)")
        print("Regex parser found \(regexTarget.dependencies.count) dependencies: \(regexTarget.dependencies)")
    }

    @Test("Compare line number accuracy with regex parser")
    func testLineNumberAccuracy() async throws {
        let testBundle = Bundle.module
        let fixtureURL = testBundle.url(
            forResource: "BasicPackage", withExtension: "swift", subdirectory: "Fixtures")!
        let packageContent = try String(contentsOf: fixtureURL)

        // Parse with both parsers
        let syntaxParser = SwiftSyntaxPackageParser()
        let regexParser = PackageParser()
        
        let syntaxResult = try await syntaxParser.parseContent(packageContent, packageDirectory: "/tmp")
        let regexResult = try await regexParser.parseContent(packageContent, packageDirectory: "/tmp")

        // Compare basic structure
        #expect(syntaxResult.name == regexResult.name)
        #expect(syntaxResult.targets.count == regexResult.targets.count)

        // Compare specific dependency line numbers where available
        for syntaxTarget in syntaxResult.targets {
            if let regexTarget = regexResult.targets.first(where: { $0.name == syntaxTarget.name }) {
                for syntaxDep in syntaxTarget.dependencyInfo {
                    if let regexDep = regexTarget.dependencyInfo.first(where: { $0.name == syntaxDep.name }) {
                        // Both should have line numbers, and they should be close (within 2 lines tolerance)
                        if let syntaxLine = syntaxDep.lineNumber, let regexLine = regexDep.lineNumber {
                            #expect(abs(syntaxLine - regexLine) <= 2, "Line numbers should be close: SwiftSyntax=\(syntaxLine), Regex=\(regexLine)")
                        }
                    }
                }
            }
        }
    }
}

// Helper extension for dependency type checking
extension DependencyInfo.DependencyType {
    var isProduct: Bool {
        switch self {
        case .product: return true
        case .target: return false
        }
    }
}