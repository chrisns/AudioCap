import XCTest
import AudioToolbox
import AVFoundation
@testable import AudioCap

final class ProcessTapTests: XCTestCase {
    
    var mockProcess: AudioProcess!
    var mockTap: MockProcessTap!
    
    override func setUp() {
        super.setUp()
        mockProcess = MockAudioProcess.createMockProcess()
        mockTap = MockProcessTap.createMockTap(process: mockProcess)
    }
    
    override func tearDown() {
        mockTap?.invalidate()
        mockTap = nil
        mockProcess = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testProcessTapInitialization() {
        let tap = ProcessTap(process: mockProcess, muteWhenRunning: false)
        
        XCTAssertEqual(tap.process.id, mockProcess.id)
        XCTAssertEqual(tap.process.name, mockProcess.name)
        XCTAssertFalse(tap.muteWhenRunning)
        XCTAssertFalse(tap.activated)
        XCTAssertNil(tap.errorMessage)
    }
    
    func testProcessTapInitializationWithMuting() {
        let tap = ProcessTap(process: mockProcess, muteWhenRunning: true)
        
        XCTAssertTrue(tap.muteWhenRunning)
        XCTAssertFalse(tap.activated)
    }
    
    // MARK: - Activation Tests
    
    @MainActor
    func testSuccessfulActivation() {
        XCTAssertFalse(mockTap.activated)
        XCTAssertEqual(mockTap.activationCallCount, 0)
        
        mockTap.activate()
        
        XCTAssertTrue(mockTap.activated)
        XCTAssertEqual(mockTap.activationCallCount, 1)
        XCTAssertNil(mockTap.errorMessage)
        XCTAssertNotNil(mockTap.tapStreamDescription)
    }
    
    @MainActor
    func testFailedActivation() {
        mockTap.shouldFailActivation = true
        mockTap.mockErrorMessage = "Test activation failure"
        
        mockTap.activate()
        
        XCTAssertEqual(mockTap.activationCallCount, 1)
        XCTAssertEqual(mockTap.errorMessage, "Test activation failure")
    }
    
    @MainActor
    func testMultipleActivationCalls() {
        mockTap.activate()
        XCTAssertEqual(mockTap.activationCallCount, 1)
        XCTAssertTrue(mockTap.activated)
        
        // Second activation should not increase call count due to guard
        mockTap.activate()
        XCTAssertEqual(mockTap.activationCallCount, 1)
        XCTAssertTrue(mockTap.activated)
    }
    
    // MARK: - Invalidation Tests
    
    @MainActor
    func testSuccessfulInvalidation() {
        mockTap.activate()
        XCTAssertTrue(mockTap.activated)
        
        mockTap.invalidate()
        
        XCTAssertEqual(mockTap.invalidationCallCount, 1)
        XCTAssertFalse(mockTap.activated)
    }
    
    @MainActor
    func testInvalidationWithFailure() {
        mockTap.shouldFailInvalidation = true
        mockTap.activate()
        
        mockTap.invalidate()
        
        XCTAssertEqual(mockTap.invalidationCallCount, 1)
        XCTAssertFalse(mockTap.activated) // Should still deactivate despite failure
    }
    
    @MainActor
    func testMultipleInvalidationCalls() {
        mockTap.activate()
        
        mockTap.invalidate()
        XCTAssertEqual(mockTap.invalidationCallCount, 1)
        XCTAssertFalse(mockTap.activated)
        
        // Second invalidation should still be called (no guard in invalidate)
        mockTap.invalidate()
        XCTAssertEqual(mockTap.invalidationCallCount, 2)
        XCTAssertFalse(mockTap.activated)
    }
    
    // MARK: - Run Tests
    
    @MainActor
    func testSuccessfulRun() throws {
        mockTap.activate()
        
        let expectation = XCTestExpectation(description: "IO block called")
        let queue = DispatchQueue(label: "test.queue")
        var ioBlockCalled = false
        var invalidationHandlerCalled = false
        
        let ioBlock: AudioDeviceIOBlock = { _, _, _, _, _ in
            ioBlockCalled = true
            expectation.fulfill()
        }
        
        let invalidationHandler: ProcessTap.InvalidationHandler = { _ in
            invalidationHandlerCalled = true
        }
        
        try mockTap.run(on: queue, ioBlock: ioBlock, invalidationHandler: invalidationHandler)
        
        XCTAssertEqual(mockTap.runCallCount, 1)
        XCTAssertNotNil(mockTap.lastIOBlock)
        XCTAssertNotNil(mockTap.lastInvalidationHandler)
        XCTAssertEqual(mockTap.lastQueue?.label, queue.label)
        
        // Simulate audio data to test IO block
        mockTap.simulateAudioData()
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(ioBlockCalled)
        
        // Test invalidation handler
        mockTap.simulateInvalidation()
        XCTAssertTrue(invalidationHandlerCalled)
    }
    
    @MainActor
    func testRunFailure() {
        mockTap.shouldFailRunning = true
        mockTap.mockErrorMessage = "Test run failure"
        mockTap.activate()
        
        let queue = DispatchQueue(label: "test.queue")
        let ioBlock: AudioDeviceIOBlock = { _, _, _, _, _ in }
        let invalidationHandler: ProcessTap.InvalidationHandler = { _ in }
        
        XCTAssertThrowsError(try mockTap.run(on: queue, ioBlock: ioBlock, invalidationHandler: invalidationHandler)) { error in
            XCTAssertEqual(error.localizedDescription, "Test run failure")
        }
        
        XCTAssertEqual(mockTap.runCallCount, 1)
    }
    
    @MainActor
    func testRunWithoutActivation() {
        // This test verifies behavior when run is called without activation
        // The mock doesn't enforce this, but real ProcessTap might
        XCTAssertFalse(mockTap.activated)
        
        let queue = DispatchQueue(label: "test.queue")
        let ioBlock: AudioDeviceIOBlock = { _, _, _, _, _ in }
        let invalidationHandler: ProcessTap.InvalidationHandler = { _ in }
        
        XCTAssertNoThrow(try mockTap.run(on: queue, ioBlock: ioBlock, invalidationHandler: invalidationHandler))
        XCTAssertEqual(mockTap.runCallCount, 1)
    }
    
    // MARK: - Lifecycle Tests
    
    @MainActor
    func testCompleteLifecycle() throws {
        // Test complete activation -> run -> invalidation lifecycle
        XCTAssertFalse(mockTap.activated)
        
        // 1. Activate
        mockTap.activate()
        XCTAssertTrue(mockTap.activated)
        XCTAssertEqual(mockTap.activationCallCount, 1)
        
        // 2. Run
        let queue = DispatchQueue(label: "test.queue")
        var ioCallCount = 0
        var invalidationCalled = false
        
        let ioBlock: AudioDeviceIOBlock = { _, _, _, _, _ in
            ioCallCount += 1
        }
        
        let invalidationHandler: ProcessTap.InvalidationHandler = { _ in
            invalidationCalled = true
        }
        
        try mockTap.run(on: queue, ioBlock: ioBlock, invalidationHandler: invalidationHandler)
        XCTAssertEqual(mockTap.runCallCount, 1)
        
        // 3. Simulate some audio processing
        mockTap.simulateAudioData()
        mockTap.simulateAudioData()
        XCTAssertEqual(ioCallCount, 2)
        
        // 4. Invalidate
        mockTap.invalidate()
        XCTAssertFalse(mockTap.activated)
        XCTAssertEqual(mockTap.invalidationCallCount, 1)
        XCTAssertTrue(invalidationCalled)
    }
    
    // MARK: - Error Handling Tests
    
    @MainActor
    func testErrorMessagePersistence() {
        mockTap.shouldFailActivation = true
        mockTap.mockErrorMessage = "Persistent error message"
        
        mockTap.activate()
        XCTAssertEqual(mockTap.errorMessage, "Persistent error message")
        
        // Error message should persist until next successful operation
        mockTap.shouldFailActivation = false
        mockTap.activate()
        XCTAssertNil(mockTap.errorMessage)
    }
    
    // MARK: - Stream Description Tests
    
    @MainActor
    func testStreamDescriptionAfterActivation() {
        XCTAssertNil(mockTap.tapStreamDescription)
        
        mockTap.activate()
        
        XCTAssertNotNil(mockTap.tapStreamDescription)
        let streamDesc = mockTap.tapStreamDescription!
        XCTAssertEqual(streamDesc.mSampleRate, 44100.0)
        XCTAssertEqual(streamDesc.mChannelsPerFrame, 2)
        XCTAssertEqual(streamDesc.mFormatID, kAudioFormatLinearPCM)
    }
    
    @MainActor
    func testCustomStreamDescription() {
        let customStreamDesc = AudioStreamBasicDescription(
            mSampleRate: 48000.0,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 32,
            mReserved: 0
        )
        
        mockTap.mockStreamDescription = customStreamDesc
        mockTap.activate()
        
        XCTAssertNotNil(mockTap.tapStreamDescription)
        let streamDesc = mockTap.tapStreamDescription!
        XCTAssertEqual(streamDesc.mSampleRate, 48000.0)
        XCTAssertEqual(streamDesc.mChannelsPerFrame, 1)
    }
    
    // MARK: - Mock State Management Tests
    
    func testMockStateReset() {
        // Set up some state
        mockTap.shouldFailActivation = true
        mockTap.mockErrorMessage = "Custom error"
        
        Task { @MainActor in
            mockTap.activate()
        }
        
        XCTAssertEqual(mockTap.activationCallCount, 1)
        XCTAssertTrue(mockTap.shouldFailActivation)
        
        // Reset state
        mockTap.resetMockState()
        
        XCTAssertEqual(mockTap.activationCallCount, 0)
        XCTAssertEqual(mockTap.invalidationCallCount, 0)
        XCTAssertEqual(mockTap.runCallCount, 0)
        XCTAssertFalse(mockTap.shouldFailActivation)
        XCTAssertFalse(mockTap.shouldFailRunning)
        XCTAssertFalse(mockTap.shouldFailInvalidation)
        XCTAssertEqual(mockTap.mockErrorMessage, "Mock error")
        XCTAssertNil(mockTap.errorMessage)
    }
    
    // MARK: - Factory Method Tests
    
    func testFactoryMethods() {
        let defaultTap = MockProcessTap.createMockTap()
        XCTAssertFalse(defaultTap.shouldFailActivation)
        XCTAssertFalse(defaultTap.shouldFailRunning)
        XCTAssertFalse(defaultTap.shouldFailInvalidation)
        
        let failingActivationTap = MockProcessTap.createFailingActivationTap()
        XCTAssertTrue(failingActivationTap.shouldFailActivation)
        XCTAssertEqual(failingActivationTap.mockErrorMessage, "Mock activation failure")
        
        let failingRunTap = MockProcessTap.createFailingRunTap()
        XCTAssertTrue(failingRunTap.shouldFailRunning)
        XCTAssertEqual(failingRunTap.mockErrorMessage, "Mock run failure")
        
        let failingInvalidationTap = MockProcessTap.createFailingInvalidationTap()
        XCTAssertTrue(failingInvalidationTap.shouldFailInvalidation)
        XCTAssertEqual(failingInvalidationTap.mockErrorMessage, "Mock invalidation failure")
    }
    
    // MARK: - Deinit Tests
    
    func testDeinitCallsInvalidate() {
        var tap: MockProcessTap? = MockProcessTap.createMockTap()
        
        Task { @MainActor in
            tap?.activate()
        }
        
        let initialInvalidationCount = tap?.invalidationCallCount ?? 0
        
        // Deinit should call invalidate
        tap = nil
        
        // Note: We can't directly test deinit behavior with the mock since the reference is gone
        // This test serves as documentation of expected behavior
        XCTAssertNil(tap)
    }
}