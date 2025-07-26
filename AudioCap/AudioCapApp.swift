import SwiftUI
import OSLog

let kAppSubsystem = "codes.rambo.AudioCap"

private let logger = Logger(subsystem: kAppSubsystem, category: "App")

@main
struct AudioCapApp: App {
    @State private var httpServerManager = HTTPServerManager()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(httpServerManager)
        }
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Quit AudioCap") {
                    Task {
                        await httpServerManager.stop()
                        NSApplication.shared.terminate(nil)
                    }
                }
                .keyboardShortcut("q")
            }
        }
    }
    
    init() {
        logger.info("AudioCap application starting")
        
        // Set up termination handler for proper cleanup
        setupTerminationHandler()
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
