import SwiftUI
import OSLog

let kAppSubsystem = "codes.rambo.AudioCap"

private let logger = Logger(subsystem: kAppSubsystem, category: "App")

@main
struct AudioCapApp: App {
    @State private var httpServerManager = HTTPServerManager()
    
    // Check if running in test environment
    private static let isRunningTests: Bool = {
        return ProcessInfo.processInfo.environment["AUDIOCAP_TEST_MODE"] == "1" ||
               ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
               NSClassFromString("XCTestCase") != nil
    }()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(httpServerManager)
                .task {
                    // Only start HTTP server if not in test mode
                    if !Self.isRunningTests {
                        await httpServerManager.startOrTerminate()
                    } else {
                        logger.info("Skipping HTTP server startup - running in test mode")
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Quit AudioCap") {
                    Task {
                        if !Self.isRunningTests {
                            await httpServerManager.stop()
                        }
                        NSApplication.shared.terminate(nil)
                    }
                }
                .keyboardShortcut("q")
            }
        }
    }
    
    init() {
        logger.info("AudioCap application starting (Test mode: \(Self.isRunningTests))")
        
        // Only set up termination handler if not in test mode
        if !Self.isRunningTests {
            setupTerminationHandler()
        } else {
            logger.info("Skipping termination handler setup - running in test mode")
        }
    }
    
    private func setupTerminationHandler() {
        // Handle app lifecycle notifications
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            logger.info("Application will terminate notification received")
            // Note: The server cleanup will be handled by the deinit of HTTPServerManager
        }
    }
}
