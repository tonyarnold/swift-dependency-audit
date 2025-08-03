import PackageDescription

let package = Package(
    name: "LargePackage",
    targets: [
        .target(name: "LargeTarget", dependencies: [])
    ]
)
