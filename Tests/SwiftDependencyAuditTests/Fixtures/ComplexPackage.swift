import PackageDescription

let package = Package(
    name: "ComplexPackage",
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "MyLibrary",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .executableTarget(
            name: "MyApp",
            dependencies: ["MyLibrary"]
        )
    ]
)