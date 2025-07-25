import PackageDescription

let package = Package(
    name: "MyCustomPathPackage",
    targets: [
        .target(
            name: "LibraryTarget",
            dependencies: ["Dep1"],
            path: "/Sources/MyCustomPath"
        ),
    ]
)