import Foundation
import PackagePlugin

@main
struct VersionPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        let versionGenerator = try context.tool(named: "VersionGenerator")
        let versionFileURL = context.pluginWorkDirectoryURL.appending(path: "Version.swift")

        return [
            .buildCommand(
                displayName: "Generate version information into \(versionFileURL.lastPathComponent)",
                executable: versionGenerator.url,
                arguments: [versionFileURL.path(percentEncoded: false)],
                environment: ProcessInfo.processInfo.environment,
                inputFiles: [],
                outputFiles: [versionFileURL]
            )
        ]
    }
}
