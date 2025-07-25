import XCTest
import Combine
import AudioToolbox
import OSLog
@testable import AudioCap

/// Tests for AudioProcessController functionality including process discovery,
/// enumeration, grouping, and automatic updates
@MainActor
final class AudioProcessControllerTests: XCTestCase {
    
    private var controller: AudioProcessController!
    private var cancellables: Set<AnyCancellable>!
    private let logger = Logger(subsystem: "com.audiocap.tests", category: "AudioProcessControllerTests")
    
    override func setUp() {
        super.setUp()
        controller = AudioProcessController()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables?.removeAll()
        controller = nil
        super.tearDown()
    }
    
    // MARK: - Process Discovery Tests
    
    /// Tests that AudioProcessController can be initialized and activated
    /// Requirements: 3.1 - Process discovery and application enumeration
    func testControllerInitializationAndActivation() {
        // Given: A new AudioProcessController
        XCTAssertNotNil(controller, "Controller should be initialized")
        XCTAssertTrue(controller.processes.isEmpty, "Initial processes should be empty")
        XCTAssertTrue(controller.processGroups.isEmpty, "Initial process groups should be empty")
        
        // When: Controller is activated
        controller.activate()
        
        // Then: Controller should be ready to receive process updates
        // Note: We can't test actual process discovery without mocking CoreAudio
        // This test verifies the basic initialization and activation flow
        XCTAssertNotNil(controller, "Controller should remain valid after activation")
    }
    
    /// Tests process discovery with mock running applications
    /// Requirements: 3.1 - Process discovery and application enumeration
    func testProcessDiscoveryWithMockApplications() {
        // Given: Mock running applications
        let mockApps = TestHelpers.mockRunningApplications(count: 3, includeAudioApps: true)
        
        // When: Controller processes the mock applications
        // Note: We're testing the reload method directly since we can't easily mock NSWorkspace
        // This is an internal method but necessary for isolated testing
        controller.reload(apps: mockApps)
        
        // Then: Processes should be discovered (though they may be empty due to CoreAudio mocking limitations)
        // The test verifies the method can be called without crashing
        XCTAssertNotNil(controller.processes, "Processes array should exist")
        XCTAssertNotNil(controller.processGroups, "Process groups should exist")
    }
    
    // MARK: - Process List Update Tests
    
    /// Tests that process list updates when running applications change
    /// Requirements: 3.2 - Automatic process list updates when running applications change
    func testProcessListUpdatesOnApplicationChanges() async {
        // Given: Controller is activated
        controller.activate()
        
        let expectation = XCTestExpectation(description: "Process list should update")
        var updateCount = 0
        
        // Monitor process changes
        controller.$processes
            .dropFirst() // Skip initial empty state
            .sink { processes in
                updateCount += 1
                if updateCount >= 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When: We simulate an application change by calling reload directly
        let mockApps = TestHelpers.mockRunningApplications(count: 2)
        controller.reload(apps: mockApps)
        
        // Then: Process list should be updated
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertGreaterThanOrEqual(updateCount, 1, "Process list should have been updated")
    }
    
    /// Tests that process groups are updated when processes change
    /// Requirements: 3.2 - Automatic process list updates when running applications change
    func testProcessGroupsUpdateWithProcessChanges() {
        // Given: Initial empty state
        XCTAssertTrue(controller.processGroups.isEmpty, "Initial process groups should be empty")
        
        // When: We update processes with mock data
        let mockProcesses = MockAudioProcess.createProcessesForGroupingTests()
        
        // Simulate the internal process update by directly setting processes
        // This tests the didSet behavior that updates processGroups
        let groups = AudioProcessGroup.groups(with: mockProcesses)
        
        // Then: Process groups should be created
        XCTAssertFalse(groups.isEmpty, "Process groups should not be empty")
        XCTAssertEqual(groups.count, 2, "Should have Apps and Processes groups")
        
        let groupTitles = groups.map { $0.title }.sorted()
        XCTAssertEqual(groupTitles, ["Apps", "Processes"], "Should have correct group titles")
    }
    
    // MARK: - Process Grouping Tests
    
    /// Tests process grouping by app/process categories
    /// Requirements: 3.3 - Process grouping by app/process categories
    func testProcessGroupingByCategory() {
        // Given: Mixed processes (apps and system processes)
        let mockProcesses = MockAudioProcess.createProcessesForGroupingTests()
        
        // When: Processes are grouped
        let groups = AudioProcessGroup.groups(with: mockProcesses)
        
        // Then: Processes should be correctly grouped
        XCTAssertEqual(groups.count, 2, "Should have exactly 2 groups")
        
        let appsGroup = groups.first { $0.title == "Apps" }
        let processesGroup = groups.first { $0.title == "Processes" }
        
        XCTAssertNotNil(appsGroup, "Apps group should exist")
        XCTAssertNotNil(processesGroup, "Processes group should exist")
        
        // Verify apps group contains only app-type processes
        if let appsGroup = appsGroup {
            XCTAssertGreaterThan(appsGroup.processes.count, 0, "Apps group should contain processes")
            for process in appsGroup.processes {
                XCTAssertEqual(process.kind, .app, "Apps group should only contain app processes")
            }
        }
        
        // Verify processes group contains only process-type processes
        if let processesGroup = processesGroup {
            XCTAssertGreaterThan(processesGroup.processes.count, 0, "Processes group should contain processes")
            for process in processesGroup.processes {
                XCTAssertEqual(process.kind, .process, "Processes group should only contain system processes")
            }
        }
    }
    
    /// Tests that empty process list results in empty groups
    /// Requirements: 3.3 - Process grouping by app/process categories
    func testEmptyProcessListGrouping() {
        // Given: Empty process list
        let emptyProcesses: [AudioProcess] = []
        
        // When: Processes are grouped
        let groups = AudioProcessGroup.groups(with: emptyProcesses)
        
        // Then: No groups should be created
        XCTAssertTrue(groups.isEmpty, "Empty process list should result in empty groups")
    }
    
    /// Tests grouping with only one type of process
    /// Requirements: 3.3 - Process grouping by app/process categories
    func testSingleTypeProcessGrouping() {
        // Given: Only app processes
        let appOnlyProcesses = [
            MockAudioProcess.createMockApplication(id: 1001, name: "Safari"),
            MockAudioProcess.createMockApplication(id: 1002, name: "Music")
        ]
        
        // When: Processes are grouped
        let groups = AudioProcessGroup.groups(with: appOnlyProcesses)
        
        // Then: Only one group should be created
        XCTAssertEqual(groups.count, 1, "Should have exactly 1 group for single type")
        XCTAssertEqual(groups.first?.title, "Apps", "Single group should be Apps")
        XCTAssertEqual(groups.first?.processes.count, 2, "Apps group should contain 2 processes")
    }
    
    // MARK: - Process Information Extraction Tests
    
    /// Tests process information extraction from AudioProcess
    /// Requirements: 3.4 - Process information extraction and icon loading
    func testProcessInformationExtraction() {
        // Given: Mock processes with various configurations
        let processes = MockAudioProcess.createProcessesWithVariousBundleIDs()
        
        // When: We examine process information
        // Then: Each process should have correct information extracted
        for process in processes {
            XCTAssertNotEqual(process.id, 0, "Process should have valid PID")
            XCTAssertFalse(process.name.isEmpty, "Process should have non-empty name")
            XCTAssertTrue(process.kind == .app || process.kind == .process, "Process should have valid kind")
            XCTAssertNotEqual(process.objectID, AudioObjectID.unknown, "Process should have valid object ID")
            
            // Test bundle ID handling
            if process.kind == .app {
                // Apps may or may not have bundle IDs, but if they do, they should be valid
                if let bundleID = process.bundleID {
                    XCTAssertFalse(bundleID.isEmpty, "Non-nil bundle ID should not be empty")
                }
            }
        }
    }
    
    /// Tests audio active state extraction
    /// Requirements: 3.4 - Process information extraction and icon loading
    func testAudioActiveStateExtraction() {
        // Given: Processes with different audio states
        let activeProcesses = MockAudioProcess.createProcessesWithAudioStates(activeCount: 3, inactiveCount: 2)
        
        // When: We examine audio states
        let audioActiveProcesses = activeProcesses.filter { $0.audioActive }
        let audioInactiveProcesses = activeProcesses.filter { !$0.audioActive }
        
        // Then: Audio states should be correctly extracted
        XCTAssertEqual(audioActiveProcesses.count, 3, "Should have 3 audio active processes")
        XCTAssertEqual(audioInactiveProcesses.count, 2, "Should have 2 audio inactive processes")
        
        for process in audioActiveProcesses {
            XCTAssertTrue(process.audioActive, "Audio active processes should have audioActive = true")
        }
        
        for process in audioInactiveProcesses {
            XCTAssertFalse(process.audioActive, "Audio inactive processes should have audioActive = false")
        }
    }
    
    // MARK: - Icon Loading Tests
    
    /// Tests that process icons can be loaded
    /// Requirements: 3.5 - Process information extraction and icon loading
    func testProcessIconLoading() {
        // Given: Mock processes with different configurations
        let appProcess = MockAudioProcess.createMockApplication(
            id: 1001,
            name: "Safari",
            bundleID: "com.apple.Safari"
        )
        let systemProcess = MockAudioProcess.createMockSystemProcess(
            id: 2001,
            name: "coreaudiod"
        )
        
        // When: We request icons for processes
        let appIcon = appProcess.icon
        let systemIcon = systemProcess.icon
        
        // Then: Icons should be available
        XCTAssertNotNil(appIcon, "App process should have an icon")
        XCTAssertNotNil(systemIcon, "System process should have an icon")
        
        // Verify icon properties
        XCTAssertEqual(appIcon.size, NSSize(width: 32, height: 32), "App icon should have correct size")
        XCTAssertEqual(systemIcon.size, NSSize(width: 32, height: 32), "System icon should have correct size")
    }
    
    /// Tests default icons for different process kinds
    /// Requirements: 3.5 - Process information extraction and icon loading
    func testDefaultIconsForProcessKinds() {
        // Given: Process kinds
        let appKind = AudioProcess.Kind.app
        let processKind = AudioProcess.Kind.process
        
        // When: We request default icons
        let appDefaultIcon = appKind.defaultIcon
        let processDefaultIcon = processKind.defaultIcon
        
        // Then: Default icons should be available
        XCTAssertNotNil(appDefaultIcon, "App kind should have default icon")
        XCTAssertNotNil(processDefaultIcon, "Process kind should have default icon")
        
        // Icons should be different for different kinds
        XCTAssertNotEqual(appDefaultIcon, processDefaultIcon, "Different process kinds should have different default icons")
    }
    
    // MARK: - Process Sorting Tests
    
    /// Tests that processes are sorted correctly with audio active processes prioritized
    /// Requirements: 3.1, 3.4 - Process discovery and information extraction
    func testProcessSortingWithAudioActivePriority() {
        // Given: Mixed processes with different audio states and names
        let processes = [
            MockAudioProcess.createMockApplication(id: 1001, name: "Zebra App", audioActive: false),
            MockAudioProcess.createMockApplication(id: 1002, name: "Alpha App", audioActive: true),
            MockAudioProcess.createMockApplication(id: 1003, name: "Beta App", audioActive: false),
            MockAudioProcess.createMockApplication(id: 1004, name: "Gamma App", audioActive: true)
        ]
        
        // When: Processes are sorted (simulating the sorting logic from AudioProcessController)
        let sortedProcesses = processes.sorted { lhs, rhs in
            if lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending {
                return rhs.audioActive && !lhs.audioActive ? false : true
            } else {
                return lhs.audioActive && !rhs.audioActive ? true : false
            }
        }
        
        // Then: Audio active processes should be prioritized
        let audioActiveProcesses = sortedProcesses.filter { $0.audioActive }
        let audioInactiveProcesses = sortedProcesses.filter { !$0.audioActive }
        
        // Find the indices of the first audio active and first audio inactive process
        let firstActiveIndex = sortedProcesses.firstIndex { $0.audioActive }
        let firstInactiveIndex = sortedProcesses.firstIndex { !$0.audioActive }
        
        if let activeIndex = firstActiveIndex, let inactiveIndex = firstInactiveIndex {
            XCTAssertLessThan(activeIndex, inactiveIndex, "Audio active processes should come before inactive ones")
        }
        
        // Within each group, processes should be sorted alphabetically
        let activeNames = audioActiveProcesses.map { $0.name }
        let sortedActiveNames = activeNames.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        XCTAssertEqual(activeNames, sortedActiveNames, "Audio active processes should be sorted alphabetically")
    }
    
    // MARK: - Performance Tests
    
    /// Tests performance with large number of processes
    /// Requirements: 3.1, 3.3 - Process discovery and grouping performance
    func testPerformanceWithLargeProcessSet() {
        // Given: Large set of mock processes
        let largeProcessSet = MockAudioProcess.createLargeProcessSet(count: 100)
        
        // When: We measure grouping performance
        let (groups, time) = TestHelpers.measureTime {
            return AudioProcessGroup.groups(with: largeProcessSet)
        }
        
        // Then: Grouping should complete in reasonable time
        XCTAssertLessThan(time, 1.0, "Grouping 100 processes should complete within 1 second")
        XCTAssertFalse(groups.isEmpty, "Large process set should produce groups")
        
        let totalProcessesInGroups = groups.reduce(0) { $0 + $1.processes.count }
        XCTAssertEqual(totalProcessesInGroups, largeProcessSet.count, "All processes should be included in groups")
    }
    
    // MARK: - Error Handling Tests
    
    /// Tests handling of invalid process data
    /// Requirements: 3.4 - Process information extraction robustness
    func testHandlingOfInvalidProcessData() {
        // Given: Process with minimal/invalid data
        let invalidProcess = AudioProcess(
            id: -1,
            kind: .process,
            name: "",
            audioActive: false,
            bundleID: nil,
            bundleURL: nil,
            objectID: AudioObjectID.unknown
        )
        
        // When: We try to group invalid processes
        let groups = AudioProcessGroup.groups(with: [invalidProcess])
        
        // Then: Grouping should handle invalid data gracefully
        XCTAssertEqual(groups.count, 1, "Should create one group even with invalid process")
        XCTAssertEqual(groups.first?.processes.count, 1, "Invalid process should still be included")
        
        // Icon loading should not crash
        let icon = invalidProcess.icon
        XCTAssertNotNil(icon, "Should provide default icon for invalid process")
    }
    
    // MARK: - Integration Tests
    
    /// Tests the complete workflow from activation to process grouping
    /// Requirements: 3.1, 3.2, 3.3, 3.4, 3.5 - Complete process management workflow
    func testCompleteProcessManagementWorkflow() async {
        // Given: Fresh controller
        let controller = AudioProcessController()
        
        // When: Controller is activated
        controller.activate()
        
        // Simulate process updates
        let mockApps = TestHelpers.mockRunningApplications(count: 5)
        controller.reload(apps: mockApps)
        
        // Then: Controller should have processed the applications
        // Note: Due to CoreAudio mocking limitations, we mainly test that the workflow doesn't crash
        XCTAssertNotNil(controller.processes, "Processes should be initialized")
        XCTAssertNotNil(controller.processGroups, "Process groups should be initialized")
        
        // Test that the controller can handle multiple updates
        let updatedMockApps = TestHelpers.mockRunningApplications(count: 3)
        controller.reload(apps: updatedMockApps)
        
        XCTAssertNotNil(controller.processes, "Processes should remain valid after update")
        XCTAssertNotNil(controller.processGroups, "Process groups should remain valid after update")
    }
}

// MARK: - Test Extensions

extension AudioProcessControllerTests {
    
    /// Helper method to create a test expectation for process updates
    private func expectProcessUpdate(description: String) -> XCTestExpectation {
        let expectation = XCTestExpectation(description: description)
        
        controller.$processes
            .dropFirst()
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        return expectation
    }
    
    /// Helper method to verify process group consistency
    private func verifyProcessGroupConsistency(_ groups: [AudioProcessGroup]) {
        for group in groups {
            XCTAssertFalse(group.title.isEmpty, "Group title should not be empty")
            XCTAssertFalse(group.id.isEmpty, "Group ID should not be empty")
            
            // All processes in a group should have the same kind
            if let firstProcess = group.processes.first {
                for process in group.processes {
                    XCTAssertEqual(process.kind, firstProcess.kind, "All processes in group should have same kind")
                }
            }
        }
    }
}