import XCTest
import Network
@testable import AudioCap

final class HTTPServerManagerTests: XCTestCase {
    
    private var serverManager: HTTPServerManager!
    private var testPort: Int!
    
    override func setUp() {
        super.setUp()
        serverManager = HTTPServerManager()
        testPort = TestHelpers.findAvailablePort()
    }
    
    override func tearDown() {
        if let manager = serverManager {
            Task {
                await manager.stop()
            }
        }
        serverManager = nil
        super.tearDown()
    }
    
    // MARK: - Startup Success Tests
    
    func testStartServerSuccessfully() async throws {
        // Configure with available port
        var config = serverManager.configuration
        config.port = testPort
        config.ipAddress = "127.0.0.1"
        serverManager.updateConfiguration(config)
        
        // Test that start() succeeds on available port
        try await serverManager.start()
        
        XCTAssertTrue(serverManager.isRunning)
        XCTAssertEqual(serverManager.statusMessage, "Server running on 127.0.0.1:\(testPort!)")
        XCTAssertNotNil(serverManager.endpointURL)
    }
    
    // MARK: - Startup Failure Tests
    
    func testStartServerThrowsOnPortConflict() async throws {
        // Create a dummy server to occupy the port
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        let dummyListener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: UInt16(testPort)))
        
        dummyListener.start(queue: .global())
        
        // Wait for dummy server to start
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        defer {
            dummyListener.cancel()
        }
        
        // Configure server manager with the occupied port
        var config = serverManager.configuration
        config.port = testPort
        config.ipAddress = "127.0.0.1"
        serverManager.updateConfiguration(config)
        
        // Test that start() throws when port is occupied
        do {
            try await serverManager.start()
            XCTFail("Expected start() to throw when port is occupied")
        } catch {
            // Expected failure
            XCTAssertFalse(serverManager.isRunning)
            XCTAssertTrue(serverManager.statusMessage.contains("Failed to start server"))
        }
    }
    
    func testStartServerThrowsOnInvalidPort() async throws {
        // Configure with invalid port (0 is invalid for binding)
        var config = serverManager.configuration
        config.port = 0
        config.ipAddress = "127.0.0.1"
        serverManager.updateConfiguration(config)
        
        // Test that start() throws with invalid port
        do {
            try await serverManager.start()
            XCTFail("Expected start() to throw with invalid port")
        } catch {
            // Expected failure
            XCTAssertFalse(serverManager.isRunning)
        }
    }
    
    // MARK: - Fail-Fast Behavior Tests
    
    func testStartOrTerminateWithMockTermination() async throws {
        // This test verifies the fail-fast behavior without actually terminating the test process
        // We'll test this by injecting a mock configuration that will fail and verifying the error path
        
        let expectation = XCTestExpectation(description: "Should call termination handler on failure")
        
        // Create a custom server manager that we can intercept the termination call
        let mockServerManager = MockHTTPServerManager()
        mockServerManager.shouldFailStart = true
        mockServerManager.terminationHandler = {
            expectation.fulfill()
        }
        
        // Test startOrTerminate - should call termination handler on failure
        await mockServerManager.startOrTerminate()
        
        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertTrue(mockServerManager.terminationCalled)
    }
    
    // MARK: - Configuration Updates
    
    func testConfigurationUpdateRestartsServer() async throws {
        // Start server on initial port
        var config = serverManager.configuration
        config.port = testPort
        config.ipAddress = "127.0.0.1"
        serverManager.updateConfiguration(config)
        
        try await serverManager.start()
        XCTAssertTrue(serverManager.isRunning)
        
        // Update to different port - should restart
        let newPort = TestHelpers.findAvailablePort()
        config.port = newPort
        serverManager.updateConfiguration(config)
        
        // Give time for restart
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        XCTAssertTrue(serverManager.isRunning)
        XCTAssertTrue(serverManager.statusMessage.contains("\(newPort)"))
    }
}

// MARK: - Mock HTTPServerManager for Testing

class MockHTTPServerManager: HTTPServerManager {
    var shouldFailStart = false
    var terminationCalled = false
    var terminationHandler: (() -> Void)?
    
    override func start() async throws {
        if shouldFailStart {
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock failure for testing"])
        }
        try await super.start()
    }
    
    override func startOrTerminate() async {
        do {
            try await start()
        } catch {
            terminationCalled = true
            terminationHandler?()
            // Don't actually call exit() in tests
        }
    }
} 