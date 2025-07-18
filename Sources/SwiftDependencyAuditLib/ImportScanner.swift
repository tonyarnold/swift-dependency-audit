import Foundation
import RegexBuilder

public actor ImportScanner {
    
    private let importRegex = Regex {
        Anchor.startOfLine
        ZeroOrMore(.whitespace)
        // Handle optional attributes like @testable, @preconcurrency, @_exported, etc.
        ZeroOrMore {
            "@"
            OneOrMore(.word)
            OneOrMore(.whitespace)
        }
        // Handle optional access level modifiers like private, internal, public, etc.
        Optionally {
            ChoiceOf {
                "private"
                "internal"
                "public"
                "open"
                "fileprivate"
            }
            OneOrMore(.whitespace)
        }
        "import"
        OneOrMore(.whitespace)
        Capture {
            OneOrMore(.word)
        }
        Optionally {
            ZeroOrMore {
                "."
                OneOrMore(.word)
            }
        }
        ZeroOrMore(.whitespace)
        Anchor.endOfLine
    }
    
    public init() {}
    
    public func scanFile(at path: String, customWhitelist: Set<String> = []) async throws -> Set<ImportInfo> {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        return await scanContent(content, customWhitelist: customWhitelist)
    }
    
    public func scanContent(_ content: String, customWhitelist: Set<String> = []) async -> Set<ImportInfo> {
        var imports = Set<ImportInfo>()
        
        let lines = content.components(separatedBy: .newlines)
        
        for (lineIndex, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Skip comments and empty lines
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("//") || trimmedLine.hasPrefix("/*") {
                continue
            }
            
            if let match = trimmedLine.firstMatch(of: importRegex) {
                let moduleName = String(match.1)
                let isTestable = trimmedLine.contains("@testable")
                let lineNumber = lineIndex + 1 // Convert to 1-based line numbering
                
                // Skip standard library, platform imports, and custom whitelist items
                if !isStandardLibraryModule(moduleName) && !customWhitelist.contains(moduleName) {
                    imports.insert(ImportInfo(moduleName: moduleName, isTestable: isTestable, lineNumber: lineNumber))
                }
            }
        }
        
        return imports
    }
    
    public func scanDirectory(at path: String, targetName: String, customWhitelist: Set<String> = []) async throws -> [SourceFile] {
        let fileManager = FileManager.default
        
        // Try Sources directory first
        var sourcePath = URL(fileURLWithPath: path).appendingPathComponent("Sources").appendingPathComponent(targetName)
        
        // If not found in Sources, try Tests directory for test targets
        if !fileManager.fileExists(atPath: sourcePath.path) {
            sourcePath = URL(fileURLWithPath: path).appendingPathComponent("Tests").appendingPathComponent(targetName)
        }
        
        guard fileManager.fileExists(atPath: sourcePath.path) else {
            throw ScannerError.sourceDirectoryNotFound(sourcePath.path)
        }
        
        let swiftFiles = try await findSwiftFiles(in: sourcePath.path)
        var sourceFiles: [SourceFile] = []
        
        for filePath in swiftFiles {
            do {
                let imports = try await scanFile(at: filePath, customWhitelist: customWhitelist)
                sourceFiles.append(SourceFile(path: filePath, imports: imports))
            } catch {
                throw ScannerError.fileReadError(filePath, error)
            }
        }
        
        return sourceFiles
    }
    
    private func findSwiftFiles(in directory: String) async throws -> [String] {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                let fileManager = FileManager.default
                let directoryURL = URL(fileURLWithPath: directory)
                
                guard let enumerator = fileManager.enumerator(
                    at: directoryURL,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) else {
                    continuation.resume(returning: [])
                    return
                }
                
                var swiftFiles: [String] = []
                
                while let fileURL = enumerator.nextObject() as? URL {
                    do {
                        let fileAttributes = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                        if fileAttributes.isRegularFile == true && fileURL.pathExtension == "swift" {
                            swiftFiles.append(fileURL.path)
                        }
                    } catch {
                        // Skip files we can't read attributes for
                        continue
                    }
                }
                
                continuation.resume(returning: swiftFiles)
            }
        }
    }
    
    private func isStandardLibraryModule(_ moduleName: String) -> Bool {
        // Common Swift standard library and platform modules that don't require explicit dependencies
        let standardModules: Set<String> = [
            "Accelerate",
            "Accessibility",
            "AccessorySetupKit",
            "Accounts",
            "AddressBook",
            "AdServices",
            "AdSupport",
            "AGL",
            "AppIntents",
            "AppKit",
            "AppleScriptKit",
            "AppleScriptObjC",
            "ApplicationServices",
            "AppTrackingTransparency",
            "AudioToolbox",
            "AudioUnit",
            "AudioVideoBridging",
            "AuthenticationServices",
            "AutomaticAssessmentConfiguration",
            "Automator",
            "AVFAudio",
            "AVFoundation",
            "AVKit",
            "AVRouting",
            "BackgroundAssets",
            "BackgroundTasks",
            "BrowserEngineCore",
            "BrowserEngineKit",
            "BusinessChat",
            "CalendarStore",
            "CallKit",
            "Carbon",
            "CarKey",
            "CFNetwork",
            "Charts",
            "Cinematic",
            "ClassKit",
            "CloudKit",
            "Cocoa",
            "Collaboration",
            "ColorSync",
            "Combine",
            "Compression",
            "Contacts",
            "ContactsUI",
            "CoreAudio",
            "CoreAudioKit",
            "CoreAudioTypes",
            "CoreBluetooth",
            "CoreData",
            "CoreDisplay",
            "CoreFoundation",
            "CoreGraphics",
            "CoreHaptics",
            "CoreHID",
            "CoreImage",
            "CoreLocation",
            "CoreMedia",
            "CoreMediaIO",
            "CoreMIDI",
            "CoreMIDIServer",
            "CoreML",
            "CoreMotion",
            "CoreServices",
            "CoreSpotlight",
            "CoreTelephony",
            "CoreText",
            "CoreTransferable",
            "CoreVideo",
            "CoreWLAN",
            "CreateML",
            "CreateMLComponents",
            "CryptoKit",
            "CryptoTokenKit",
            "Darwin",
            "DataDetection",
            "DeveloperToolsSupport",
            "DeviceActivity",
            "DeviceCheck",
            "DeviceDiscoveryExtension",
            "DirectoryService",
            "DiscRecording",
            "DiscRecordingUI",
            "DiskArbitration",
            "Dispatch",
            "DockKit",
            "DriverKit",
            "DVDPlayback",
            "EventKit",
            "ExceptionHandling",
            "ExecutionPolicy",
            "ExtensionFoundation",
            "ExtensionKit",
            "ExternalAccessory",
            "FamilyControls",
            "FileProvider",
            "FileProviderUI",
            "FinanceKit",
            "FinanceKitUI",
            "FinderSync",
            "ForceFeedback",
            "Foundation",
            "FSKit",
            "GameController",
            "GameKit",
            "GameplayKit",
            "Glibc",
            "GLKit",
            "GLUT",
            "GroupActivities",
            "GSS",
            "HealthKit",
            "Hypervisor",
            "ICADevices",
            "IdentityLookup",
            "ImageCaptureCore",
            "ImageIO",
            "ImagePlayground",
            "InputMethodKit",
            "InstallerPlugins",
            "InstantMessage",
            "Intents",
            "IntentsUI",
            "IOBluetooth",
            "IOBluetoothUI",
            "IOKit",
            "IOSurface",
            "IOUSBHost",
            "iTunesLibrary",
            "JavaNativeFoundation",
            "JavaRuntimeSupport",
            "JavaScriptCore",
            "Kerberos",
            "Kernel",
            "KernelManagement",
            "LatentSemanticMapping",
            "LDAP",
            "LightweightCodeRequirements",
            "LinkPresentation",
            "LocalAuthentication",
            "LocalAuthenticationEmbeddedUI",
            "MailKit",
            "ManagedAppDistribution",
            "ManagedSettings",
            "MapKit",
            "Matter",
            "MatterSupport",
            "MediaAccessibility",
            "MediaExtension",
            "MediaLibrary",
            "MediaPlayer",
            "MediaToolbox",
            "Message",
            "Metal",
            "MetalFX",
            "MetalKit",
            "MetalPerformanceShaders",
            "MetalPerformanceShadersGraph",
            "MetricKit",
            "MLCompute",
            "ModelIO",
            "MultipeerConnectivity",
            "MusicKit",
            "NaturalLanguage",
            "NearbyInteraction",
            "NetFS",
            "Network",
            "NetworkExtension",
            "NotificationCenter",
            "ObjectiveC",
            "OpenAL",
            "OpenCL",
            "OpenDirectory",
            "OpenGL",
            "os",
            "OSAKit",
            "OSLog",
            "ParavirtualizedGraphics",
            "PassKit",
            "PCSC",
            "PDFKit",
            "PencilKit",
            "PHASE",
            "Photos",
            "PhotosUI",
            "PreferencePanes",
            "ProximityReaderStub",
            "PushKit",
            "PushToTalk",
            "QTKit",
            "Quartz",
            "QuartzCore",
            "QuickLook",
            "QuickLookThumbnailing",
            "QuickLookUI",
            "RealityFoundation",
            "RealityKit",
            "RegexBuilder",
            "ReplayKit",
            "Ruby",
            "SafariServices",
            "SafetyKit",
            "SceneKit",
            "ScreenCaptureKit",
            "ScreenSaver",
            "ScreenTime",
            "ScriptingBridge",
            "Security",
            "SecurityFoundation",
            "SecurityInterface",
            "SecurityUI",
            "SensitiveContentAnalysis",
            "SensorKit",
            "ServiceManagement",
            "SharedWithYou",
            "SharedWithYouCore",
            "ShazamKit",
            "simd",
            "Social",
            "SoundAnalysis",
            "Speech",
            "SpriteKit",
            "StickerFoundation",
            "StickerKit",
            "StoreKit",
            "Swift",
            "SwiftData",
            "SwiftUI",
            "SwiftUICore",
            "Symbols",
            "SyncServices",
            "System",
            "SystemConfiguration",
            "SystemExtensions",
            "TabularData",
            "Tcl",
            "Testing",
            "ThreadNetwork",
            "TipKit",
            "Tk",
            "Translation",
            "TWAIN",
            "UIKit",
            "UniformTypeIdentifiers",
            "UserNotifications",
            "UserNotificationsUI",
            "vecLib",
            "VideoDecodeAcceleration",
            "VideoSubscriberAccount",
            "VideoToolbox",
            "Virtualization",
            "Vision",
            "VisionKit",
            "vmnet",
            "WeatherKit",
            "WebKit",
            "WidgetKit",
            "WinSDK",
            "WorkoutKit",
            "XCTest"
        ]

        return standardModules.contains(moduleName)
    }
}
