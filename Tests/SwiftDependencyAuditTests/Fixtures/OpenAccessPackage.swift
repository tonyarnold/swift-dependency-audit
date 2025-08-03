// swift-tools-version: 6.0
import PackageDescription

// swift-format-ignore: AlwaysUseLowerCamelCase
open let OpenDep = Target.Dependency.product(
    name: "OpenFramework",
    package: "open-package"
)

let package = Package(
    name: "OpenAccessPackage",
    dependencies: [
        .package(url: "https://github.com/example/open-package", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "OpenTarget",
            dependencies: [
                OpenDep
            ]
        )
    ]
)
