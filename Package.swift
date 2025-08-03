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
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.1"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "601.0.1"),
    ],
    targets: [
        .target(
            name: "SwiftDependencyAuditLib",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ],
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
            dependencies: ["SwiftDependencyAuditLib"],
            resources: [.copy("Fixtures")]
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
