import Foundation
import AudioToolbox
import AVFoundation
@testable import AudioCap

/// Mock implementation of ProcessTap for testing purposes
class MockProcessTap: ProcessTap {
    
    // MARK: - Mock Configuration Properties
    
    /// Controls whether activation should fail
    var shouldFailActivation: Bool = false
    
    /// Controls whether running should fail
    var shouldFailRunning: Bool = false
    
    /// Controls whether invalidation should fail
    var shouldFailInvalidation: Bool = false
    
    /// Mock stream description to return
    var mockStreamDescription: AudioStreamBasicDescription?
    
    /// Error message to use when failures are simulated
    var mockErrorMessage: String = "Mock error"
    
    // MARK: - Mock State Tracking
    
    /// Tracks activation calls
    private(set) var activationCallCount: Int = 0
    
    /// Tracks invalidation calls
    private(set) var invalidationCallCount: Int = 0
    
    /// Tracks run calls
    private(set) var runCallCount: Int = 0
    
    /// Stores the last IO block passed to run
    private(set) var lastIOBlock: AudioDeviceIOBlock?
    
    /// Stores the last invalidation handler passed to run
    private(set) var lastInvalidationHandler: InvalidationHandler?
    
    /// Stores the last queue passed to run
    private(set) var lastQueue: DispatchQueue?
    
    // MARK: - Initialization
    
    override init(process: AudioProcess, muteWhenRunning: Bool = false) {
        super.init(process: process, muteWhenRunning: muteWhenRunning)
        
        // Set up mock stream description if not provided
        if mockStreamDescription == nil {
            mockStreamDescription = AudioStreamBasicDescription(
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
        }
    }
    
    // MARK: - Overridden Methods
    
    @MainActor
    override func activate() {
        activationCallCount += 1
        
        if shouldFailActivation {
            self.errorMessage = mockErrorMessage
            return
        }
        
        // Simulate successful activation
        self.errorMessage = nil
        self.tapStreamDescription = mockStreamDescription
        
        // Call super to maintain proper state
        super.activate()
    }
    
    override func invalidate() {
        invalidationCallCount += 1
        
        if shouldFailInvalidation {
            // In a real scenario, we might log an error but still proceed with cleanup
            print("Mock invalidation failure: \(mockErrorMessage)")
        }
        
        // Always call super to maintain proper cleanup
        super.invalidate()
    }
    
    override func run(on queue: DispatchQueue, ioBlock: @escaping AudioDeviceIOBlock, invalidationHandler: @escaping InvalidationHandler) throws {
        runCallCount += 1
        lastQueue = queue
        lastIOBlock = ioBlock
        lastInvalidationHandler = invalidationHandler
        
        if shouldFailRunning {
            throw mockErrorMessage
        }
        
        // Don't call super.run() as it would try to interact with real CoreAudio
        // Instead, simulate the behavior we need for testing
    }
    
    // MARK: - Mock Helper Methods
    
    /// Simulates calling the IO block with mock audio data
    func simulateAudioData() {
        guard let ioBlock = lastIOBlock else { return }
        
        // Create mock audio buffer list
        let bufferSize: UInt32 = 1024
        let channelCount: UInt32 = 2
        
        let audioBufferList = AudioBufferList.allocate(maximumBuffers: Int(channelCount))
        defer { audioBufferList.deallocate() }
        
        for i in 0..<Int(channelCount) {
            audioBufferList[i] = AudioBuffer(
                mNumberChannels: 1,
                mDataByteSize: bufferSize * 4, // 4 bytes per float32 sample
                mData: UnsafeMutableRawPointer.allocate(byteCount: Int(bufferSize * 4), alignment: 4)
            )
        }
        
        // Create mock timestamps
        let now = AudioTimeStamp()
        let inputTime = AudioTimeStamp()
        let outputTime = AudioTimeStamp()
        
        // Call the IO block
        ioBlock(now, audioBufferList.unsafeMutablePointer, inputTime, audioBufferList.unsafeMutablePointer, outputTime)
        
        // Clean up allocated memory
        for i in 0..<Int(channelCount) {
            audioBufferList[i].mData?.deallocate()
        }
    }
    
    /// Simulates invalidation by calling the invalidation handler
    func simulateInvalidation() {
        lastInvalidationHandler?(self)
    }
    
    /// Resets all mock state for clean testing
    func resetMockState() {
        activationCallCount = 0
        invalidationCallCount = 0
        runCallCount = 0
        lastIOBlock = nil
        lastInvalidationHandler = nil
        lastQueue = nil
        shouldFailActivation = false
        shouldFailRunning = false
        shouldFailInvalidation = false
        mockErrorMessage = "Mock error"
        errorMessage = nil
    }
    
    // MARK: - Factory Methods
    
    /// Creates a mock ProcessTap with default configuration
    static func createMockTap(process: AudioProcess? = nil) -> MockProcessTap {
        let mockProcess = process ?? MockAudioProcess.createMockProcess()
        return MockProcessTap(process: mockProcess)
    }
    
    /// Creates a mock ProcessTap configured to fail activation
    static func createFailingActivationTap(process: AudioProcess? = nil) -> MockProcessTap {
        let tap = createMockTap(process: process)
        tap.shouldFailActivation = true
        tap.mockErrorMessage = "Mock activation failure"
        return tap
    }
    
    /// Creates a mock ProcessTap configured to fail running
    static func createFailingRunTap(process: AudioProcess? = nil) -> MockProcessTap {
        let tap = createMockTap(process: process)
        tap.shouldFailRunning = true
        tap.mockErrorMessage = "Mock run failure"
        return tap
    }
    
    /// Creates a mock ProcessTap configured to fail invalidation
    static func createFailingInvalidationTap(process: AudioProcess? = nil) -> MockProcessTap {
        let tap = createMockTap(process: process)
        tap.shouldFailInvalidation = true
        tap.mockErrorMessage = "Mock invalidation failure"
        return tap
    }
}