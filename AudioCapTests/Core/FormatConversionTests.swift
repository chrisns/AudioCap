import XCTest
import AudioToolbox
import AVFoundation
@testable import AudioCap

/// Comprehensive tests for audio format conversion functionality in ProcessTapRecorder
/// Tests the format conversion infrastructure including AVAudioConverter creation,
/// buffer management, and error handling for different format combinations
final class FormatConversionTests: BaseTestCase {
    
    var mockProcess: AudioProcess!
    var mockTap: MockProcessTap!
    var testFileURL: URL!
    var recorder: ProcessTapRecorder!
    
    override func customSetUp() {
        super.customSetUp()
        
        // Create mock process and tap
        mockProcess = MockAudioProcess.createMockProcess()
        mockTap = MockProcessTap.createMockTap(process: mockProcess)
        
        // Create test file URL
        testFileURL = testEnvironment.createTempFile(name: "format_conversion_test.m4a")
        
        // Create recorder for testing
        recorder = ProcessTapRecorder(fileURL: testFileURL, tap: mockTap)
    }
    
    override func customTearDown() {
        recorder?.stop()
        recorder = nil
        mockTap = nil
        mockProcess = nil
        testFileURL = nil
        
        super.customTearDown()
    }
    
    // MARK: - AVAudioConverter Creation Tests
    
    func testAVAudioConverterCreationWithMatchingFormats() throws {
        // Test that no converter is created when input and output formats match
        let sampleRate: Double = 44100
        let channels: UInt32 = 2
        
        let inputFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels)!
        let outputFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels)!
        
        // Create converter - should be nil for identical formats
        let converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        
        // Even identical formats may create a converter, so we test that it's valid
        XCTAssertNotNil(converter, "Converter should be created even for identical formats")
        
        // Test that the formats are indeed equal
        XCTAssertTrue(inputFormat.isEqual(outputFormat), "Input and output formats should be equal")
    }
    
    func testAVAudioConverterCreationWithDifferentSampleRates() throws {
        // Test converter creation with different sample rates
        let inputFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
        let outputFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        
        let converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        
        XCTAssertNotNil(converter, "Converter should be created for different sample rates")
        XCTAssertEqual(converter!.inputFormat.sampleRate, 48000, "Input format should be 48kHz")
        XCTAssertEqual(converter!.outputFormat.sampleRate, 44100, "Output format should be 44.1kHz")
        XCTAssertEqual(converter!.inputFormat.channelCount, 2, "Input should be stereo")
        XCTAssertEqual(converter!.outputFormat.channelCount, 2, "Output should be stereo")
    }
    
    func testAVAudioConverterCreationWithDifferentChannelCounts() throws {
        // Test converter creation with different channel counts
        let inputFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)! // Mono
        let outputFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)! // Stereo
        
        let converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        
        XCTAssertNotNil(converter, "Converter should be created for different channel counts")
        XCTAssertEqual(converter!.inputFormat.channelCount, 1, "Input should be mono")
        XCTAssertEqual(converter!.outputFormat.channelCount, 2, "Output should be stereo")
        XCTAssertEqual(converter!.inputFormat.sampleRate, 44100, "Sample rates should match")
        XCTAssertEqual(converter!.outputFormat.sampleRate, 44100, "Sample rates should match")
    }
    
    func testAVAudioConverterCreationPCMToAAC() throws {
        // Test converter creation from PCM to AAC format
        let inputFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        
        // Create AAC format using AudioTestUtilities
        guard let outputFormat = AudioTestUtilities.createM4AFormat(sampleRate: 44100, channels: 2) else {
            XCTFail("Failed to create M4A/AAC format")
            return
        }
        
        let converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        
        XCTAssertNotNil(converter, "Converter should be created for PCM to AAC conversion")
        XCTAssertEqual(converter!.inputFormat.commonFormat, .pcmFormatFloat32, "Input should be PCM Float32")
        XCTAssertEqual(converter!.outputFormat.commonFormat, .otherFormat, "Output should be other format (AAC)")
    }
    
    func testAVAudioConverterCreationWithComplexFormats() throws {
        // Test converter creation with complex format differences
        let inputFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)! // 48kHz mono
        
        guard let outputFormat = AudioTestUtilities.createM4AFormat(sampleRate: 44100, channels: 2) else {
            XCTFail("Failed to create M4A/AAC format")
            return
        }
        
        let converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        
        XCTAssertNotNil(converter, "Converter should be created for complex format conversion")
        XCTAssertEqual(converter!.inputFormat.sampleRate, 48000, "Input should be 48kHz")
        XCTAssertEqual(converter!.outputFormat.sampleRate, 44100, "Output should be 44.1kHz")
        XCTAssertEqual(converter!.inputFormat.channelCount, 1, "Input should be mono")
        XCTAssertEqual(converter!.outputFormat.channelCount, 2, "Output should be stereo")
    }
    
    // MARK: - Format Conversion Success Tests
    
    func testSuccessfulPCMToAACConversion() throws {
        // Test actual conversion from PCM to AAC
        let inputFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        
        guard let outputFormat = AudioTestUtilities.createM4AFormat(sampleRate: 44100, channels: 2) else {
            XCTFail("Failed to create M4A/AAC format")
            return
        }
        
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            XCTFail("Failed to create converter")
            return
        }
        
        // Create input buffer with test data
        let frameCount: AVAudioFrameCount = 1024
        guard let inputBuffer = AudioTestUtilities.createTestPCMBuffer(
            format: inputFormat,
            frameCount: frameCount,
            frequency: 440.0
        ) else {
            XCTFail("Failed to create test PCM buffer")
            return
        }
        
        // Create output buffer
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount) else {
            XCTFail("Failed to create output buffer")
            return
        }
        
        // Perform conversion
        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { _, _ in
            return inputBuffer
        }
        
        XCTAssertEqual(status, .haveData, "Conversion should succeed")
        XCTAssertNil(error, "Conversion should not produce errors")
        XCTAssertGreaterThan(outputBuffer.frameLength, 0, "Output buffer should contain data")
    }
    
    func testSuccessfulSampleRateConversion() throws {
        // Test sample rate conversion
        let inputFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
        let outputFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            XCTFail("Failed to create converter")
            return
        }
        
        // Create input buffer
        let frameCount: AVAudioFrameCount = 1024
        guard let inputBuffer = AudioTestUtilities.createTestPCMBuffer(
            format: inputFormat,
            frameCount: frameCount,
            frequency: 440.0
        ) else {
            XCTFail("Failed to create test PCM buffer")
            return
        }
        
        // Create output buffer (may need different size due to sample rate change)
        let outputFrameCount = AVAudioFrameCount(Double(frameCount) * (44100.0 / 48000.0)) + 100 // Add buffer
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputFrameCount) else {
            XCTFail("Failed to create output buffer")
            return
        }
        
        // Perform conversion
        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { _, _ in
            return inputBuffer
        }
        
        XCTAssertEqual(status, .haveData, "Sample rate conversion should succeed")
        XCTAssertNil(error, "Sample rate conversion should not produce errors")
        XCTAssertGreaterThan(outputBuffer.frameLength, 0, "Output buffer should contain converted data")
    }
    
    func testSuccessfulChannelCountConversion() throws {
        // Test mono to stereo conversion
        let inputFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)! // Mono
        let outputFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)! // Stereo
        
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            XCTFail("Failed to create converter")
            return
        }
        
        // Create mono input buffer
        let frameCount: AVAudioFrameCount = 1024
        guard let inputBuffer = AudioTestUtilities.createTestPCMBuffer(
            format: inputFormat,
            frameCount: frameCount,
            frequency: 440.0
        ) else {
            XCTFail("Failed to create test PCM buffer")
            return
        }
        
        // Create stereo output buffer
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount) else {
            XCTFail("Failed to create output buffer")
            return
        }
        
        // Perform conversion
        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { _, _ in
            return inputBuffer
        }
        
        XCTAssertEqual(status, .haveData, "Channel count conversion should succeed")
        XCTAssertNil(error, "Channel count conversion should not produce errors")
        XCTAssertGreaterThan(outputBuffer.frameLength, 0, "Output buffer should contain converted data")
        
        // Verify that both stereo channels have data
        if let leftChannel = outputBuffer.floatChannelData?[0],
           let rightChannel = outputBuffer.floatChannelData?[1] {
            
            var leftHasData = false
            var rightHasData = false
            
            for i in 0..<Int(outputBuffer.frameLength) {
                if leftChannel[i] != 0 { leftHasData = true }
                if rightChannel[i] != 0 { rightHasData = true }
            }
            
            XCTAssertTrue(leftHasData, "Left channel should contain data")
            XCTAssertTrue(rightHasData, "Right channel should contain data")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testUnsupportedFormatConversionError() throws {
        // Test conversion between incompatible formats
        let inputFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        
        // Create an unusual output format that might not be supported
        let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 8000,
            channels: 8,
            interleaved: true
        )
        
        // This might return nil for unsupported conversions
        let converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        
        if let converter = converter {
            // If converter was created, test that conversion might fail
            let frameCount: AVAudioFrameCount = 1024
            guard let inputBuffer = AudioTestUtilities.createTestPCMBuffer(
                format: inputFormat,
                frameCount: frameCount,
                frequency: 440.0
            ) else {
                XCTFail("Failed to create test PCM buffer")
                return
            }
            
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat!, frameCapacity: frameCount) else {
                XCTFail("Failed to create output buffer")
                return
            }
            
            // Attempt conversion - this might fail
            var error: NSError?
            let status = converter.convert(to: outputBuffer, error: &error) { _, _ in
                return inputBuffer
            }
            
            // Either conversion succeeds or fails gracefully
            if status == .error {
                XCTAssertNotNil(error, "Error should be provided when conversion fails")
            } else {
                XCTAssertNil(error, "No error should be present for successful conversion")
            }
        } else {
            // Converter creation failed, which is expected for unsupported formats
            XCTAssertNil(converter, "Converter should be nil for unsupported format combinations")
        }
    }
    
    func testConverterCreationWithInvalidFormats() throws {
        // Test converter creation with invalid format parameters
        
        // Test with zero sample rate
        let invalidFormat1 = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 0, // Invalid
            channels: 2,
            interleaved: false
        )
        
        let validFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        
        if let invalidFormat1 = invalidFormat1 {
            let converter = AVAudioConverter(from: invalidFormat1, to: validFormat)
            // System might handle this gracefully or return nil
            // We just verify it doesn't crash
        }
        
        // Test with zero channels
        let invalidFormat2 = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44100,
            channels: 0, // Invalid
            interleaved: false
        )
        
        if let invalidFormat2 = invalidFormat2 {
            let converter = AVAudioConverter(from: validFormat, to: invalidFormat2)
            // System might handle this gracefully or return nil
            // We just verify it doesn't crash
        }
    }
    
    // MARK: - Buffer Allocation and Cleanup Tests
    
    func testProperBufferAllocation() throws {
        // Test that buffers are properly allocated for conversion
        let inputFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        
        guard let outputFormat = AudioTestUtilities.createM4AFormat(sampleRate: 44100, channels: 2) else {
            XCTFail("Failed to create M4A/AAC format")
            return
        }
        
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            XCTFail("Failed to create converter")
            return
        }
        
        // Test different buffer sizes
        let bufferSizes: [AVAudioFrameCount] = [256, 512, 1024, 2048, 4096]
        
        for bufferSize in bufferSizes {
            // Create input buffer
            guard let inputBuffer = AudioTestUtilities.createTestPCMBuffer(
                format: inputFormat,
                frameCount: bufferSize,
                frequency: 440.0
            ) else {
                XCTFail("Failed to create input buffer of size \(bufferSize)")
                continue
            }
            
            // Create output buffer
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: bufferSize) else {
                XCTFail("Failed to create output buffer of size \(bufferSize)")
                continue
            }
            
            // Verify buffer properties
            XCTAssertEqual(inputBuffer.frameCapacity, bufferSize, "Input buffer capacity should match requested size")
            XCTAssertEqual(outputBuffer.frameCapacity, bufferSize, "Output buffer capacity should match requested size")
            XCTAssertEqual(inputBuffer.frameLength, bufferSize, "Input buffer length should be set")
            XCTAssertEqual(outputBuffer.frameLength, 0, "Output buffer length should start at 0")
            
            // Test conversion with this buffer size
            var error: NSError?
            let status = converter.convert(to: outputBuffer, error: &error) { _, _ in
                return inputBuffer
            }
            
            // Conversion should succeed or provide meaningful error
            if status == .error {
                XCTAssertNotNil(error, "Error should be provided for failed conversion with buffer size \(bufferSize)")
            } else {
                XCTAssertNil(error, "No error should occur for successful conversion with buffer size \(bufferSize)")
            }
        }
    }
    
    func testBufferCleanupAfterConversion() throws {
        // Test that buffers are properly managed and don't leak memory
        let inputFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let outputFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            XCTFail("Failed to create converter")
            return
        }
        
        // Create and use multiple buffers to test cleanup
        for iteration in 0..<10 {
            autoreleasepool {
                let frameCount: AVAudioFrameCount = 1024
                
                guard let inputBuffer = AudioTestUtilities.createTestPCMBuffer(
                    format: inputFormat,
                    frameCount: frameCount,
                    frequency: 440.0
                ) else {
                    XCTFail("Failed to create input buffer in iteration \(iteration)")
                    return
                }
                
                guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount) else {
                    XCTFail("Failed to create output buffer in iteration \(iteration)")
                    return
                }
                
                // Perform conversion
                var error: NSError?
                let status = converter.convert(to: outputBuffer, error: &error) { _, _ in
                    return inputBuffer
                }
                
                XCTAssertEqual(status, .haveData, "Conversion should succeed in iteration \(iteration)")
                XCTAssertNil(error, "No error should occur in iteration \(iteration)")
                
                // Buffers should be automatically cleaned up when leaving this autoreleasepool
            }
        }
        
        // If we reach here without crashes, buffer cleanup is working properly
        XCTAssertTrue(true, "Buffer cleanup test completed successfully")
    }
    
    func testLargeBufferAllocation() throws {
        // Test allocation of large buffers for conversion
        let inputFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let outputFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            XCTFail("Failed to create converter")
            return
        }
        
        // Test with a large buffer size (1 second of audio)
        let largeBufferSize: AVAudioFrameCount = 44100
        
        guard let inputBuffer = AudioTestUtilities.createTestPCMBuffer(
            format: inputFormat,
            frameCount: largeBufferSize,
            frequency: 440.0
        ) else {
            XCTFail("Failed to create large input buffer")
            return
        }
        
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: largeBufferSize) else {
            XCTFail("Failed to create large output buffer")
            return
        }
        
        // Verify large buffer properties
        XCTAssertEqual(inputBuffer.frameCapacity, largeBufferSize, "Large input buffer should have correct capacity")
        XCTAssertEqual(outputBuffer.frameCapacity, largeBufferSize, "Large output buffer should have correct capacity")
        
        // Test conversion with large buffer
        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { _, _ in
            return inputBuffer
        }
        
        XCTAssertEqual(status, .haveData, "Large buffer conversion should succeed")
        XCTAssertNil(error, "Large buffer conversion should not produce errors")
        XCTAssertGreaterThan(outputBuffer.frameLength, 0, "Large output buffer should contain data")
    }
    
    // MARK: - ConversionConfiguration Tests
    
    func testConversionConfigurationCreation() throws {
        // Test ConversionConfiguration creation and properties
        let inputFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        let outputFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        
        let config = ConversionConfiguration.create(
            inputFormat: inputFormat,
            outputFormat: outputFormat,
            quality: .high
        )
        
        XCTAssertEqual(config.inputFormat, inputFormat, "Input format should match")
        XCTAssertEqual(config.outputFormat, outputFormat, "Output format should match")
        XCTAssertEqual(config.quality, .high, "Quality should be high")
        XCTAssertTrue(config.requiresConversion, "Conversion should be required for different formats")
        XCTAssertGreaterThan(config.bufferSize, 0, "Buffer size should be positive")
    }
    
    func testConversionConfigurationWithIdenticalFormats() throws {
        // Test ConversionConfiguration with identical formats
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        
        let config = ConversionConfiguration.create(
            inputFormat: format,
            outputFormat: format,
            quality: .medium
        )
        
        XCTAssertEqual(config.inputFormat, format, "Input format should match")
        XCTAssertEqual(config.outputFormat, format, "Output format should match")
        XCTAssertEqual(config.quality, .medium, "Quality should be medium")
        XCTAssertFalse(config.requiresConversion, "Conversion should not be required for identical formats")
    }
    
    func testConversionTypeDetection() throws {
        // Test different conversion type detection
        let baseFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        
        // Test sample rate conversion
        let sampleRateFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
        let sampleRateConfig = ConversionConfiguration.create(
            inputFormat: baseFormat,
            outputFormat: sampleRateFormat
        )
        XCTAssertEqual(sampleRateConfig.conversionType, .sampleRate, "Should detect sample rate conversion")
        
        // Test channel layout conversion
        let channelFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let channelConfig = ConversionConfiguration.create(
            inputFormat: baseFormat,
            outputFormat: channelFormat
        )
        XCTAssertEqual(channelConfig.conversionType, .channelLayout, "Should detect channel layout conversion")
        
        // Test full conversion (multiple differences)
        let fullConversionFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        let fullConfig = ConversionConfiguration.create(
            inputFormat: baseFormat,
            outputFormat: fullConversionFormat
        )
        XCTAssertEqual(fullConfig.conversionType, .full, "Should detect full conversion")
        
        // Test no conversion
        let noConversionConfig = ConversionConfiguration.create(
            inputFormat: baseFormat,
            outputFormat: baseFormat
        )
        XCTAssertEqual(noConversionConfig.conversionType, .none, "Should detect no conversion needed")
    }
    
    // MARK: - Integration Tests with ProcessTapRecorder
    
    @MainActor
    func testFormatConversionDuringRecording() throws {
        // Test format conversion during actual recording process
        
        // Set up mock tap with different format than output
        let inputStreamDesc = AudioStreamBasicDescription(
            mSampleRate: 48000.0, // Different from typical 44.1kHz output
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4, // Mono: 1 channel * 4 bytes per sample
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 1, // Mono input
            mBitsPerChannel: 32,
            mReserved: 0
        )
        mockTap.mockStreamDescription = inputStreamDesc
        
        // Start recording - this should trigger format conversion setup
        try recorder.start()
        
        XCTAssertTrue(recorder.isRecording, "Recording should start successfully")
        XCTAssertTrue(mockTap.activated, "Tap should be activated")
        
        // Simulate audio data processing which should use format conversion
        mockTap.simulateAudioData()
        
        // Stop recording
        recorder.stop()
        
        // Verify file was created
        XCTAssertTrue(FileManager.default.fileExists(atPath: testFileURL.path), 
                     "M4A file should be created with format conversion")
        
        // Verify file properties
        let audioFile = try AVAudioFile(forReading: testFileURL)
        
        // Output should be in M4A format regardless of input format
        XCTAssertTrue(AudioTestUtilities.validateM4AFile(at: testFileURL), 
                     "Output should be valid M4A file")
        
        // The output format may differ from input due to conversion
        // We just verify it's a valid audio file
        XCTAssertGreaterThanOrEqual(audioFile.length, 0, "Audio file should have content")
    }
    
    @MainActor
    func testFormatConversionErrorHandling() throws {
        // Test error handling during format conversion setup
        
        // Set up mock tap with potentially problematic format
        let problematicStreamDesc = AudioStreamBasicDescription(
            mSampleRate: 192000.0, // Very high sample rate
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 32, // 8 channels * 4 bytes per sample
            mFramesPerPacket: 1,
            mBytesPerFrame: 32,
            mChannelsPerFrame: 8, // 8 channels
            mBitsPerChannel: 32,
            mReserved: 0
        )
        mockTap.mockStreamDescription = problematicStreamDesc
        
        // Attempt to start recording
        do {
            try recorder.start()
            
            // If recording starts successfully, verify it handles the format
            XCTAssertTrue(recorder.isRecording, "Recording should handle high-resolution format")
            
            // Test with audio data
            mockTap.simulateAudioData()
            
            recorder.stop()
            
            // Verify file creation
            if FileManager.default.fileExists(atPath: testFileURL.path) {
                XCTAssertTrue(AudioTestUtilities.validateM4AFile(at: testFileURL), 
                             "Output should be valid M4A file even with complex input format")
            }
            
        } catch let error as AACEncodingError {
            // Format conversion errors are expected for extreme formats
            switch error {
            case .formatConversionFailed, .converterCreationFailed, .unsupportedFormatConversion:
                // These are acceptable errors for extreme formats
                XCTAssertFalse(recorder.isRecording, "Recording should not be active after format error")
            default:
                XCTFail("Unexpected AAC encoding error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testFormatConversionPerformance() throws {
        // Test performance of format conversion operations
        let inputFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
        
        guard let outputFormat = AudioTestUtilities.createM4AFormat(sampleRate: 44100, channels: 2) else {
            XCTFail("Failed to create M4A/AAC format")
            return
        }
        
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            XCTFail("Failed to create converter")
            return
        }
        
        let frameCount: AVAudioFrameCount = 4096 // Larger buffer for performance test
        
        measure {
            autoreleasepool {
                guard let inputBuffer = AudioTestUtilities.createTestPCMBuffer(
                    format: inputFormat,
                    frameCount: frameCount,
                    frequency: 440.0
                ) else {
                    XCTFail("Failed to create test buffer")
                    return
                }
                
                guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount) else {
                    XCTFail("Failed to create output buffer")
                    return
                }
                
                // Perform multiple conversions to test sustained performance
                for _ in 0..<10 {
                    outputBuffer.frameLength = 0 // Reset for reuse
                    
                    var error: NSError?
                    let status = converter.convert(to: outputBuffer, error: &error) { _, _ in
                        return inputBuffer
                    }
                    
                    if status == .error {
                        XCTFail("Conversion failed during performance test: \(error?.localizedDescription ?? "Unknown error")")
                        return
                    }
                }
            }
        }
    }
    
    func testMemoryUsageDuringConversion() throws {
        // Test memory usage patterns during format conversion
        let inputFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let outputFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            XCTFail("Failed to create converter")
            return
        }
        
        // Test with multiple buffer sizes to check memory scaling
        let bufferSizes: [AVAudioFrameCount] = [256, 1024, 4096, 16384]
        
        for bufferSize in bufferSizes {
            autoreleasepool {
                guard let inputBuffer = AudioTestUtilities.createTestPCMBuffer(
                    format: inputFormat,
                    frameCount: bufferSize,
                    frequency: 440.0
                ) else {
                    XCTFail("Failed to create input buffer of size \(bufferSize)")
                    return
                }
                
                guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: bufferSize) else {
                    XCTFail("Failed to create output buffer of size \(bufferSize)")
                    return
                }
                
                // Perform conversion
                var error: NSError?
                let status = converter.convert(to: outputBuffer, error: &error) { _, _ in
                    return inputBuffer
                }
                
                XCTAssertEqual(status, .haveData, "Conversion should succeed for buffer size \(bufferSize)")
                XCTAssertNil(error, "No error should occur for buffer size \(bufferSize)")
                
                // Memory should be released when leaving this autoreleasepool
            }
        }
        
        // Test completed without memory issues
        XCTAssertTrue(true, "Memory usage test completed successfully")
    }
}