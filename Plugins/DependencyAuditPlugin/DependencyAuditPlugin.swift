import PackagePlugin
import Foundation

/// Swift Package Manager build tool plugin that automatically validates dependencies during builds
@main
struct DependencyAuditPlugin: BuildToolPlugin {
    
    /// Creates build commands to run dependency validation
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        // Only run on source-based targets that could have dependencies
        guard shouldAnalyzeTarget(target) else {
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
                --target "\(target.name)" \\
                --output-format xcode \\
                --quiet
            """
        
        // Add additional arguments based on target type
        // Check if target name contains "Test" to identify test targets
        if !target.name.lowercased().contains("test") {
            // For non-test targets, exclude test dependencies from analysis
            scriptContent += " \\\n                --exclude-tests"
        }
        
        // Create the prebuild command that runs our script
        // Using prebuild because dependency state can change between builds
        // and we want to validate on every build
        let command = Command.prebuildCommand(
            displayName: "Dependency Audit for \(target.name)",
            executable: URL(fileURLWithPath: "/bin/bash"),
            arguments: [
                "-c",
                """
                # Create output directory
                mkdir -p "\(outputDir.path)"
                
                # Execute dependency audit directly
                \(scriptContent)
                """
            ],
            outputFilesDirectory: outputDir
        )
        
        return [command]
    }
    
    /// Determines if a target should be analyzed for dependencies
    private func shouldAnalyzeTarget(_ target: Target) -> Bool {
        // For now, analyze all targets and let the tool itself filter appropriately
        // The tool will skip targets that don't have source directories
        return true
    }
}