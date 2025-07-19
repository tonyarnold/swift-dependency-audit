#if os(Linux)
@preconcurrency import Glibc
#else
import Darwin.C
#endif

import ArgumentParser
import SwiftDependencyAuditLib
import Foundation

/// Get the version string, trying multiple sources
private func getVersion() -> String {
    // Always use the build-time generated version from the plugin
    return SwiftDependencyAuditLib.VERSION
}


public enum OutputFormat: String, CaseIterable, ExpressibleByArgument {
    case terminal = "terminal"
    case json = "json"
    case xcode = "xcode"
    case githubActions = "github-actions"
}

@main
public struct SwiftDependencyAudit: AsyncParsableCommand {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "swift-dependency-audit",
        abstract: "Analyze Swift package dependencies and imports",
        discussion: """
            This tool analyzes Swift Package.swift files, scans source directories for import statements,
            and compares declared dependencies against actual usage to identify missing or unused dependencies.
            """,
        version: getVersion()
    )

    @Argument(help: "Path to Package.swift or package directory (default: current directory)")
    public var path: String = "."

    @Flag(name: .long, help: "Disable colored output")
    public var noColor = false

    @Flag(name: [.short, .long], help: "Enable verbose output")
    public var verbose = false

    @Option(name: .long, help: "Analyze specific target only")
    public var target: String?

    @Flag(name: .long, help: "Skip test targets")
    public var excludeTests = false


    @Flag(name: [.short, .long], help: "Only show problems, suppress success messages")
    public var quiet = false

    @Option(
        name: .long,
        help: "Comma-separated list of system imports to ignore (e.g., Foundation,SwiftUI,AppKit)")
    public var whitelist: String?

    @Option(
        name: .long,
        help: "Output format: terminal, json, xcode, or github-actions")
    public var outputFormat: OutputFormat = .terminal

    public func run() async throws {
        // Configure color output
        let shouldDisableColor = noColor
        ColorOutput.colorEnabled = !shouldDisableColor

        do {
            // Parse whitelist
            let customWhitelist = parseWhitelist(whitelist)

            // Initialize components
            let parser = PackageParser()
            let analyzer = DependencyAnalyzer()
            let processor = ParallelProcessor()

            if verbose && outputFormat != .json {
                let message = ColorOutput.info("Parsing package at: \(path)")
                print(message)
            }

            // Parse package
            let packageInfo = try await parser.parsePackage(at: path)

            if verbose && outputFormat != .json {
                let message = ColorOutput.info(
                    "Found \(packageInfo.targets.count) target(s) in package '\(packageInfo.name)'")
                print(message)
            }

            // Filter targets based on options
            var targetsToAnalyze = packageInfo.targets

            if let targetFilter = target {
                targetsToAnalyze = targetsToAnalyze.filter { $0.name == targetFilter }
                if targetsToAnalyze.isEmpty {
                    let message = ColorOutput.error("Target '\(targetFilter)' not found")
                    print(message)
                    throw ExitCode.failure
                }
            }

            if excludeTests {
                targetsToAnalyze = targetsToAnalyze.filter { $0.type != .test }
            }

            if verbose && outputFormat != .json {
                let message = ColorOutput.info(
                    "Analyzing \(targetsToAnalyze.count) target(s)")
                print(message)
            }

            // Analyze targets (always use parallel processing for consistency)
            let results = try await processor.processTargetsInParallel(
                targetsToAnalyze, packageInfo: packageInfo, analyzer: analyzer,
                customWhitelist: customWhitelist)

            // Generate and output report
            let report: String
            switch outputFormat {
            case .terminal:
                report = await analyzer.generateReport(
                    for: results, packageName: packageInfo.name, verbose: verbose, quiet: quiet)
            case .json:
                report = try await analyzer.generateJSONReport(
                    for: results, packageName: packageInfo.name, quiet: quiet)
            case .xcode:
                report = await analyzer.generateXcodeReport(
                    for: results, packagePath: path)
            case .githubActions:
                report = await analyzer.generateGitHubActionsReport(
                    for: results, packagePath: path)
            }
            print(report)

            // Exit with error code if issues found (except for JSON format)
            if outputFormat != .json {
                let hasIssues = results.contains { $0.hasIssues }
                if hasIssues {
                    throw ExitCode.failure
                }
            }

        } catch let error as ScannerError {
            let message = ColorOutput.error(error.localizedDescription)
            fputs(message + "\n", stderr)
            throw ExitCode.failure
        } catch {
            throw ExitCode.failure
        }
    }

    private func parseWhitelist(_ whitelist: String?) -> Set<String> {
        guard let whitelist = whitelist, !whitelist.isEmpty else {
            return []
        }

        return Set(
            whitelist.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty })
    }
}
