## Binary Target Usage (Swift Package Manager Plugin)

Add this to your Package.swift for build tool plugin usage:

```swift
.binaryTarget(
    name: "SwiftDependencyAuditBinary",
    url: "https://github.com/__REPOSITORY__/releases/download/__VERSION__/swift-dependency-audit.artifactbundle.zip",
    checksum: "__CHECKSUM__"
)
```

## Manual Installation

Download the appropriate binary for your system:

- **Universal macOS** (recommended): `swift-dependency-audit-__VERSION__-macos-universal.tar.gz`
- **Linux x86_64**: `swift-dependency-audit-__VERSION__-linux-x86_64.tar.gz`
- **Linux ARM64**: `swift-dependency-audit-__VERSION__-linux-aarch64.tar.gz`

### Quick Install (macOS)
```bash
curl -L https://github.com/__REPOSITORY__/releases/download/__VERSION__/swift-dependency-audit-__VERSION__-macos-universal.tar.gz | tar -xzf -
sudo mv swift-dependency-audit-__VERSION__-macos-universal/swift-dependency-audit /usr/local/bin/
```

### Quick Install (Linux)
```bash
curl -L https://github.com/__REPOSITORY__/releases/download/__VERSION__/swift-dependency-audit-__VERSION__-linux-x86_64.tar.gz | tar -xzf -
sudo mv swift-dependency-audit-__VERSION__-linux-x86_64/swift-dependency-audit /usr/local/bin/
```

## Supported Platforms

- macOS (Universal: ARM64 + x86_64)
- Linux x86_64 (static binary, no Swift runtime required)
- Linux ARM64 (static binary, no Swift runtime required)

## Plugin Usage

The binary target can be used with the SwiftDependencyAudit build tool plugin for automatic dependency validation during builds.

## Checksums
All binaries are signed with SHA256 checksums available in `checksums.txt`.