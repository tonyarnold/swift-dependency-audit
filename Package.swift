// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "DependentImportScanner",
    platforms: [
        .macOS(.v15),
        .macCatalyst(.v18),
        .iOS(.v18),
        .tvOS(.v18),
        .watchOS(.v11),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.1")
    ],
    targets: [
        .target(
            name: "DependentImportScannerLib",
        ),
        .executableTarget(
            name: "DependentImportScanner",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "DependentImportScannerLib"
            ]
        ),
        .testTarget(
            name: "DependentImportScannerTests",
            dependencies: ["DependentImportScannerLib"]
        ),
    ]
)
