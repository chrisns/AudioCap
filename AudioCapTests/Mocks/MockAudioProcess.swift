import Foundation
import AudioToolbox
import OSLog

/// Mock implementation of AudioProcess for testing purposes
final class MockAudioProcess {
    
    private static let logger = Logger(subsystem: "com.audiocap.tests", category: "MockAudioProcess")
    
    // MARK: - Factory Methods
    
    /// Creates a mock AudioProcess with default values
    /// - Parameters:
    ///   - id: Process identifier (default: 1234)
    ///   - name: Process name (default: "Test App")
    ///   - audioActive: Whether the process has active audio (default: true)
    ///   - bundleID: Bundle identifier (default: "com.test.app")
    ///   - kind: Process kind (default: .app)
    ///   - objectID: Audio object ID (default: 100)
    /// - Returns: Configured AudioProcess instance
    static func createMockProcess(
        id: pid_t = 1234,
        name: String = "Test App",
        audioActive: Bool = true,
        bundleID: String? = "com.test.app",
        kind: AudioProcess.Kind = .app,
        objectID: AudioObjectID = 100
    ) -> AudioProcess {
        let bundleURL = bundleID != nil ? URL(fileURLWithPath: "/Applications/\(name).app") : nil
        
        let process = AudioProcess(
            id: id,
            kind: kind,
            name: name,
            audioActive: audioActive,
            bundleID: bundleID,
            bundleURL: bundleURL,
            objectID: objectID
        )
        
        logger.debug("Created mock AudioProcess: \(name) (PID: \(id), Audio: \(audioActive))")
        return process
    }
    
    /// Creates a mock AudioProcess representing a system process
    /// - Parameters:
    ///   - id: Process identifier
    ///   - name: Process name
    ///   - audioActive: Whether the process has active audio
    /// - Returns: AudioProcess configured as a system process
    static func createMockSystemProcess(
        id: pid_t = 5678,
        name: String = "coreaudiod",
        audioActive: Bool = true
    ) -> AudioProcess {
        return AudioProcess(
            id: id,
            kind: .process,
            name: name,
            audioActive: audioActive,
            bundleID: nil,
            bundleURL: nil,
            objectID: AudioObjectID(id + 1000)
        )
    }
    
    /// Creates a mock AudioProcess representing an application
    /// - Parameters:
    ///   - id: Process identifier
    ///   - name: Application name
    ///   - bundleID: Bundle identifier
    ///   - audioActive: Whether the app has active audio
    /// - Returns: AudioProcess configured as an application
    static func createMockApplication(
        id: pid_t = 9999,
        name: String = "Music",
        bundleID: String = "com.apple.Music",
        audioActive: Bool = true
    ) -> AudioProcess {
        let bundleURL = URL(fileURLWithPath: "/Applications/\(name).app")
        
        return AudioProcess(
            id: id,
            kind: .app,
            name: name,
            audioActive: audioActive,
            bundleID: bundleID,
            bundleURL: bundleURL,
            objectID: AudioObjectID(id + 2000)
        )
    }
    
    // MARK: - Configurable Test Scenarios
    
    /// Creates a collection of mock processes for different test scenarios
    /// - Parameter scenario: The test scenario to configure
    /// - Returns: Array of AudioProcess instances for the scenario
    static func createProcessesForScenario(_ scenario: TestScenario) -> [AudioProcess] {
        switch scenario {
        case .empty:
            return []
            
        case .singleApp:
            return [createMockApplication()]
            
        case .singleProcess:
            return [createMockSystemProcess()]
            
        case .mixed:
            return [
                createMockApplication(id: 1001, name: "Safari", bundleID: "com.apple.Safari", audioActive: true),
                createMockApplication(id: 1002, name: "Music", bundleID: "com.apple.Music", audioActive: true),
                createMockSystemProcess(id: 2001, name: "coreaudiod", audioActive: true),
                createMockApplication(id: 1003, name: "Terminal", bundleID: "com.apple.Terminal", audioActive: false),
                createMockSystemProcess(id: 2002, name: "kernel_task", audioActive: false)
            ]
            
        case .audioActiveOnly:
            return [
                createMockApplication(id: 1001, name: "Music", bundleID: "com.apple.Music", audioActive: true),
                createMockApplication(id: 1002, name: "Safari", bundleID: "com.apple.Safari", audioActive: true),
                createMockSystemProcess(id: 2001, name: "coreaudiod", audioActive: true)
            ]
            
        case .noAudioActive:
            return [
                createMockApplication(id: 1001, name: "TextEdit", bundleID: "com.apple.TextEdit", audioActive: false),
                createMockApplication(id: 1002, name: "Calculator", bundleID: "com.apple.Calculator", audioActive: false),
                createMockSystemProcess(id: 2001, name: "launchd", audioActive: false)
            ]
            
        case .largeSet:
            var processes: [AudioProcess] = []
            
            // Create 20 mock applications
            for i in 1...20 {
                let audioActive = i % 3 == 0 // Every third app has audio active
                processes.append(createMockApplication(
                    id: pid_t(1000 + i),
                    name: "App \(i)",
                    bundleID: "com.test.app\(i)",
                    audioActive: audioActive
                ))
            }
            
            // Create 10 mock system processes
            for i in 1...10 {
                let audioActive = i % 4 == 0 // Every fourth process has audio active
                processes.append(createMockSystemProcess(
                    id: pid_t(2000 + i),
                    name: "process\(i)",
                    audioActive: audioActive
                ))
            }
            
            return processes
        }
    }
    
    // MARK: - Process Grouping Test Helpers
    
    /// Creates mock processes specifically for testing grouping functionality
    /// - Returns: Array of AudioProcess instances with mixed kinds for grouping tests
    static func createProcessesForGroupingTests() -> [AudioProcess] {
        return [
            // Apps group
            createMockApplication(id: 1001, name: "Safari", bundleID: "com.apple.Safari", audioActive: true),
            createMockApplication(id: 1002, name: "Music", bundleID: "com.apple.Music", audioActive: true),
            createMockApplication(id: 1003, name: "Xcode", bundleID: "com.apple.dt.Xcode", audioActive: false),
            
            // Processes group
            createMockSystemProcess(id: 2001, name: "coreaudiod", audioActive: true),
            createMockSystemProcess(id: 2002, name: "WindowServer", audioActive: false),
            createMockSystemProcess(id: 2003, name: "kernel_task", audioActive: false)
        ]
    }
    
    /// Creates mock AudioProcessGroup instances for testing
    /// - Returns: Array of AudioProcessGroup instances
    static func createMockProcessGroups() -> [AudioProcessGroup] {
        let processes = createProcessesForGroupingTests()
        return AudioProcessGroup.groups(with: processes)
    }
    
    /// Verifies that process grouping works correctly
    /// - Parameter processes: Array of processes to group
    /// - Returns: Dictionary mapping group titles to process counts
    static func verifyProcessGrouping(_ processes: [AudioProcess]) -> [String: Int] {
        let groups = AudioProcessGroup.groups(with: processes)
        var groupCounts: [String: Int] = [:]
        
        for group in groups {
            groupCounts[group.title] = group.processes.count
            logger.debug("Group '\(group.title)' contains \(group.processes.count) processes")
        }
        
        return groupCounts
    }
    
    // MARK: - Audio State Testing
    
    /// Creates processes with specific audio states for testing
    /// - Parameters:
    ///   - activeCount: Number of processes with active audio
    ///   - inactiveCount: Number of processes with inactive audio
    /// - Returns: Array of AudioProcess instances with specified audio states
    static func createProcessesWithAudioStates(activeCount: Int, inactiveCount: Int) -> [AudioProcess] {
        var processes: [AudioProcess] = []
        
        // Create processes with active audio
        for i in 1...activeCount {
            processes.append(createMockApplication(
                id: pid_t(1000 + i),
                name: "Active App \(i)",
                bundleID: "com.test.active\(i)",
                audioActive: true
            ))
        }
        
        // Create processes with inactive audio
        for i in 1...inactiveCount {
            processes.append(createMockApplication(
                id: pid_t(2000 + i),
                name: "Inactive App \(i)",
                bundleID: "com.test.inactive\(i)",
                audioActive: false
            ))
        }
        
        return processes
    }
    
    // MARK: - Bundle ID Testing
    
    /// Creates processes with various bundle ID configurations for testing
    /// - Returns: Array of AudioProcess instances with different bundle ID scenarios
    static func createProcessesWithVariousBundleIDs() -> [AudioProcess] {
        return [
            // Standard app with bundle ID
            createMockApplication(id: 1001, name: "Safari", bundleID: "com.apple.Safari"),
            
            // App with nil bundle ID
            createMockProcess(id: 1002, name: "Unknown App", bundleID: nil, kind: .app),
            
            // App with empty bundle ID
            createMockProcess(id: 1003, name: "Empty Bundle App", bundleID: "", kind: .app),
            
            // System process (typically no bundle ID)
            createMockSystemProcess(id: 2001, name: "coreaudiod"),
            
            // Process with unusual bundle ID format
            createMockProcess(id: 1004, name: "Custom App", bundleID: "custom.bundle.format", kind: .app)
        ]
    }
    
    // MARK: - Performance Testing
    
    /// Creates a large number of mock processes for performance testing
    /// - Parameter count: Number of processes to create
    /// - Returns: Array of AudioProcess instances
    static func createLargeProcessSet(count: Int) -> [AudioProcess] {
        var processes: [AudioProcess] = []
        
        for i in 1...count {
            let isApp = i % 2 == 0
            let audioActive = i % 3 == 0
            
            if isApp {
                processes.append(createMockApplication(
                    id: pid_t(1000 + i),
                    name: "App \(i)",
                    bundleID: "com.test.app\(i)",
                    audioActive: audioActive
                ))
            } else {
                processes.append(createMockSystemProcess(
                    id: pid_t(2000 + i),
                    name: "process\(i)",
                    audioActive: audioActive
                ))
            }
        }
        
        logger.debug("Created \(count) mock processes for performance testing")
        return processes
    }
}

// MARK: - Supporting Types

/// Test scenarios for different process configurations
enum TestScenario {
    case empty
    case singleApp
    case singleProcess
    case mixed
    case audioActiveOnly
    case noAudioActive
    case largeSet
}

// MARK: - Extensions for Testing

extension AudioProcess {
    /// Creates a copy of the AudioProcess with modified properties for testing
    /// - Parameters:
    ///   - audioActive: New audio active state
    ///   - name: New process name
    /// - Returns: New AudioProcess instance with modified properties
    func withModifications(audioActive: Bool? = nil, name: String? = nil) -> AudioProcess {
        return AudioProcess(
            id: self.id,
            kind: self.kind,
            name: name ?? self.name,
            audioActive: audioActive ?? self.audioActive,
            bundleID: self.bundleID,
            bundleURL: self.bundleURL,
            objectID: self.objectID
        )
    }
}

extension Array where Element == AudioProcess {
    /// Filters processes by audio active state
    /// - Parameter audioActive: Whether to filter for active or inactive audio
    /// - Returns: Filtered array of AudioProcess instances
    func filterByAudioActive(_ audioActive: Bool) -> [AudioProcess] {
        return self.filter { $0.audioActive == audioActive }
    }
    
    /// Groups processes by kind
    /// - Returns: Dictionary mapping AudioProcess.Kind to arrays of processes
    func groupedByKind() -> [AudioProcess.Kind: [AudioProcess]] {
        return Dictionary(grouping: self) { $0.kind }
    }
    
    /// Sorts processes by name
    /// - Returns: Array sorted by process name
    func sortedByName() -> [AudioProcess] {
        return self.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}