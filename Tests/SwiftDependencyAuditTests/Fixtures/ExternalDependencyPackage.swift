// swift-tools-version: 6.1
import PackageDescription

let dependencies: [Package.Dependency] = [
    .package(url: "https://github.com/example/swift-algorithms.git", exact: "1.2.0"),
    .package(path: "../UtilityLibrary"),
    .package(url: "https://github.com/example/networking-kit.git", exact: "2.1.0")
]

let package = Package(
    name: "TestPackage",
    dependencies: dependencies,
    targets: []
)