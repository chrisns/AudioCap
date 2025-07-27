import XCTest
import Foundation
import Network
@testable import AudioCap

/// End-to-end integration tests for HTTP API endpoints using actual HTTP requests
/// Tests the complete workflow: server start, process list, record start/stop
final class HTTPEndToEndTests: XCTestCase {
    
    private var httpServerManager: HTTPServerManager!
    private var testPort: Int = 0
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Find an available port for testing
        testPort = try findAvailablePort()
        
        // Create and configure HTTP server manager
        await MainActor.run {
            httpServerManager = HTTPServerManager()
            var config = httpServerManager.configuration
            config.port = testPort
            config.ipAddress = "127.0.0.1"
            httpServerManager.updateConfiguration(config)
        }
        
        // Start the server
        try await httpServerManager.start()
        
        // Wait a moment for server to be ready
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    override func tearDown() async throws {
        // Stop the server
        if let serverManager = httpServerManager {
            await serverManager.stop()
        }
        
        try await super.tearDown()
    }
    
    /// Test complete workflow: server start, process list, record start/stop
    /// Requirements: 3.1, 3.2, 3.3, 3.4, 4.1, 4.2, 4.3
    func testCompleteWorkflow() async throws {
        let baseURL = "http://127.0.0.1:\(testPort)"
        
        // Test 1: GET /processes - should return process list
        let processListData = try await performHTTPRequest(
            url: "\(baseURL)/processes",
            method: "GET"
        )
        
        let processListResponse = try JSONDecoder().decode(ProcessListResponse.self, from: processListData)
        XCTAssertNotNil(processListResponse.processes)
        XCTAssertNotNil(processListResponse.timestamp)
        
        // Test 2: GET /recording/status - should return idle status
        let statusData = try await performHTTPRequest(
            url: "\(baseURL)/recording/status",
            method: "GET"
        )
        
        let statusResponse = try JSONDecoder().decode(RecordingStatusResponse.self, from: statusData)
        XCTAssertEqual(statusResponse.status, .idle)
        XCTAssertNil(statusResponse.currentSession)
        XCTAssertNil(statusResponse.elapsedTime)
        
        // Test 3: POST /recording/start with invalid process ID - should return error
        let invalidStartRequest = """
        {"processId": "invalid-id"}
        """
        
        do {
            _ = try await performHTTPRequest(
                url: "\(baseURL)/recording/start",
                method: "POST",
                body: invalidStartRequest.data(using: .utf8)
            )
            XCTFail("Expected error for invalid process ID")
        } catch HTTPTestError.httpError(let statusCode, _) {
            XCTAssertEqual(statusCode, 400) // Bad Request
        }
        
        // Test 4: POST /recording/stop when not recording - should return error
        do {
            _ = try await performHTTPRequest(
                url: "\(baseURL)/recording/stop",
                method: "POST"
            )
            XCTFail("Expected error when stopping without recording")
        } catch HTTPTestError.httpError(let statusCode, _) {
            XCTAssertEqual(statusCode, 409) // Conflict
        }
        
        // Test 5: GET /docs - should return HTML documentation
        let docsData = try await performHTTPRequest(
            url: "\(baseURL)/docs",
            method: "GET"
        )
        
        let docsHTML = String(data: docsData, encoding: .utf8)
        XCTAssertNotNil(docsHTML)
        XCTAssertTrue(docsHTML?.contains("AudioCap API Documentation") == true)
        XCTAssertTrue(docsHTML?.contains("swagger-ui") == true)
    }
    
    /// Test curl-like commands as specified in requirements
    /// Requirements: 3.1, 3.2, 3.3, 3.4
    func testCurlCommands() async throws {
        let baseURL = "http://127.0.0.1:\(testPort)"
        
        // Test: curl -X GET http://127.0.0.1:5742/processes
        let processListData = try await performHTTPRequest(
            url: "\(baseURL)/processes",
            method: "GET"
        )
        
        // Verify JSON response structure
        let json = try JSONSerialization.jsonObject(with: processListData) as? [String: Any]
        XCTAssertNotNil(json)
        XCTAssertNotNil(json?["processes"])
        XCTAssertNotNil(json?["timestamp"])
        
        // Test: curl -X GET http://127.0.0.1:5742/recording/status
        let statusData = try await performHTTPRequest(
            url: "\(baseURL)/recording/status",
            method: "GET"
        )
        
        let statusJson = try JSONSerialization.jsonObject(with: statusData) as? [String: Any]
        XCTAssertNotNil(statusJson)
        XCTAssertNotNil(statusJson?["status"])
        XCTAssertEqual(statusJson?["status"] as? String, "idle")
        
        // Test: curl -X POST http://127.0.0.1:5742/recording/start -d '{"processId": "123"}'
        let startRequestBody = """
        {"processId": "123"}
        """
        
        do {
            _ = try await performHTTPRequest(
                url: "\(baseURL)/recording/start",
                method: "POST",
                body: startRequestBody.data(using: .utf8)
            )
            XCTFail("Expected error for non-existent process")
        } catch HTTPTestError.httpError(let statusCode, let responseData) {
            XCTAssertEqual(statusCode, 400) // Bad Request
            
            // Verify error response structure
            if let errorJson = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let error = errorJson["error"] as? [String: Any] {
                XCTAssertNotNil(error["code"])
                XCTAssertNotNil(error["message"])
            }
        }
        
        // Test: curl -X POST http://127.0.0.1:5742/recording/stop
        do {
            _ = try await performHTTPRequest(
                url: "\(baseURL)/recording/stop",
                method: "POST"
            )
            XCTFail("Expected error when not recording")
        } catch HTTPTestError.httpError(let statusCode, let responseData) {
            XCTAssertEqual(statusCode, 409) // Conflict
            
            // Verify error response structure
            if let errorJson = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let error = errorJson["error"] as? [String: Any] {
                XCTAssertEqual(error["code"] as? String, "NOT_RECORDING")
                XCTAssertNotNil(error["message"])
            }
        }
    }
    
    /// Test metadata responses include all required fields
    /// Requirements: 4.1, 4.2, 4.3
    func testMetadataResponseFields() async throws {
        let baseURL = "http://127.0.0.1:\(testPort)"
        
        // Test process list metadata
        let processListData = try await performHTTPRequest(
            url: "\(baseURL)/processes",
            method: "GET"
        )
        
        let processListResponse = try JSONDecoder().decode(ProcessListResponse.self, from: processListData)
        
        // Verify timestamp is recent (within last 10 seconds)
        let timeDifference = Date().timeIntervalSince(processListResponse.timestamp)
        XCTAssertLessThan(timeDifference, 10.0)
        
        // Verify process info structure
        for process in processListResponse.processes {
            XCTAssertFalse(process.id.isEmpty)
            XCTAssertFalse(process.name.isEmpty)
            // hasAudioCapability can be true or false
        }
        
        // Test recording status metadata
        let statusData = try await performHTTPRequest(
            url: "\(baseURL)/recording/status",
            method: "GET"
        )
        
        let statusResponse = try JSONDecoder().decode(RecordingStatusResponse.self, from: statusData)
        XCTAssertEqual(statusResponse.status, .idle)
        XCTAssertNil(statusResponse.currentSession) // Should be nil when idle
        XCTAssertNil(statusResponse.elapsedTime) // Should be nil when idle
    }
    
    /// Test error handling and HTTP status codes
    /// Requirements: 4.4
    func testErrorHandlingAndStatusCodes() async throws {
        let baseURL = "http://127.0.0.1:\(testPort)"
        
        // Test 404 for unknown endpoint
        do {
            _ = try await performHTTPRequest(
                url: "\(baseURL)/unknown",
                method: "GET"
            )
            XCTFail("Expected 404 for unknown endpoint")
        } catch HTTPTestError.httpError(let statusCode, _) {
            XCTAssertEqual(statusCode, 404)
        }
        
        // Test 405 for wrong method
        do {
            _ = try await performHTTPRequest(
                url: "\(baseURL)/processes",
                method: "POST"
            )
            XCTFail("Expected 405 for wrong method")
        } catch HTTPTestError.httpError(let statusCode, _) {
            XCTAssertEqual(statusCode, 405)
        }
        
        // Test 400 for invalid JSON
        do {
            _ = try await performHTTPRequest(
                url: "\(baseURL)/recording/start",
                method: "POST",
                body: "invalid json".data(using: .utf8)
            )
            XCTFail("Expected 400 for invalid JSON")
        } catch HTTPTestError.httpError(let statusCode, _) {
            XCTAssertEqual(statusCode, 400)
        }
    }
    
    // MARK: - Helper Methods
    
    private func findAvailablePort() throws -> Int {
        let listener = try NWListener(using: .tcp, on: .any)
        listener.start(queue: .main)
        
        guard case .ready = listener.state else {
            throw HTTPTestError.portNotAvailable
        }
        
        let port = listener.port?.rawValue ?? 0
        listener.cancel()
        
        guard port > 0 else {
            throw HTTPTestError.portNotAvailable
        }
        
        return Int(port)
    }
    
    private func performHTTPRequest(
        url: String,
        method: String,
        body: Data? = nil
    ) async throws -> Data {
        guard let requestURL = URL(string: url) else {
            throw HTTPTestError.invalidURL
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        
        if let body = body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPTestError.invalidResponse
        }
        
        if httpResponse.statusCode >= 400 {
            throw HTTPTestError.httpError(httpResponse.statusCode, data)
        }
        
        return data
    }
}

enum HTTPTestError: Error {
    case invalidURL
    case invalidResponse
    case portNotAvailable
    case httpError(Int, Data)
}