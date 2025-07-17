import PackagePlugin
import Foundation

/// Swift Package Manager build tool plugin that automatically validates dependencies during builds
@main
struct DependencyAuditPlugin: BuildToolPlugin {
    
    /// Creates build commands to run dependency validation
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        // Only analyze source-based targets to reduce overhead
        guard let sourceTarget = target as? SourceModuleTarget else {
            return []
        }
        
        let tool = try context.tool(named: "SwiftDependencyAudit")
        
        // Create output directory for plugin results
        let outputDir = context.pluginWorkDirectoryURL.appendingPathComponent("DependencyAudit")
        
        // Build arguments for the tool
        var arguments = [
            context.package.directoryURL.path,
            "--target", sourceTarget.name,
            "--output-format", "xcode",
            "--quiet"
        ]
        
        // Check if the target is not a test target using the kind property
        if sourceTarget.kind != .test {
            // For non-test targets, exclude test dependencies from analysis
            arguments.append("--exclude-tests")
        }
        
        // Create the prebuild command that runs our binary tool directly
        // Using prebuild because dependency state can change between builds
        // and we want to validate on every build
        let command = Command.prebuildCommand(
            displayName: "Dependency Audit for \(sourceTarget.name)",
            executable: tool.url,
            arguments: arguments,
            outputFilesDirectory: outputDir
        )
        
        return [command]
    }
}