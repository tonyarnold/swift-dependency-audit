// swift-tools-version:5.9

import PackageDescription

// Regression: a dependency call inside an unlabeled array nested under dependencies
// should not be treated as a target declaration.
func helper(_ deps: [Target.Dependency]) -> [Target.Dependency] {
    deps
}

let package = Package(
    name: "NestedArrayDependencyRegression",
    products: [
        .library(name: "App", targets: ["App"]),
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                helper([.target(name: "Shared")]),
                .target(name: "Core"),
            ]
        ),
        .target(name: "Core"),
        .target(name: "Shared"),
    ]
)
