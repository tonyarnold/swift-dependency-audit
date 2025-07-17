// swift-tools-version: 6.1
import PackageDescription

// Conditional plugin dependencies based on platform
// Note: Using source target for development until binary target is available
let swiftDependencyAuditPluginDependencies: [Target.Dependency] = [.target(name: "SwiftDependencyAudit")]

// For production with binary target, use this instead:
/*
#if os(macOS)
swiftDependencyAuditPluginDependencies = [.target(name: "SwiftDependencyAuditBinary")]
#else
swiftDependencyAuditPluginDependencies = [.target(name: "SwiftDependencyAudit")]
#endif
*/

let package = Package(
    name: "SwiftDependencyAudit",
    platforms: [
        .macOS(.v15),
        .macCatalyst(.v18),
        .iOS(.v18),
        .tvOS(.v18),
        .watchOS(.v11),
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
// Note: Commented out for development until first release with binary target is created
/*
#if os(macOS)
package.targets.append(
    .binaryTarget(
        name: "SwiftDependencyAuditBinary",
        url: "https://github.com/tonyarnold/swift-dependency-audit/releases/download/v0.1.0-test/swift-dependency-audit.artifactbundle.zip",
        checksum: "b7bf85dc914055edac980164ba7424c4d7b6f174ef5b85a95d4d3ba543ca04f6"
    )
)
#endif
*/
