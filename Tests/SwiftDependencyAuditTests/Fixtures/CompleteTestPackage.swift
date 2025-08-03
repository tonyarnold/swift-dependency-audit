// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TestPackage",
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "TestPackage",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .target(
            name: "CustomPathTarget",
            dependencies: [],
            path: "/Sources/MyCustomPath"
        ),
        .testTarget(
            name: "TestPackageTests",
            dependencies: ["TestPackage"]
        ),
    ]
)
