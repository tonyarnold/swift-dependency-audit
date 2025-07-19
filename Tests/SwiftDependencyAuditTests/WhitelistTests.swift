import Foundation
import Testing

@testable import SwiftDependencyAuditLib

@Suite("Whitelist Functionality Tests")
struct WhitelistTests {

    @Test("Whitelist filters imports correctly")
    func testWhitelistFiltering() async throws {
        let scanner = ImportScanner()
        let content = """
            import Foundation
            import SwiftUI
            import AppKit
            import MyCustomModule
            import AnotherCustomModule
            """

        let whitelist: Set<String> = ["SwiftUI", "AppKit"]
        let imports = await scanner.scanContent(content, customWhitelist: whitelist)

        // Foundation should be filtered by built-in list
        // SwiftUI and AppKit should be filtered by custom whitelist
        // Only custom modules should remain
        #expect(imports.count == 2)

        let moduleNames = Set(imports.map { $0.moduleName })
        #expect(moduleNames.contains("MyCustomModule"))
        #expect(moduleNames.contains("AnotherCustomModule"))
        #expect(!moduleNames.contains("Foundation"))
        #expect(!moduleNames.contains("SwiftUI"))
        #expect(!moduleNames.contains("AppKit"))
    }

    @Test("Empty whitelist behaves normally")
    func testEmptyWhitelist() async throws {
        let scanner = ImportScanner()
        let content = """
            import Foundation
            import MyCustomModule
            """

        let imports = await scanner.scanContent(content, customWhitelist: [])

        // Foundation should still be filtered by built-in list
        #expect(imports.count == 1)
        #expect(imports.first?.moduleName == "MyCustomModule")
    }

    @Test("Whitelist with testable imports")
    func testWhitelistWithTestableImports() async throws {
        let scanner = ImportScanner()
        let content = """
            @testable import SwiftUI
            @testable import MyModule
            import AppKit
            """

        let whitelist: Set<String> = ["SwiftUI", "AppKit"]
        let imports = await scanner.scanContent(content, customWhitelist: whitelist)

        #expect(imports.count == 1)
        #expect(imports.first?.moduleName == "MyModule")
        #expect(imports.first?.isTestable == true)
    }

    @Test("Case sensitive whitelist matching")
    func testCaseSensitiveWhitelist() async throws {
        let scanner = ImportScanner()
        let content = """
            import swiftui
            import SwiftUI
            import SWIFTUI
            """

        let whitelist: Set<String> = ["SwiftUI"]
        let imports = await scanner.scanContent(content, customWhitelist: whitelist)

        // Only exact case match should be filtered
        #expect(imports.count == 2)

        let moduleNames = Set(imports.map { $0.moduleName })
        #expect(moduleNames.contains("swiftui"))
        #expect(moduleNames.contains("SWIFTUI"))
        #expect(!moduleNames.contains("SwiftUI"))
    }

    @Test("Whitelist integration with DependencyAnalyzer")
    func testWhitelistIntegrationWithAnalyzer() async throws {
        let tempDir = try createTestPackage(
            sourceFiles: [
                "main.swift": """
                import Foundation
                import CustomFramework
                import MyModule
                """
            ]
        )

        defer { try? FileManager.default.removeItem(at: tempDir) }

        let packageInfo = PackageInfo(
            name: "TestPackage",
            targets: [Target(name: "TestTarget", type: .executable, dependencies: ["MyModule"], path: nil)],
            dependencies: ["MyModule"],
            path: tempDir.path
        )

        let analyzer = DependencyAnalyzer()

        // Test without whitelist - should detect CustomFramework as missing
        let resultWithoutWhitelist = try await analyzer.analyzeTarget(
            packageInfo.targets[0],
            in: packageInfo
        )

        #expect(resultWithoutWhitelist.missingDependencies.contains("CustomFramework"))
        #expect(resultWithoutWhitelist.correctDependencies.contains("MyModule"))

        // Test with whitelist - CustomFramework should be ignored
        let customWhitelist: Set<String> = ["CustomFramework"]
        let resultWithWhitelist = try await analyzer.analyzeTarget(
            packageInfo.targets[0],
            in: packageInfo,
            customWhitelist: customWhitelist
        )

        #expect(resultWithWhitelist.missingDependencies.isEmpty)
        #expect(resultWithWhitelist.correctDependencies.contains("MyModule"))
        #expect(!resultWithWhitelist.hasIssues)
    }

    @Test("Whitelist with standard library overlap")
    func testWhitelistWithStandardLibraryOverlap() async throws {
        let scanner = ImportScanner()
        let content = """
            import Foundation
            import UIKit
            import MyUIKit
            """

        // Include standard library module in whitelist (should be redundant)
        let whitelist: Set<String> = ["Foundation", "MyUIKit"]
        let imports = await scanner.scanContent(content, customWhitelist: whitelist)

        // Foundation and UIKit filtered by standard library list
        // MyUIKit filtered by custom whitelist
        #expect(imports.isEmpty)
    }

    @Test("Large whitelist performance")
    func testLargeWhitelistPerformance() async throws {
        let scanner = ImportScanner()

        // Create a large whitelist
        var whitelist: Set<String> = []
        for i in 0..<1000 {
            whitelist.insert("Module\(i)")
        }

        let content = """
            import Module500
            import Module999
            import NotInWhitelist
            """

        let startTime = Date()
        let imports = await scanner.scanContent(content, customWhitelist: whitelist)
        let endTime = Date()

        #expect(imports.count == 1)
        #expect(imports.first?.moduleName == "NotInWhitelist")

        // Performance should be reasonable (under 100ms for this test)
        let duration = endTime.timeIntervalSince(startTime)
        #expect(duration < 0.1)
    }

    private func createTestPackage(sourceFiles: [String: String]) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("TestPackage_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let sourceDir = tempDir.appendingPathComponent("Sources").appendingPathComponent("TestTarget")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)

        for (filename, content) in sourceFiles {
            let fileURL = sourceDir.appendingPathComponent(filename)
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        }

        return tempDir
    }
}
