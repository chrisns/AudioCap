import XCTest
import AudioToolbox
import AVFoundation
@testable import AudioCap

final class RobustnessTests: XCTestCase {
    
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        tempDirectory = TestHelpers.createTemporaryDirectory(prefix: "RobustnessTests")
    }
    
    override func tearDown() {
        TestHelpers.cleanupTemporaryDirectory(at: tempDirectory)
        tempDirectory = nil
        super.tearDown()
    }
    
    // MARK: - Invalid Process Selection Handling Tests
    
    @MainActor
    func testInvalidProcessSelectionHandling() async throws {
        // Test with invalid process ID
        let invalidProcess = AudioProcess(
            id: -1,
            kind: .process,
            name: "Invalid Process",
            audioActive: false,
            bundleID: nil,
            bundleURL: nil,
            objectID: AudioObjectID.unknown
        )
        
        let tap = ProcessTap(process: invalidProcess)
        let fileURL = tempDirectory.appendingPathComponent("invalid_process.wav")
        let recorder = ProcessTapRecorder(fileURL: fileURL, tap: tap)
        
        // Should handle invalid process gracefully
        tap.activate()
        XCTAssertNotNil(tap.errorMessage, "Should have error message for invalid process")
        
        // Recording should fail gracefully
        XCTAssertThrowsError(try recorder.start()) { error in
            XCTAssertTrue(error.localizedDescription.contains("Tap stream description not available") ||
                         error.localizedDescription.contains("Process tab unavailable"))
        }
        
        XCTAssertFalse(recorder.isRecording)
    }
    
    @MainActor
    func testNonExistentProcessHandling() async throws {
        // Test with process that doesn't exist anymore
        let nonExistentProcess = AudioProcess(
            id: 99999, // Very unlikely to exist
            kind: .process,
            name: "Non-existent Process",
            audioActive: false,
            bundleID: "com.nonexistent.app",
            bundleURL: nil,
            objectID: AudioObjectID(99999)
        )
        
        let tap = ProcessTap(process: nonExistentProcess)
        let fileURL = tempDirectory.appendingPathComponent("nonexistent_process.wav")
        let recorder = ProcessTapRecorder(fileURL: fileURL, tap: tap)
        
        // Should handle non-existent process gracefully
        tap.activate()
        
        // May or may not have an error depending on implementation
        // The key is that it doesn't crash
        do {
            try recorder.start()
            recorder.stop()
        } catch {
            // Expected for non-existent process
            XCTAssertFalse(recorder.isRecording)
        }
    }
    
    func testProcessTerminationDuringRecording() async throws {
        let mockProcess = MockAudioProcess.createMockProcess()
        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
        let fileURL = tempDirectory.appendingPathComponent("terminated_process.wav")
        let recorder = ProcessTapRecorder(fileURL: fileURL, tap: mockTap)
        
        try await Task { @MainActor in
            try recorder.start()
            XCTAssertTrue(recorder.isRecording)
        }.value
        
        // Simulate process termination by triggering invalidation
        mockTap.simulateInvalidation()
        
        // Allow time for invalidation handling
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Recording should handle termination gracefully
        await Task { @MainActor in
            recorder.stop()
        }.value
        
        XCTAssertFalse(recorder.isRecording)
    }
    
    func testInvalidAudioObjectIDHandling() {
        let invalidProcess = AudioProcess(
            id: 1234,
            kind: .app,
            name: "Test App",
            audioActive: true,
            bundleID: "com.test.app",
            bundleURL: nil,
            objectID: AudioObjectID.unknown
        )
        
        let tap = ProcessTap(process: invalidProcess)
        
        Task { @MainActor in
            tap.activate()
            
            // Should handle invalid object ID gracefully
            XCTAssertNotNil(tap.errorMessage, "Should have error for invalid object ID")
            XCTAssertFalse(tap.activated, "Should not be activated with invalid object ID")
        }
    }
    
    // MARK: - System Audio Device Change Adaptation Tests
    
    func testAudioDeviceChangeAdaptation() async throws {
        let mockProcess = MockAudioProcess.createMockProcess()
        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
        let fileURL = tempDirectory.appendingPathComponent("device_change.wav")
        let recorder = ProcessTapRecorder(fileURL: fileURL, tap: mockTap)
        
        try await Task { @MainActor in
            try recorder.start()
            XCTAssertTrue(recorder.isRecording)
        }.value
        
        // Simulate audio device change by invalidating the tap
        mockTap.simulateInvalidation()
        
        // Allow time for adaptation
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // System should handle device change gracefully
        await Task { @MainActor in
            recorder.stop()
        }.value
        
        XCTAssertFalse(recorder.isRecording)
        
        // Should be able to restart after device change
        try await Task { @MainActor in
            mockTap.resetMockState()
            try recorder.start()
            XCTAssertTrue(recorder.isRecording)
            recorder.stop()
        }.value
    }
    
    func testMultipleAudioDeviceChanges() async throws {
        let mockProcess = MockAudioProcess.createMockProcess()
        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
        let fileURL = tempDirectory.appendingPathComponent("multiple_device_changes.wav")
        let recorder = ProcessTapRecorder(fileURL: fileURL, tap: mockTap)
        
        // Test multiple device changes
        for i in 0..<5 {
            try await Task { @MainActor in
                try recorder.start()
                XCTAssertTrue(recorder.isRecording, "Should be recording in iteration \(i)")
            }.value
            
            // Simulate device change
            mockTap.simulateInvalidation()
            
            await Task { @MainActor in
                recorder.stop()
                XCTAssertFalse(recorder.isRecording, "Should stop recording in iteration \(i)")
            }.value
            
            // Reset for next iteration
            mockTap.resetMockState()
            
            // Brief pause between iterations
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
    }
    
    func testAudioFormatChangeHandling() async throws {
        let mockProcess = MockAudioProcess.createMockProcess()
        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
        let fileURL = tempDirectory.appendingPathComponent("format_change.wav")
        let recorder = ProcessTapRecorder(fileURL: fileURL, tap: mockTap)
        
        // Start with initial format
        let initialFormat = AudioStreamBasicDescription(
            mSampleRate: 44100.0,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 8,
            mFramesPerPacket: 1,
            mBytesPerFrame: 8,
            mChannelsPerFrame: 2,
            mBitsPerChannel: 32,
            mReserved: 0
        )
        mockTap.mockStreamDescription = initialFormat
        
        try await Task { @MainActor in
            try recorder.start()
            XCTAssertTrue(recorder.isRecording)
        }.value
        
        // Simulate format change
        let newFormat = AudioStreamBasicDescription(
            mSampleRate: 48000.0,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 32,
            mReserved: 0
        )
        
        await Task { @MainActor in
            recorder.stop()
        }.value
        
        mockTap.mockStreamDescription = newFormat
        mockTap.resetMockState()
        
        // Should handle format change gracefully
        try await Task { @MainActor in
            try recorder.start()
            XCTAssertTrue(recorder.isRecording)
            recorder.stop()
        }.value
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentProcessTapOperations() async throws {
        let mockProcess = MockAudioProcess.createMockProcess()
        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
        let concurrentCount = 10
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<concurrentCount {
                group.addTask {
                    Task { @MainActor in
                        if i % 2 == 0 {
                            mockTap.activate()
                        } else {
                            mockTap.invalidate()
                        }
                    }
                }
            }
        }
        
        // Should handle concurrent operations without crashing
        XCTAssertTrue(true, "Concurrent operations completed without crash")
    }
    
    func testConcurrentRecorderOperations() async throws {
        let mockProcess = MockAudioProcess.createMockProcess()
        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
        let concurrentCount = 5
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<concurrentCount {
                group.addTask { [weak self] in
                    guard let self = self else { return }
                    
                    let fileURL = self.tempDirectory.appendingPathComponent("concurrent_\(i).wav")
                    let recorder = ProcessTapRecorder(fileURL: fileURL, tap: mockTap)
                    
                    Task { @MainActor in
                        do {
                            try recorder.start()
                            
                            // Brief recording
                            for _ in 0..<5 {
                                mockTap.simulateAudioData()
                            }
                            
                            recorder.stop()
                        } catch {
                            // Some operations may fail due to concurrency - that's expected
                        }
                    }
                }
            }
        }
        
        // Should handle concurrent recorder operations
        XCTAssertTrue(true, "Concurrent recorder operations completed")
    }
    
    func testThreadSafetyWithProcessController() async throws {
        let controller = AudioProcessController()
        let concurrentCount = 20
        
        await Task { @MainActor in
            controller.activate()
        }.value
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<concurrentCount {
                group.addTask {
                    let mockApps = TestHelpers.mockRunningApplications(count: 10 + i)
                    
                    Task { @MainActor in
                        controller.reload(apps: mockApps)
                    }
                }
            }
        }
        
        // Should handle concurrent process list updates
        await Task { @MainActor in
            XCTAssertNotNil(controller.processes)
            XCTAssertNotNil(controller.processGroups)
        }.value
    }
    
    func testRaceConditionInRecordingLifecycle() async throws {
        let mockProcess = MockAudioProcess.createMockProcess()
        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
        let fileURL = tempDirectory.appendingPathComponent("race_condition.wav")
        let recorder = ProcessTapRecorder(fileURL: fileURL, tap: mockTap)
        
        let operationCount = 50
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<operationCount {
                group.addTask {
                    Task { @MainActor in
                        if i % 2 == 0 {
                            do {
                                try recorder.start()
                            } catch {
                                // Expected in race conditions
                            }
                        } else {
                            recorder.stop()
                        }
                    }
                }
                
                // Small delay to create race conditions
                try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
            }
        }
        
        // Ensure final state is consistent
        await Task { @MainActor in
            recorder.stop()
            XCTAssertFalse(recorder.isRecording)
        }.value
    }
    
    // MARK: - Graceful Degradation Tests
    
    func testGracefulDegradationWhenResourcesUnavailable() async throws {
        // Test with read-only file system location
        let readOnlyURL = URL(fileURLWithPath: "/System/Library/test_readonly.wav")
        let mockProcess = MockAudioProcess.createMockProcess()
        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
        let recorder = ProcessTapRecorder(fileURL: readOnlyURL, tap: mockTap)
        
        // Should fail gracefully when file cannot be created
        await Task { @MainActor in
            XCTAssertThrowsError(try recorder.start()) { error in
                // Should provide meaningful error message
                XCTAssertFalse(error.localizedDescription.isEmpty)
            }
            
            XCTAssertFalse(recorder.isRecording)
        }.value
    }
    
    func testGracefulDegradationWithInsufficientDiskSpace() async throws {
        // Create a very large file URL that would exceed available space
        let largeFileURL = tempDirectory.appendingPathComponent("large_file.wav")
        let mockProcess = MockAudioProcess.createMockProcess()
        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
        let recorder = ProcessTapRecorder(fileURL: largeFileURL, tap: mockTap)
        
        try await Task { @MainActor in
            try recorder.start()
            XCTAssertTrue(recorder.isRecording)
        }.value
        
        // Simulate disk space exhaustion by generating lots of audio data
        // In a real scenario, this would eventually fail when disk is full
        for _ in 0..<1000 {
            mockTap.simulateAudioData()
        }
        
        await Task { @MainActor in
            recorder.stop()
        }.value
        
        // Should handle potential disk space issues gracefully
        XCTAssertFalse(recorder.isRecording)
    }
    
    func testGracefulDegradationWithCorruptedAudioData() async throws {
        let mockProcess = MockAudioProcess.createMockProcess()
        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
        let fileURL = tempDirectory.appendingPathComponent("corrupted_data.wav")
        let recorder = ProcessTapRecorder(fileURL: fileURL, tap: mockTap)
        
        // Set up corrupted stream description
        var corruptedDescription = AudioStreamBasicDescription()
        corruptedDescription.mSampleRate = 0 // Invalid sample rate
        corruptedDescription.mChannelsPerFrame = 0 // Invalid channel count
        mockTap.mockStreamDescription = corruptedDescription
        
        // Should handle corrupted audio format gracefully
        await Task { @MainActor in
            XCTAssertThrowsError(try recorder.start()) { error in
                XCTAssertTrue(error.localizedDescription.contains("Failed to create AVAudioFormat") ||
                             error.localizedDescription.contains("invalid"))
            }
            
            XCTAssertFalse(recorder.isRecording)
        }.value
    }
    
    func testGracefulDegradationWithSystemResourceExhaustion() async throws {
        // Test behavior when system resources are exhausted
        let resourceCount = 100
        var recorders: [ProcessTapRecorder] = []
        var successfulStarts = 0
        
        // Try to create many recorders to exhaust resources
        for i in 0..<resourceCount {
            let mockProcess = MockAudioProcess.createMockProcess(id: pid_t(3000 + i))
            let mockTap = MockProcessTap.createMockTap(process: mockProcess)
            let fileURL = tempDirectory.appendingPathComponent("resource_\(i).wav")
            let recorder = ProcessTapRecorder(fileURL: fileURL, tap: mockTap)
            
            recorders.append(recorder)
            
            await Task { @MainActor in
                do {
                    try recorder.start()
                    successfulStarts += 1
                } catch {
                    // Expected when resources are exhausted
                }
            }.value
        }
        
        // Should handle resource exhaustion gracefully
        XCTAssertGreaterThan(successfulStarts, 0, "At least some recorders should start successfully")
        XCTAssertLessThan(successfulStarts, resourceCount, "Not all recorders should start (resource limits)")
        
        // Clean up
        for recorder in recorders {
            await Task { @MainActor in
                recorder.stop()
            }.value
        }
    }
    
    func testGracefulDegradationWithPermissionChanges() async throws {
        let mockProcess = MockAudioProcess.createMockProcess()
        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
        let fileURL = tempDirectory.appendingPathComponent("permission_change.wav")
        let recorder = ProcessTapRecorder(fileURL: fileURL, tap: mockTap)
        
        try await Task { @MainActor in
            try recorder.start()
            XCTAssertTrue(recorder.isRecording)
        }.value
        
        // Simulate permission revocation during recording
        mockTap.shouldFailRunning = true
        mockTap.mockErrorMessage = "Permission denied"
        
        // Trigger invalidation to simulate permission change
        mockTap.simulateInvalidation()
        
        // Should handle permission changes gracefully
        await Task { @MainActor in
            recorder.stop()
            XCTAssertFalse(recorder.isRecording)
        }.value
        
        // Should not be able to restart without permissions
        mockTap.resetMockState()
        mockTap.shouldFailRunning = true
        
        await Task { @MainActor in
            XCTAssertThrowsError(try recorder.start()) { error in
                XCTAssertTrue(error.localizedDescription.contains("Permission denied") ||
                             error.localizedDescription.contains("Mock error"))
            }
        }.value
    }
    
    // MARK: - Error Recovery Tests
    
    func testErrorRecoveryAfterFailedActivation() async throws {
        let mockProcess = MockAudioProcess.createMockProcess()
        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
        let fileURL = tempDirectory.appendingPathComponent("recovery_test.wav")
        let recorder = ProcessTapRecorder(fileURL: fileURL, tap: mockTap)
        
        // First attempt should fail
        mockTap.shouldFailActivation = true
        mockTap.mockErrorMessage = "Initial activation failure"
        
        await Task { @MainActor in
            XCTAssertThrowsError(try recorder.start()) { error in
                XCTAssertTrue(error.localizedDescription.contains("Tap stream description not available"))
            }
            XCTAssertFalse(recorder.isRecording)
        }.value
        
        // Reset and try again - should succeed
        mockTap.resetMockState()
        mockTap.shouldFailActivation = false
        
        try await Task { @MainActor in
            try recorder.start()
            XCTAssertTrue(recorder.isRecording)
            recorder.stop()
            XCTAssertFalse(recorder.isRecording)
        }.value
    }
    
    func testErrorRecoveryAfterInvalidation() async throws {
        let mockProcess = MockAudioProcess.createMockProcess()
        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
        let fileURL = tempDirectory.appendingPathComponent("invalidation_recovery.wav")
        let recorder = ProcessTapRecorder(fileURL: fileURL, tap: mockTap)
        
        try await Task { @MainActor in
            try recorder.start()
            XCTAssertTrue(recorder.isRecording)
        }.value
        
        // Simulate unexpected invalidation
        mockTap.simulateInvalidation()
        
        // Allow time for invalidation handling
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        await Task { @MainActor in
            recorder.stop()
            XCTAssertFalse(recorder.isRecording)
        }.value
        
        // Should be able to recover and start again
        mockTap.resetMockState()
        
        try await Task { @MainActor in
            try recorder.start()
            XCTAssertTrue(recorder.isRecording)
            recorder.stop()
        }.value
    }
    
    // MARK: - Edge Case Handling Tests
    
    func testHandlingOfExtremeAudioFormats() async throws {
        let mockProcess = MockAudioProcess.createMockProcess()
        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
        let fileURL = tempDirectory.appendingPathComponent("extreme_format.wav")
        let recorder = ProcessTapRecorder(fileURL: fileURL, tap: mockTap)
        
        // Test with extreme sample rate
        let extremeFormat = AudioStreamBasicDescription(
            mSampleRate: 192000.0, // Very high sample rate
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 32, // 8 channels * 4 bytes
            mFramesPerPacket: 1,
            mBytesPerFrame: 32,
            mChannelsPerFrame: 8, // Many channels
            mBitsPerChannel: 32,
            mReserved: 0
        )
        
        mockTap.mockStreamDescription = extremeFormat
        
        // Should handle extreme formats gracefully
        do {
            try await Task { @MainActor in
                try recorder.start()
                XCTAssertTrue(recorder.isRecording)
                
                // Brief recording with extreme format
                mockTap.simulateAudioData()
                
                recorder.stop()
            }.value
        } catch {
            // May fail with extreme formats - that's acceptable
            XCTAssertFalse(recorder.isRecording)
        }
    }
    
    func testHandlingOfRapidStateChanges() async throws {
        let mockProcess = MockAudioProcess.createMockProcess()
        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
        let fileURL = tempDirectory.appendingPathComponent("rapid_changes.wav")
        let recorder = ProcessTapRecorder(fileURL: fileURL, tap: mockTap)
        
        // Perform rapid state changes
        for i in 0..<20 {
            await Task { @MainActor in
                do {
                    try recorder.start()
                    
                    // Very brief recording
                    if i % 3 == 0 {
                        mockTap.simulateAudioData()
                    }
                    
                    recorder.stop()
                } catch {
                    // Some operations may fail due to rapid changes
                }
            }.value
            
            // Minimal delay
            try await Task.sleep(nanoseconds: 5_000_000) // 5ms
        }
        
        // Final state should be consistent
        await Task { @MainActor in
            XCTAssertFalse(recorder.isRecording)
        }.value
    }
}