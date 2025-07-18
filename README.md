# SwiftDependencyAudit

A Swift CLI tool that analyzes Swift Package.swift files, scans target source directories for import statements, and compares declared dependencies against actual usage to identify missing or unused dependencies.

## Features

- **Dependency Analysis**: Identifies missing dependencies (imports without declarations) and unused dependencies (declarations without imports)
- **Package.swift Parsing**: Extracts target dependencies from Swift Package Manager manifests
- **Import Scanning**: Uses regex to scan Swift source files for import statements (including `@testable` imports)
- **Configurable Whitelist**: Filter out system frameworks (Foundation, SwiftUI, AppKit, etc.)
- **Parallel Processing**: High-performance scanning using Swift's TaskGroup concurrency
- **Multiple Output Formats**: Colored terminal output, JSON, Xcode-compatible, or GitHub Actions format
- **Target Filtering**: Analyze specific targets or exclude test targets
- **Swift 6.1+ Compatible**: Built with modern Swift concurrency and strict typing

## Installation

### Swift Package Manager

Clone the repository and build:

```bash
git clone https://github.com/tonyarnold/swift-dependency-audit.git
cd swift-dependency-audit
swift build -c release
```

The executable will be available at `.build/release/swift-dependency-audit`.

## Usage

### Basic Usage

```bash
# Analyze current directory
swift run swift-dependency-audit

# Analyze specific package
swift run swift-dependency-audit /path/to/package

# Use built executable
.build/release/swift-dependency-audit /path/to/package
```

### Command Line Options

```
USAGE: swift-dependency-audit [<path>] [--no-color] [--verbose] [--target <target>] [--exclude-tests] [--json] [--quiet] [--whitelist <whitelist>] [--output-format <output-format>]

ARGUMENTS:
  <path>                  Path to Package.swift or package directory (default: current directory)

OPTIONS:
  --no-color              Disable colored output
  -v, --verbose           Enable verbose output
  --target <target>       Analyze specific target only
  --exclude-tests         Skip test targets
  --json                  Output results in JSON format
  -q, --quiet             Only show problems, suppress success messages
  --whitelist <whitelist> Comma-separated list of system imports to ignore
                          (e.g., Foundation,SwiftUI,AppKit)
  --output-format <format> Output format: default, xcode, or github-actions
                          (default: default)
  --version               Show the version.
  -h, --help              Show help information.
```

### Examples

```bash
# Verbose analysis with custom whitelist
swift run swift-dependency-audit --verbose --whitelist "Foundation,SwiftUI,AppKit,UIKit"

# JSON output for CI/automation
swift run swift-dependency-audit --json --no-color

# Analyze only a specific target
swift run swift-dependency-audit --target MyLibrary

# Exclude test targets from analysis
swift run swift-dependency-audit --exclude-tests

# Xcode-compatible output for IDE integration
swift run swift-dependency-audit --output-format xcode

# GitHub Actions format for CI/CD workflows
swift run swift-dependency-audit --output-format github-actions

# Quiet mode with Xcode format (only show problems)
swift run swift-dependency-audit --output-format xcode --quiet
```

## Build Tool Plugin Integration

SwiftDependencyAudit includes a Swift Package Manager build tool plugin that automatically validates dependencies during builds, providing seamless integration with both Swift Package Manager and Xcode.

### Plugin Integration

The build tool plugin uses a hybrid approach for optimal performance and compatibility:

```swift
// Package.swift
let package = Package(
    name: "MyPackage",
    dependencies: [
        .package(url: "https://github.com/tonyarnold/swift-dependency-audit.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "MyLibrary",
            dependencies: ["SomeOtherDependency"],
            plugins: [
                .plugin(name: "DependencyAuditPlugin", package: "swift-dependency-audit")
            ]
        ),
        .testTarget(
            name: "MyLibraryTests",
            dependencies: ["MyLibrary"],
            plugins: [
                .plugin(name: "DependencyAuditPlugin", package: "swift-dependency-audit")
            ]
        )
    ]
)
```


## Sample Output

### Terminal Output (Default)

```
📦 Package: MyAwesomePackage

🔍 Found 2 target(s) with dependency issues
🔍 Total missing: 1, unused: 2

📱 Target: MyLibrary
  ❌ Missing dependencies (1):
    • Alamofire
  ⚠️  Unused dependencies (2):
    • SwiftyJSON
    • Kingfisher

🧪 Target: MyLibraryTests
  ✅ All dependencies correct
```

### JSON Output

```json
{
  "packageName": "MyAwesomePackage",
  "targets": [
    {
      "name": "MyLibrary",
      "type": "regular",
      "hasIssues": true,
      "missingDependencies": ["Alamofire"],
      "unusedDependencies": ["SwiftyJSON", "Kingfisher"],
      "correctDependencies": ["Foundation"],
      "sourceFiles": 15
    }
  ],
  "summary": {
    "totalTargets": 2,
    "targetsWithIssues": 1,
    "totalMissing": 1,
    "totalUnused": 2
  }
}
```

### Xcode Output Format

Perfect for IDE integration and build systems:

```
/path/to/Sources/MyLibrary/NetworkManager.swift:15: error: Missing dependency 'Alamofire' is imported but not declared in Package.swift
/path/to/Package.swift:25: warning: Unused dependency 'SwiftyJSON' is declared but never imported
/path/to/Package.swift:26: warning: Unused dependency 'Kingfisher' is declared but never imported
```

### GitHub Actions Output Format

Creates rich annotations in CI/CD workflows:

```
::error file=Sources/MyLibrary/NetworkManager.swift,line=15::Missing dependency 'Alamofire' is imported but not declared in Package.swift
::warning file=Package.swift,line=25::Unused dependency 'SwiftyJSON' is declared but never imported
::warning file=Package.swift,line=26::Unused dependency 'Kingfisher' is declared but never imported
```

## How It Works

1. **Parse Package.swift**: Extracts package information and target dependencies
2. **Scan Source Files**: Uses regex to find import statements in Swift files
3. **Compare Dependencies**: Identifies mismatches between declared and actual imports
4. **Apply Whitelist**: Filters out system frameworks and custom ignored modules
5. **Generate Report**: Outputs findings in human-readable or JSON format

## Use Cases

- **IDE Integration**: Seamless Xcode integration with clickable error/warning annotations
- **CI/CD Integration**: Validate dependencies in automated builds with GitHub Actions support
- **Swift Build Plugins**: Perfect output formats for Swift Package Manager build plugins
- **Code Quality**: Identify unused dependencies bloating your package
- **Dependency Auditing**: Ensure all imports are properly declared
- **Package Cleanup**: Find and remove unnecessary dependencies
- **Migration Assistance**: Verify dependencies when updating packages
- **Automated Workflows**: Rich annotations in GitHub Actions with file/line linking

## Requirements

- Swift 6.1+
- macOS 15+

## Development

### Building

```bash
swift build
```

### Testing

```bash
swift test
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass (`swift test`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with [Swift Argument Parser](https://github.com/apple/swift-argument-parser)
- Inspired by dependency analysis tools in other ecosystems
- Thanks to the Swift community for excellent tooling and documentation
