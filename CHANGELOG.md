# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release preparation
- README.md with comprehensive documentation
- MIT License for open source distribution
- Comprehensive .gitignore for Swift projects

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

- **CLI Interface**
  - Built with Swift Argument Parser
  - Comprehensive command-line options
  - Path-based analysis (current directory or specified path)
  - Target filtering (`--target` option)
  - Test target exclusion (`--exclude-tests`)
  - Verbose output mode (`--verbose`)
  - No-color output option (`--no-color`)

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
  - Complete test suite with 30 tests
  - ImportScanner regex parsing tests
  - PackageParser Package.swift parsing tests
  - DependencyAnalyzer logic tests
  - Whitelist functionality tests
  - End-to-end integration tests
  - Performance tests for large codebases

### Technical Details
- **Language**: Swift 6.1+
- **Concurrency**: Modern Swift concurrency with strict safety
- **Dependencies**: Swift Argument Parser
- **Platforms**: macOS 14.0+, Linux (Swift on Linux)
- **Architecture**: Library/executable split for testability

### Performance
- Parallel file scanning using TaskGroup
- Optimized regex patterns for import detection
- Efficient memory usage for large project analysis
- Concurrent processing of multiple targets

[Unreleased]: https://github.com/yourusername/DependentImportScanner/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/yourusername/DependentImportScanner/releases/tag/v1.0.0