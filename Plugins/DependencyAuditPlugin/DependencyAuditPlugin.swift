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
        
        // Create output directory for plugin results
        let outputDir = context.pluginWorkDirectoryURL.appendingPathComponent("DependencyAudit")
        
        // Build script content that will execute swift run with our tool
        var scriptContent = """
            #!/bin/bash
            set -e
            
            # Change to package directory
            cd "\(context.package.directoryURL.path)"
            
            # Run dependency audit for specific target
            swift run swift-dependency-audit \\
                "\(context.package.directoryURL.path)" \\
                --target "\(sourceTarget.name)" \\
                --output-format xcode \\
                --quiet
            """
        
        // Check if the target is not a test target using the kind property
        if sourceTarget.kind != .test {
            // For non-test targets, exclude test dependencies from analysis
            scriptContent += " \\\n                --exclude-tests"
        }
        
        // Create the prebuild command that runs our script
        // Using prebuild because dependency state can change between builds
        // and we want to validate on every build
        let command = Command.prebuildCommand(
            displayName: "Dependency Audit for \(sourceTarget.name)",
            executable: URL(fileURLWithPath: "/bin/bash"),
            arguments: [
                "-c",
                """
                # Create output directory
                mkdir -p "\(outputDir.path)"
                
                # Execute dependency audit
                \(scriptContent)
                """
            ],
            outputFilesDirectory: outputDir
        )
        
        return [command]
    }
}