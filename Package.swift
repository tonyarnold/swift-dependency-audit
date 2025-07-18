// swift-tools-version: 6.1
import PackageDescription

// Conditional plugin dependencies based on platform
let swiftDependencyAuditPluginDependencies: [Target.Dependency]

#if os(macOS)
swiftDependencyAuditPluginDependencies = [.target(name: "SwiftDependencyAuditBinary")]
#else
swiftDependencyAuditPluginDependencies = [.target(name: "SwiftDependencyAudit")]
#endif

let package = Package(
    name: "SwiftDependencyAudit",
    platforms: [
        .macOS(.v13),
        .macCatalyst(.v16),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
    ],
    products: [
        .executable(name: "swift-dependency-audit", targets: ["SwiftDependencyAudit"]),
        .plugin(name: "DependencyAuditPlugin", targets: ["DependencyAuditPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.1")
    ],
    targets: [
        .target(
            name: "SwiftDependencyAuditLib",
        ),
        .executableTarget(
            name: "SwiftDependencyAudit",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "SwiftDependencyAuditLib"
            ]
        ),
        .testTarget(
            name: "SwiftDependencyAuditTests",
            dependencies: ["SwiftDependencyAuditLib"]
        ),
        .plugin(
            name: "DependencyAuditPlugin",
            capability: .buildTool(),
            dependencies: swiftDependencyAuditPluginDependencies
        ),
    ]
)

// Conditionally add binary target only on macOS
#if os(macOS)
package.targets.append(
    .binaryTarget(
        name: "SwiftDependencyAuditBinary",
        url: "https://github.com/tonyarnold/swift-dependency-audit/releases/download/v1.4.5/swift-dependency-audit.artifactbundle.zip",
        checksum: "222e0acc37f4bbe0b936f609f0f364ae94c5e310fd3399709a398696387ef702"
    )
)
#endif
