// swift-tools-version: 6.0
import PackageDescription

private let PrivateDep = Target.Dependency.product(
    name: "Private",
    package: "private-package"
)

public let PublicDep = Target.Dependency.product(
    name: "Public",
    package: "public-package"
)

internal let InternalDep = Target.Dependency.product(
    name: "Internal",
    package: "internal-package"
)

fileprivate let FileprivateDep = Target.Dependency.product(
    name: "Fileprivate",
    package: "fileprivate-package"
)

open let OpenDep = Target.Dependency.product(
    name: "Open",
    package: "open-package"
)

let NoModifierDep = Target.Dependency.product(
    name: "NoModifier",
    package: "no-modifier-package"
)

let package = Package(
    name: "MixedAccessPackage",
    dependencies: [
        .package(url: "https://github.com/example/private-package", from: "1.0.0"),
        .package(url: "https://github.com/example/public-package", from: "1.0.0"),
        .package(url: "https://github.com/example/internal-package", from: "1.0.0"),
        .package(url: "https://github.com/example/fileprivate-package", from: "1.0.0"),
        .package(url: "https://github.com/example/open-package", from: "1.0.0"),
        .package(url: "https://github.com/example/no-modifier-package", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "MixedTarget",
            dependencies: [
                PrivateDep,
                FileprivateDep,
                InternalDep,
                PublicDep,
                OpenDep,
                NoModifierDep,
            ]
        )
    ]
)