import XCTest
import Foundation
import OSLog
import Darwin.Mach
@testable import AudioCap

/// Tests for concurrent access scenarios between GUI and API interfaces
/// Validates thread safety, state synchronization, and resource management
final class ConcurrentAccessTests: BaseIntegrationTestCase {
    
    private let logger = Logger(subsystem: "com.audiocap.tests", category: "ConcurrentAccessTests")
    
    // Test components
    private var processController: AudioProcessController!
    private var processAPIHandler: ProcessAPIHandler!
    private var recordingAPIHandler: RecordingAPIHandler!
    private var httpServerManager: HTTPServerManager!
    
    // Mock GUI components for testing
    private var mockGUIRecordingController: MockGUIRecordingController!
    
    // Test configuration
    private let concurrentClientCount = 5
    private let testTimeout: TimeInterval = 30.0
    
    override func customSetUp() {
        super.customSetUp()
        
        // Set up process controller
        processController = AudioProcessController()
        
        // Set up API handlers
        processAPIHandler = ProcessAPIHandler(processController: processController)
        recordingAPIHandler = RecordingAPIHandler(processController: processController)
        
        // Set up HTTP server manager
        httpServerManager = HTTPServerManager()
        
        // Set up mock GUI controller
        mockGUIRecordingController = MockGUIRecordingController(processController: processController)
        
        logger.info("ConcurrentAccessTests setup completed")
    }
    
    override func customTearDown() {
        // Stop any running servers
        Task {
            await httpServerManager.stop()
        }
        
        // Clean up mock GUI controller
        mockGUIRecordingController.cleanup()
        
        logger.info("ConcurrentAccessTests teardown completed")
        super.customTearDown()
    }
    
    // MARK: - Simultaneous GUI and API Usage Tests
    
    /// Test simultaneous process listing from GUI and API
    /// Requirements: 6.1 - New recording features added to GUI are also exposed via REST API
    func testSimultaneousProcessListing() async throws {
        // Given: Process controller is activated
        await processController.activate()
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // When: Simultaneously accessing process list from GUI and API
        async let guiProcesses = mockGUIRecordingController.getProcessList()
        async let apiProcesses = processAPIHandler.handleProcessList()
        
        let (guiResult, apiResult) = try await (guiProcesses, apiProcesses)
        
        // Then: Both should return consistent data
        XCTAssertEqual(guiResult.count, apiResult.processes.count, "GUI and API should return same number of processes")
        
        // Verify process data consistency
        for apiProcess in apiResult.processes {
            let matchingGUIProcess = guiResult.first { $0.id == Int32(apiProcess.id) }
            XCTAssertNotNil(matchingGUIProcess, "API process \(apiProcess.id) should exist in GUI list")
            
            if let guiProcess = matchingGUIProcess {
                XCTAssertEqual(guiProcess.name, apiProcess.name, "Process names should match")
                XCTAssertEqual(guiProcess.audioActive, apiProcess.hasAudioCapability, "Audio capability should match")
            }
        }
        
        logger.info("Simultaneous process listing test passed with \(apiResult.processes.count) processes")
    }
    
    /// Test GUI and API recording state synchronization
    /// Requirements: 6.2 - Underlying recording engine is modified, both GUI and API have access to same functionality
    func testGUIAPIRecordingStateSynchronization() async throws {
        // Given: Process controller is activated and has processes
        await processController.activate()
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        guard let testProcess = processController.processes.first(where: { $0.audioActive }) else {
            throw XCTSkip("No audio-active processes available for testing")
        }
        
        // Test 1: Start recording via API, check GUI state
        let startRequest = StartRecordingRequest(processId: String(testProcess.id), outputFormat: nil)
        let recordingSession = try await recordingAPIHandler.handleStartRecording(request: startRequest)
        
        // Verify GUI sees the recording state
        let guiRecordingState = await mockGUIRecordingController.getCurrentRecordingState()
        XCTAssertTrue(guiRecordingState.isRecording, "GUI should detect API-started recording")
        XCTAssertEqual(guiRecordingState.processId, testProcess.id, "GUI should show correct recording process")
        
        // Test 2: Check API status reflects the recording
        let apiStatus = try await recordingAPIHandler.handleRecordingStatus()
        XCTAssertEqual(apiStatus.status, .recording, "API should show recording status")
        XCTAssertEqual(apiStatus.currentSession?.sessionId, recordingSession.sessionId, "API should show correct session")
        
        // Test 3: Stop recording via API, verify GUI state updates
        let recordingMetadata = try await recordingAPIHandler.handleStopRecording()
        
        let updatedGUIState = await mockGUIRecordingController.getCurrentRecordingState()
        XCTAssertFalse(updatedGUIState.isRecording, "GUI should detect recording stopped")
        
        // Verify metadata consistency
        XCTAssertEqual(recordingMetadata.sessionId, recordingSession.sessionId, "Session IDs should match")
        XCTAssertGreaterThan(recordingMetadata.duration, 0, "Recording should have positive duration")
        
        logger.info("GUI-API recording state synchronization test passed")
    }
    
    /// Test resource conflict prevention between GUI and API
    /// Requirements: 6.5 - No resource conflicts between GUI and API
    func testResourceConflictPrevention() async throws {
        // Given: Process controller is activated
        await processController.activate()
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        guard let testProcess = processController.processes.first(where: { $0.audioActive }) else {
            throw XCTSkip("No audio-active processes available for testing")
        }
        
        // Test 1: Start recording via GUI
        try await mockGUIRecordingController.startRecording(processId: testProcess.id)
        
        // Test 2: Attempt to start recording via API (should fail)
        let apiStartRequest = StartRecordingRequest(processId: String(testProcess.id), outputFormat: nil)
        
        do {
            _ = try await recordingAPIHandler.handleStartRecording(request: apiStartRequest)
            XCTFail("API should not allow starting recording when GUI is already recording")
        } catch let error as RecordingAPIError {
            XCTAssertEqual(error, .alreadyRecording, "Should get already recording error")
        }
        
        // Test 3: Stop recording via GUI
        try await mockGUIRecordingController.stopRecording()
        
        // Test 4: Now API should be able to start recording
        let apiSession = try await recordingAPIHandler.handleStartRecording(request: apiStartRequest)
        XCTAssertNotNil(apiSession, "API should be able to start recording after GUI stops")
        
        // Clean up
        _ = try await recordingAPIHandler.handleStopRecording()
        
        logger.info("Resource conflict prevention test passed")
    }
    
    // MARK: - Multiple Concurrent API Clients Tests
    
    /// Test multiple concurrent API clients accessing process list
    /// Requirements: 6.3 - Multiple concurrent API clients
    func testConcurrentProcessListAccess() async throws {
        // Given: Process controller is activated
        await processController.activate()
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // When: Multiple clients simultaneously request process list
        let tasks = (0..<concurrentClientCount).map { clientId in
            Task {
                let startTime = Date()
                let result = try await processAPIHandler.handleProcessList()
                let duration = Date().timeIntervalSince(startTime)
                return (clientId: clientId, result: result, duration: duration)
            }
        }
        
        // Wait for all tasks to complete
        var results: [(clientId: Int, result: ProcessListResponse, duration: TimeInterval)] = []
        for task in tasks {
            let result = try await task.value
            results.append(result)
        }
        
        // Then: All clients should get consistent results
        XCTAssertEqual(results.count, concurrentClientCount, "All clients should complete")
        
        let firstResult = results[0].result
        for (index, result) in results.enumerated() {
            XCTAssertEqual(result.result.processes.count, firstResult.processes.count, 
                          "Client \(index) should get same process count")
            
            // Verify response times are reasonable (under 5 seconds)
            XCTAssertLessThan(result.duration, 5.0, "Client \(index) response time should be reasonable")
        }
        
        // Verify process data consistency across all responses
        for i in 1..<results.count {
            let currentProcesses = results[i].result.processes.sorted { $0.id < $1.id }
            let firstProcesses = firstResult.processes.sorted { $0.id < $1.id }
            
            XCTAssertEqual(currentProcesses.count, firstProcesses.count, "Process counts should match")
            
            for (current, first) in zip(currentProcesses, firstProcesses) {
                XCTAssertEqual(current.id, first.id, "Process IDs should match")
                XCTAssertEqual(current.name, first.name, "Process names should match")
            }
        }
        
        logger.info("Concurrent process list access test passed with \(concurrentClientCount) clients")
    }
    
    /// Test concurrent recording status queries
    /// Requirements: 6.3 - Multiple concurrent API clients
    func testConcurrentRecordingStatusQueries() async throws {
        // Given: A recording is in progress
        await processController.activate()
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        guard let testProcess = processController.processes.first(where: { $0.audioActive }) else {
            throw XCTSkip("No audio-active processes available for testing")
        }
        
        let startRequest = StartRecordingRequest(processId: String(testProcess.id), outputFormat: nil)
        let recordingSession = try await recordingAPIHandler.handleStartRecording(request: startRequest)
        
        // When: Multiple clients simultaneously query recording status
        let statusTasks = (0..<concurrentClientCount).map { clientId in
            Task {
                let startTime = Date()
                let status = try await recordingAPIHandler.handleRecordingStatus()
                let duration = Date().timeIntervalSince(startTime)
                return (clientId: clientId, status: status, duration: duration)
            }
        }
        
        // Wait for all status queries to complete
        var statusResults: [(clientId: Int, status: RecordingStatusResponse, duration: TimeInterval)] = []
        for task in statusTasks {
            let result = try await task.value
            statusResults.append(result)
        }
        
        // Then: All clients should get consistent status
        XCTAssertEqual(statusResults.count, concurrentClientCount, "All status queries should complete")
        
        for (index, result) in statusResults.enumerated() {
            XCTAssertEqual(result.status.status, .recording, "Client \(index) should see recording status")
            XCTAssertEqual(result.status.currentSession?.sessionId, recordingSession.sessionId, 
                          "Client \(index) should see correct session ID")
            XCTAssertNotNil(result.status.elapsedTime, "Client \(index) should get elapsed time")
            XCTAssertGreaterThanOrEqual(result.status.elapsedTime!, 0, "Elapsed time should be non-negative")
            
            // Verify response times are reasonable
            XCTAssertLessThan(result.duration, 2.0, "Client \(index) status query should be fast")
        }
        
        // Clean up
        _ = try await recordingAPIHandler.handleStopRecording()
        
        logger.info("Concurrent recording status queries test passed with \(concurrentClientCount) clients")
    }
    
    /// Test concurrent recording operations (should be properly serialized)
    /// Requirements: 6.4 - Thread safety of shared recording engine
    func testConcurrentRecordingOperations() async throws {
        // Given: Process controller is activated
        await processController.activate()
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        guard let testProcess = processController.processes.first(where: { $0.audioActive }) else {
            throw XCTSkip("No audio-active processes available for testing")
        }
        
        let startRequest = StartRecordingRequest(processId: String(testProcess.id), outputFormat: nil)
        
        // When: Multiple clients try to start recording simultaneously
        let startTasks = (0..<concurrentClientCount).map { clientId in
            Task {
                do {
                    let session = try await recordingAPIHandler.handleStartRecording(request: startRequest)
                    return (clientId: clientId, success: true, session: session, error: nil)
                } catch {
                    return (clientId: clientId, success: false, session: nil, error: error)
                }
            }
        }
        
        // Wait for all start attempts to complete
        var startResults: [(clientId: Int, success: Bool, session: RecordingSession?, error: Error?)] = []
        for task in startTasks {
            let result = await task.value
            startResults.append(result)
        }
        
        // Then: Only one client should succeed, others should get "already recording" error
        let successfulStarts = startResults.filter { $0.success }
        let failedStarts = startResults.filter { !$0.success }
        
        XCTAssertEqual(successfulStarts.count, 1, "Only one client should successfully start recording")
        XCTAssertEqual(failedStarts.count, concurrentClientCount - 1, "Other clients should fail")
        
        // Verify failed attempts got the correct error
        for failedResult in failedStarts {
            XCTAssertNotNil(failedResult.error, "Failed attempts should have error")
            if let recordingError = failedResult.error as? RecordingAPIError {
                XCTAssertEqual(recordingError, .alreadyRecording, "Should get already recording error")
            }
        }
        
        // Test concurrent stop attempts
        let stopTasks = (0..<concurrentClientCount).map { clientId in
            Task {
                do {
                    let metadata = try await recordingAPIHandler.handleStopRecording()
                    return (clientId: clientId, success: true, metadata: metadata, error: nil)
                } catch {
                    return (clientId: clientId, success: false, metadata: nil, error: error)
                }
            }
        }
        
        // Wait for all stop attempts to complete
        var stopResults: [(clientId: Int, success: Bool, metadata: RecordingMetadata?, error: Error?)] = []
        for task in stopTasks {
            let result = await task.value
            stopResults.append(result)
        }
        
        // Only one client should succeed in stopping
        let successfulStops = stopResults.filter { $0.success }
        let failedStops = stopResults.filter { !$0.success }
        
        XCTAssertEqual(successfulStops.count, 1, "Only one client should successfully stop recording")
        XCTAssertEqual(failedStops.count, concurrentClientCount - 1, "Other clients should fail to stop")
        
        // Verify failed stop attempts got the correct error
        for failedResult in failedStops {
            XCTAssertNotNil(failedResult.error, "Failed stop attempts should have error")
            if let recordingError = failedResult.error as? RecordingAPIError {
                XCTAssertEqual(recordingError, .notRecording, "Should get not recording error")
            }
        }
        
        logger.info("Concurrent recording operations test passed - proper serialization verified")
    }
    
    // MARK: - Thread Safety Tests
    
    /// Test thread safety of shared recording engine under concurrent access
    /// Requirements: 6.4 - Thread safety of shared recording engine
    func testSharedRecordingEngineThreadSafety() async throws {
        // Given: Process controller is activated
        await processController.activate()
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        guard let testProcess = processController.processes.first(where: { $0.audioActive }) else {
            throw XCTSkip("No audio-active processes available for testing")
        }
        
        // Test concurrent access to process controller
        let processAccessTasks = (0..<concurrentClientCount).map { clientId in
            Task {
                // Simulate various operations that might be performed concurrently
                let processes1 = processController.processes
                await processController.activate() // Should be safe to call multiple times
                let processes2 = processController.processes
                
                return (clientId: clientId, processCount1: processes1.count, processCount2: processes2.count)
            }
        }
        
        // Wait for all process access tasks
        var processAccessResults: [(clientId: Int, processCount1: Int, processCount2: Int)] = []
        for task in processAccessTasks {
            let result = await task.value
            processAccessResults.append(result)
        }
        
        // Verify consistent results across all concurrent accesses
        let firstResult = processAccessResults[0]
        for result in processAccessResults {
            XCTAssertEqual(result.processCount1, firstResult.processCount1, 
                          "Process count should be consistent across concurrent accesses")
            XCTAssertEqual(result.processCount2, firstResult.processCount2, 
                          "Process count should remain consistent after reactivation")
        }
        
        // Test concurrent recording state checks
        let stateCheckTasks = (0..<concurrentClientCount).map { clientId in
            Task {
                let status1 = try await recordingAPIHandler.handleRecordingStatus()
                let status2 = try await recordingAPIHandler.handleRecordingStatus()
                
                return (clientId: clientId, status1: status1, status2: status2)
            }
        }
        
        // Wait for all state check tasks
        var stateCheckResults: [(clientId: Int, status1: RecordingStatusResponse, status2: RecordingStatusResponse)] = []
        for task in stateCheckTasks {
            let result = try await task.value
            stateCheckResults.append(result)
        }
        
        // Verify consistent state across all concurrent checks
        for result in stateCheckResults {
            XCTAssertEqual(result.status1.status, result.status2.status, 
                          "Recording status should be consistent within same client")
            XCTAssertEqual(result.status1.status, .idle, "Should be idle initially")
        }
        
        logger.info("Shared recording engine thread safety test passed")
    }
    
    /// Test memory management under concurrent access
    /// Requirements: 6.4 - Thread safety of shared recording engine
    func testMemoryManagementUnderConcurrentAccess() async throws {
        // Given: Process controller is activated
        await processController.activate()
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Measure initial memory usage
        let initialMemory = getMemoryUsage()
        
        // Create many concurrent tasks that create and release objects
        let memoryStressTasks = (0..<concurrentClientCount * 2).map { clientId in
            Task {
                // Create multiple API handlers to stress memory management
                let processHandler = ProcessAPIHandler(processController: processController)
                let recordingHandler = RecordingAPIHandler(processController: processController)
                
                // Perform operations that allocate memory
                let processList = try await processHandler.handleProcessList()
                let status = try await recordingHandler.handleRecordingStatus()
                
                return (clientId: clientId, processCount: processList.processes.count, status: status.status)
            }
        }
        
        // Wait for all memory stress tasks
        var memoryResults: [(clientId: Int, processCount: Int, status: RecordingStatus)] = []
        for task in memoryStressTasks {
            let result = try await task.value
            memoryResults.append(result)
        }
        
        // Allow some time for cleanup
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Measure final memory usage
        let finalMemory = getMemoryUsage()
        
        // Verify no significant memory leaks (allow for some variance)
        let memoryIncrease = finalMemory - initialMemory
        let maxAllowedIncrease = initialMemory * 0.5 // Allow 50% increase
        
        XCTAssertLessThan(memoryIncrease, maxAllowedIncrease, 
                         "Memory usage should not increase significantly under concurrent access")
        
        // Verify all tasks completed successfully
        XCTAssertEqual(memoryResults.count, concurrentClientCount * 2, "All memory stress tasks should complete")
        
        for result in memoryResults {
            XCTAssertGreaterThanOrEqual(result.processCount, 0, "Process count should be valid")
            XCTAssertEqual(result.status, .idle, "Status should be idle")
        }
        
        logger.info("Memory management under concurrent access test passed")
    }
    
    // MARK: - Helper Methods
    
    /// Get current memory usage in bytes
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            return 0
        }
    }
}

// MARK: - Mock GUI Recording Controller

/// Mock GUI recording controller for testing GUI-API interactions
@MainActor
private class MockGUIRecordingController {
    private let processController: AudioProcessController
    private var currentRecordingProcess: AudioProcess?
    private var isRecording = false
    private let logger = Logger(subsystem: "com.audiocap.tests", category: "MockGUIRecordingController")
    
    init(processController: AudioProcessController) {
        self.processController = processController
    }
    
    func getProcessList() async -> [AudioProcess] {
        return processController.processes
    }
    
    func startRecording(processId: pid_t) async throws {
        guard !isRecording else {
            throw NSError(domain: "MockGUIError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Already recording"])
        }
        
        guard let process = processController.processes.first(where: { $0.id == processId }) else {
            throw NSError(domain: "MockGUIError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Process not found"])
        }
        
        currentRecordingProcess = process
        isRecording = true
        logger.info("Mock GUI started recording process \(process.name)")
    }
    
    func stopRecording() async throws {
        guard isRecording else {
            throw NSError(domain: "MockGUIError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Not recording"])
        }
        
        isRecording = false
        currentRecordingProcess = nil
        logger.info("Mock GUI stopped recording")
    }
    
    func getCurrentRecordingState() async -> (isRecording: Bool, processId: pid_t?) {
        return (isRecording: isRecording, processId: currentRecordingProcess?.id)
    }
    
    func cleanup() {
        isRecording = false
        currentRecordingProcess = nil
    }
}

// MARK: - Test Extensions

extension RecordingAPIError: Equatable {
    public static func == (lhs: RecordingAPIError, rhs: RecordingAPIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidProcessId(let lhsId), .invalidProcessId(let rhsId)):
            return lhsId == rhsId
        case (.processNotFound(let lhsId), .processNotFound(let rhsId)):
            return lhsId == rhsId
        case (.processHasNoAudio(let lhsId, let lhsName), .processHasNoAudio(let rhsId, let rhsName)):
            return lhsId == rhsId && lhsName == rhsName
        case (.alreadyRecording, .alreadyRecording):
            return true
        case (.notRecording, .notRecording):
            return true
        case (.recordingStartFailed(let lhsMsg), .recordingStartFailed(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.recordingStopFailed(let lhsMsg), .recordingStopFailed(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.permissionDenied, .permissionDenied):
            return true
        case (.fileSystemError(let lhsMsg), .fileSystemError(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.invalidRecordingState(let lhsMsg), .invalidRecordingState(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.internalError(let lhsMsg), .internalError(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}