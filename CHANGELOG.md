# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Constant-Based Dependency Declarations**
  - Support for dependency constants like `private let TCA = Target.Dependency.product(name: "ComposableArchitecture", package: "swift-composable-architecture")`
  - Resolves constant references in dependency arrays (e.g., `dependencies: [TCA]`)
  - Works with all Swift access levels (`private`, `fileprivate`, `internal`, `public`, `open`)
  - Maintains full backward compatibility with existing dependency declaration methods

- **SwiftSyntax Parser Integration**
  - Added AST-based Package.swift parsing using SwiftSyntax for improved accuracy
  - Configurable parser backend: `--parser swiftsyntax|regex|auto` (default: auto)
  - Auto mode attempts SwiftSyntax first with regex fallback for compatibility
  - SwiftSyntax parser fixes conditional dependency parsing limitations of regex parser

### Fixed
- **Missing Access Modifier Support**
  - Added support for `open` access modifier in dependency constants
  - Fixed parsing of dependency constants without explicit access modifiers (defaults to `internal`)

- **Conditional Product Dependency Parsing**
  - Fixed bug where products declared after conditional dependencies with platform-specific conditions were ignored during parsing
  - Enhanced bracket counting algorithm to properly handle nested brackets within parentheses (e.g., `condition: .when(platforms: [.tvOS])`)
  - Section extraction now correctly ignores square brackets inside parentheses to prevent premature parsing termination
  - Resolves issue where dependencies like `RxSwift` were missed when following conditional products like `MyModuleTV` with platform conditions

## [v1.4.0]

### Changed
- **CLI Interface Simplification**
  - Removed redundant `--json` flag in favor of unified `--output-format json` option
  - Consolidated output format selection into single `--output-format` parameter supporting `terminal`, `json`, `xcode`, and `github-actions`
  - Renamed `default` output format to `terminal` for better clarity and descriptiveness
  - Simplified CLI interface with consistent format selection pattern

### Added
- **Multi-Platform Binary Target Distribution**
  - Cross-platform artifact bundles for Swift Package Manager with pre-compiled binaries
  - Universal macOS binary supporting ARM64 and x86_64 architectures
  - Linux binaries for x86_64 and ARM64 architectures
  - Automated GitHub Actions release workflow for multi-platform builds
  - SHA256 checksum verification for binary integrity
  - Artifact bundle generation script for automated distribution
  - Hybrid binary/source build tool plugin execution following SwiftLint's proven pattern

- **Swift Build Tool Plugin Integration**
  - Automatic dependency validation during builds with Swift Package Manager build tool plugin
  - Zero-configuration integration - works automatically when applied to package targets
  - Seamless Xcode integration with native build system error and warning reporting
  - Target-specific analysis validates dependencies for each target individually
  - Prebuild command execution ensures validation before compilation begins
  - IDE-friendly output with Xcode-compatible error messages and navigation
  - Support for both Swift Package Manager command-line builds and Xcode workspace builds
  - Plugin automatically excludes test dependencies when analyzing non-test targets
  - Operates in quiet mode by default to focus on dependency issues during builds
- **Product-Level Dependency Detection**
  - Analyzes external package products from `.build/checkouts` directory after `swift resolve`
  - Detects imports satisfied by product dependencies to prevent false "missing dependency" reports
  - Identifies redundant direct target dependencies when covered by product dependencies
  - Enhanced verbose reporting shows product-to-target mappings and satisfied imports
  - Seamless integration with existing whitelist functionality
  - Comprehensive test coverage with 6 new tests using generic examples

- **Enhanced Package.swift Parsing**
  - Support for variable-based Package.swift definitions (`let name = "..."`, `let targets = [...]`)
  - Variable resolution for package name, targets, dependencies, and products arrays
  - Support for complex Package.swift patterns with `targets.forEach` post-processing
  - Enhanced custom path support for targets with explicit `path:` parameters
  - Improved parsing of mixed target types (`.target`, `.testTarget`, `.executableTarget`, etc.)
  - Product parsing with RegexBuilder patterns for `.library()`, `.executable()`, and `.plugin()` declarations
  - External dependency extraction supporting both URL and path-based packages
  - All new parsing patterns implemented using RegexBuilder DSL for better maintainability

- **IDE and CI/CD Integration**
  - New `--output-format` option supporting `default`, `xcode`, and `github-actions` output formats
  - Xcode-compatible error/warning output for seamless IDE integration
  - GitHub Actions workflow commands for rich CI/CD annotations
  - Precise line number tracking for import statements
  - File-specific error reporting with exact line numbers

### Fixed
- **Exit Code Handling**
  - Redundant direct dependencies now generate warnings instead of errors
  - Tool exits with code 0 when only warnings are present (no missing or unused dependencies)
  - Improved CI compatibility by treating redundant dependencies as non-blocking warnings

### Enhanced
- **Build Tool Plugin Robustness**
  - Enhanced target filtering to use `SourceModuleTarget` type checking instead of analyzing all targets
  - Improved test target detection using `sourceTarget.kind != .test` instead of brittle string matching
  - Optimized plugin to only run on source-based targets, reducing unnecessary executions

### Enhanced
- **Redundant Dependency Reporting**
  - Enhanced redundant dependency warnings to show which specific product dependency provides each redundant direct dependency
  - Updated output format: `• TargetName (available through ProductName from PackageName)`
  - Enhanced JSON output to include detailed product/package attribution for redundant dependencies
  - Improved actionability of redundant dependency warnings with complete provenance information

### Fixed
- **Product vs Target Dependency Detection**
  - Fixed false positive redundant dependency warnings for product dependencies with matching target names
  - Product dependencies like `.product(name: "Apollo", package: "apollo-ios")` are no longer incorrectly flagged as redundant
  - Enhanced dependency parsing to properly distinguish between product dependencies and target dependencies
  - Corrected redundancy detection to only flag actual target dependencies that are covered by product dependencies
  - Resolves issue where tools reported confusing messages like "Apollo (available through Apollo from Apollo)"

- **Package.swift Parser Robustness**
  - Fixed parsing failures with complex Package.swift files using variable declarations
  - Enhanced bracket counting for nested array structures in variable assignments
  - Improved target detection for packages with post-processing logic
  - Better support for modern Swift Package Manager patterns

- **Line Number Reporting**
  - Fixed incomplete line number capture in Xcode and GitHub Actions output formats
  - Now reports all occurrences of missing dependencies across all source files with correct line numbers
  - Removed premature loop termination that was causing missing line number information
  - Added line number tracking for unused dependencies in Package.swift files
  - Enhanced dependency parsing to capture exact line numbers where dependencies are declared

### Technical Details
- **Multi-Platform Binary Distribution**
  - Added `Scripts/spm-artifact-bundle.sh` for automated artifact bundle generation
  - Created `Scripts/spm-artifact-bundle-info.json` for Swift Package Manager manifest generation
  - Implemented GitHub Actions workflow with matrix strategy for cross-platform builds
  - Binary optimization with `strip` for size reduction and `-Xswiftc -Osize` for performance
  - Artifact bundle structure following SPM schema version 1.0 with multi-platform variants
  - Automated checksum calculation with SHA256 for security verification
  - Hybrid distribution model with conditional binary targets for optimal platform support
  - Dedicated `Scripts/update-artifact-bundle.sh` script for automated Package.swift checksum updates
  - Conditional compilation patterns following Swift Package Manager best practices

- **Swift Build Tool Plugin Architecture**
  - Added `DependencyAuditPlugin` conforming to `BuildToolPlugin` protocol with `@main` annotation
  - Implemented `createBuildCommands(context:target:)` method for prebuild command generation
  - Hybrid execution using `context.tool(named:)` with conditional platform dependencies
  - Uses modern PackagePlugin API with `pluginWorkDirectoryURL` and `directoryURL` properties
  - Target filtering with `SourceModuleTarget` type checking to reduce overhead
  - Proper test target detection using `sourceTarget.kind != .test` instead of string matching
  - Automatic test exclusion for non-test targets via `--exclude-tests` flag
  - Xcode-compatible output format via `--output-format xcode` for seamless IDE integration
  - Quiet mode operation via `--quiet` flag to focus on issues during builds
  - Plugin target definition in Package.swift with `.buildTool()` capability

- **Product-Level Dependency Analysis**
  - Added `Product`, `ExternalPackage`, `ExternalPackageDependency`, and `ProductSatisfiedDependency` models
  - New `ExternalPackageResolver` actor for discovering and parsing external packages from `.build/checkouts`
  - Enhanced `PackageParser` with product parsing using RegexBuilder patterns (`parseProductDeclaration`, `parseProductTargets`)
  - Enhanced `DependencyAnalyzer` with two-level analysis supporting both product and target dependencies
  - Added product-to-target mapping for external package analysis
  - Enhanced `AnalysisResult` with `productSatisfiedDependencies` and `redundantDirectDependencies` fields
  - Updated reporting logic to show product dependency information in verbose mode
  - Package caching for performance optimization during external package parsing

- **Enhanced Package.swift Parsing**
  - Enhanced `PackageParser` with RegexBuilder-based variable resolution patterns
  - Added `resolveStringVariable()`, `resolveTargetsVariable()`, `resolveDependenciesVariable()`, `resolveProductsVariable()` methods
  - Added `extractProducts()` and `extractExternalDependencies()` methods with RegexBuilder patterns
  - Added `applyForEachModifications()` for handling target post-processing
  - Enhanced target parsing with custom path extraction using `pathParameter` pattern
  - Improved `extractVariableArrayContent()` with robust bracket counting
  - Added `extractPackageNameFromURL()` and `extractPackageNameFromPath()` utilities

- **IDE and CI/CD Integration**
  - Enhanced `ImportInfo` model with line number tracking
  - Added `DependencyInfo` model to track dependency line numbers in Package.swift
  - Added `XcodeOutput` module for Xcode-compatible format (`file:line: error: message`)
  - Added `GitHubActionsOutput` module for GitHub Actions format (`::error file=path,line=N::message`)
  - Updated `ImportScanner` to capture line numbers during regex matching
  - Enhanced `PackageParser` with `parseDependencyListWithLineNumbers()` and `findDependencyLineNumber()` methods
  - Extended `DependencyAnalyzer` with `generateXcodeReport()` and `generateGitHubActionsReport()` methods
  - Fixed loop logic in `generateXcodeReport()` and `generateGitHubActionsReport()` to report all import occurrences
  - Updated `Target` model to include `dependencyInfo` array with line number tracking

- All existing functionality preserved with backward compatibility - all 44 tests pass (38 existing + 6 new)

## [1.0.0] - 2025-07-16

### Added
- **Core Functionality**
  - Swift Package.swift parsing with Swift 6.1 support
  - Import statement scanning using Swift regex patterns
  - Support for `@testable` import analysis
  - Dependency analysis comparing declared vs actual imports
  - Missing dependency detection (imports without declarations)
  - Unused dependency detection (declarations without imports)

- **Performance & Concurrency**
  - Parallel processing with Swift TaskGroup for high performance
  - Concurrent file scanning across multiple CPU cores
  - Optimized processing for large codebases
  - Parallel file scanning using TaskGroup
  - Optimized regex patterns for import detection
  - Efficient memory usage for large project analysis
  - Concurrent processing of multiple targets

- **CLI Interface**
  - Built with Swift Argument Parser
  - Comprehensive command-line options
  - Path-based analysis (current directory or specified path)
  - Target filtering (`--target` option)
  - Test target exclusion (`--exclude-tests`)
  - Verbose output mode (`--verbose`)
  - No-color output option (`--no-color`)
  - Quiet mode (`--quiet`) to show only problems

- **Output Formats**
  - Colored terminal output with ANSI escape sequences
  - JSON output format for automation (`--json`)
  - Emoji-enhanced status indicators
  - Structured error reporting

- **Whitelist System**
  - Configurable whitelist for system imports
  - Built-in filtering for Foundation, SwiftUI, AppKit, UIKit
  - Custom whitelist support via `--whitelist` parameter
  - Case-sensitive whitelist matching

- **Error Handling**
  - Comprehensive error handling for file system operations
  - Graceful handling of malformed Package.swift files
  - Detailed error messages with context

- **Testing**
  - Complete test suite with 38 tests
  - ImportScanner regex parsing tests
  - PackageParser Package.swift parsing tests
  - DependencyAnalyzer logic tests
  - Whitelist functionality tests
  - End-to-end integration tests
  - Performance tests for large codebases

- **Project Setup**
  - Initial release preparation
  - README.md with comprehensive documentation
  - MIT License for open source distribution
  - Comprehensive .gitignore for Swift projects

### Technical Details
- **Language**: Swift 6.1+
- **Concurrency**: Modern Swift concurrency with strict safety
- **Dependencies**: Swift Argument Parser
- **Platforms**: macOS 15.0+, iOS 18.0+, tvOS 18.0+, watchOS 11.0+, macCatalyst 18.0+
- **Architecture**: Library/executable split for testability
- **Executable**: `swift-dependency-audit`

[Unreleased]: https://github.com/yourusername/SwiftDependencyAudit/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/yourusername/SwiftDependencyAudit/releases/tag/v1.0.0
