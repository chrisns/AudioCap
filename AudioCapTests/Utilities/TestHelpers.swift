import Foundation
import XCTest
import OSLog
import Network

/// Utility class for common test operations and async handling
final class TestHelpers {
    
    static let logger = Logger(subsystem: "com.audiocap.tests", category: "TestHelpers")
    
    // MARK: - Test Environment Management
    
    private static var testEnvironments: [String: TestEnvironment] = [:]
    private static let environmentQueue = DispatchQueue(label: "TestHelpers.environments")
    
    /// Sets up a consistent test environment for a test class
    /// - Parameters:
    ///   - testClass: The test class name
    ///   - configuration: Optional test configuration
    /// - Returns: TestEnvironment instance for the test class
    @discardableResult
    static func setupTestEnvironment(
        for testClass: String,
        configuration: TestConfiguration = TestConfiguration()
    ) -> TestEnvironment {
        return environmentQueue.sync {
            let environment = TestEnvironment(
                testClass: testClass,
                configuration: configuration
            )
            testEnvironments[testClass] = environment
            logger.info("Set up test environment for \(testClass)")
            return environment
        }
    }
    
    /// Tears down the test environment for a test class
    /// - Parameter testClass: The test class name
    static func teardownTestEnvironment(for testClass: String) {
        environmentQueue.sync {
            if let environment = testEnvironments[testClass] {
                environment.cleanup()
                testEnvironments.removeValue(forKey: testClass)
                logger.info("Tore down test environment for \(testClass)")
            }
        }
    }
    
    /// Gets the test environment for a test class
    /// - Parameter testClass: The test class name
    /// - Returns: TestEnvironment instance if it exists
    static func getTestEnvironment(for testClass: String) -> TestEnvironment? {
        return environmentQueue.sync {
            return testEnvironments[testClass]
        }
    }
    
    /// Cleans up all test environments
    static func cleanupAllTestEnvironments() {
        environmentQueue.sync {
            for (testClass, environment) in testEnvironments {
                environment.cleanup()
                logger.info("Cleaned up test environment for \(testClass)")
            }
            testEnvironments.removeAll()
        }
    }
    
    // MARK: - Async Operation Utilities
    
    /// Waits for an async operation to complete with timeout handling
    /// - Parameters:
    ///   - timeout: Maximum time to wait for the operation (default: 5.0 seconds)
    ///   - operation: The async operation to execute
    /// - Returns: The result of the async operation
    /// - Throws: TimeoutError if the operation doesn't complete within the timeout
    static func waitForAsyncOperation<T>(
        timeout: TimeInterval = 5.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            // Add the main operation
            group.addTask {
                try await operation()
            }
            
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TimeoutError(timeout: timeout)
            }
            
            // Return the first completed result and cancel the other task
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }
    
    /// Waits for a condition to become true with timeout
    /// - Parameters:
    ///   - timeout: Maximum time to wait (default: 5.0 seconds)
    ///   - interval: Check interval (default: 0.1 seconds)
    ///   - condition: The condition to check
    /// - Throws: TimeoutError if condition doesn't become true within timeout
    static func waitForCondition(
        timeout: TimeInterval = 5.0,
        interval: TimeInterval = 0.1,
        condition: @escaping () -> Bool
    ) async throws {
        let startTime = Date()
        
        while !condition() {
            if Date().timeIntervalSince(startTime) > timeout {
                throw TimeoutError(timeout: timeout)
            }
            
            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
    }
    
    /// Waits for a condition to become true with timeout (synchronous version)
    /// - Parameters:
    ///   - timeout: Maximum time to wait (default: 5.0 seconds)
    ///   - interval: Check interval (default: 0.1 seconds)
    ///   - condition: The condition to check
    /// - Returns: true if condition became true, false if timeout occurred
    static func waitForConditionSync(
        timeout: TimeInterval = 5.0,
        interval: TimeInterval = 0.1,
        condition: @escaping () -> Bool
    ) -> Bool {
        let startTime = Date()
        
        while !condition() {
            if Date().timeIntervalSince(startTime) > timeout {
                return false
            }
            
            Thread.sleep(forTimeInterval: interval)
        }
        
        return true
    }
    
    // MARK: - Temporary Directory Management
    
    private static var createdDirectories: Set<URL> = []
    private static let directoryQueue = DispatchQueue(label: "TestHelpers.directories")
    
    /// Creates a temporary directory for test use
    /// - Parameter prefix: Optional prefix for the directory name
    /// - Returns: URL of the created temporary directory
    static func createTemporaryDirectory(prefix: String = "AudioCapTest") -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(prefix)
            .appendingPathComponent(UUID().uuidString)
        
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            _ = directoryQueue.sync {
                createdDirectories.insert(tempDir)
            }
            logger.debug("Created temporary directory: \(tempDir.path)")
        } catch {
            logger.error("Failed to create temporary directory: \(error)")
        }
        
        return tempDir
    }
    
    /// Cleans up all temporary directories created by TestHelpers
    static func cleanupTemporaryDirectories() {
        directoryQueue.sync {
            for directory in createdDirectories {
                do {
                    if FileManager.default.fileExists(atPath: directory.path) {
                        try FileManager.default.removeItem(at: directory)
                        logger.debug("Cleaned up temporary directory: \(directory.path)")
                    }
                } catch {
                    logger.error("Failed to cleanup temporary directory \(directory.path): \(error)")
                }
            }
            createdDirectories.removeAll()
        }
    }
    
    /// Cleans up a specific temporary directory
    /// - Parameter url: URL of the directory to clean up
    static func cleanupTemporaryDirectory(at url: URL) {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
                _ = directoryQueue.sync {
                    createdDirectories.remove(url)
                }
                logger.debug("Cleaned up temporary directory: \(url.path)")
            }
        } catch {
            logger.error("Failed to cleanup temporary directory \(url.path): \(error)")
        }
    }
    
    // MARK: - Mock NSRunningApplication Generation
    
    /// Creates mock NSRunningApplication instances for testing
    /// - Parameters:
    ///   - count: Number of mock applications to create (default: 5)
    ///   - includeAudioApps: Whether to include applications that would have audio capabilities
    /// - Returns: Array of mock NSRunningApplication instances
    static func mockRunningApplications(count: Int = 5, includeAudioApps: Bool = true) -> [NSRunningApplication] {
        var mockApps: [MockNSRunningApplication] = []
        
        // Create some standard mock applications
        let appConfigs = [
            ("Safari", "com.apple.Safari", "/Applications/Safari.app"),
            ("Music", "com.apple.Music", "/Applications/Music.app"),
            ("Finder", "com.apple.finder", "/System/Library/CoreServices/Finder.app"),
            ("Terminal", "com.apple.Terminal", "/Applications/Utilities/Terminal.app"),
            ("Xcode", "com.apple.dt.Xcode", "/Applications/Xcode.app")
        ]
        
        for i in 0..<min(count, appConfigs.count) {
            let config = appConfigs[i]
            let mockApp = MockNSRunningApplication(
                processIdentifier: pid_t(1000 + i),
                localizedName: config.0,
                bundleIdentifier: config.1,
                bundleURL: URL(fileURLWithPath: config.2)
            )
            mockApps.append(mockApp)
        }
        
        // Fill remaining slots with generic apps if needed
        for i in appConfigs.count..<count {
            let mockApp = MockNSRunningApplication(
                processIdentifier: pid_t(1000 + i),
                localizedName: "Test App \(i)",
                bundleIdentifier: "com.test.app\(i)",
                bundleURL: URL(fileURLWithPath: "/Applications/TestApp\(i).app")
            )
            mockApps.append(mockApp)
        }
        
        logger.debug("Created \(mockApps.count) mock running applications")
        return mockApps
    }
    
    /// Creates a single mock NSRunningApplication with specific properties
    /// - Parameters:
    ///   - pid: Process identifier
    ///   - name: Localized name of the application
    ///   - bundleID: Bundle identifier
    ///   - bundleURL: Bundle URL
    /// - Returns: Mock NSRunningApplication instance
    static func createMockRunningApplication(
        pid: pid_t,
        name: String,
        bundleID: String,
        bundleURL: URL
    ) -> NSRunningApplication {
        return MockNSRunningApplication(
            processIdentifier: pid,
            localizedName: name,
            bundleIdentifier: bundleID,
            bundleURL: bundleURL
        )
    }
    
    // MARK: - Test Timing Utilities
    
    /// Measures the execution time of a synchronous operation
    /// - Parameter operation: The operation to measure
    /// - Returns: Tuple containing the result and execution time in seconds
    static func measureTime<T>(_ operation: () throws -> T) rethrows -> (result: T, time: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try operation()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        return (result, timeElapsed)
    }
    
    /// Measures the execution time of an async operation
    /// - Parameter operation: The async operation to measure
    /// - Returns: Tuple containing the result and execution time in seconds
    static func measureTimeAsync<T>(_ operation: () async throws -> T) async rethrows -> (result: T, time: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        return (result, timeElapsed)
    }
    
    // MARK: - XCTest Integration
    
    /// Creates an XCTestExpectation that can be fulfilled after a delay
    /// - Parameters:
    ///   - description: Description of the expectation
    ///   - delay: Delay before fulfilling the expectation
    /// - Returns: The created expectation
    static func createDelayedExpectation(description: String, delay: TimeInterval) -> XCTestExpectation {
        let expectation = XCTestExpectation(description: description)
        
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
            expectation.fulfill()
        }
        
        return expectation
    }
}

// MARK: - Supporting Types

/// Error thrown when an operation times out
struct TimeoutError: Error, LocalizedError {
    let timeout: TimeInterval
    
    var errorDescription: String? {
        "Operation timed out after \(timeout) seconds"
    }
}

// MARK: - Test Data Factories

/// Factory for creating reproducible test data
struct TestDataFactory {
    
    /// Creates a set of test audio processes with predictable properties
    /// - Parameter count: Number of processes to create
    /// - Returns: Array of test audio processes
    static func createTestAudioProcesses(count: Int = 5) -> [TestAudioProcess] {
        let processConfigs = [
            TestAudioProcess(
                pid: 1001,
                name: "Music",
                bundleID: "com.apple.Music",
                isAudioActive: true,
                kind: .app,
                icon: NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)
            ),
            TestAudioProcess(
                pid: 1002,
                name: "Safari",
                bundleID: "com.apple.Safari",
                isAudioActive: false,
                kind: .app,
                icon: NSImage(systemSymbolName: "safari", accessibilityDescription: nil)
            ),
            TestAudioProcess(
                pid: 1003,
                name: "coreaudiod",
                bundleID: nil,
                isAudioActive: true,
                kind: .process,
                icon: NSImage(systemSymbolName: "waveform", accessibilityDescription: nil)
            ),
            TestAudioProcess(
                pid: 1004,
                name: "Spotify",
                bundleID: "com.spotify.client",
                isAudioActive: true,
                kind: .app,
                icon: NSImage(systemSymbolName: "music.note.list", accessibilityDescription: nil)
            ),
            TestAudioProcess(
                pid: 1005,
                name: "VLC",
                bundleID: "org.videolan.vlc",
                isAudioActive: false,
                kind: .app,
                icon: NSImage(systemSymbolName: "play.circle", accessibilityDescription: nil)
            )
        ]
        
        return Array(processConfigs.prefix(count))
    }
    
    /// Creates test recording sessions with various configurations
    /// - Parameter count: Number of sessions to create
    /// - Returns: Array of test recording sessions
    static func createTestRecordingSessions(count: Int = 3) -> [TestRecordingSession] {
        let sessions = [
            TestRecordingSession(
                processName: "Music",
                duration: 5.0,
                sampleRate: 44100,
                channels: 2,
                expectedFileSize: 1024 * 1024, // 1MB
                format: .pcm
            ),
            TestRecordingSession(
                processName: "Safari",
                duration: 2.0,
                sampleRate: 48000,
                channels: 2,
                expectedFileSize: 512 * 1024, // 512KB
                format: .pcm
            ),
            TestRecordingSession(
                processName: "Spotify",
                duration: 10.0,
                sampleRate: 44100,
                channels: 2,
                expectedFileSize: 2048 * 1024, // 2MB
                format: .pcm
            )
        ]
        
        return Array(sessions.prefix(count))
    }
    
    /// Creates test permission scenarios
    /// - Returns: Array of test permission scenarios
    static func createTestPermissionScenarios() -> [TestPermissionScenario] {
        return [
            TestPermissionScenario(
                initialStatus: .unknown,
                requestResult: .granted,
                expectedFinalStatus: .authorized,
                description: "First time permission request - granted"
            ),
            TestPermissionScenario(
                initialStatus: .unknown,
                requestResult: .denied,
                expectedFinalStatus: .denied,
                description: "First time permission request - denied"
            ),
            TestPermissionScenario(
                initialStatus: .denied,
                requestResult: .denied,
                expectedFinalStatus: .denied,
                description: "Previously denied permission - still denied"
            ),
            TestPermissionScenario(
                initialStatus: .authorized,
                requestResult: .granted,
                expectedFinalStatus: .authorized,
                description: "Already authorized - remains authorized"
            )
        ]
    }
}

// MARK: - Test Environment Management

/// Manages test environment setup and cleanup for consistent testing
class TestEnvironment {
    let testClass: String
    let configuration: TestConfiguration
    private let tempDirectory: URL
    private var createdFiles: Set<URL> = []
    private var mockObjects: [String: Any] = [:]
    
    init(testClass: String, configuration: TestConfiguration) {
        self.testClass = testClass
        self.configuration = configuration
        self.tempDirectory = TestHelpers.createTemporaryDirectory(prefix: "TestEnv_\(testClass)")
    }
    
    /// Creates a temporary file in the test environment
    /// - Parameters:
    ///   - name: File name
    ///   - content: File content
    /// - Returns: URL of the created file
    func createTempFile(name: String, content: Data = Data()) -> URL {
        let fileURL = tempDirectory.appendingPathComponent(name)
        do {
            try content.write(to: fileURL)
            createdFiles.insert(fileURL)
        } catch {
            TestHelpers.logger.error("Failed to create temp file \(name): \(error)")
        }
        return fileURL
    }
    
    /// Stores a mock object for later retrieval
    /// - Parameters:
    ///   - key: Key to store the mock under
    ///   - mock: The mock object
    func storeMock<T>(_ mock: T, forKey key: String) {
        mockObjects[key] = mock
    }
    
    /// Retrieves a stored mock object
    /// - Parameter key: Key of the mock object
    /// - Returns: The mock object if it exists
    func getMock<T>(forKey key: String, type: T.Type) -> T? {
        return mockObjects[key] as? T
    }
    
    /// Cleans up the test environment
    func cleanup() {
        // Clean up created files
        for fileURL in createdFiles {
            try? FileManager.default.removeItem(at: fileURL)
        }
        createdFiles.removeAll()
        
        // Clean up temp directory
        TestHelpers.cleanupTemporaryDirectory(at: tempDirectory)
        
        // Clear mock objects
        mockObjects.removeAll()
    }
}

/// Configuration for test environments
struct TestConfiguration {
    let useRealFileSystem: Bool
    let enableLogging: Bool
    let mockAudioDevices: Bool
    let testTimeout: TimeInterval
    
    init(
        useRealFileSystem: Bool = false,
        enableLogging: Bool = true,
        mockAudioDevices: Bool = true,
        testTimeout: TimeInterval = 10.0
    ) {
        self.useRealFileSystem = useRealFileSystem
        self.enableLogging = enableLogging
        self.mockAudioDevices = mockAudioDevices
        self.testTimeout = testTimeout
    }
    
    static let `default` = TestConfiguration()
    static let integration = TestConfiguration(useRealFileSystem: true, mockAudioDevices: false)
    static let performance = TestConfiguration(enableLogging: false, testTimeout: 30.0)
}

// MARK: - Test Data Types

/// Represents a test audio process with predictable properties
struct TestAudioProcess {
    let pid: pid_t
    let name: String
    let bundleID: String?
    let isAudioActive: Bool
    let kind: AudioProcessKind
    let icon: NSImage?
    
    enum AudioProcessKind {
        case app
        case process
    }
}

/// Represents a test recording session configuration
struct TestRecordingSession {
    let processName: String
    let duration: TimeInterval
    let sampleRate: Double
    let channels: Int
    let expectedFileSize: Int
    let format: AudioFormat
    
    enum AudioFormat {
        case pcm
        case compressed
    }
}

/// Represents a test permission scenario
struct TestPermissionScenario {
    let initialStatus: PermissionStatus
    let requestResult: PermissionRequestResult
    let expectedFinalStatus: PermissionStatus
    let description: String
    
    enum PermissionStatus {
        case unknown
        case authorized
        case denied
    }
    
    enum PermissionRequestResult {
        case granted
        case denied
    }
}

/// Mock implementation of NSRunningApplication for testing
private class MockNSRunningApplication: NSRunningApplication, @unchecked Sendable {
    private let _processIdentifier: pid_t
    private let _localizedName: String?
    private let _bundleIdentifier: String?
    private let _bundleURL: URL?
    
    init(processIdentifier: pid_t, localizedName: String?, bundleIdentifier: String?, bundleURL: URL?) {
        self._processIdentifier = processIdentifier
        self._localizedName = localizedName
        self._bundleIdentifier = bundleIdentifier
        self._bundleURL = bundleURL
        super.init()
    }
    
    override var processIdentifier: pid_t {
        return _processIdentifier
    }
    
    override var localizedName: String? {
        return _localizedName
    }
    
    override var bundleIdentifier: String? {
        return _bundleIdentifier
    }
    
    override var bundleURL: URL? {
        return _bundleURL
    }
}

// MARK: - Network Test Helpers

extension TestHelpers {
    /// Find an available port for testing HTTP server
    static func findAvailablePort() -> Int {
        do {
            let listener = try NWListener(using: .tcp, on: .any)
            listener.start(queue: .main)
            
            // Wait briefly for listener to be ready
            Thread.sleep(forTimeInterval: 0.1)
            
            guard case .ready = listener.state,
                  let port = listener.port?.rawValue,
                  port > 0 else {
                listener.cancel()
                return 5742 // Fallback to default port
            }
            
            listener.cancel()
            return Int(port)
        } catch {
            // Fallback to default port if we can't find one dynamically
            return 5742
        }
    }
}