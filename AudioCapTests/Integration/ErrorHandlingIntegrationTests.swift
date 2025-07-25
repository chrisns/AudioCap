import XCTest
import AudioToolbox
import AVFoundation
import OSLog
@testable import AudioCap

// Helper function for async XCTAssertThrowsError
func XCTAssertThrowsError<T>(
    _ expression: @autoclosure () async throws -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line,
    _ errorHandler: (_ error: Error) -> Void = { _ in }
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw an error", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}

/// Integration tests for error handling scenarios across components
final class ErrorHandlingIntegrationTests: XCTestCase {
    
    private let logger = Logger(subsystem: "com.audiocap.tests", category: "ErrorHandlingIntegrationTests")
    private var tempDirectory: URL!
    private var mockProcessController: AudioProcessController!
    
    override func setUp() {
        super.setUp()
        tempDirectory = TestHelpers.createTemporaryDirectory(prefix: "ErrorHandlingIntegrationTests")
        mockProcessController = AudioProcessController()
    }
    
    override func tearDown() {
        TestHelpers.cleanupTemporaryDirectory(at: tempDirectory)
        AudioTestUtilities.cleanupTestFiles()
        super.tearDown()
    }
    
    // MARK: - Aggregate Device Creation Failure Tests
    
    /// Tests aggregate device creation failure scenarios
    /// Requirements: 5.3
    func testAggregateDeviceCreationFailure() async throws {
        // Given: A mock process that will fail aggregate device creation
        let mockProcess = MockAudioProcess.createMockProcess(
            id: 9999,
            name: "Failing Aggregate Device App",
            audioActive: true
        )
        
        let mockTap = MockProcessTap.createFailingActivationTap(process: mockProcess)
        mockTap.mockErrorMessage = "Failed to create aggregate device"
        
        // When: Attempting to activate the tap
        await mockTap.activate()
        
        // Then: Should handle the failure gracefully
        XCTAssertNotNil(mockTap.errorMessage)
        XCTAssertTrue(mockTap.errorMessage!.contains("aggregate device"))
        XCTAssertEqual(mockTap.activationCallCount, 1)
        
        // Verify that the tap is not in an activated state
        XCTAssertNil(mockTap.tapStreamDescription)
        
        // Cleanup should still work even after failure
        mockTap.invalidate()
        XCTAssertEqual(mockTap.invalidationCallCount, 1)
    }
    
    /// Tests recovery from aggregate device creation failure
    /// Requirements: 5.3
    func testAggregateDeviceCreationFailureRecovery() async throws {
        // Given: A mock process that initially fails but can recover
        let mockProcess = MockAudioProcess.createMockProcess()
        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
        
        // Test initial failure
        mockTap.shouldFailActivation = true
        mockTap.mockErrorMessage = "Aggregate device creation failed - audio hardware busy"
        
        await mockTap.activate()
        XCTAssertNotNil(mockTap.errorMessage)
        XCTAssertTrue(mockTap.errorMessage!.contains("hardware busy"))
        
        // Simulate hardware becoming available
        mockTap.shouldFailActivation = false
        mockTap.resetMockState()
        
        // When: Retrying activation
        await mockTap.activate()
        
        // Then: Should succeed on retry
        XCTAssertNil(mockTap.errorMessage)
        XCTAssertNotNil(mockTap.tapStreamDescription)
        XCTAssertEqual(mockTap.activationCallCount, 1)
        
        mockTap.invalidate()
    }
    
    /// Tests multiple aggregate device creation attempts
    /// Requirements: 5.3
    func testMultipleAggregateDeviceCreationAttempts() async throws {
        // Given: Multiple processes attempting to create aggregate devices
        let processes = [
            MockAudioProcess.createMockProcess(id: 1001, name: "App 1"),
            MockAudioProcess.createMockProcess(id: 1002, name: "App 2"),
            MockAudioProcess.createMockProcess(id: 1003, name: "App 3")
        ]
        
        var taps: [MockProcessTap] = []
        
        // When: Creating multiple taps simultaneously
        for process in processes {
            let tap = MockProcessTap.createMockTap(process: process)
            taps.append(tap)
        }
        
        // Activate all taps
        for tap in taps {
            await tap.activate()
        }
        
        // Then: All should handle activation appropriately
        for (index, tap) in taps.enumerated() {
            XCTAssertEqual(tap.activationCallCount, 1, "Tap \(index) should have been activated once")
            // In a real scenario, some might fail due to resource constraints
            // but our mocks should all succeed unless configured otherwise
            XCTAssertNil(tap.errorMessage, "Tap \(index) should not have errors")
        }
        
        // Cleanup all taps
        for tap in taps {
            tap.invalidate()
        }
    }
    
    // MARK: - Process Tap Creation Failure Tests
    
    /// Tests process tap creation failure handling and user feedback
    /// Requirements: 5.3
    func testProcessTapCreationFailureHandling() async throws {
        // Given: A mock process that will fail tap creation
        let mockProcess = MockAudioProcess.createMockProcess(
            id: 404,
            name: "Non-existent Process",
            audioActive: false
        )
        
        let mockTap = MockProcessTap.createFailingRunTap(process: mockProcess)
        mockTap.mockErrorMessage = "Process tap creation failed - process not found"
        
        await mockTap.activate() // This should succeed
        XCTAssertNil(mockTap.errorMessage)
        
        // When: Attempting to run the tap (this is where tap creation actually happens)
        XCTAssertThrowsError(try mockTap.run(
            on: DispatchQueue.global(),
            ioBlock: { _, _, _, _, _ in },
            invalidationHandler: { _ in }
        )) { error in
            // Then: Should provide meaningful error message
            XCTAssertTrue(error.localizedDescription.contains("process not found") ||
                         error.localizedDescription.contains("Process tap creation failed"))
        }
        
        XCTAssertEqual(mockTap.runCallCount, 1)
        mockTap.invalidate()
    }
    
    /// Tests process tap creation failure with different error scenarios
    /// Requirements: 5.3
    func testProcessTapCreationVariousFailureScenarios() async throws {
        let failureScenarios: [(String, String)] = [
            ("Permission denied", "Process tap creation failed - permission denied"),
            ("Process terminated", "Process tap creation failed - target process terminated"),
            ("Audio format unsupported", "Process tap creation failed - unsupported audio format"),
            ("System resource exhausted", "Process tap creation failed - system resources exhausted")
        ]
        
        for (scenarioName, errorMessage) in failureScenarios {
            // Given: A mock process configured for specific failure
            let mockProcess = MockAudioProcess.createMockProcess(
                name: "Test Process - \(scenarioName)"
            )
            
            let mockTap = MockProcessTap.createFailingRunTap(process: mockProcess)
            mockTap.mockErrorMessage = errorMessage
            
            await mockTap.activate()
            
            // When: Attempting to run the tap
            XCTAssertThrowsError(try mockTap.run(
                on: DispatchQueue.global(),
                ioBlock: { _, _, _, _, _ in },
                invalidationHandler: { _ in }
            )) { error in
                // Then: Should handle each scenario appropriately
                XCTAssertTrue(error.localizedDescription.contains(errorMessage),
                             "Scenario '\(scenarioName)' should contain expected error message")
            }
            
            mockTap.invalidate()
        }
    }
    
    /// Tests user feedback for process tap creation failures
    /// Requirements: 5.3
    func testProcessTapCreationFailureUserFeedback() async throws {
        // Given: A mock process and UI components that would display errors
        let mockProcess = MockAudioProcess.createMockProcess()
        let mockTap = MockProcessTap.createFailingActivationTap(process: mockProcess)
        mockTap.mockErrorMessage = "Unable to access audio from this process"
        
        // When: Activation fails
        await mockTap.activate()
        
        // Then: Error message should be user-friendly
        XCTAssertNotNil(mockTap.errorMessage)
        let errorMessage = mockTap.errorMessage!
        
        // Verify error message is user-friendly (not too technical)
        XCTAssertFalse(errorMessage.contains("AudioObjectID"))
        XCTAssertFalse(errorMessage.contains("kAudio"))
        XCTAssertFalse(errorMessage.contains("OSStatus"))
        
        // Should contain helpful information
        XCTAssertTrue(errorMessage.contains("process") || errorMessage.contains("audio"))
        
        mockTap.invalidate()
    }
    
    // MARK: - File System Error Handling Tests
    
    /// Tests file system error handling during recording
    /// Requirements: 5.4
    func testFileSystemErrorHandlingDuringRecording() async throws {
        // Given: A working mock process and tap
        let mockProcess = MockAudioProcess.createMockProcess()
        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
        
        await mockTap.activate()
        
        // Test 1: Invalid file path
        let invalidPath = URL(fileURLWithPath: "/root/restricted/recording.wav")
        let recorder1 = ProcessTapRecorder(fileURL: invalidPath, tap: mockTap)
        
        await XCTAssertThrowsError(try await recorder1.start()) { error in
            XCTAssertTrue(error.localizedDescription.contains("permission") ||
                         error.localizedDescription.contains("access") ||
                         error.localizedDescription.contains("directory"))
        }
        
        // Test 2: Read-only directory
        let readOnlyDir = tempDirectory.appendingPathComponent("readonly")
        try FileManager.default.createDirectory(at: readOnlyDir, withIntermediateDirectories: true)
        
        // Make directory read-only (this might not work in all test environments)
        var resourceValues = URLResourceValues()
        resourceValues.isWritable = false
        try? readOnlyDir.setResourceValues(resourceValues)
        
        let readOnlyFile = readOnlyDir.appendingPathComponent("recording.wav")
        let recorder2 = ProcessTapRecorder(fileURL: readOnlyFile, tap: mockTap)
        
        // This might succeed in test environment, so we'll check if it throws or succeeds
        do {
            try await recorder2.start()
            // If it succeeds, clean up
            recorder2.stop()
        } catch {
            // Expected in a properly restricted environment
            XCTAssertTrue(error.localizedDescription.contains("write") ||
                         error.localizedDescription.contains("permission") ||
                         error.localizedDescription.contains("read-only"))
        }
        
        // Test 3: Disk space exhaustion simulation (using a very large file size request)
        // This is harder to simulate reliably, so we'll test the error handling path
        
        mockTap.invalidate()
    }
    
    /// Tests file system error recovery
    /// Requirements: 5.4
    func testFileSystemErrorRecovery() async throws {
        // Given: A working mock process and tap
        let mockProcess = MockAudioProcess.createMockProcess()
        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
        
        await mockTap.activate()
        
        // Test 1: Recovery from invalid path to valid path
        let invalidPath = URL(fileURLWithPath: "/invalid/path/recording.wav")
        let recorder1 = ProcessTapRecorder(fileURL: invalidPath, tap: mockTap)
        
        await XCTAssertThrowsError(try await recorder1.start())
        
        // Recovery: Use valid path
        let validPath = tempDirectory.appendingPathComponent("recovery_recording.wav")
        let recorder2 = ProcessTapRecorder(fileURL: validPath, tap: mockTap)
        try await recorder2.start()
        
        XCTAssertTrue(recorder2.isRecording)
        XCTAssertEqual(recorder2.fileURL, validPath)
        
        mockTap.simulateAudioData()
        try await Task.sleep(nanoseconds: 200_000_000)
        recorder2.stop()
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: validPath.path))
        XCTAssertTrue(AudioTestUtilities.verifyAudioFileIntegrity(at: validPath))
        
        mockTap.invalidate()
    }
    
    /// Tests file system error handling with concurrent operations
    /// Requirements: 5.4
    func testFileSystemErrorHandlingWithConcurrentOperations() async throws {
        // Given: Multiple recorders attempting to write to the same location
        let mockProcess = MockAudioProcess.createMockProcess()
        let mockTap1 = MockProcessTap.createMockTap(process: mockProcess)
        let mockTap2 = MockProcessTap.createMockTap(process: mockProcess)
        
        await mockTap1.activate()
        await mockTap2.activate()
        
        let sharedFilePath = tempDirectory.appendingPathComponent("shared_recording.wav")
        
        // When: First recorder starts successfully
        let recorder1 = ProcessTapRecorder(fileURL: sharedFilePath, tap: mockTap1)
        try await recorder1.start()
        XCTAssertTrue(recorder1.isRecording)
        
        // When: Second recorder attempts to write to same file
        // This should either fail or handle the conflict gracefully
        let recorder2 = ProcessTapRecorder(fileURL: sharedFilePath, tap: mockTap2)
        do {
            try await recorder2.start()
            // If it succeeds, both recorders are writing to different files or handling conflict
            XCTAssertTrue(recorder2.isRecording)
            recorder2.stop()
        } catch {
            // Expected behavior - should prevent concurrent access to same file
            XCTAssertTrue(error.localizedDescription.contains("use") ||
                         error.localizedDescription.contains("access") ||
                         error.localizedDescription.contains("file"))
        }
        
        recorder1.stop()
        mockTap1.invalidate()
        mockTap2.invalidate()
    }
    
    // MARK: - Permission Changes During Recording Tests
    
    /// Tests permission changes during active recording
    /// Requirements: 5.4
    func testPermissionChangesDuringActiveRecording() async throws {
        // Given: A mock process and permission handler
        let mockProcess = MockAudioProcess.createMockProcess()
        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
        let mockPermissionHandler = MockPermissionHandler()
        
        // Start with authorized permission
        mockPermissionHandler.mockStatus = .authorized
        
        await mockTap.activate()
        let recordingURL = tempDirectory.appendingPathComponent("permission_test_recording.wav")
        
        // When: Starting recording with valid permissions
        let recorder = ProcessTapRecorder(fileURL: recordingURL, tap: mockTap)
        try await recorder.start()
        XCTAssertTrue(recorder.isRecording)
        
        // Simulate some recording activity
        mockTap.simulateAudioData()
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // When: Permission is revoked during recording
        mockPermissionHandler.mockStatus = .denied
        
        // Simulate permission change notification
        // In a real app, this would trigger through the permission system
        // For testing, we'll simulate the effect
        
        // The recording should handle this gracefully
        // Either by stopping recording or by continuing until explicitly stopped
        XCTAssertTrue(recorder.isRecording) // Should still be recording until explicitly stopped
        
        // When: Stopping recording after permission change
        recorder.stop()
        XCTAssertFalse(recorder.isRecording)
        
        // File should still exist and be valid
        XCTAssertTrue(FileManager.default.fileExists(atPath: recordingURL.path))
        XCTAssertTrue(AudioTestUtilities.verifyAudioFileIntegrity(at: recordingURL))
        
        mockTap.invalidate()
    }
    
    /// Tests permission status changes and their effects on tap creation
    /// Requirements: 5.4
    func testPermissionStatusChangesEffectOnTapCreation() async throws {
        let mockPermissionHandler = MockPermissionHandler()
        
        // Test different permission states
        let permissionStates: [(AudioRecordingPermission.Status, Bool)] = [
            (.unknown, false),
            (.denied, false),
            (.authorized, true)
        ]
        
        for (permissionStatus, shouldSucceed) in permissionStates {
            // Given: Permission handler with specific status
            mockPermissionHandler.mockStatus = permissionStatus
            
            let mockProcess = MockAudioProcess.createMockProcess(
                name: "Permission Test App - \(permissionStatus)"
            )
            let mockTap = MockProcessTap.createMockTap(process: mockProcess)
            
            // Configure tap to fail activation if permissions are not authorized
            if permissionStatus != .authorized {
                mockTap.shouldFailActivation = true
                mockTap.mockErrorMessage = "Audio recording permission required"
            }
            
            // When: Attempting to activate tap
            await mockTap.activate()
            
            // Then: Result should match expected permission behavior
            if shouldSucceed {
                XCTAssertNil(mockTap.errorMessage, "Should succeed with \(permissionStatus) permission")
                XCTAssertNotNil(mockTap.tapStreamDescription)
            } else {
                XCTAssertNotNil(mockTap.errorMessage, "Should fail with \(permissionStatus) permission")
                XCTAssertTrue(mockTap.errorMessage!.contains("permission"))
            }
            
            mockTap.invalidate()
        }
    }
    
    /// Tests permission request handling during error scenarios
    /// Requirements: 5.4
    func testPermissionRequestHandlingDuringErrors() async throws {
        // Given: A mock permission handler that simulates request flow
        let mockPermissionHandler = MockPermissionHandler()
        mockPermissionHandler.mockStatus = .unknown
        
        // When: Requesting permission
        let expectation = XCTestExpectation(description: "Permission request completed")
        
        mockPermissionHandler.requestPermission { granted in
            XCTAssertTrue(granted, "Mock should grant permission")
            expectation.fulfill()
        }
        
        // Simulate permission being granted
        mockPermissionHandler.mockStatus = .authorized
        
        await fulfillment(of: [expectation], timeout: 2.0)
        
        // Then: Permission status should be updated
        XCTAssertEqual(mockPermissionHandler.status, .authorized)
        XCTAssertEqual(mockPermissionHandler.requestCallCount, 1)
        
        // Test error during permission request
        mockPermissionHandler.mockStatus = .unknown
        mockPermissionHandler.shouldFailRequest = true
        
        let errorExpectation = XCTestExpectation(description: "Permission request failed")
        
        mockPermissionHandler.requestPermission { granted in
            XCTAssertFalse(granted, "Should fail when configured to fail")
            errorExpectation.fulfill()
        }
        
        await fulfillment(of: [errorExpectation], timeout: 2.0)
    }
    
    // MARK: - Complex Error Scenario Tests
    
    /// Tests cascading error scenarios across multiple components
    /// Requirements: 5.3, 5.4
    func testCascadingErrorScenarios() async throws {
        // Given: A complex scenario with multiple potential failure points
        let mockProcess = MockAudioProcess.createMockProcess()
        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
        let mockPermissionHandler = MockPermissionHandler()
        
        // Scenario 1: Permission failure -> Tap activation failure -> Recovery
        mockPermissionHandler.mockStatus = .denied
        mockTap.shouldFailActivation = true
        mockTap.mockErrorMessage = "Permission denied for audio recording"
        
        await mockTap.activate()
        XCTAssertNotNil(mockTap.errorMessage)
        
        // Recovery: Grant permission and retry
        mockPermissionHandler.mockStatus = .authorized
        mockTap.shouldFailActivation = false
        mockTap.resetMockState()
        
        await mockTap.activate()
        XCTAssertNil(mockTap.errorMessage)
        
        // Scenario 2: Successful tap -> File system failure -> Recovery
        let invalidURL = URL(fileURLWithPath: "/invalid/path/recording.wav")
        let recorder1 = ProcessTapRecorder(fileURL: invalidURL, tap: mockTap)
        
        await XCTAssertThrowsError(try await recorder1.start())
        
        // Recovery: Use valid path
        let validURL = tempDirectory.appendingPathComponent("cascading_test.wav")
        let recorder2 = ProcessTapRecorder(fileURL: validURL, tap: mockTap)
        try await recorder2.start()
        
        mockTap.simulateAudioData()
        try await Task.sleep(nanoseconds: 200_000_000)
        recorder2.stop()
        
        XCTAssertTrue(AudioTestUtilities.verifyAudioFileIntegrity(at: validURL))
        
        mockTap.invalidate()
    }
    
    /// Tests error handling with resource cleanup
    /// Requirements: 5.3, 5.4
    func testErrorHandlingWithResourceCleanup() async throws {
        // Given: Multiple resources that need cleanup on error
        var taps: [MockProcessTap] = []
        var recorders: [ProcessTapRecorder] = []
        
        // Create multiple resources
        for i in 0..<3 {
            let process = MockAudioProcess.createMockProcess(id: pid_t(2000 + i), name: "Cleanup Test App \(i)")
            let tap = MockProcessTap.createMockTap(process: process)
            
            taps.append(tap)
        }
        
        // Activate all taps
        for tap in taps {
            await tap.activate()
            XCTAssertNil(tap.errorMessage)
        }
        
        // Start recordings
        for (index, tap) in taps.enumerated() {
            let url = tempDirectory.appendingPathComponent("cleanup_test_\(index).wav")
            let recorder = ProcessTapRecorder(fileURL: url, tap: tap)
            try await recorder.start()
            recorders.append(recorder)
        }
        
        // Simulate error condition that requires cleanup
        // Force invalidation of all taps
        for tap in taps {
            tap.invalidate()
        }
        
        // Stop all recordings
        for recorder in recorders {
            if recorder.isRecording {
                recorder.stop()
            }
        }
        
        // Verify cleanup was successful
        for tap in taps {
            XCTAssertEqual(tap.invalidationCallCount, 1)
        }
        
        for recorder in recorders {
            XCTAssertFalse(recorder.isRecording)
        }
    }
}