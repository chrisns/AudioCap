//
//  APISettingsView.swift
//  AudioCap
//
//  GUI configuration interface for HTTP API server settings
//

import SwiftUI
import OSLog

private let logger = Logger(subsystem: kAppSubsystem, category: "APISettings")

@MainActor
struct APISettingsView: View {
    @Environment(HTTPServerManager.self) private var httpServerManager
    
    @State private var showingAdvancedSettings = false
    @State private var tempIPAddress: String = ""
    @State private var tempPort: String = ""
    @State private var isEditingIP = false
    @State private var isEditingPort = false
    
    var body: some View {
        GroupBox("HTTP API Server") {
            VStack(alignment: .leading, spacing: 12) {
                // Server Status Section
                serverStatusSection
                
                Divider()
                
                // Basic Configuration Section
                basicConfigurationSection
                
                // Advanced Settings Toggle
                DisclosureGroup("Advanced Settings", isExpanded: $showingAdvancedSettings) {
                    advancedSettingsSection
                }
                .padding(.top, 8)
            }
        }
        .onAppear {
            initializeTempValues()
        }
    }
    
    // MARK: - Server Status Section
    @ViewBuilder
    private var serverStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Status", systemImage: "circle.fill")
                    .foregroundColor(httpServerManager.isRunning ? .green : .secondary)
                Spacer()
                Text(httpServerManager.statusMessage)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(httpServerManager.isRunning ? .green : .secondary)
            }
            
            if let endpointURL = httpServerManager.endpointURL {
                HStack {
                    Label("Endpoint", systemImage: "link")
                    Spacer()
                    Text(endpointURL)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .foregroundColor(.blue)
                }
                
                HStack {
                    Spacer()
                    Button("Copy URL") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(endpointURL, forType: .string)
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
            }
        }
    }
    
    // MARK: - Basic Configuration Section
    @ViewBuilder
    private var basicConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Enable/Disable Toggle
            HStack {
                Toggle("Enable API Server", isOn: Binding(
                    get: { httpServerManager.configuration.enabled },
                    set: { enabled in
                        logger.info("API server enabled changed to: \(enabled)")
                        var config = httpServerManager.configuration
                        config.enabled = enabled
                        httpServerManager.updateConfiguration(config)
                    }
                ))
                .toggleStyle(.switch)
                
                Spacer()
                
                if httpServerManager.configuration.enabled && !httpServerManager.isRunning {
                    Button("Start Server") {
                        Task {
                            await startServer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } else if httpServerManager.configuration.enabled && httpServerManager.isRunning {
                    Button("Stop Server") {
                        Task {
                            await httpServerManager.stop()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            if httpServerManager.configuration.enabled {
                // Port Configuration
                HStack {
                    Text("Port:")
                        .frame(width: 80, alignment: .leading)
                    
                    TextField("Port", text: $tempPort)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onSubmit {
                            updatePortConfiguration()
                        }
                        .onChange(of: tempPort) { _, newValue in
                            // Validate port input in real-time
                            if let port = Int(newValue), port > 0 && port <= 65535 {
                                // Valid port, no visual feedback needed
                            }
                        }
                    
                    Text("(1-65535)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Advanced Settings Section
    @ViewBuilder
    private var advancedSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // IP Address Configuration
            HStack {
                Text("IP Address:")
                    .frame(width: 80, alignment: .leading)
                
                TextField("IP Address", text: $tempIPAddress)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .onSubmit {
                        updateIPConfiguration()
                    }
                
                Button("Localhost") {
                    tempIPAddress = "127.0.0.1"
                    updateIPConfiguration()
                }
                .buttonStyle(.link)
                .font(.caption)
                
                Spacer()
            }
            
            // Security Warning for non-localhost binding
            if !tempIPAddress.isEmpty && tempIPAddress != "127.0.0.1" && tempIPAddress != "localhost" {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Warning: Binding to non-localhost addresses may expose your system to network access.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.vertical, 4)
            }
            
            // CORS Configuration
            HStack {
                Toggle("Enable CORS Headers", isOn: Binding(
                    get: { httpServerManager.configuration.enableCORS },
                    set: { enabled in
                        var config = httpServerManager.configuration
                        config.enableCORS = enabled
                        httpServerManager.updateConfiguration(config)
                    }
                ))
                
                Spacer()
                
                Button("?") {
                    // Show CORS help
                    showCORSHelp()
                }
                .buttonStyle(.link)
                .font(.caption)
            }
            
            // Reset to Defaults
            HStack {
                Spacer()
                Button("Reset to Defaults") {
                    resetToDefaults()
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        }
        .padding(.leading, 16)
    }
    
    // MARK: - Helper Methods
    private func initializeTempValues() {
        tempIPAddress = httpServerManager.configuration.ipAddress
        tempPort = String(httpServerManager.configuration.port)
    }
    
    private func updatePortConfiguration() {
        guard let port = Int(tempPort), port > 0 && port <= 65535 else {
            // Reset to current valid value
            tempPort = String(httpServerManager.configuration.port)
            return
        }
        
        logger.info("Updating port configuration to: \(port)")
        var config = httpServerManager.configuration
        config.port = port
        httpServerManager.updateConfiguration(config)
    }
    
    private func updateIPConfiguration() {
        guard !tempIPAddress.isEmpty else {
            // Reset to current valid value
            tempIPAddress = httpServerManager.configuration.ipAddress
            return
        }
        
        logger.info("Updating IP address configuration to: \(tempIPAddress)")
        var config = httpServerManager.configuration
        config.ipAddress = tempIPAddress
        httpServerManager.updateConfiguration(config)
    }
    
    private func startServer() async {
        do {
            logger.info("Starting HTTP server from settings")
            try await httpServerManager.start()
        } catch {
            logger.error("Failed to start HTTP server: \(error)")
            // In a production app, you might want to show an alert
        }
    }
    
    private func resetToDefaults() {
        logger.info("Resetting API server configuration to defaults")
        let defaultConfig = ServerConfiguration.default
        httpServerManager.updateConfiguration(defaultConfig)
        initializeTempValues()
    }
    
    private func showCORSHelp() {
        let alert = NSAlert()
        alert.messageText = "CORS Headers"
        alert.informativeText = "Cross-Origin Resource Sharing (CORS) headers allow web browsers to access the API from web pages. Enable this if you plan to use the API from web applications."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

#if DEBUG
#Preview {
    APISettingsView()
        .environment(HTTPServerManager())
        .frame(width: 400)
}
#endif