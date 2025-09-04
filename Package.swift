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
        .plugin(name: "DependencyAuditPlugin", targets: ["DependencyAuditPlugin"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.1")
    ],
    targets: [
        .target(
            name: "SwiftDependencyAuditLib",
            plugins: ["VersionPlugin"]
        ),
        .executableTarget(
            name: "SwiftDependencyAudit",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "SwiftDependencyAuditLib",
            ]
        ),
        .executableTarget(
            name: "VersionGenerator",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
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
        .plugin(
            name: "VersionPlugin",
            capability: .buildTool(),
            dependencies: ["VersionGenerator"]
        ),
    ]
)

// Conditionally add binary target only on macOS
#if os(macOS)
    package.targets.append(
        .binaryTarget(
            name: "SwiftDependencyAuditBinary",
            url:
                "https://github.com/tonyarnold/swift-dependency-audit/releases/download/v2.0.5/swift-dependency-audit.artifactbundle.zip",
            checksum: "9d90d5b96a082536e0e873ecfa0eb77ac1d4628c5138de7b63172a0b59739a83"
        )
    )
#endif
