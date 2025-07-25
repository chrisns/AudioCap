import Foundation
import AudioToolbox
import AVFoundation
import OSLog

/// Utility class for creating test audio files and mock audio stream descriptions
final class AudioTestUtilities {
    
    private static let logger = Logger(subsystem: "com.audiocap.tests", category: "AudioTestUtilities")
    
    // MARK: - Test Audio File Creation
    
    /// Creates a test audio file with specified parameters
    /// - Parameters:
    ///   - duration: Duration of the test audio file in seconds (default: 1.0)
    ///   - sampleRate: Sample rate for the audio file (default: 44100)
    ///   - channels: Number of channels (default: 2 for stereo)
    ///   - frequency: Frequency of the test tone in Hz (default: 440 Hz - A4)
    /// - Returns: URL of the created test audio file
    static func createTestAudioFile(
        duration: TimeInterval = 1.0,
        sampleRate: Double = 44100,
        channels: UInt32 = 2,
        frequency: Double = 440.0
    ) throws -> URL {
        let tempDir = createTemporaryDirectory()
        let fileURL = tempDir.appendingPathComponent("test_audio_\(UUID().uuidString).wav")
        
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: false
        )!
        
        let file = try AVAudioFile(forWriting: fileURL, settings: format.settings)
        
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        
        // Generate test tone
        let channelCount = Int(channels)
        for channel in 0..<channelCount {
            let channelData = buffer.floatChannelData![channel]
            for frame in 0..<Int(frameCount) {
                let time = Double(frame) / sampleRate
                let amplitude: Float = 0.5 // 50% amplitude to avoid clipping
                let phase = 2.0 * Double.pi * frequency * time
                channelData[frame] = amplitude * Float(sin(phase))
            }
        }
        
        try file.write(from: buffer)
        
        logger.debug("Created test audio file at: \(fileURL.path)")
        return fileURL
    }
    
    /// Creates a silent test audio file
    /// - Parameters:
    ///   - duration: Duration of the silent audio file in seconds
    ///   - sampleRate: Sample rate for the audio file
    ///   - channels: Number of channels
    /// - Returns: URL of the created silent audio file
    static func createSilentTestAudioFile(
        duration: TimeInterval = 1.0,
        sampleRate: Double = 44100,
        channels: UInt32 = 2
    ) throws -> URL {
        let tempDir = createTemporaryDirectory()
        let fileURL = tempDir.appendingPathComponent("silent_test_\(UUID().uuidString).wav")
        
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: false
        )!
        
        let file = try AVAudioFile(forWriting: fileURL, settings: format.settings)
        
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        
        // Buffer is already zeroed by default, so no need to fill with silence
        try file.write(from: buffer)
        
        logger.debug("Created silent test audio file at: \(fileURL.path)")
        return fileURL
    }
    
    // MARK: - Mock Audio Stream Descriptions
    
    /// Creates a mock AudioStreamBasicDescription for testing
    /// - Parameters:
    ///   - sampleRate: Sample rate (default: 44100)
    ///   - channels: Number of channels (default: 2)
    ///   - formatID: Audio format ID (default: kAudioFormatLinearPCM)
    /// - Returns: Configured AudioStreamBasicDescription
    static func createMockAudioStreamDescription(
        sampleRate: Double = 44100,
        channels: UInt32 = 2,
        formatID: AudioFormatID = kAudioFormatLinearPCM
    ) -> AudioStreamBasicDescription {
        var description = AudioStreamBasicDescription()
        
        description.mSampleRate = sampleRate
        description.mFormatID = formatID
        description.mChannelsPerFrame = channels
        description.mBitsPerChannel = 32
        description.mBytesPerFrame = channels * 4 // 4 bytes per float32 sample
        description.mFramesPerPacket = 1
        description.mBytesPerPacket = description.mBytesPerFrame * description.mFramesPerPacket
        description.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved
        
        return description
    }
    
    /// Creates a mock AudioStreamBasicDescription for compressed audio formats
    /// - Parameters:
    ///   - sampleRate: Sample rate
    ///   - channels: Number of channels
    ///   - formatID: Compressed format ID (e.g., kAudioFormatMPEG4AAC)
    /// - Returns: Configured AudioStreamBasicDescription for compressed format
    static func createMockCompressedAudioStreamDescription(
        sampleRate: Double = 44100,
        channels: UInt32 = 2,
        formatID: AudioFormatID = kAudioFormatMPEG4AAC
    ) -> AudioStreamBasicDescription {
        var description = AudioStreamBasicDescription()
        
        description.mSampleRate = sampleRate
        description.mFormatID = formatID
        description.mChannelsPerFrame = channels
        description.mBitsPerChannel = 0 // Variable for compressed formats
        description.mBytesPerFrame = 0 // Variable for compressed formats
        description.mFramesPerPacket = 0 // Variable for compressed formats
        description.mBytesPerPacket = 0 // Variable for compressed formats
        description.mFormatFlags = 0 // Format-specific flags
        
        return description
    }
    
    // MARK: - Audio File Integrity Verification
    
    /// Verifies the integrity of an audio file
    /// - Parameter url: URL of the audio file to verify
    /// - Returns: true if the file is valid and readable, false otherwise
    static func verifyAudioFileIntegrity(at url: URL) -> Bool {
        do {
            let file = try AVAudioFile(forReading: url)
            
            // Basic integrity checks
            guard file.length > 0 else {
                logger.warning("Audio file has zero length: \(url.path)")
                return false
            }
            
            guard file.processingFormat.sampleRate > 0 else {
                logger.warning("Audio file has invalid sample rate: \(url.path)")
                return false
            }
            
            guard file.processingFormat.channelCount > 0 else {
                logger.warning("Audio file has invalid channel count: \(url.path)")
                return false
            }
            
            // Try to read a small buffer to ensure the file is readable
            let frameCount: AVAudioFrameCount = min(1024, AVAudioFrameCount(file.length))
            let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount)!
            try file.read(into: buffer, frameCount: frameCount)
            
            logger.debug("Audio file integrity verified: \(url.path)")
            return true
            
        } catch {
            logger.error("Audio file integrity check failed for \(url.path): \(error)")
            return false
        }
    }
    
    /// Verifies that an audio file matches expected properties
    /// - Parameters:
    ///   - url: URL of the audio file to verify
    ///   - expectedDuration: Expected duration in seconds (with tolerance)
    ///   - expectedSampleRate: Expected sample rate
    ///   - expectedChannels: Expected number of channels
    ///   - tolerance: Tolerance for duration comparison (default: 0.1 seconds)
    /// - Returns: true if the file matches expected properties
    static func verifyAudioFileProperties(
        at url: URL,
        expectedDuration: TimeInterval,
        expectedSampleRate: Double,
        expectedChannels: UInt32,
        tolerance: TimeInterval = 0.1
    ) -> Bool {
        do {
            let file = try AVAudioFile(forReading: url)
            
            let actualDuration = Double(file.length) / file.processingFormat.sampleRate
            let actualSampleRate = file.processingFormat.sampleRate
            let actualChannels = file.processingFormat.channelCount
            
            let durationMatch = abs(actualDuration - expectedDuration) <= tolerance
            let sampleRateMatch = actualSampleRate == expectedSampleRate
            let channelsMatch = actualChannels == expectedChannels
            
            if !durationMatch {
                logger.warning("Duration mismatch: expected \(expectedDuration), got \(actualDuration)")
            }
            if !sampleRateMatch {
                logger.warning("Sample rate mismatch: expected \(expectedSampleRate), got \(actualSampleRate)")
            }
            if !channelsMatch {
                logger.warning("Channel count mismatch: expected \(expectedChannels), got \(actualChannels)")
            }
            
            return durationMatch && sampleRateMatch && channelsMatch
            
        } catch {
            logger.error("Failed to verify audio file properties: \(error)")
            return false
        }
    }
    
    // MARK: - Test File Cleanup
    
    private static var createdDirectories: Set<URL> = []
    private static let cleanupQueue = DispatchQueue(label: "AudioTestUtilities.cleanup")
    
    /// Creates a temporary directory for test files
    /// - Returns: URL of the created temporary directory
    static func createTemporaryDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AudioCapTests")
            .appendingPathComponent(UUID().uuidString)
        
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            _ = cleanupQueue.sync {
                createdDirectories.insert(tempDir)
            }
            logger.debug("Created temporary directory: \(tempDir.path)")
        } catch {
            logger.error("Failed to create temporary directory: \(error)")
        }
        
        return tempDir
    }
    
    /// Cleans up all test files and directories created during testing
    static func cleanupTestFiles() {
        cleanupQueue.sync {
            for directory in createdDirectories {
                do {
                    if FileManager.default.fileExists(atPath: directory.path) {
                        try FileManager.default.removeItem(at: directory)
                        logger.debug("Cleaned up test directory: \(directory.path)")
                    }
                } catch {
                    logger.error("Failed to cleanup test directory \(directory.path): \(error)")
                }
            }
            createdDirectories.removeAll()
        }
    }
    
    /// Cleans up a specific test file or directory
    /// - Parameter url: URL of the file or directory to clean up
    static func cleanupTestFile(at url: URL) {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
                logger.debug("Cleaned up test file: \(url.path)")
            }
        } catch {
            logger.error("Failed to cleanup test file \(url.path): \(error)")
        }
    }
    
    // MARK: - Audio Buffer Utilities
    
    /// Creates a test PCM buffer with a sine wave
    /// - Parameters:
    ///   - format: Audio format for the buffer
    ///   - frameCount: Number of frames in the buffer
    ///   - frequency: Frequency of the sine wave
    /// - Returns: Configured AVAudioPCMBuffer
    static func createTestPCMBuffer(
        format: AVAudioFormat,
        frameCount: AVAudioFrameCount,
        frequency: Double = 440.0
    ) -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        
        buffer.frameLength = frameCount
        
        let channelCount = Int(format.channelCount)
        let sampleRate = format.sampleRate
        
        for channel in 0..<channelCount {
            guard let channelData = buffer.floatChannelData?[channel] else { continue }
            
            for frame in 0..<Int(frameCount) {
                let time = Double(frame) / sampleRate
                let amplitude: Float = 0.5
                let phase = 2.0 * Double.pi * frequency * time
                channelData[frame] = amplitude * Float(sin(phase))
            }
        }
        
        return buffer
    }
}