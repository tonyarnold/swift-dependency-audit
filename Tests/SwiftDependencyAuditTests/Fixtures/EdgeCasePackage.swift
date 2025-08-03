// swift-tools-version: 6.0
import PackageDescription

// Constant with different formatting (minimal spaces)
let CompactDep = Target.Dependency.product(name: "Compact", package: "compact-package")

// Standard dependencies mixed with constants
let package = Package(
    name: "EdgeCasePackage",
    dependencies: [
        .package(url: "https://github.com/example/compact-package", from: "1.0.0"),
        .package(url: "https://github.com/example/standard-package", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "EdgeTarget",
            dependencies: [
                CompactDep,
                .product(name: "StandardProduct", package: "standard-package"),
                "LocalTarget",
            ]
        )
    ]
)