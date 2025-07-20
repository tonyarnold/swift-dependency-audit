import Foundation
import Testing

@testable import SwiftDependencyAuditLib

@Suite("PackageParser Tests")
struct PackageParserTests {

    @Test("Parse basic Package.swift")
    func testBasicPackageParsing() async throws {
        let packageContent = """
            // swift-tools-version: 6.0
            import PackageDescription

            let package = Package(
                name: "TestPackage",
                dependencies: [
                    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0")
                ],
                targets: [
                    .executableTarget(
                        name: "TestTarget",
                        dependencies: [
                            .product(name: "ArgumentParser", package: "swift-argument-parser")
                        ]
                    ),
                ]
            )
            """

        // Create temporary file for testing
        let tempDir = FileManager.default.temporaryDirectory
        let packageDir = tempDir.appendingPathComponent("TestPackage_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: packageDir, withIntermediateDirectories: true)

        let packageFile = packageDir.appendingPathComponent("Package.swift")
        try packageContent.write(to: packageFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: packageDir)
        }

        let parser = PackageParser()
        let packageInfo = try await parser.parsePackage(at: packageDir.path)

        #expect(packageInfo.name == "TestPackage")
        #expect(packageInfo.targets.count == 1)
        #expect(packageInfo.targets.first?.name == "TestTarget")
        #expect(packageInfo.targets.first?.type == .executable)
        #expect(packageInfo.targets.first?.dependencies.contains("ArgumentParser") == true)
    }

    @Test("Parse package with multiple targets")
    func testMultipleTargets() async throws {
        let packageContent = """
            import PackageDescription

            let package = Package(
                name: "MultiTargetPackage",
                targets: [
                    .target(name: "LibraryTarget", dependencies: ["Dep1"]),
                    .executableTarget(name: "ExecutableTarget", dependencies: ["LibraryTarget"]),
                    .testTarget(name: "TestTarget", dependencies: ["LibraryTarget"])
                ]
            )
            """

        let tempDir = FileManager.default.temporaryDirectory
        let packageDir = tempDir.appendingPathComponent("MultiTargetPackage_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: packageDir, withIntermediateDirectories: true)

        let packageFile = packageDir.appendingPathComponent("Package.swift")
        try packageContent.write(to: packageFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: packageDir)
        }

        let parser = PackageParser()
        let packageInfo = try await parser.parsePackage(at: packageDir.path)

        #expect(packageInfo.name == "MultiTargetPackage")
        #expect(packageInfo.targets.count == 3)

        let libTarget = packageInfo.targets.first { $0.name == "LibraryTarget" }
        #expect(libTarget?.type == .library)
        #expect(libTarget?.dependencies == ["Dep1"])

        let execTarget = packageInfo.targets.first { $0.name == "ExecutableTarget" }
        #expect(execTarget?.type == .executable)
        #expect(execTarget?.dependencies == ["LibraryTarget"])

        let testTarget = packageInfo.targets.first { $0.name == "TestTarget" }
        #expect(testTarget?.type == .test)
        #expect(testTarget?.dependencies == ["LibraryTarget"])
    }

    @Test("Handle missing Package.swift")
    func testMissingPackageFile() async throws {
        let parser = PackageParser()

        do {
            _ = try await parser.parsePackage(at: "/nonexistent/path")
            #expect(Bool(false), "Should have thrown an error")
        } catch let error as ScannerError {
            #expect(error.localizedDescription.contains("Package.swift not found"))
        }
    }

    @Test("Parse package name with special characters")
    func testPackageNameParsing() async throws {
        let packageContent = """
            import PackageDescription

            let package = Package(
                name: "My-Special_Package123",
                targets: []
            )
            """

        let tempDir = FileManager.default.temporaryDirectory
        let packageDir = tempDir.appendingPathComponent("SpecialPackage_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: packageDir, withIntermediateDirectories: true)

        let packageFile = packageDir.appendingPathComponent("Package.swift")
        try packageContent.write(to: packageFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: packageDir)
        }

        let parser = PackageParser()
        let packageInfo = try await parser.parsePackage(at: packageDir.path)

        #expect(packageInfo.name == "My-Special_Package123")
    }

    @Test("Parse package name with custom path")
    func testPackagePathParsing() async throws {
        let packageContent = """
            import PackageDescription

            let package = Package(
                name: "MyCustomPathPackage",
                targets: [
                    .target(
                        name: "LibraryTarget",
                        dependencies: ["Dep1"],
                        path: "/Sources/MyCustomPath"
                    ),
                ]
            )
            """

        let tempDir = FileManager.default.temporaryDirectory
        let packageDir = tempDir.appendingPathComponent("SpecialPackage_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: packageDir, withIntermediateDirectories: true)

        let packageFile = packageDir.appendingPathComponent("Package.swift")
        try packageContent.write(to: packageFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: packageDir)
        }

        let parser = PackageParser()
        let packageInfo = try await parser.parsePackage(at: packageDir.path)

        let libTarget = packageInfo.targets.first { $0.name == "LibraryTarget" }
        #expect(libTarget?.path == "/Sources/MyCustomPath")
    }
}
