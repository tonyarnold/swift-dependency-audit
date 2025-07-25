// swift-tools-version: 6.0
import PackageDescription

// Constant with condition parameter (realistic use case)
private let iOSOnlyDep = Target.Dependency.product(
    name: "iOSFramework",
    package: "ios-framework",
    condition: .when(platforms: [.iOS])
)

let package = Package(
    name: "ConditionalPackage",
    dependencies: [
        .package(url: "https://github.com/example/ios-framework", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "ConditionalTarget",
            dependencies: [
                iOSOnlyDep,
            ]
        )
    ]
)