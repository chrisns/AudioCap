import SwiftUI
import OSLog

private let logger = Logger(subsystem: kAppSubsystem, category: "RootView")

@MainActor
struct RootView: View {
    @State private var permission = AudioRecordingPermission()
    @Environment(HTTPServerManager.self) private var httpServerManager

    var body: some View {
        Form {
            switch permission.status {
            case .unknown:
                requestPermissionView
            case .authorized:
                recordingView
            case .denied:
                permissionDeniedView
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var requestPermissionView: some View {
        LabeledContent("Please Allow Audio Recording") {
            Button("Allow") {
                permission.request()
            }
        }
    }

    @ViewBuilder
    private var permissionDeniedView: some View {
        LabeledContent("Audio Recording Permission Required") {
            Button("Open System Settings") {
                NSWorkspace.shared.openSystemSettings()
            }
        }
    }

    @ViewBuilder
    private var recordingView: some View {
        VStack(spacing: 0) {
            // HTTP API Settings Section
            APISettingsView()
                .padding(.horizontal)
            
            Divider()
                .padding(.vertical, 8)
            
            // Main Recording Interface
            ProcessSelectionView()
        }
    }
    

}

extension NSWorkspace {
    func openSystemSettings() {
        guard let url = urlForApplication(withBundleIdentifier: "com.apple.systempreferences") else {
            assertionFailure("Failed to get System Settings app URL")
            return
        }

        openApplication(at: url, configuration: .init())
    }
}

#if DEBUG
#Preview {
    RootView()
}
#endif
