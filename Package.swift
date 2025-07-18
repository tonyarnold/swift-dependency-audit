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
#if os(macOS)
package.targets.append(
    .binaryTarget(
        name: "SwiftDependencyAuditBinary",
        url: "https://github.com/tonyarnold/swift-dependency-audit/releases/download/v1.4.2/swift-dependency-audit.artifactbundle.zip",
        checksum: "4e39733d4aa15a58bc164467b27e71d99f8c4828ab8a39566bea4fded138be47"
    )
)
#endif