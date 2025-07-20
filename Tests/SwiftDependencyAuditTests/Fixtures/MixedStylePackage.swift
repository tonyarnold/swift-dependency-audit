import PackageDescription

private let CustomDep = Target.Dependency.product(
    name: "CustomFramework",
    package: "custom-framework"
)

let package = Package(
    name: "MixedStylePackage",
    dependencies: [
        .package(url: "https://github.com/example/custom-framework", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "MainTarget",
            dependencies: [
                CustomDep,
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "InternalDependency"
            ]
        )
    ]
)