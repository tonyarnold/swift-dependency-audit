// swift-tools-version: 6.1
import PackageDescription

// Regression: dependency entries like .target(name:) must not be parsed as target declarations.
let package = Package(
    name: "DemoPackage",
    targets: [
        .target(
            name: "Core",
            dependencies: [
                .target(name: "Shared"),
                .target(name: "SharedUI", condition: .when(platforms: [.iOS]))
            ]
        ),
        .target(
            name: "Shared",
            dependencies: []
        ),
        .target(
            name: "SharedUI",
            dependencies: []
        )
    ]
)
