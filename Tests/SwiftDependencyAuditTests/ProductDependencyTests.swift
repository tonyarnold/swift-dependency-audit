import Foundation
import Testing

@testable import SwiftDependencyAuditLib

struct ProductDependencyTests {

    @Test func testProductParsing() async throws {
        let testBundle = Bundle.module
        let fixtureURL = testBundle.url(
            forResource: "ProductTestPackage", withExtension: "swift", subdirectory: "Fixtures")!
        let packageContent = try String(contentsOf: fixtureURL)

        let parser = PackageParser()
        let packageInfo = try await parser.parseContent(packageContent, packageDirectory: "/tmp/test")

        #expect(packageInfo.products.count == 3)

        let networkKit = packageInfo.products.first { $0.name == "NetworkKit" }
        #expect(networkKit != nil)
        #expect(networkKit?.type == .library)
        #expect(networkKit?.targets == ["NetworkClient", "NetworkCore"])

        let dataProcessor = packageInfo.products.first { $0.name == "DataProcessor" }
        #expect(dataProcessor != nil)
        #expect(dataProcessor?.type == .library)
        #expect(dataProcessor?.targets == ["DataModels", "DataStorage"])

        let cliTool = packageInfo.products.first { $0.name == "CLITool" }
        #expect(cliTool != nil)
        #expect(cliTool?.type == .executable)
        #expect(cliTool?.targets == ["CLIMain"])
    }

    @Test func testExternalDependencyParsing() async throws {
        let testBundle = Bundle.module
        let fixtureURL = testBundle.url(
            forResource: "ExternalDependencyPackage", withExtension: "swift", subdirectory: "Fixtures")!
        let packageContent = try String(contentsOf: fixtureURL)

        let parser = PackageParser()
        let packageInfo = try await parser.parseContent(packageContent, packageDirectory: "/tmp/test")

        #expect(packageInfo.externalDependencies.count == 3)

        let algorithms = packageInfo.externalDependencies.first { $0.packageName == "swift-algorithms" }
        #expect(algorithms != nil)
        #expect(algorithms?.url == "https://github.com/example/swift-algorithms.git")

        let utility = packageInfo.externalDependencies.first { $0.packageName == "UtilityLibrary" }
        #expect(utility != nil)
        #expect(utility?.path == "../UtilityLibrary")

        let networking = packageInfo.externalDependencies.first { $0.packageName == "networking-kit" }
        #expect(networking != nil)
        #expect(networking?.url == "https://github.com/example/networking-kit.git")
    }

    @Test func testProductToTargetMapping() async throws {
        let externalPackages = [
            ExternalPackage(
                name: "UtilityLibrary",
                products: [
                    Product(
                        name: "CoreUtilities", type: .library, targets: ["StringUtils", "DateUtils"],
                        packageName: "UtilityLibrary"),
                    Product(
                        name: "NetworkUtilities", type: .library, targets: ["HTTPClient", "WebSocket"],
                        packageName: "UtilityLibrary"),
                ],
                path: "/tmp/UtilityLibrary"
            ),
            ExternalPackage(
                name: "DataKit",
                products: [
                    Product(
                        name: "DataModels", type: .library, targets: ["Models", "Validators"], packageName: "DataKit")
                ],
                path: "/tmp/DataKit"
            ),
        ]

        let resolver = ExternalPackageResolver()
        let mapping = await resolver.buildProductToTargetMapping(from: externalPackages)

        #expect(mapping.count == 3)
        #expect(mapping["CoreUtilities"] == ["StringUtils", "DateUtils"])
        #expect(mapping["NetworkUtilities"] == ["HTTPClient", "WebSocket"])
        #expect(mapping["DataModels"] == ["Models", "Validators"])
    }

    @Test func testProductSatisfiedDependencyDetection() async throws {
        // Create a target that imports "StringUtils" and has a product dependency on "CoreUtilities"
        let target = Target(
            name: "TestTarget",
            type: .library,
            dependencyInfo: [
                DependencyInfo(name: "CoreUtilities", type: .product(packageName: "UtilityLibrary")),
                DependencyInfo(name: "SomeOtherDep", type: .target),
            ],
            path: nil
        )

        let packageInfo = PackageInfo(
            name: "TestPackage",
            targets: [target],
            dependencies: [],
            path: "/tmp/test"
        )

        // Mock external packages
        let externalPackages = [
            ExternalPackage(
                name: "UtilityLibrary",
                products: [
                    Product(
                        name: "CoreUtilities", type: .library, targets: ["StringUtils", "DateUtils"],
                        packageName: "UtilityLibrary")
                ],
                path: "/tmp/UtilityLibrary"
            )
        ]

        let productToTargetMapping = ["CoreUtilities": ["StringUtils", "DateUtils"]]

        // Mock source files with imports
        let sourceFiles = [
            SourceFile(
                path: "/tmp/test/file1.swift",
                imports: [
                    ImportInfo(moduleName: "StringUtils", lineNumber: 1),
                    ImportInfo(moduleName: "SomeOtherDep", lineNumber: 2),
                ])
        ]

        let analyzer = DependencyAnalyzer()
        let result = await analyzer.analyzeWithProductSupport(
            target: target,
            allImports: Set(["StringUtils", "SomeOtherDep"]),
            packageInfo: packageInfo,
            externalPackages: externalPackages,
            productToTargetMapping: productToTargetMapping,
            sourceFiles: sourceFiles
        )

        // StringUtils should be detected as product-satisfied
        #expect(result.productSatisfiedDependencies.count == 1)
        #expect(result.productSatisfiedDependencies.first?.importName == "StringUtils")
        #expect(result.productSatisfiedDependencies.first?.productName == "CoreUtilities")
        #expect(result.productSatisfiedDependencies.first?.packageName == "UtilityLibrary")

        // StringUtils should not be in missing dependencies since it's satisfied by product
        #expect(!result.missingDependencies.contains("StringUtils"))

        // SomeOtherDep should be in correct dependencies
        #expect(result.correctDependencies.contains("SomeOtherDep"))
    }

    @Test func testRedundantDirectDependencyDetection() async throws {
        // Create a target with both product dependency and direct target dependency
        let target = Target(
            name: "TestTarget",
            type: .library,
            dependencyInfo: [
                DependencyInfo(name: "CoreUtilities", type: .product(packageName: "UtilityLibrary")),
                DependencyInfo(name: "StringUtils", type: .target),
            ],
            path: nil
        )

        let packageInfo = PackageInfo(
            name: "TestPackage",
            targets: [target],
            dependencies: [],
            path: "/tmp/test"
        )

        let externalPackages = [
            ExternalPackage(
                name: "UtilityLibrary",
                products: [
                    Product(
                        name: "CoreUtilities", type: .library, targets: ["StringUtils", "DateUtils"],
                        packageName: "UtilityLibrary")
                ],
                path: "/tmp/UtilityLibrary"
            )
        ]

        let productToTargetMapping = ["CoreUtilities": ["StringUtils", "DateUtils"]]

        let sourceFiles = [
            SourceFile(
                path: "/tmp/test/file1.swift",
                imports: [
                    ImportInfo(moduleName: "StringUtils", lineNumber: 1)
                ])
        ]

        let analyzer = DependencyAnalyzer()
        let result = await analyzer.analyzeWithProductSupport(
            target: target,
            allImports: Set(["StringUtils"]),
            packageInfo: packageInfo,
            externalPackages: externalPackages,
            productToTargetMapping: productToTargetMapping,
            sourceFiles: sourceFiles
        )

        // StringUtils should be detected as redundant since it's covered by CoreUtilities
        #expect(result.redundantDirectDependencies.contains(where: { $0.targetName == "StringUtils" }))

        // StringUtils should be detected as product-satisfied
        #expect(result.productSatisfiedDependencies.count == 1)
        #expect(result.productSatisfiedDependencies.first?.importName == "StringUtils")
        #expect(result.productSatisfiedDependencies.first?.productName == "CoreUtilities")
    }

    @Test func testMixedProductAndDirectDependencies() async throws {
        let target = Target(
            name: "TestTarget",
            type: .library,
            dependencyInfo: [
                DependencyInfo(name: "CoreUtilities", type: .product(packageName: "UtilityLibrary")),
                DependencyInfo(name: "IndependentLibrary", type: .target),
            ],
            path: nil
        )

        let packageInfo = PackageInfo(
            name: "TestPackage",
            targets: [target],
            dependencies: [],
            path: "/tmp/test"
        )

        let externalPackages = [
            ExternalPackage(
                name: "UtilityLibrary",
                products: [
                    Product(
                        name: "CoreUtilities", type: .library, targets: ["StringUtils", "DateUtils"],
                        packageName: "UtilityLibrary")
                ],
                path: "/tmp/UtilityLibrary"
            )
        ]

        let productToTargetMapping = ["CoreUtilities": ["StringUtils", "DateUtils"]]

        let sourceFiles = [
            SourceFile(
                path: "/tmp/test/file1.swift",
                imports: [
                    ImportInfo(moduleName: "StringUtils", lineNumber: 1),  // Satisfied by product
                    ImportInfo(moduleName: "IndependentLibrary", lineNumber: 2),  // Direct dependency
                    ImportInfo(moduleName: "MissingDep", lineNumber: 3),  // Missing
                ])
        ]

        let analyzer = DependencyAnalyzer()
        let result = await analyzer.analyzeWithProductSupport(
            target: target,
            allImports: Set(["StringUtils", "IndependentLibrary", "MissingDep"]),
            packageInfo: packageInfo,
            externalPackages: externalPackages,
            productToTargetMapping: productToTargetMapping,
            sourceFiles: sourceFiles
        )

        // StringUtils should be product-satisfied
        #expect(result.productSatisfiedDependencies.count == 1)
        #expect(result.productSatisfiedDependencies.first?.importName == "StringUtils")

        // IndependentLibrary should be correct
        #expect(result.correctDependencies.contains("IndependentLibrary"))

        // MissingDep should be missing
        #expect(result.missingDependencies.contains("MissingDep"))

        // No redundant dependencies in this case
        #expect(result.redundantDirectDependencies.isEmpty)
    }

    @Test func testProductAndTargetWithSameNameNoFalsePositive() async throws {
        // Test scenario from user report: product "Apollo" providing target "Apollo"
        // This should NOT be flagged as redundant since there's no separate target dependency
        let target = Target(
            name: "TestTarget",
            type: .library,
            dependencyInfo: [
                DependencyInfo(name: "Apollo", type: .product(packageName: "apollo-ios"))
            ],
            path: nil
        )

        let packageInfo = PackageInfo(
            name: "TestPackage",
            targets: [target],
            dependencies: [],
            path: "/tmp/test"
        )

        let externalPackages = [
            ExternalPackage(
                name: "apollo-ios",
                products: [
                    Product(name: "Apollo", type: .library, targets: ["Apollo"], packageName: "apollo-ios")
                ],
                path: "/tmp/apollo-ios"
            )
        ]

        let productToTargetMapping = ["Apollo": ["Apollo"]]

        let sourceFiles = [
            SourceFile(
                path: "/tmp/test/file1.swift",
                imports: [
                    ImportInfo(moduleName: "Apollo", lineNumber: 1)
                ])
        ]

        let analyzer = DependencyAnalyzer()
        let result = await analyzer.analyzeWithProductSupport(
            target: target,
            allImports: Set(["Apollo"]),
            packageInfo: packageInfo,
            externalPackages: externalPackages,
            productToTargetMapping: productToTargetMapping,
            sourceFiles: sourceFiles
        )

        // Should NOT report redundant dependencies (this was the bug)
        #expect(result.redundantDirectDependencies.isEmpty)

        // Apollo should be product-satisfied
        #expect(result.productSatisfiedDependencies.count == 1)
        #expect(result.productSatisfiedDependencies.first?.importName == "Apollo")
        #expect(result.productSatisfiedDependencies.first?.productName == "Apollo")
        #expect(result.productSatisfiedDependencies.first?.packageName == "apollo-ios")

        // No missing dependencies
        #expect(result.missingDependencies.isEmpty)

        // Apollo should be in correct dependencies since it's a directly declared product dependency that's used
        #expect(result.correctDependencies.contains("Apollo"))
    }
}
