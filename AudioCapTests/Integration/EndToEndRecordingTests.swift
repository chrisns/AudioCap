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

/// Integration tests for end-to-end recording workflow
final class EndToEndRecordingTests: XCTestCase {
    
    private let logger = Logger(subsystem: "com.audiocap.tests", category: "EndToEndRecordingTests")
    private var tempDirectory: URL!
    private var mockProcessController: AudioProcessController!
    
    override func setUp() {
        super.setUp()
        tempDirectory = TestHelpers.createTemporaryDirectory(prefix: "EndToEndRecordingTests")
        mockProcessController = AudioProcessController()
    }
    
    override func tearDown() {
        TestHelpers.cleanupTemporaryDirectory(at: tempDirectory)
        AudioTestUtilities.cleanupTestFiles()
        super.tearDown()
    }
    
    // MARK: - Complete Recording Session Tests
    
    /// Tests complete recording session from start to file creation
    /// Requirements: 5.1
    func testCompleteRecordingSessionWorkflow() async throws {
        // Given: A mock process and recording setup
        let mockProcess = MockAudioProcess.createMockProcess(
            id: 1234,
            name: "Test Audio App",
            audioActive: true,
            bundleID: "com.test.audioapp"
        )
        
        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
        
        // Configure mock tap for successful operation
        mockTap.shouldFailActivation = false
        mockTap.shouldFailRunning = false
        
        // When: Activating the tap
        await mockTap.activate()
        
        // Then: Tap should be activated successfully
        XCTAssertEqual(mockTap.activationCallCount, 1)
        XCTAssertNil(mockTap.errorMessage)
        XCTAssertNotNil(mockTap.tapStreamDescription)
        
        // When: Starting recording
        let recordingURL = tempDirectory.appendingPathComponent("test_recording.wav")
        let recorder = ProcessTapRecorder(fileURL: recordingURL, tap: mockTap)
        
        try await recorder.start()
        
        // Then: Recording should be active
        XCTAssertTrue(recorder.isRecording)
        XCTAssertEqual(recorder.fileURL, recordingURL)
        
        // When: Simulating audio data
        mockTap.simulateAudioData()
        
        // Allow some time for audio processing
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // When: Stopping recording
        recorder.stop()
        
        // Then: Recording should be stopped and file should exist
        XCTAssertFalse(recorder.isRecording)
        XCTAssertTrue(FileManager.default.fileExists(atPath: recordingURL.path))
        
        // Verify file integrity
        XCTAssertTrue(AudioTestUtilities.verifyAudioFileIntegrity(at: recordingURL))
        
        // When: Cleaning up
        mockTap.invalidate()
        
        // Then: Cleanup should be successful
        XCTAssertEqual(mockTap.invalidationCallCount, 1)
    }
    
    /// Tests recording session with specific duration and format requirements
    /// Requirements: 5.1, 5.2
    func testRecordingSessionWithSpecificFormat() async throws {
        // Given: A mock process with specific audio format
        let mockProcess = MockAudioProcess.createMockProcess(
            id: 5678,
            name: "High Quality Audio App",
            audioActive: true
        )
        
        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
        
        // Configure specific audio format
        let customStreamDescription = AudioTestUtilities.createMockAudioStreamDescription(
            sampleRate: 48000,
            channels: 2,
            formatID: kAudioFormatLinearPCM
        )
        mockTap.mockStreamDescription = customStreamDescription
        
        // When: Activating and starting recording
        await mockTap.activate()
        
        let recordingURL = tempDirectory.appendingPathComponent("high_quality_recording.wav")
        let recorder = ProcessTapRecorder(fileURL: recordingURL, tap: mockTap)
        try await recorder.start()
        
        // Simulate recording for a specific duration
        let recordingDuration: TimeInterval = 2.0
        let simulationInterval: TimeInterval = 0.1
        let iterations = Int(recordingDuration / simulationInterval)
        
        for _ in 0..<iterations {
            mockTap.simulateAudioData()
            try await Task.sleep(nanoseconds: UInt64(simulationInterval * 1_000_000_000))
        }
        
        // When: Stopping recording
        recorder.stop()
        
        // Then: Verify file properties match expected format
        XCTAssertTrue(AudioTestUtilities.verifyAudioFileProperties(
            at: recordingURL,
            expectedDuration: recordingDuration,
            expectedSampleRate: 48000,
            expectedChannels: 2,
            tolerance: 0.5 // Allow some tolerance for timing
        ))
        
        mockTap.invalidate()
    }
    
    /// Tests concurrent recording prevention
    /// Requirements: 5.1
    func testConcurrentRecordingPrevention() async throws {
        // Given: A mock process and recorder
        let mockProcess = MockAudioProcess.createMockProcess()
        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
        
        await mockTap.activate()
        
        let firstRecordingURL = tempDirectory.appendingPathComponent("first_recording.wav")
        let secondRecordingURL = tempDirectory.appendingPathComponent("second_recording.wav")
        
        // When: Starting first recording
        let recorder1 = ProcessTapRecorder(fileURL: firstRecordingURL, tap: mockTap)
        try await recorder1.start()
        XCTAssertTrue(recorder1.isRecording)
        
        // When: Attempting to start second recording with same tap
        // Then: Should throw error for concurrent recording
        let recorder2 = ProcessTapRecorder(fileURL: secondRecordingURL, tap: mockTap)
        await XCTAssertThrowsError(try await recorder2.start()) { error in
            XCTAssertTrue(error.localizedDescription.contains("already") || 
                         error.localizedDescription.contains("active") ||
                         error.localizedDescription.contains("running"))
        }
        
        // Cleanup
        recorder1.stop()
        mockTap.invalidate()
    }
    
    // MARK: - File Operations and Directory Handling Tests
    
    /// Tests application support directory handling
    /// Requirements: 5.2
    func testApplicationSupportDirectoryHandling() async throws {
        // Given: A mock process and recorder
        let mockProcess = MockAudioProcess.createMockProcess()
        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
        
        await mockTap.activate()
        
        // When: Creating recording in application support directory structure
        let appSupportDir = tempDirectory.appendingPathComponent("Application Support/AudioCap")
        try FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        
        let recordingURL = appSupportDir.appendingPathComponent("app_support_recording.wav")
        
        // When: Recording to application support directory
        let recorder = ProcessTapRecorder(fileURL: recordingURL, tap: mockTap)
        try await recorder.start()
        mockTap.simulateAudioData()
        
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        recorder.stop()
        
        // Then: File should be created in correct location
        XCTAssertTrue(FileManager.default.fileExists(atPath: recordingURL.path))
        XCTAssertTrue(AudioTestUtilities.verifyAudioFileIntegrity(at: recordingURL))
        
        // Verify directory structure
        XCTAssertTrue(FileManager.default.fileExists(atPath: appSupportDir.path))
        
        mockTap.invalidate()
    }
    
    /// Tests file operations with various file formats
    /// Requirements: 5.2
    func testFileOperationsWithDifferentFormats() async throws {
        // Given: A mock process and tap
        let mockProcess = MockAudioProcess.createMockProcess()
        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
        
        await mockTap.activate()
        
        let testFormats: [(String, AudioStreamBasicDescription)] = [
            ("wav_44100_stereo.wav", AudioTestUtilities.createMockAudioStreamDescription(sampleRate: 44100, channels: 2)),
            ("wav_48000_mono.wav", AudioTestUtilities.createMockAudioStreamDescription(sampleRate: 48000, channels: 1)),
            ("wav_96000_stereo.wav", AudioTestUtilities.createMockAudioStreamDescription(sampleRate: 96000, channels: 2))
        ]
        
        for (filename, streamDescription) in testFormats {
            // When: Recording with different formats
            let recordingURL = tempDirectory.appendingPathComponent(filename)
            mockTap.mockStreamDescription = streamDescription
            
            let recorder = ProcessTapRecorder(fileURL: recordingURL, tap: mockTap)
            try await recorder.start()
            mockTap.simulateAudioData()
            
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            recorder.stop()
            
            // Then: File should be created with correct format
            XCTAssertTrue(FileManager.default.fileExists(atPath: recordingURL.path))
            XCTAssertTrue(AudioTestUtilities.verifyAudioFileIntegrity(at: recordingURL))
            
            // Verify format properties
            let file = try AVAudioFile(forReading: recordingURL)
            XCTAssertEqual(file.processingFormat.sampleRate, streamDescription.mSampleRate)
            XCTAssertEqual(file.processingFormat.channelCount, streamDescription.mChannelsPerFrame)
        }
        
        mockTap.invalidate()
    }
    
    // MARK: - Audio Format Integrity Tests
    
    /// Tests audio format integrity throughout the pipeline
    /// Requirements: 5.5
    func testAudioFormatIntegrityThroughPipeline() async throws {
        // Given: A mock process with specific audio format
        let mockProcess = MockAudioProcess.createMockProcess()
        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
        
        // Define expected format
        let expectedFormat = AudioTestUtilities.createMockAudioStreamDescription(
            sampleRate: 44100,
            channels: 2,
            formatID: kAudioFormatLinearPCM
        )
        mockTap.mockStreamDescription = expectedFormat
        
        await mockTap.activate()
        
        // When: Recording with the expected format
        let recordingURL = tempDirectory.appendingPathComponent("format_integrity_test.wav")
        let recorder = ProcessTapRecorder(fileURL: recordingURL, tap: mockTap)
        try await recorder.start()
        
        // Simulate multiple audio data chunks
        for _ in 0..<10 {
            mockTap.simulateAudioData()
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        }
        
        recorder.stop()
        
        // Then: Verify format integrity at each stage
        
        // 1. Verify tap stream description matches expected
        XCTAssertEqual(mockTap.tapStreamDescription?.mSampleRate, expectedFormat.mSampleRate)
        XCTAssertEqual(mockTap.tapStreamDescription?.mChannelsPerFrame, expectedFormat.mChannelsPerFrame)
        XCTAssertEqual(mockTap.tapStreamDescription?.mFormatID, expectedFormat.mFormatID)
        
        // 2. Verify recorded file format matches expected
        let recordedFile = try AVAudioFile(forReading: recordingURL)
        XCTAssertEqual(recordedFile.processingFormat.sampleRate, expectedFormat.mSampleRate)
        XCTAssertEqual(recordedFile.processingFormat.channelCount, expectedFormat.mChannelsPerFrame)
        
        // 3. Verify file can be read back without format conversion issues
        let buffer = AVAudioPCMBuffer(pcmFormat: recordedFile.processingFormat, frameCapacity: 1024)!
        try recordedFile.read(into: buffer)
        XCTAssertGreaterThan(buffer.frameLength, 0)
        
        mockTap.invalidate()
    }
    
    /// Tests format conversion handling
    /// Requirements: 5.5
    func testFormatConversionHandling() async throws {
        // Given: A mock process with different input and output formats
        let mockProcess = MockAudioProcess.createMockProcess()
        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
        
        // Input format: 48kHz, 1 channel
        let inputFormat = AudioTestUtilities.createMockAudioStreamDescription(
            sampleRate: 48000,
            channels: 1
        )
        mockTap.mockStreamDescription = inputFormat
        
        await mockTap.activate()
        
        // When: Recording (ProcessTapRecorder should handle format appropriately)
        let recordingURL = tempDirectory.appendingPathComponent("format_conversion_test.wav")
        let recorder = ProcessTapRecorder(fileURL: recordingURL, tap: mockTap)
        try await recorder.start()
        
        mockTap.simulateAudioData()
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        recorder.stop()
        
        // Then: Verify the recorded file maintains quality
        XCTAssertTrue(AudioTestUtilities.verifyAudioFileIntegrity(at: recordingURL))
        
        let recordedFile = try AVAudioFile(forReading: recordingURL)
        XCTAssertGreaterThan(recordedFile.length, 0)
        
        // Verify we can read the entire file without errors
        let totalFrames = recordedFile.length
        let buffer = AVAudioPCMBuffer(pcmFormat: recordedFile.processingFormat, frameCapacity: AVAudioFrameCount(totalFrames))!
        try recordedFile.read(into: buffer, frameCount: AVAudioFrameCount(totalFrames))
        
        mockTap.invalidate()
    }
    
    // MARK: - Error Propagation Tests
    
    /// Tests error propagation between components
    /// Requirements: 5.5
    func testErrorPropagationBetweenComponents() async throws {
        // Given: A mock process configured to fail at different stages
        let mockProcess = MockAudioProcess.createMockProcess()
        
        // Test 1: Activation failure propagation
        let failingActivationTap = MockProcessTap.createFailingActivationTap(process: mockProcess)
        await failingActivationTap.activate()
        
        XCTAssertNotNil(failingActivationTap.errorMessage)
        XCTAssertTrue(failingActivationTap.errorMessage!.contains("Mock activation failure"))
        
        // Test 2: Recording failure propagation
        let failingRunTap = MockProcessTap.createFailingRunTap(process: mockProcess)
        await failingRunTap.activate() // This should succeed
        XCTAssertNil(failingRunTap.errorMessage)
        
        // Attempt to run should fail
        XCTAssertThrowsError(try failingRunTap.run(on: DispatchQueue.global(), ioBlock: { _, _, _, _, _ in }, invalidationHandler: { _ in })) { error in
            XCTAssertTrue(error.localizedDescription.contains("Mock run failure"))
        }
        
        // Test 3: File system error propagation
        let workingTap = MockProcessTap.createMockTap(process: mockProcess)
        let recorder = ProcessTapRecorder()
        
        await workingTap.activate()
        
        // Try to record to an invalid path
        let invalidURL = URL(fileURLWithPath: "/invalid/path/that/does/not/exist/recording.wav")
        
        XCTAssertThrowsError(try recorder.startRecording(to: invalidURL, with: workingTap.tapStreamDescription!)) { error in
            // Should propagate file system error
            XCTAssertTrue(error.localizedDescription.contains("No such file") || 
                         error.localizedDescription.contains("directory") ||
                         error.localizedDescription.contains("path"))
        }
        
        workingTap.invalidate()
        failingActivationTap.invalidate()
        failingRunTap.invalidate()
    }
    
    /// Tests error recovery scenarios
    /// Requirements: 5.5
    func testErrorRecoveryScenarios() async throws {
        // Given: A mock process that initially fails but can recover
        let mockProcess = MockAudioProcess.createMockProcess()
        let mockTap = MockProcessTap.createMockTap(process: mockProcess)
        let recorder = ProcessTapRecorder()
        
        // Test 1: Recovery from activation failure
        mockTap.shouldFailActivation = true
        await mockTap.activate()
        XCTAssertNotNil(mockTap.errorMessage)
        
        // Recovery: Fix the issue and try again
        mockTap.shouldFailActivation = false
        mockTap.resetMockState()
        await mockTap.activate()
        XCTAssertNil(mockTap.errorMessage)
        XCTAssertEqual(mockTap.activationCallCount, 1)
        
        // Test 2: Recovery from recording failure
        let recordingURL = tempDirectory.appendingPathComponent("recovery_test.wav")
        let streamDescription = mockTap.tapStreamDescription!
        
        // First attempt should succeed
        try recorder.startRecording(to: recordingURL, with: streamDescription)
        XCTAssertTrue(recorder.isRecording)
        
        // Stop and try again (should work)
        try recorder.stopRecording()
        XCTAssertFalse(recorder.isRecording)
        
        // Second recording attempt
        let secondRecordingURL = tempDirectory.appendingPathComponent("recovery_test_2.wav")
        try recorder.startRecording(to: secondRecordingURL, with: streamDescription)
        XCTAssertTrue(recorder.isRecording)
        
        mockTap.simulateAudioData()
        try await Task.sleep(nanoseconds: 200_000_000)
        try recorder.stopRecording()
        
        // Verify both files exist and are valid
        XCTAssertTrue(FileManager.default.fileExists(atPath: recordingURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: secondRecordingURL.path))
        XCTAssertTrue(AudioTestUtilities.verifyAudioFileIntegrity(at: secondRecordingURL))
        
        mockTap.invalidate()
    }
}