# SwiftDependencyAudit

A Swift CLI tool that analyzes Swift Package.swift files, scans target source directories for import statements, and compares declared dependencies against actual usage to identify missing or unused dependencies.

## Features

- **Dependency Analysis**: Identifies missing dependencies (imports without declarations) and unused dependencies (declarations without imports)
- **Package.swift Parsing**: Extracts target dependencies from Swift Package Manager manifests
- **Import Scanning**: Uses regex to scan Swift source files for import statements (including `@testable` imports)
- **Configurable Whitelist**: Filter out system frameworks (Foundation, SwiftUI, AppKit, etc.)
- **Parallel Processing**: High-performance scanning using Swift's TaskGroup concurrency
- **Multiple Output Formats**: Colored terminal output or JSON for automation
- **Target Filtering**: Analyze specific targets or exclude test targets
- **Swift 6.1+ Compatible**: Built with modern Swift concurrency and strict typing

## Installation

### Swift Package Manager

Clone the repository and build:

```bash
git clone https://github.com/yourusername/SwiftDependencyAudit.git
cd SwiftDependencyAudit
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
USAGE: swift-dependency-audit [<path>] [--no-color] [--verbose] [--target <target>] [--exclude-tests] [--json] [--whitelist <whitelist>]

ARGUMENTS:
  <path>                  Path to Package.swift or package directory (default: current directory)

OPTIONS:
  --no-color              Disable colored output
  -v, --verbose           Enable verbose output
  --target <target>       Analyze specific target only
  --exclude-tests         Skip test targets
  --json                  Output results in JSON format
  --whitelist <whitelist> Comma-separated list of system imports to ignore
                          (e.g., Foundation,SwiftUI,AppKit)
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

## How It Works

1. **Parse Package.swift**: Extracts package information and target dependencies
2. **Scan Source Files**: Uses regex to find import statements in Swift files
3. **Compare Dependencies**: Identifies mismatches between declared and actual imports
4. **Apply Whitelist**: Filters out system frameworks and custom ignored modules
5. **Generate Report**: Outputs findings in human-readable or JSON format

## Use Cases

- **CI/CD Integration**: Validate dependencies in automated builds
- **Code Quality**: Identify unused dependencies bloating your package
- **Dependency Auditing**: Ensure all imports are properly declared
- **Package Cleanup**: Find and remove unnecessary dependencies
- **Migration Assistance**: Verify dependencies when updating packages

## Requirements

- Swift 6.1+
- macOS 15+
- Xcode 16.4+ (for development)

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
