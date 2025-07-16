import Testing
import Foundation
@testable import DependentImportScannerLib

@Suite("DependencyAnalyzer Tests")
struct DependencyAnalyzerTests {
    
    @Test("Analyze target with correct dependencies")
    func testCorrectDependencies() async throws {
        let tempDir = try createTestPackage(
            packageName: "TestPackage",
            targetName: "TestTarget",
            dependencies: ["ArgumentParser"],
            sourceFiles: ["main.swift": "import ArgumentParser\nprint(\"Hello\")\n"]
        )
        
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let packageInfo = PackageInfo(
            name: "TestPackage",
            targets: [Target(name: "TestTarget", type: .executable, dependencies: ["ArgumentParser"], path: nil)],
            dependencies: ["ArgumentParser"],
            path: tempDir.path
        )
        
        let analyzer = DependencyAnalyzer()
        let result = try await analyzer.analyzeTarget(packageInfo.targets[0], in: packageInfo)
        
        #expect(result.correctDependencies.contains("ArgumentParser"))
        #expect(result.missingDependencies.isEmpty)
        #expect(result.unusedDependencies.isEmpty)
        #expect(!result.hasIssues)
    }
    
    @Test("Detect missing dependencies")
    func testMissingDependencies() async throws {
        let tempDir = try createTestPackage(
            packageName: "TestPackage",
            targetName: "TestTarget",
            dependencies: [], // No dependencies declared
            sourceFiles: ["main.swift": "import SomeLibrary\nprint(\"Hello\")\n"]
        )
        
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let packageInfo = PackageInfo(
            name: "TestPackage",
            targets: [Target(name: "TestTarget", type: .executable, dependencies: [], path: nil)],
            dependencies: [],
            path: tempDir.path
        )
        
        let analyzer = DependencyAnalyzer()
        let result = try await analyzer.analyzeTarget(packageInfo.targets[0], in: packageInfo)
        
        #expect(result.missingDependencies.contains("SomeLibrary"))
        #expect(result.correctDependencies.isEmpty)
        #expect(result.unusedDependencies.isEmpty)
        #expect(result.hasIssues)
    }
    
    @Test("Detect unused dependencies")
    func testUnusedDependencies() async throws {
        let tempDir = try createTestPackage(
            packageName: "TestPackage",
            targetName: "TestTarget",
            dependencies: ["UnusedLibrary"],
            sourceFiles: ["main.swift": "print(\"Hello\")\n"] // No imports
        )
        
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let packageInfo = PackageInfo(
            name: "TestPackage",
            targets: [Target(name: "TestTarget", type: .executable, dependencies: ["UnusedLibrary"], path: nil)],
            dependencies: ["UnusedLibrary"],
            path: tempDir.path
        )
        
        let analyzer = DependencyAnalyzer()
        let result = try await analyzer.analyzeTarget(packageInfo.targets[0], in: packageInfo)
        
        #expect(result.unusedDependencies.contains("UnusedLibrary"))
        #expect(result.correctDependencies.isEmpty)
        #expect(result.missingDependencies.isEmpty)
        #expect(result.hasIssues)
    }
    
    @Test("Analyze multiple files with mixed dependencies")
    func testMultipleFiles() async throws {
        let tempDir = try createTestPackage(
            packageName: "TestPackage",
            targetName: "TestTarget",
            dependencies: ["UsedLibrary"],
            sourceFiles: [
                "main.swift": "import UsedLibrary\nimport MissingLibrary\n",
                "helper.swift": "import Foundation\nimport UsedLibrary\n"
            ]
        )
        
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let packageInfo = PackageInfo(
            name: "TestPackage",
            targets: [Target(name: "TestTarget", type: .executable, dependencies: ["UsedLibrary"], path: nil)],
            dependencies: ["UsedLibrary"],
            path: tempDir.path
        )
        
        let analyzer = DependencyAnalyzer()
        let result = try await analyzer.analyzeTarget(packageInfo.targets[0], in: packageInfo)
        
        #expect(result.correctDependencies.contains("UsedLibrary"))
        #expect(result.missingDependencies.contains("MissingLibrary"))
        #expect(result.unusedDependencies.isEmpty)
        #expect(result.hasIssues)
        #expect(result.sourceFiles.count == 2)
    }
    
    @Test("Respect custom whitelist")
    func testCustomWhitelist() async throws {
        let tempDir = try createTestPackage(
            packageName: "TestPackage",
            targetName: "TestTarget",
            dependencies: [],
            sourceFiles: ["main.swift": "import CustomSystemLibrary\nprint(\"Hello\")\n"]
        )
        
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let packageInfo = PackageInfo(
            name: "TestPackage",
            targets: [Target(name: "TestTarget", type: .executable, dependencies: [], path: nil)],
            dependencies: [],
            path: tempDir.path
        )
        
        let analyzer = DependencyAnalyzer()
        let customWhitelist: Set<String> = ["CustomSystemLibrary"]
        let result = try await analyzer.analyzeTarget(packageInfo.targets[0], in: packageInfo, customWhitelist: customWhitelist)
        
        #expect(result.missingDependencies.isEmpty) // Should be filtered by whitelist
        #expect(result.correctDependencies.isEmpty)
        #expect(result.unusedDependencies.isEmpty)
        #expect(!result.hasIssues)
    }
    
    @Test("Analyze package with multiple targets")
    func testAnalyzePackage() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("TestPackage_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Create first target
        let target1Dir = tempDir.appendingPathComponent("Sources/Target1")
        try FileManager.default.createDirectory(at: target1Dir, withIntermediateDirectories: true)
        try "import LibraryA".write(to: target1Dir.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)
        
        // Create second target
        let target2Dir = tempDir.appendingPathComponent("Sources/Target2")
        try FileManager.default.createDirectory(at: target2Dir, withIntermediateDirectories: true)
        try "import LibraryB".write(to: target2Dir.appendingPathComponent("helper.swift"), atomically: true, encoding: .utf8)
        
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let packageInfo = PackageInfo(
            name: "TestPackage",
            targets: [
                Target(name: "Target1", type: .library, dependencies: ["LibraryA"], path: nil),
                Target(name: "Target2", type: .library, dependencies: [], path: nil)
            ],
            dependencies: ["LibraryA"],
            path: tempDir.path
        )
        
        let analyzer = DependencyAnalyzer()
        let results = try await analyzer.analyzePackage(packageInfo)
        
        #expect(results.count == 2)
        
        let target1Result = results.first { $0.target.name == "Target1" }
        #expect(target1Result?.correctDependencies.contains("LibraryA") == true)
        #expect(target1Result?.hasIssues == false)
        
        let target2Result = results.first { $0.target.name == "Target2" }
        #expect(target2Result?.missingDependencies.contains("LibraryB") == true)
        #expect(target2Result?.hasIssues == true)
    }
    
    private func createTestPackage(
        packageName: String,
        targetName: String,
        dependencies: [String],
        sourceFiles: [String: String]
    ) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("\(packageName)_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let sourceDir = tempDir.appendingPathComponent("Sources").appendingPathComponent(targetName)
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        
        for (filename, content) in sourceFiles {
            let fileURL = sourceDir.appendingPathComponent(filename)
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        
        return tempDir
    }
}