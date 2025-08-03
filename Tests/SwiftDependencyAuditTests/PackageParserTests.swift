import Foundation
import Testing

@testable import SwiftDependencyAuditLib

@Suite("PackageParser Tests")
struct PackageParserTests {

    @Test("Parse basic Package.swift")
    func testBasicPackageParsing() async throws {
        let testBundle = Bundle.module
        let fixtureURL = testBundle.url(
            forResource: "BasicPackage", withExtension: "swift", subdirectory: "Fixtures")!
        let packageContent = try String(contentsOf: fixtureURL)

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
        let testBundle = Bundle.module
        let fixtureURL = testBundle.url(
            forResource: "MultiTargetPackage", withExtension: "swift", subdirectory: "Fixtures")!
        let packageContent = try String(contentsOf: fixtureURL)

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
        let testBundle = Bundle.module
        let fixtureURL = testBundle.url(
            forResource: "SpecialNamePackage", withExtension: "swift", subdirectory: "Fixtures")!
        let packageContent = try String(contentsOf: fixtureURL)

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
        let testBundle = Bundle.module
        let fixtureURL = testBundle.url(
            forResource: "CustomPathPackage", withExtension: "swift", subdirectory: "Fixtures")!
        let packageContent = try String(contentsOf: fixtureURL)

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

    @Test("Parse package with constant-based dependencies")
    func testConstantBasedDependencies() async throws {
        let testBundle = Bundle.module
        let fixtureURL = testBundle.url(
            forResource: "ConstantDepsPackage", withExtension: "swift", subdirectory: "Fixtures")!
        let packageContent = try String(contentsOf: fixtureURL)

        let tempDir = FileManager.default.temporaryDirectory
        let packageDir = tempDir.appendingPathComponent("ConstantDepsPackage_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: packageDir, withIntermediateDirectories: true)

        let packageFile = packageDir.appendingPathComponent("Package.swift")
        try packageContent.write(to: packageFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: packageDir)
        }

        let parser = PackageParser()
        let packageInfo = try await parser.parsePackage(at: packageDir.path)

        #expect(packageInfo.name == "ConstantDepsPackage")
        #expect(packageInfo.targets.count == 2)

        // Check MyFeature target
        let myFeature = packageInfo.targets.first { $0.name == "MyFeature" }
        #expect(myFeature != nil)
        #expect(myFeature?.type == .library)
        #expect(myFeature?.dependencies.count == 2)
        #expect(myFeature?.dependencies.contains("ComposableArchitecture") == true)
        #expect(myFeature?.dependencies.contains("AsyncAlgorithms") == true)

        // Check MyFeatureTests target
        let myFeatureTests = packageInfo.targets.first { $0.name == "MyFeatureTests" }
        #expect(myFeatureTests != nil)
        #expect(myFeatureTests?.type == .test)
        #expect(myFeatureTests?.dependencies.count == 2)
        #expect(myFeatureTests?.dependencies.contains("MyFeature") == true)
        #expect(myFeatureTests?.dependencies.contains("ComposableArchitecture") == true)
    }

    @Test("Parse package with mixed dependency styles")
    func testMixedDependencyStyles() async throws {
        let testBundle = Bundle.module
        let fixtureURL = testBundle.url(
            forResource: "MixedStylePackage", withExtension: "swift", subdirectory: "Fixtures")!
        let packageContent = try String(contentsOf: fixtureURL)

        let tempDir = FileManager.default.temporaryDirectory
        let packageDir = tempDir.appendingPathComponent("MixedStylePackage_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: packageDir, withIntermediateDirectories: true)

        let packageFile = packageDir.appendingPathComponent("Package.swift")
        try packageContent.write(to: packageFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: packageDir)
        }

        let parser = PackageParser()
        let packageInfo = try await parser.parsePackage(at: packageDir.path)

        #expect(packageInfo.name == "MixedStylePackage")
        #expect(packageInfo.targets.count == 1)

        let mainTarget = packageInfo.targets.first
        #expect(mainTarget?.name == "MainTarget")
        #expect(mainTarget?.dependencies.count == 3)
        #expect(mainTarget?.dependencies.contains("CustomFramework") == true)
        #expect(mainTarget?.dependencies.contains("ArgumentParser") == true)
        #expect(mainTarget?.dependencies.contains("InternalDependency") == true)
    }

    @Test("Parse package with constants without access modifiers")
    func testConstantsWithoutAccessModifiers() async throws {
        let testBundle = Bundle.module
        let fixtureURL = testBundle.url(
            forResource: "NoAccessModifierPackage", withExtension: "swift", subdirectory: "Fixtures")!
        let packageContent = try String(contentsOf: fixtureURL)

        let tempDir = FileManager.default.temporaryDirectory
        let packageDir = tempDir.appendingPathComponent("NoAccessModifierPackage_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: packageDir, withIntermediateDirectories: true)

        let packageFile = packageDir.appendingPathComponent("Package.swift")
        try packageContent.write(to: packageFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: packageDir)
        }

        let parser = PackageParser()
        let packageInfo = try await parser.parsePackage(at: packageDir.path)

        #expect(packageInfo.name == "NoAccessModifierPackage")
        #expect(packageInfo.targets.count == 1)

        let myTarget = packageInfo.targets.first
        #expect(myTarget?.name == "MyTarget")
        #expect(myTarget?.dependencies.count == 2)
        #expect(myTarget?.dependencies.contains("ComposableArchitecture") == true)
        #expect(myTarget?.dependencies.contains("AsyncAlgorithms") == true)
    }

    @Test("Parse package with mixed access modifier styles")
    func testMixedAccessModifierStyles() async throws {
        let testBundle = Bundle.module
        let fixtureURL = testBundle.url(
            forResource: "MixedAccessPackage", withExtension: "swift", subdirectory: "Fixtures")!
        let packageContent = try String(contentsOf: fixtureURL)

        let tempDir = FileManager.default.temporaryDirectory
        let packageDir = tempDir.appendingPathComponent("MixedAccessPackage_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: packageDir, withIntermediateDirectories: true)

        let packageFile = packageDir.appendingPathComponent("Package.swift")
        try packageContent.write(to: packageFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: packageDir)
        }

        let parser = PackageParser()
        let packageInfo = try await parser.parsePackage(at: packageDir.path)

        #expect(packageInfo.name == "MixedAccessPackage")
        #expect(packageInfo.targets.count == 1)

        let mixedTarget = packageInfo.targets.first
        #expect(mixedTarget?.name == "MixedTarget")
        #expect(mixedTarget?.dependencies.count == 6)
        #expect(mixedTarget?.dependencies.contains("Private") == true)
        #expect(mixedTarget?.dependencies.contains("Fileprivate") == true)
        #expect(mixedTarget?.dependencies.contains("Internal") == true)
        #expect(mixedTarget?.dependencies.contains("Public") == true)
        #expect(mixedTarget?.dependencies.contains("Open") == true)
        #expect(mixedTarget?.dependencies.contains("NoModifier") == true)
    }

    @Test("Parse package with edge cases in constant parsing")
    func testConstantParsingEdgeCases() async throws {
        let testBundle = Bundle.module
        let fixtureURL = testBundle.url(
            forResource: "EdgeCasePackage", withExtension: "swift", subdirectory: "Fixtures")!
        let packageContent = try String(contentsOf: fixtureURL)

        let tempDir = FileManager.default.temporaryDirectory
        let packageDir = tempDir.appendingPathComponent("EdgeCasePackage_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: packageDir, withIntermediateDirectories: true)

        let packageFile = packageDir.appendingPathComponent("Package.swift")
        try packageContent.write(to: packageFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: packageDir)
        }

        let parser = PackageParser()
        let packageInfo = try await parser.parsePackage(at: packageDir.path)

        #expect(packageInfo.name == "EdgeCasePackage")
        #expect(packageInfo.targets.count == 1)

        let edgeTarget = packageInfo.targets.first
        #expect(edgeTarget?.name == "EdgeTarget")
        #expect(edgeTarget?.dependencies.count == 3)
        #expect(edgeTarget?.dependencies.contains("Compact") == true)
        #expect(edgeTarget?.dependencies.contains("StandardProduct") == true)
        #expect(edgeTarget?.dependencies.contains("LocalTarget") == true)
    }

    @Test("Parse package with constants having extra parameters")
    func testConstantsWithExtraParameters() async throws {
        let testBundle = Bundle.module
        let fixtureURL = testBundle.url(
            forResource: "ConditionalPackage", withExtension: "swift", subdirectory: "Fixtures")!
        let packageContent = try String(contentsOf: fixtureURL)

        let tempDir = FileManager.default.temporaryDirectory
        let packageDir = tempDir.appendingPathComponent("ConditionalPackage_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: packageDir, withIntermediateDirectories: true)

        let packageFile = packageDir.appendingPathComponent("Package.swift")
        try packageContent.write(to: packageFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: packageDir)
        }

        let parser = PackageParser()
        let packageInfo = try await parser.parsePackage(at: packageDir.path)

        #expect(packageInfo.name == "ConditionalPackage")
        #expect(packageInfo.targets.count == 1)

        let conditionalTarget = packageInfo.targets.first
        #expect(conditionalTarget?.name == "ConditionalTarget")
        #expect(conditionalTarget?.dependencies.count == 1)
        #expect(conditionalTarget?.dependencies.contains("iOSFramework") == true)
    }

    @Test("Parse package with open access modifier")
    func testOpenAccessModifier() async throws {
        let testBundle = Bundle.module
        let fixtureURL = testBundle.url(
            forResource: "OpenAccessPackage", withExtension: "swift", subdirectory: "Fixtures")!
        let packageContent = try String(contentsOf: fixtureURL)

        let tempDir = FileManager.default.temporaryDirectory
        let packageDir = tempDir.appendingPathComponent("OpenAccessPackage_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: packageDir, withIntermediateDirectories: true)

        let packageFile = packageDir.appendingPathComponent("Package.swift")
        try packageContent.write(to: packageFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: packageDir)
        }

        let parser = PackageParser()
        let packageInfo = try await parser.parsePackage(at: packageDir.path)

        #expect(packageInfo.name == "OpenAccessPackage")
        #expect(packageInfo.targets.count == 1)

        let openTarget = packageInfo.targets.first
        #expect(openTarget?.name == "OpenTarget")
        #expect(openTarget?.dependencies.count == 1)
        #expect(openTarget?.dependencies.contains("OpenFramework") == true)
    }

    @Test("Parse package with conditional product dependencies that ignore subsequent products - Bug Reproduction")
    func testConditionalProductBug() async throws {
        let testBundle = Bundle.module
        let fixtureURL = testBundle.url(
            forResource: "ConditionalBugPackage", withExtension: "swift", subdirectory: "Fixtures")!
        let packageContent = try String(contentsOf: fixtureURL)

        let tempDir = FileManager.default.temporaryDirectory
        let packageDir = tempDir.appendingPathComponent("ConditionalBugPackage_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: packageDir, withIntermediateDirectories: true)

        let packageFile = packageDir.appendingPathComponent("Package.swift")
        try packageContent.write(to: packageFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: packageDir)
        }

        let parser = PackageParser()
        let packageInfo = try await parser.parsePackage(at: packageDir.path)

        #expect(packageInfo.name == "ConditionalBugPackage")
        #expect(packageInfo.targets.count == 1)

        let testTarget = packageInfo.targets.first
        #expect(testTarget?.name == "TestTarget")
        
        // This test should demonstrate the bug - products after conditional dependencies are ignored
        // Expected: Should find all 3 dependencies: MyModuleTV, RxSwift, and AnotherProduct
        #expect(testTarget?.dependencies.count == 3, "Bug: Expected 3 dependencies but found \(testTarget?.dependencies.count ?? 0)")
        #expect(testTarget?.dependencies.contains("MyModuleTV") == true)
        #expect(testTarget?.dependencies.contains("RxSwift") == true, "Bug: RxSwift product after conditional dependency is ignored")
        #expect(testTarget?.dependencies.contains("AnotherProduct") == true, "Bug: AnotherProduct after conditional dependency is ignored")
    }
}
