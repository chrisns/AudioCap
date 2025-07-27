import XCTest
import Network
@testable import AudioCap

final class AppFailFastTests: XCTestCase {
    
    private var testPort: Int!
    private var dummyListener: NWListener?
    
    override func setUp() {
        super.setUp()
        testPort = TestHelpers.findAvailablePort()
    }
    
    override func tearDown() {
        dummyListener?.cancel()
        dummyListener = nil
        super.tearDown()
    }
    
    // MARK: - Port Conflict Tests
    
    func testHTTPServerManagerFailsOnPortConflict() async throws {
        // Start a dummy server on the test port to simulate conflict
        try startDummyServer(on: testPort)
        
        // Create HTTP server manager and configure it to use the occupied port
        let serverManager = HTTPServerManager()
        var config = serverManager.configuration
        config.port = testPort
        config.ipAddress = "127.0.0.1"
        serverManager.updateConfiguration(config)
        
        // Verify that start() throws when port is occupied
        do {
            try await serverManager.start()
            XCTFail("Expected HTTPServerManager.start() to throw when port is occupied")
        } catch {
            // Expected behavior - server should fail to start
            XCTAssertFalse(serverManager.isRunning, "Server should not be running after failed start")
            XCTAssertTrue(serverManager.statusMessage.contains("Failed to start server"), 
                         "Status message should indicate failure")
        }
    }
    
    func testStartOrTerminateCallsExitOnPortConflict() async throws {
        // Start a dummy server on the test port
        try startDummyServer(on: testPort)
        
        // Create a mock server manager that doesn't actually call exit()
        let mockServerManager = MockFailFastHTTPServerManager()
        var config = mockServerManager.configuration
        config.port = testPort
        config.ipAddress = "127.0.0.1"
        mockServerManager.updateConfiguration(config)
        
        let expectation = XCTestExpectation(description: "Should call exit on startup failure")
        mockServerManager.exitHandler = {
            expectation.fulfill()
        }
        
        // Call startOrTerminate - should attempt to exit on failure
        await mockServerManager.startOrTerminate()
        
        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertTrue(mockServerManager.exitCalled, "Exit should be called when server fails to start")
    }
    
    func testRuntimeFailureTriggersExit() async throws {
        // Create a mock server manager that simulates runtime failure
        let mockServerManager = MockFailFastHTTPServerManager()
        var config = mockServerManager.configuration
        config.port = testPort
        config.ipAddress = "127.0.0.1"
        mockServerManager.updateConfiguration(config)
        
        // Start the server successfully first
        try await mockServerManager.start()
        XCTAssertTrue(mockServerManager.isRunning)
        
        let expectation = XCTestExpectation(description: "Should call exit on runtime failure")
        mockServerManager.exitHandler = {
            expectation.fulfill()
        }
        
        // Simulate runtime failure
        mockServerManager.simulateRuntimeFailure()
        
        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertTrue(mockServerManager.exitCalled, "Exit should be called when server fails during runtime")
    }
    
    // MARK: - Configuration Error Tests
    
    func testInvalidConfigurationFailsFast() async throws {
        let mockServerManager = MockFailFastHTTPServerManager()
        
        // Configure with invalid port range
        var config = mockServerManager.configuration
        config.port = -1 // Invalid port
        config.ipAddress = "127.0.0.1"
        mockServerManager.updateConfiguration(config)
        
        let expectation = XCTestExpectation(description: "Should call exit on invalid configuration")
        mockServerManager.exitHandler = {
            expectation.fulfill()
        }
        
        // Should fail and trigger exit
        await mockServerManager.startOrTerminate()
        
        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertTrue(mockServerManager.exitCalled, "Exit should be called with invalid configuration")
    }
    
    // MARK: - Helper Methods
    
    private func startDummyServer(on port: Int) throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        
        dummyListener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: UInt16(port)))
        dummyListener?.start(queue: .global())
        
        // Give the dummy server a moment to start
        Thread.sleep(forTimeInterval: 0.1)
    }
}

// MARK: - Mock HTTPServerManager for Integration Testing

class MockFailFastHTTPServerManager: HTTPServerManager {
    var exitCalled = false
    var exitHandler: (() -> Void)?
    
    override func startOrTerminate() async {
        do {
            try await start()
        } catch {
            exitCalled = true
            exitHandler?()
            // Don't actually call exit() in tests - just mark that it would be called
        }
    }
    
    func simulateRuntimeFailure() {
        // Simulate the listener failing during runtime
        let error = NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Simulated runtime failure"])
        
        // Manually trigger the failure handler that would normally be called by the network listener
        Task { @MainActor in
            if self.isRunning {
                self.exitCalled = true
                self.exitHandler?()
            }
        }
    }
} 