import Foundation
import Testing

@testable import SwiftDependencyAuditLib

@Suite("ImportScanner Tests")
struct ImportScannerTests {

    @Test("Scan simple import statement")
    func testSimpleImport() async throws {
        let scanner = ImportScanner()
        let content = "import Foundation"

        let imports = await scanner.scanContent(content)

        #expect(imports.isEmpty)  // Foundation should be ignored as standard library
    }

    @Test("Scan import with custom module")
    func testCustomModuleImport() async throws {
        let scanner = ImportScanner()
        let content = "import MyCustomModule"

        let imports = await scanner.scanContent(content)

        #expect(imports.count == 1)
        #expect(imports.first?.moduleName == "MyCustomModule")
        #expect(imports.first?.isTestable == false)
    }

    @Test("Scan testable import")
    func testTestableImport() async throws {
        let scanner = ImportScanner()
        let content = "@testable import MyModule"

        let imports = await scanner.scanContent(content)

        #expect(imports.count == 1)
        #expect(imports.first?.moduleName == "MyModule")
        #expect(imports.first?.isTestable == true)
    }

    @Test("Scan multiple imports")
    func testMultipleImports() async throws {
        let scanner = ImportScanner()
        let content = """
            import Foundation
            import MyModule
            import AnotherModule
            @testable import TestModule
            """

        let imports = await scanner.scanContent(content)

        // Foundation should be filtered out, leaving 3 custom modules
        #expect(imports.count == 3)

        let moduleNames = Set(imports.map { $0.moduleName })
        #expect(moduleNames.contains("MyModule"))
        #expect(moduleNames.contains("AnotherModule"))
        #expect(moduleNames.contains("TestModule"))

        let testableImport = imports.first { $0.moduleName == "TestModule" }
        #expect(testableImport?.isTestable == true)
    }

    @Test("Ignore whitelist modules")
    func testWhitelistFiltering() async throws {
        let scanner = ImportScanner()
        let content = """
            import SwiftUI
            import MyModule
            import AppKit
            """

        let whitelist: Set<String> = ["SwiftUI", "AppKit"]
        let imports = await scanner.scanContent(content, customWhitelist: whitelist)

        #expect(imports.count == 1)
        #expect(imports.first?.moduleName == "MyModule")
    }

    @Test("Handle malformed import statements")
    func testMalformedImports() async throws {
        let scanner = ImportScanner()
        let content = """
            import
            importSomething
            // import Comment
            /* import BlockComment */
            """

        let imports = await scanner.scanContent(content)

        #expect(imports.isEmpty)
    }

    @Test("Handle import with submodules")
    func testSubmoduleImports() async throws {
        let scanner = ImportScanner()
        let content = "import MyModule.SubModule"

        let imports = await scanner.scanContent(content)

        #expect(imports.count == 1)
        #expect(imports.first?.moduleName == "MyModule")
    }

    @Test("Filter standard library modules")
    func testStandardLibraryFiltering() async throws {
        let scanner = ImportScanner()
        let content = """
            import Swift
            import Testing
            import Foundation
            import Dispatch
            import UIKit
            import AppKit
            import SwiftUI
            import MyCustomModule
            """

        let imports = await scanner.scanContent(content)

        // All system modules should be filtered out, leaving only MyCustomModule
        #expect(imports.count == 1)
        #expect(imports.first?.moduleName == "MyCustomModule")
    }

    @Test("Scan private import statements")
    func testPrivateImports() async throws {
        let scanner = ImportScanner()
        let content = """
            private import FrameworkOne
            private import FrameworkTwo
            import RegularModule
            """

        let imports = await scanner.scanContent(content)

        #expect(imports.count == 3)
        let moduleNames = Set(imports.map { $0.moduleName })
        #expect(moduleNames.contains("FrameworkOne"))
        #expect(moduleNames.contains("FrameworkTwo"))
        #expect(moduleNames.contains("RegularModule"))
    }

    @Test("Scan @preconcurrency import statements")
    func testPreconcurrencyImports() async throws {
        let scanner = ImportScanner()
        let content = """
            @preconcurrency private import SomeFramework
            @testable import TestModule
            """

        let imports = await scanner.scanContent(content)

        #expect(imports.count == 2)
        let moduleNames = Set(imports.map { $0.moduleName })
        #expect(moduleNames.contains("SomeFramework"))
        #expect(moduleNames.contains("TestModule"))

        let testableImport = imports.first { $0.moduleName == "TestModule" }
        #expect(testableImport?.isTestable == true)
    }

    @Test("Scan mixed import modifiers")
    func testMixedImportModifiers() async throws {
        let scanner = ImportScanner()
        let content = """
            import Foundation
            private import PrivateModule
            @preconcurrency import ConcurrencyModule
            @testable import TestableModule
            @preconcurrency private import ComplexModule
            public import PublicModule
            @_exported import ExportedModule
            """

        let imports = await scanner.scanContent(content)

        // Foundation should be filtered out, leaving 6 custom modules
        #expect(imports.count == 6)
        let moduleNames = Set(imports.map { $0.moduleName })
        #expect(moduleNames.contains("PrivateModule"))
        #expect(moduleNames.contains("ConcurrencyModule"))
        #expect(moduleNames.contains("TestableModule"))
        #expect(moduleNames.contains("ComplexModule"))
        #expect(moduleNames.contains("PublicModule"))
        #expect(moduleNames.contains("ExportedModule"))

        let testableImport = imports.first { $0.moduleName == "TestableModule" }
        #expect(testableImport?.isTestable == true)
    }

    @Test("Trailing comments on imports")
    func testTrailingCommentsOnImports() async throws {
        let scanner = ImportScanner()
        let content = """
            import RegularModule // A trailing comment
            """

        let imports = await scanner.scanContent(content)

        // Foundation should be filtered out, leaving 6 custom modules
        #expect(imports.count == 1)
        let moduleNames = Set(imports.map { $0.moduleName })
        #expect(moduleNames.contains("RegularModule"))
    }
}
