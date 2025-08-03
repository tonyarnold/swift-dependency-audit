// swift-tools-version: 6.1
import PackageDescription

let products: [Product] = [
    .library(name: "NetworkKit", targets: ["NetworkClient", "NetworkCore"]),
    .library(name: "DataProcessor", targets: ["DataModels", "DataStorage"]),
    .executable(name: "CLITool", targets: ["CLIMain"]),
]

let package = Package(
    name: "ExamplePackage",
    products: products,
    targets: []
)
