import XCTest
import OSLog

/// Base test case class that provides automatic test environment setup and teardown
class BaseTestCase: XCTestCase {
    
    private static let logger = Logger(subsystem: "com.audiocap.tests", category: "BaseTestCase")
    
    /// Test environment for this test class
    var testEnvironment: TestEnvironment!
    
    /// Test configuration - override in subclasses for custom configuration
    var testConfiguration: TestConfiguration {
        return .default
    }
    
    /// Test class identifier - automatically derived from class name
    private var testClassIdentifier: String {
        return String(describing: type(of: self))
    }
    
    // MARK: - XCTest Lifecycle
    
    override class func setUp() {
        super.setUp()
        
        // Global test setup
        Self.logger.info("Setting up global test environment")
        
        // Set test environment variables
        setenv("AUDIOCAP_TEST_MODE", "1", 1)
        setenv("AUDIOCAP_MOCK_AUDIO", "1", 1)
        
        // Configure logging for tests
        if ProcessInfo.processInfo.environment["AUDIOCAP_TEST_LOGGING"] == "1" {
            setenv("OS_ACTIVITY_MODE", "enable", 1)
        }
    }
    
    override class func tearDown() {
        // Global test cleanup
        Self.logger.info("Tearing down global test environment")
        TestHelpers.cleanupAllTestEnvironments()
        TestHelpers.cleanupTemporaryDirectories()
        
        super.tearDown()
    }
    
    override func setUp() {
        super.setUp()
        
        // Set up test environment for this test class
        testEnvironment = TestHelpers.setupTestEnvironment(
            for: testClassIdentifier,
            configuration: testConfiguration
        )
        
        Self.logger.debug("Set up test environment for \(self.testClassIdentifier)")
        
        // Perform custom setup
        customSetUp()
    }
    
    override func tearDown() {
        // Perform custom teardown
        customTearDown()
        
        // Clean up test environment
        TestHelpers.teardownTestEnvironment(for: testClassIdentifier)
        
        Self.logger.debug("Tore down test environment for \(self.testClassIdentifier)")
        
        super.tearDown()
    }
    
    // MARK: - Custom Setup/Teardown Hooks
    
    /// Override this method in subclasses for custom setup logic
    func customSetUp() {
        // Default implementation does nothing
    }
    
    /// Override this method in subclasses for custom teardown logic
    func customTearDown() {
        // Default implementation does nothing
    }
    
    // MARK: - Test Utilities
    
    /// Creates a temporary file in the test environment
    /// - Parameters:
    ///   - name: File name
    ///   - content: File content (default: empty)
    /// - Returns: URL of the created file
    func createTempFile(name: String, content: Data = Data()) -> URL {
        return testEnvironment.createTempFile(name: name, content: content)
    }
    
    /// Creates a temporary audio file with test data
    /// - Parameters:
    ///   - name: File name (should include .wav extension)
    ///   - duration: Duration in seconds (default: 1.0)
    /// - Returns: URL of the created audio file
    func createTempAudioFile(name: String = "test.wav", duration: TimeInterval = 1.0) -> URL {
        // Create minimal WAV file header for testing
        let sampleRate: UInt32 = 44100
        let channels: UInt16 = 2
        let bitsPerSample: UInt16 = 16
        let samples = Int(duration * Double(sampleRate))
        let dataSize = samples * Int(channels) * Int(bitsPerSample) / 8
        
        var wavData = Data()
        
        // WAV header
        wavData.append("RIFF".data(using: .ascii)!)
        wavData.append(withUnsafeBytes(of: UInt32(36 + dataSize).littleEndian) { Data($0) })
        wavData.append("WAVE".data(using: .ascii)!)
        wavData.append("fmt ".data(using: .ascii)!)
        wavData.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: channels.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: UInt32(sampleRate * UInt32(channels * bitsPerSample / 8)).littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: UInt16(channels * bitsPerSample / 8).littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })
        wavData.append("data".data(using: .ascii)!)
        wavData.append(withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Data($0) })
        
        // Generate simple sine wave data
        for i in 0..<samples {
            let sample = sin(2.0 * Double.pi * 440.0 * Double(i) / Double(sampleRate))
            let intSample = Int16(sample * 32767.0)
            
            for _ in 0..<channels {
                wavData.append(withUnsafeBytes(of: intSample.littleEndian) { Data($0) })
            }
        }
        
        return createTempFile(name: name, content: wavData)
    }
    
    /// Stores a mock object in the test environment
    /// - Parameters:
    ///   - mock: The mock object
    ///   - key: Key to store it under
    func storeMock<T>(_ mock: T, forKey key: String) {
        testEnvironment.storeMock(mock, forKey: key)
    }
    
    /// Retrieves a mock object from the test environment
    /// - Parameters:
    ///   - key: Key of the mock object
    ///   - type: Type of the mock object
    /// - Returns: The mock object if it exists
    func getMock<T>(forKey key: String, type: T.Type) -> T? {
        return testEnvironment.getMock(forKey: key, type: type)
    }
    
    /// Waits for an async operation with the test's configured timeout
    /// - Parameter operation: The async operation to execute
    /// - Returns: The result of the operation
    func waitForAsyncOperation<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        return try await TestHelpers.waitForAsyncOperation(
            timeout: testConfiguration.testTimeout,
            operation: operation
        )
    }
    
    /// Waits for a condition to become true with the test's configured timeout
    /// - Parameter condition: The condition to check
    func waitForCondition(_ condition: @escaping () -> Bool) async throws {
        try await TestHelpers.waitForCondition(
            timeout: testConfiguration.testTimeout,
            condition: condition
        )
    }
    
    /// Measures execution time of a synchronous operation
    /// - Parameter operation: The operation to measure
    /// - Returns: Tuple containing result and execution time
    func measureTime<T>(_ operation: () throws -> T) rethrows -> (result: T, time: TimeInterval) {
        return try TestHelpers.measureTime(operation)
    }
    
    /// Measures execution time of an async operation
    /// - Parameter operation: The async operation to measure
    /// - Returns: Tuple containing result and execution time
    func measureTimeAsync<T>(_ operation: () async throws -> T) async rethrows -> (result: T, time: TimeInterval) {
        return try await TestHelpers.measureTimeAsync(operation)
    }
}

// MARK: - Specialized Base Test Cases

/// Base test case for UI component tests
class BaseUITestCase: BaseTestCase {
    
    override var testConfiguration: TestConfiguration {
        return TestConfiguration(
            useRealFileSystem: false,
            enableLogging: true,
            mockAudioDevices: true,
            testTimeout: 5.0
        )
    }
    
    override func customSetUp() {
        super.customSetUp()
        
        // UI-specific setup
        continueAfterFailure = false
    }
}

/// Base test case for integration tests
class BaseIntegrationTestCase: BaseTestCase {
    
    override var testConfiguration: TestConfiguration {
        return .integration
    }
    
    override func customSetUp() {
        super.customSetUp()
        
        // Integration test specific setup
        continueAfterFailure = true
    }
}

/// Base test case for performance tests
class BasePerformanceTestCase: BaseTestCase {
    
    override var testConfiguration: TestConfiguration {
        return .performance
    }
    
    override func customSetUp() {
        super.customSetUp()
        
        // Performance test specific setup
        continueAfterFailure = false
    }
}