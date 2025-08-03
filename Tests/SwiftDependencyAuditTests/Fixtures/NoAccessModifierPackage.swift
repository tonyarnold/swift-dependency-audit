// swift-tools-version: 6.0
import PackageDescription

// swift-format-ignore: AlwaysUseLowerCamelCase
let TCA = Target.Dependency.product(
    name: "ComposableArchitecture",
    package: "swift-composable-architecture"
)

// swift-format-ignore: AlwaysUseLowerCamelCase
let AsyncAlgorithms = Target.Dependency.product(
    name: "AsyncAlgorithms",
    package: "swift-async-algorithms"
)

let package = Package(
    name: "NoAccessModifierPackage",
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "MyTarget",
            dependencies: [
                TCA,
                AsyncAlgorithms,
            ]
        )
    ]
)
