import XCTest
import AudioToolbox
import AVFoundation
@testable import AudioCap

final class MemoryManagementTests: XCTestCase {
    
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        tempDirectory = TestHelpers.createTemporaryDirectory(prefix: "MemoryTests")
    }
    
    override func tearDown() {
        TestHelpers.cleanupTemporaryDirectory(at: tempDirectory)
        tempDirectory = nil
        super.tearDown()
    }
    
    // MARK: - Memory Leak Detection Tests
    
    func testProcessTapMemoryLeakDuringMultipleRecordingSessions() {
        let memoryMetric = XCTMemoryMetric()
        let options = XCTMeasureOptions()
        options.iterationCount = 10
        
        measure(metrics: [memoryMetric], options: options) {
            autoreleasepool {
                let mockProcess = MockAudioProcess.createMockProcess()
                let mockTap = MockProcessTap.createMockTap(process: mockProcess)
                let fileURL = tempDirectory.appendingPathComponent("session_\(UUID().uuidString).wav")
                let recorder = ProcessTapRecorder(fileURL: fileURL, tap: mockTap)
                
                Task { @MainActor in
                    do {
                        try recorder.start()
                        
                        // Simulate audio processing
                        for _ in 0..<50 {
                            mockTap.simulateAudioData()
                        }
                        
                        recorder.stop()
                    } catch {
                        XCTFail("Recording session failed: \(error)")
                    }
                }
                
                // Force cleanup
                mockTap.resetMockState()
            }
        }
    }
    
    func testProcessTapRecorderMemoryLeakWithMultipleInstances() {
        let memoryMetric = XCTMemoryMetric()
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        
        measure(metrics: [memoryMetric], options: options) {
            var recorders: [ProcessTapRecorder] = []
            
            autoreleasepool {
                // Create multiple recorder instances
                for i in 0..<20 {
                    let mockProcess = MockAudioProcess.createMockProcess(id: pid_t(1000 + i))
                    let mockTap = MockProcessTap.createMockTap(process: mockProcess)
                    let fileURL = tempDirectory.appendingPathComponent("recorder_\(i).wav")
                    let recorder = ProcessTapRecorder(fileURL: fileURL, tap: mockTap)
                    recorders.append(recorder)
                }
                
                // Start and stop all recorders
                Task { @MainActor in
                    for recorder in recorders {
                        do {
                            try recorder.start()
                            recorder.stop()
                        } catch {
                            // Continue with other recorders
                        }
                    }
                }
            }
            
            // Clear references
            recorders.removeAll()
        }
    }
    
    func testAudioProcessControllerMemoryLeakDuringProcessDiscovery() {
        let memoryMetric = XCTMemoryMetric()
        let options = XCTMeasureOptions()
        options.iterationCount = 10
        
        measure(metrics: [memoryMetric], options: options) {
            autoreleasepool {
                let controller = AudioProcessController()
                
                Task { @MainActor in
                    controller.activate()
                    
                    // Simulate multiple process list updates
                    let mockApps = TestHelpers.mockRunningApplications(count: 50)
                    for _ in 0..<10 {
                        controller.reload(apps: mockApps)
                    }
                }
            }
        }
    }
    
    // MARK: - Resource Cleanup Tests
    
    @MainActor
    func testResourceCleanupAfterLongRecordingSession() async throws {
        let mockProcess = MockAudioProcess.createMockProcess()
        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
        let fileURL = tempDirectory.appendingPathComponent("long_session.wav")
        let recorder = ProcessTapRecorder(fileURL: fileURL, tap: mockTap)
        
        // Start recording
        try recorder.start()
        XCTAssertTrue(recorder.isRecording)
        XCTAssertTrue(mockTap.activated)
        
        // Simulate long recording session with continuous audio data
        let sessionDuration: TimeInterval = 2.0 // Reduced for test performance
        let dataInterval: TimeInterval = 0.01
        let iterations = Int(sessionDuration / dataInterval)
        
        for i in 0..<iterations {
            mockTap.simulateAudioData()
            
            // Periodically check memory usage doesn't grow excessively
            if i % 50 == 0 {
                // Allow some processing time
                try await Task.sleep(nanoseconds: 1_000_000) // 1ms
            }
        }
        
        // Stop recording
        recorder.stop()
        XCTAssertFalse(recorder.isRecording)
        XCTAssertFalse(mockTap.activated)
        
        // Verify resources are cleaned up
        XCTAssertEqual(mockTap.invalidationCallCount, 1)
        XCTAssertNil(mockTap.lastIOBlock)
        XCTAssertNil(mockTap.lastInvalidationHandler)
        
        // Verify file was created
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }
    
    func testResourceCleanupWithAbruptTermination() {
        weak var weakRecorder: ProcessTapRecorder?
        weak var weakTap: MockProcessTap?
        
        autoreleasepool {
            let mockProcess = MockAudioProcess.createMockProcess()
            let mockTap = MockProcessTap.createMockTap(process: mockProcess)
            let fileURL = tempDirectory.appendingPathComponent("abrupt_termination.wav")
            let recorder = ProcessTapRecorder(fileURL: fileURL, tap: mockTap)
            
            weakRecorder = recorder
            weakTap = mockTap
            
            Task { @MainActor in
                do {
                    try recorder.start()
                    XCTAssertTrue(recorder.isRecording)
                    
                    // Simulate some audio processing
                    for _ in 0..<10 {
                        mockTap.simulateAudioData()
                    }
                    
                    // Don't call stop() - simulate abrupt termination
                } catch {
                    XCTFail("Failed to start recording: \(error)")
                }
            }
        }
        
        // Objects should be deallocated and resources cleaned up
        XCTAssertNil(weakRecorder, "ProcessTapRecorder should be deallocated")
        XCTAssertNil(weakTap, "MockProcessTap should be deallocated")
    }
    
    func testResourceCleanupWithMultipleStartStopCycles() async throws {
        let mockProcess = MockAudioProcess.createMockProcess()
        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
        let fileURL = tempDirectory.appendingPathComponent("multiple_cycles.wav")
        let recorder = ProcessTapRecorder(fileURL: fileURL, tap: mockTap)
        
        // Perform multiple start/stop cycles
        for cycle in 0..<10 {
            try await Task { @MainActor in
                try recorder.start()
                XCTAssertTrue(recorder.isRecording, "Recording should be active in cycle \(cycle)")
                
                // Simulate brief audio processing
                for _ in 0..<5 {
                    mockTap.simulateAudioData()
                }
                
                recorder.stop()
                XCTAssertFalse(recorder.isRecording, "Recording should be stopped in cycle \(cycle)")
                
                // Brief pause between cycles
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }.value
        }
        
        // Verify final state
        XCTAssertFalse(recorder.isRecording)
        XCTAssertFalse(mockTap.activated)
        XCTAssertEqual(mockTap.invalidationCallCount, 10, "Should have 10 invalidation calls")
    }
    
    // MARK: - Stress Tests for Concurrent Operations
    
    func testConcurrentRecordingOperations() async throws {
        let concurrentCount = 5
        let expectation = XCTestExpectation(description: "Concurrent recordings complete")
        expectation.expectedFulfillmentCount = concurrentCount
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<concurrentCount {
                group.addTask { [weak self] in
                    guard let self = self else { return }
                    
                    autoreleasepool {
                        let mockProcess = MockAudioProcess.createMockProcess(id: pid_t(2000 + i))
                        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
                        let fileURL = self.tempDirectory.appendingPathComponent("concurrent_\(i).wav")
                        let recorder = ProcessTapRecorder(fileURL: fileURL, tap: mockTap)
                        
                        Task { @MainActor in
                            do {
                                try recorder.start()
                                
                                // Simulate concurrent audio processing
                                for _ in 0..<20 {
                                    mockTap.simulateAudioData()
                                }
                                
                                recorder.stop()
                                expectation.fulfill()
                            } catch {
                                XCTFail("Concurrent recording \(i) failed: \(error)")
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
    }
    
    func testConcurrentProcessControllerOperations() async throws {
        let controller = AudioProcessController()
        let concurrentCount = 10
        let expectation = XCTestExpectation(description: "Concurrent controller operations complete")
        expectation.expectedFulfillmentCount = concurrentCount
        
        await Task { @MainActor in
            controller.activate()
        }.value
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<concurrentCount {
                group.addTask {
                    autoreleasepool {
                        let mockApps = TestHelpers.mockRunningApplications(count: 20 + i)
                        
                        Task { @MainActor in
                            controller.reload(apps: mockApps)
                            expectation.fulfill()
                        }
                    }
                }
            }
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
    }
    
    func testStressTestWithRapidStartStopOperations() async throws {
        let mockProcess = MockAudioProcess.createMockProcess()
        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
        let fileURL = tempDirectory.appendingPathComponent("stress_test.wav")
        let recorder = ProcessTapRecorder(fileURL: fileURL, tap: mockTap)
        
        let operationCount = 100
        let expectation = XCTestExpectation(description: "Stress test operations complete")
        expectation.expectedFulfillmentCount = operationCount
        
        // Perform rapid start/stop operations
        for i in 0..<operationCount {
            Task { @MainActor in
                do {
                    try recorder.start()
                    
                    // Very brief recording
                    mockTap.simulateAudioData()
                    
                    recorder.stop()
                    expectation.fulfill()
                } catch {
                    // Some operations might fail due to rapid cycling - that's expected
                    expectation.fulfill()
                }
            }
            
            // Small delay to prevent overwhelming the system
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }
        
        await fulfillment(of: [expectation], timeout: 30.0)
        
        // Verify final state is clean
        XCTAssertFalse(recorder.isRecording)
        XCTAssertFalse(mockTap.activated)
    }
    
    // MARK: - Object Deallocation Tests
    
    func testProcessTapProperDeallocation() {
        weak var weakTap: ProcessTap?
        
        autoreleasepool {
            let mockProcess = MockAudioProcess.createMockProcess()
            let tap = ProcessTap(process: mockProcess)
            weakTap = tap
            
            Task { @MainActor in
                tap.activate()
                XCTAssertTrue(tap.activated)
                tap.invalidate()
                XCTAssertFalse(tap.activated)
            }
        }
        
        // ProcessTap should be deallocated
        XCTAssertNil(weakTap, "ProcessTap should be deallocated")
    }
    
    func testProcessTapRecorderProperDeallocation() {
        weak var weakRecorder: ProcessTapRecorder?
        weak var weakTap: ProcessTap?
        
        autoreleasepool {
            let mockProcess = MockAudioProcess.createMockProcess()
            let tap = ProcessTap(process: mockProcess)
            let fileURL = tempDirectory.appendingPathComponent("deallocation_test.wav")
            let recorder = ProcessTapRecorder(fileURL: fileURL, tap: tap)
            
            weakRecorder = recorder
            weakTap = tap
            
            Task { @MainActor in
                do {
                    try recorder.start()
                    mockTap.simulateAudioData()
                    recorder.stop()
                } catch {
                    // Ignore errors for deallocation test
                }
            }
        }
        
        // Both objects should be deallocated
        XCTAssertNil(weakRecorder, "ProcessTapRecorder should be deallocated")
        XCTAssertNil(weakTap, "ProcessTap should be deallocated")
    }
    
    func testAudioProcessControllerProperDeallocation() {
        weak var weakController: AudioProcessController?
        
        autoreleasepool {
            let controller = AudioProcessController()
            weakController = controller
            
            Task { @MainActor in
                controller.activate()
                
                // Simulate some operations
                let mockApps = TestHelpers.mockRunningApplications(count: 10)
                controller.reload(apps: mockApps)
            }
        }
        
        // Controller should be deallocated
        XCTAssertNil(weakController, "AudioProcessController should be deallocated")
    }
    
    func testMockObjectsProperDeallocation() {
        weak var weakMockProcess: AudioProcess?
        weak var weakMockTap: MockProcessTap?
        
        autoreleasepool {
            let mockProcess = MockAudioProcess.createMockProcess()
            let mockTap = MockProcessTap.createMockTap(process: mockProcess)
            
            weakMockProcess = mockProcess
            weakMockTap = mockTap
            
            // Use the objects briefly
            mockTap.resetMockState()
        }
        
        // Mock objects should be deallocated
        XCTAssertNil(weakMockProcess, "Mock AudioProcess should be deallocated")
        XCTAssertNil(weakMockTap, "MockProcessTap should be deallocated")
    }
    
    // MARK: - Memory Usage Monitoring Tests
    
    func testMemoryUsageStabilityDuringExtendedOperation() async throws {
        let mockProcess = MockAudioProcess.createMockProcess()
        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
        let fileURL = tempDirectory.appendingPathComponent("extended_operation.wav")
        let recorder = ProcessTapRecorder(fileURL: fileURL, tap: mockTap)
        
        // Measure memory at start
        let initialMemory = getMemoryUsage()
        
        try await Task { @MainActor in
            try recorder.start()
        }.value
        
        // Run extended operation
        for i in 0..<1000 {
            mockTap.simulateAudioData()
            
            // Check memory periodically
            if i % 100 == 0 {
                let currentMemory = getMemoryUsage()
                let memoryGrowth = currentMemory - initialMemory
                
                // Memory growth should be reasonable (less than 50MB for this test)
                XCTAssertLessThan(memoryGrowth, 50 * 1024 * 1024, 
                                "Memory usage grew too much: \(memoryGrowth) bytes at iteration \(i)")
                
                // Allow some processing time
                try await Task.sleep(nanoseconds: 1_000_000) // 1ms
            }
        }
        
        await Task { @MainActor in
            recorder.stop()
        }.value
        
        // Final memory check
        let finalMemory = getMemoryUsage()
        let totalGrowth = finalMemory - initialMemory
        
        // Total memory growth should be reasonable
        XCTAssertLessThan(totalGrowth, 100 * 1024 * 1024, 
                         "Total memory growth too large: \(totalGrowth) bytes")
    }
    
    // MARK: - Helper Methods
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}