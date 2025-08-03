// swift-tools-version: 6.0
// Test fixture demonstrating the bug where products after conditional dependencies are ignored
import PackageDescription

let package = Package(
    name: "ConditionalBugPackage",
    dependencies: [
        .package(url: "https://github.com/example/MyModuleTV", from: "1.0.0"),
        .package(url: "https://github.com/ReactiveX/RxSwift", from: "6.0.0"),
        .package(url: "https://github.com/example/AnotherPackage", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "TestTarget",
            dependencies: [
                .product(name: "MyModuleTV", package: "MyModuleTV", condition: .when(platforms: [.tvOS])),
                .product(name: "RxSwift", package: "RxSwift"),
                .product(name: "AnotherProduct", package: "AnotherPackage")
            ]
        )
    ]
)