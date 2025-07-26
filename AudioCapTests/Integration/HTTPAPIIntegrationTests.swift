import XCTest
import Foundation
import OSLog
@testable import AudioCap

/// Integration tests for HTTP API components and workflow
/// Tests the API handlers, data models, and integration between components
final class HTTPAPIIntegrationTests: XCTestCase {
    
    private let logger = Logger(subsystem: "com.audiocap.tests", category: "HTTPAPIIntegrationTests")
    
    // Test configuration
    private var tempDirectory: URL!
    
    // Test components
    private var processController: AudioProcessController!
    private var processAPIHandler: ProcessAPIHandler!
    private var recordingAPIHandler: RecordingAPIHandler!
    
    override func setUp() {
        super.setUp()
        
        // Set up temporary directory
        tempDirectory = TestHelpers.createTemporaryDirectory(prefix: "HTTPAPIIntegrationTests")
        
        logger.info("HTTPAPIIntegrationTests setup completed")
    }
    
    @MainActor
    private func setupComponents() async {
        // Set up process controller
        processController = AudioProcessController()
        
        // Set up API handlers
        processAPIHandler = ProcessAPIHandler(processController: processController)
        recordingAPIHandler = RecordingAPIHandler(processController: processController)
    }
    
    override func tearDown() {
        // Clean up temporary directory
        TestHelpers.cleanupTemporaryDirectory(at: tempDirectory)
        
        logger.info("HTTPAPIIntegrationTests teardown completed")
        super.tearDown()
    }
    
    // MARK: - Process Listing API Tests
    
    /// Test process listing API handler returns valid process list
    /// Requirements: 5.2 - Test process listing via API
    func testProcessListingAPIHandler() async throws {
        // Given: Components are set up
        await setupComponents()
        
        // Process controller is activated
        await processController.activate()
        
        // Allow some time for process enumeration
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // When: Calling the process list handler
        let processListResponse = try await processAPIHandler.handleProcessList()
        
        // Then: Response should contain valid data
        XCTAssertNotNil(processListResponse.processes)
        XCTAssertNotNil(processListResponse.timestamp)
        
        // Verify timestamp is recent (within last 10 seconds)
        let timeDifference = Date().timeIntervalSince(processListResponse.timestamp)
        XCTAssertLessThan(timeDifference, 10.0)
        
        // Verify process data structure
        for process in processListResponse.processes {
            XCTAssertFalse(process.id.isEmpty)
            XCTAssertFalse(process.name.isEmpty)
            // hasAudioCapability can be true or false
        }
        
        logger.info("Process list API handler returned \(processListResponse.processes.count) processes")
    }
    
    /// Test process listing response schema validation
    /// Requirements: 5.5 - Verify that API responses match expected JSON schemas
    func testProcessListingResponseSchema() async throws {
        // Given: Components are set up
        await setupComponents()
        
        // Process controller is activated
        await processController.activate()
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // When: Getting process list response
        let processListResponse = try await processAPIHandler.handleProcessList()
        
        // Then: Serialize to JSON and verify schema
        let data = try JSONEncoder().encode(processListResponse)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json)
        
        // Verify top-level structure
        XCTAssertNotNil(json?["processes"])
        XCTAssertNotNil(json?["timestamp"])
        
        // Verify processes array structure
        let processes = json?["processes"] as? [[String: Any]]
        XCTAssertNotNil(processes)
        
        for process in processes ?? [] {
            XCTAssertNotNil(process["id"])
            XCTAssertNotNil(process["name"])
            XCTAssertNotNil(process["hasAudioCapability"])
            
            // Verify data types
            XCTAssertTrue(process["id"] is String)
            XCTAssertTrue(process["name"] is String)
            XCTAssertTrue(process["hasAudioCapability"] is Bool)
        }
        
        logger.info("Process list response schema validation passed")
    }
    
    // MARK: - Recording Control API Tests
    
    /// Test recording status API handler
    /// Requirements: 5.3 - Test recording start/stop workflow via API calls
    func testRecordingStatusAPIHandler() async throws {
        // Given: Components are set up
        await setupComponents()
        
        // When: Getting recording status
        let statusResponse = try await recordingAPIHandler.handleRecordingStatus()
        
        // Then: Should return valid status response
        XCTAssertNotNil(statusResponse.status)
        
        // In test environment, should typically be idle
        if statusResponse.status == .idle {
            XCTAssertNil(statusResponse.currentSession)
            XCTAssertNil(statusResponse.elapsedTime)
        } else if statusResponse.status == .recording {
            XCTAssertNotNil(statusResponse.currentSession)
            XCTAssertNotNil(statusResponse.elapsedTime)
            XCTAssertGreaterThanOrEqual(statusResponse.elapsedTime!, 0)
        }
        
        logger.info("Recording status API handler returned status: \(statusResponse.status.rawValue)")
    }
    
    /// Test recording with invalid process ID
    /// Requirements: 5.4 - Test error conditions and error handling
    func testRecordingWithInvalidProcessId() async throws {
        // Given: Components are set up
        await setupComponents()
        
        // Invalid start recording request
        let invalidRequest = StartRecordingRequest(
            processId: "invalid-process-id",
            outputFormat: nil
        )
        
        // When: Attempting to start recording with invalid process ID
        do {
            _ = try await recordingAPIHandler.handleStartRecording(request: invalidRequest)
            XCTFail("Expected error for invalid process ID")
        } catch {
            // Then: Should return appropriate error
            XCTAssertTrue(error.localizedDescription.contains("process") || 
                         error.localizedDescription.contains("not found") ||
                         error.localizedDescription.contains("invalid"))
            logger.info("Invalid process ID handled correctly: \(error)")
        }
    }
    
    // MARK: - JSON Schema Validation Tests
    
    /// Test API responses match expected JSON schemas
    /// Requirements: 5.5 - Verify that API responses match expected JSON schemas
    func testAPIResponseSchemaValidation() async throws {
        // Given: Components are set up
        await setupComponents()
        
        // Process controller is activated
        await processController.activate()
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Test 1: Process list response schema
        let processListResponse = try await processAPIHandler.handleProcessList()
        try validateProcessListResponseSchema(response: processListResponse)
        
        // Test 2: Recording status response schema
        let statusResponse = try await recordingAPIHandler.handleRecordingStatus()
        try validateRecordingStatusResponseSchema(response: statusResponse)
        
        logger.info("All API response schemas validated successfully")
    }
    
    // MARK: - Schema Validation Helpers
    
    private func validateProcessListResponseSchema(response: ProcessListResponse) throws {
        // Serialize to JSON and validate structure
        let data = try JSONEncoder().encode(response)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json)
        
        // Required fields
        XCTAssertNotNil(json?["processes"])
        XCTAssertNotNil(json?["timestamp"])
        
        // Validate processes array
        let processes = json?["processes"] as? [[String: Any]]
        XCTAssertNotNil(processes)
        
        for process in processes ?? [] {
            XCTAssertNotNil(process["id"])
            XCTAssertNotNil(process["name"])
            XCTAssertNotNil(process["hasAudioCapability"])
            
            XCTAssertTrue(process["id"] is String)
            XCTAssertTrue(process["name"] is String)
            XCTAssertTrue(process["hasAudioCapability"] is Bool)
        }
        
        // Validate timestamp format
        XCTAssertTrue(json?["timestamp"] is String || json?["timestamp"] is Double)
    }
    
    private func validateRecordingStatusResponseSchema(response: RecordingStatusResponse) throws {
        // Serialize to JSON and validate structure
        let data = try JSONEncoder().encode(response)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json)
        
        // Required fields
        XCTAssertNotNil(json?["status"])
        
        // Validate status
        let status = json?["status"] as? String
        XCTAssertTrue(["idle", "recording", "stopping"].contains(status))
        
        // If currentSession exists, validate its structure
        if let currentSession = json?["currentSession"] as? [String: Any] {
            XCTAssertNotNil(currentSession["sessionId"])
            XCTAssertNotNil(currentSession["processId"])
            XCTAssertNotNil(currentSession["processName"])
            XCTAssertNotNil(currentSession["startTime"])
            XCTAssertNotNil(currentSession["status"])
        }
        
        // If elapsedTime exists, validate it's a number
        if let elapsedTime = json?["elapsedTime"] {
            XCTAssertTrue(elapsedTime is Double || elapsedTime is Int)
        }
    }
}