# Swift Dependency Audit - Project Plan

## Overview
Create a CLI tool that analyzes Swift Package.swift files, scans target source directories for import statements, and compares declared dependencies against actual usage. The tool will provide parallel processing, colored output, and comprehensive validation.

## Technical Architecture

### Core Components

1. **Package.swift Parser**
   - Parse Package.swift using Swift's PackageDescription 
   - Extract targets, dependencies, and source paths
   - Handle both regular targets and test targets
   - Support Swift 6.1+ package formats

2. **Import Scanner**
   - Scan Swift source files for import statements using regex patterns
   - Extract and deduplicate import declarations
   - Support standard Swift import syntax (import Foundation, import MyModule, etc.)
   - Handle conditional imports and @testable imports

3. **Dependency Analyzer**
   - Compare declared dependencies vs. actual imports
   - Identify missing dependencies (imports without declarations)
   - Identify unused dependencies (declarations without imports)
   - Cross-reference target dependencies with source file imports

4. **Parallel Processing Engine**
   - Use Swift TaskGroup for concurrent file scanning
   - Distribute workload across available CPU cores
   - Process multiple targets simultaneously
   - Handle large codebases efficiently

### CLI Interface (Swift Argument Parser)

```
swift-dependency-audit [OPTIONS] [PATH]

ARGUMENTS:
  <path>                    Path to Package.swift or package directory (default: current directory)

OPTIONS:
  --no-color               Disable colored output
  --verbose, -v            Enable verbose output
  --target <name>          Analyze specific target only
  --exclude-tests          Skip test targets
  --json                   Output results in JSON format
  --quiet, -q              Only show problems, suppress success messages
  --whitelist <list>       Comma-separated list of system imports to ignore (e.g., Foundation,SwiftUI,AppKit)
  --output-format <format> Output format: default, xcode, or github-actions (default: default)
  --help, -h               Show help information
  --version                Show version
```

### Dependencies

- **Swift Argument Parser**: CLI interface and argument handling
- **Foundation**: File system operations and JSON output
- **Swift Standard Library**: Concurrency (TaskGroup), regex parsing

### Output Formatting

**Colored Terminal Output (default):**
- ✅ Green: Dependencies correctly declared and used
- ❌ Red: Missing dependencies (imports without declarations)
- ⚠️ Yellow: Unused dependencies (declarations without imports)
- 🔍 Blue: Informational messages

**JSON Output Option:**
```json
{
  "targets": [
    {
      "name": "MyTarget",
      "missing_dependencies": ["Foundation"],
      "unused_dependencies": ["SwiftUI"],
      "correct_dependencies": ["ArgumentParser"]
    }
  ]
}
```

**Xcode Output Format:**
Perfect for IDE integration and build systems:
```
/path/to/Sources/MyTarget/File.swift:15: error: Missing dependency 'Foundation' is imported but not declared in Package.swift
/path/to/Package.swift:25: warning: Unused dependency 'SwiftUI' is declared but never imported
```

**GitHub Actions Output Format:**
Creates rich annotations in CI/CD workflows:
```
::error file=Sources/MyTarget/File.swift,line=15::Missing dependency 'Foundation' is imported but not declared in Package.swift
::warning file=Package.swift,line=25::Unused dependency 'SwiftUI' is declared but never imported
```

## Implementation Phases

### Phase 1: Core Parsing ✅ COMPLETED
- Package.swift parsing infrastructure
- Basic import statement detection with regex
- Target and dependency extraction

### Phase 2: Analysis Engine ✅ COMPLETED
- Dependency comparison logic
- Missing/unused dependency detection
- Basic CLI with essential options

### Phase 3: Parallel Processing ✅ COMPLETED
- TaskGroup implementation for file scanning
- CPU core distribution optimization
- Performance improvements for large codebases

### Phase 4: Output & UX ✅ COMPLETED
- ANSI color support with disable option
- JSON output format
- Verbose mode and comprehensive error reporting
- Help documentation and examples

### Phase 5: Advanced Features ✅ COMPLETED
- Support for conditional imports
- @testable import handling
- Target-specific analysis
- Integration testing with real Swift packages

### Phase 6: IDE & CI/CD Integration ✅ COMPLETED
- Xcode-compatible output format with precise line numbers
- GitHub Actions workflow commands for rich annotations
- Line number tracking for import statements
- Enhanced error reporting with file/line context
- Multiple output format support via --output-format option

## Technical Details

### Import Parsing Strategy
Use Swift regex to match import patterns with line number tracking:
```swift
let importRegex = /^import\s+(?:@testable\s+)?(\w+)(?:\.\w+)*$/
// Enhanced with line number capture for precise error reporting
for (lineIndex, line) in lines.enumerated() {
    let lineNumber = lineIndex + 1
    // Store line number with ImportInfo for IDE integration
}
```

### Parallelization Approach
```swift
await withThrowingTaskGroup(of: [String].self) { group in
    for sourceFile in sourceFiles {
        group.addTask {
            return try await scanImports(in: sourceFile)
        }
    }
}
```

### Output Format Implementation
Multiple output formats with specialized modules:
```swift
// Terminal output with ANSI colors
struct ColorOutput {
    static func success(_ text: String) -> String {
        isColorEnabled ? "\u{001B}[32m\(text)\u{001B}[0m" : text
    }
}

// Xcode-compatible format
struct XcodeOutput {
    static func error(file: String, line: Int?, message: String) -> String {
        "\(file):\(line ?? 0): error: \(message)"
    }
}

// GitHub Actions workflow commands
struct GitHubActionsOutput {
    static func error(file: String, line: Int?, message: String) -> String {
        "::error file=\(file),line=\(line ?? 0)::\(message)"
    }
}
```

## Success Criteria

1. **Functionality**: Accurately detect missing and unused dependencies in Swift packages ✅
2. **Performance**: Process large codebases (1000+ files) efficiently using parallel processing ✅
3. **Usability**: Clear, colored output with options for automation (JSON, no-color) ✅
4. **Reliability**: Handle edge cases and provide meaningful error messages ✅
5. **Maintainability**: Clean, well-structured code following Swift best practices ✅
6. **IDE Integration**: Seamless Xcode integration with clickable error/warning annotations ✅
7. **CI/CD Integration**: Rich GitHub Actions annotations with file/line linking ✅
8. **Build System Ready**: Output formats perfect for Swift Build Plugin implementation ✅

## Estimated Timeline
- Phase 1-2: 2-3 days (core functionality) ✅ COMPLETED
- Phase 3: 1 day (parallelization) ✅ COMPLETED
- Phase 4: 1 day (output formatting) ✅ COMPLETED
- Phase 5: 1-2 days (advanced features and testing) ✅ COMPLETED
- Phase 6: 1 day (IDE & CI/CD integration) ✅ COMPLETED

**Total: 6-8 days for complete implementation including IDE/CI integration**

## File Structure

```
SwiftDependencyAudit/
├── Package.swift                    # Package definition with library/executable targets
├── PROJECT_PLAN.md                  # This file
├── CLAUDE.md                        # Development guidance
├── CHANGELOG.md                     # Version history and changes
├── README.md                        # Documentation and usage examples
├── Sources/
│   ├── SwiftDependencyAuditLib/     # Core library (public API for testing)
│   │   ├── PackageParser.swift             # Package.swift parsing logic
│   │   ├── ImportScanner.swift             # Source file import scanning with line numbers
│   │   ├── DependencyAnalyzer.swift        # Comparison and analysis logic
│   │   ├── ParallelProcessor.swift         # TaskGroup-based parallel processing
│   │   ├── ColorOutput.swift               # ANSI terminal color support
│   │   ├── XcodeOutput.swift               # Xcode-compatible output format
│   │   ├── GitHubActionsOutput.swift       # GitHub Actions workflow commands
│   │   └── Models.swift                    # Data structures and types
│   └── SwiftDependencyAudit/        # Executable entry point
│       └── DependentImportScanner.swift    # CLI interface with argument parsing
└── Tests/
    └── SwiftDependencyAuditTests/   # Comprehensive test suite (38 tests)
        ├── ImportScannerTests.swift        # Import parsing tests
        ├── PackageParserTests.swift        # Package parsing tests
        ├── DependencyAnalyzerTests.swift   # Analysis logic tests
        ├── WhitelistTests.swift            # Whitelist functionality tests
        └── IntegrationTests.swift          # End-to-end integration tests
```