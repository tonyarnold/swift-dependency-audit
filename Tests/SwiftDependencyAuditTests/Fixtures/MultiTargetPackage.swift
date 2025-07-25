import PackageDescription

let package = Package(
    name: "MultiTargetPackage",
    targets: [
        .target(name: "LibraryTarget", dependencies: ["Dep1"]),
        .executableTarget(name: "ExecutableTarget", dependencies: ["LibraryTarget"]),
        .testTarget(name: "TestTarget", dependencies: ["LibraryTarget"])
    ]
)