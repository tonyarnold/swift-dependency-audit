// swift-tools-version: 6.1
import PackageDescription

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
            dependencies: ["SwiftDependencyAudit"]
        ),
        .plugin(
            name: "VersionPlugin",
            capability: .buildTool(),
            dependencies: ["VersionGenerator"]
        ),
    ]
)
