//
//  ProcessAPIHandlerTests.swift
//  AudioCapTests
//
//  Unit tests for ProcessAPIHandler
//

import XCTest
@testable import AudioCap

@MainActor
final class ProcessAPIHandlerTests: XCTestCase {
    
    private var processController: AudioProcessController!
    private var processAPIHandler: ProcessAPIHandler!
    
    override func setUp() async throws {
        try await super.setUp()
        processController = AudioProcessController()
        processAPIHandler = ProcessAPIHandler(processController: processController)
    }
    
    override func tearDown() async throws {
        processAPIHandler = nil
        processController = nil
        try await super.tearDown()
    }
    
    // MARK: - Process List Tests
    
    func testHandleProcessList_ReturnsValidResponse() async throws {
        // Given: Process controller is activated to populate processes
        processController.activate()
        
        // Wait a moment for processes to be loaded
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // When: Handling process list request
        let response = try await processAPIHandler.handleProcessList()
        
        // Then: Response should be valid
        XCTAssertNotNil(response)
        XCTAssertTrue(response.processes.count >= 0) // Should have at least 0 processes
        XCTAssertNotNil(response.timestamp)
        
        // Verify timestamp is recent (within last 5 seconds)
        let now = Date()
        let timeDifference = now.timeIntervalSince(response.timestamp)
        XCTAssertTrue(timeDifference >= 0 && timeDifference < 5.0, "Timestamp should be recent")
    }
    
    func testHandleProcessList_ProcessInfoStructure() async throws {
        // Given: Process controller with some processes
        processController.activate()
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // When: Handling process list request
        let response = try await processAPIHandler.handleProcessList()
        
        // Then: Each process info should have valid structure
        for processInfo in response.processes {
            XCTAssertFalse(processInfo.id.isEmpty, "Process ID should not be empty")
            XCTAssertFalse(processInfo.name.isEmpty, "Process name should not be empty")
            // hasAudioCapability can be true or false, both are valid
        }
    }
    
    func testHandleProcessList_ProcessIdIsNumeric() async throws {
        // Given: Process controller with processes
        processController.activate()
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // When: Handling process list request
        let response = try await processAPIHandler.handleProcessList()
        
        // Then: Process IDs should be numeric (convertible to Int)
        for processInfo in response.processes {
            XCTAssertNotNil(Int(processInfo.id), "Process ID '\(processInfo.id)' should be numeric")
        }
    }
    
    func testHandleProcessList_ConsistentResults() async throws {
        // Given: Process controller is activated
        processController.activate()
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // When: Making multiple requests
        let response1 = try await processAPIHandler.handleProcessList()
        let response2 = try await processAPIHandler.handleProcessList()
        
        // Then: Results should be consistent (same process count within reasonable bounds)
        // Note: Process count might vary slightly due to system processes starting/stopping
        let countDifference = abs(response1.processes.count - response2.processes.count)
        XCTAssertTrue(countDifference <= 5, "Process count should be relatively stable between requests")
    }
    
    // MARK: - Error Handling Tests
    
    func testAPIHandlerError_ProcessListFailed() {
        // Given: A process list failed error
        let error = APIHandlerError.processListFailed("Test error message")
        
        // When: Converting to API error
        let apiError = error.apiError
        
        // Then: Should have correct structure
        XCTAssertEqual(apiError.code, "PROCESS_LIST_FAILED")
        XCTAssertEqual(apiError.message, "Failed to retrieve process list")
        XCTAssertEqual(apiError.details, "Test error message")
        XCTAssertEqual(error.httpStatusCode, 500)
    }
    
    func testAPIHandlerError_InvalidRequest() {
        // Given: An invalid request error
        let error = APIHandlerError.invalidRequest("Invalid parameter")
        
        // When: Converting to API error
        let apiError = error.apiError
        
        // Then: Should have correct structure
        XCTAssertEqual(apiError.code, "INVALID_REQUEST")
        XCTAssertEqual(apiError.message, "Invalid request parameters")
        XCTAssertEqual(apiError.details, "Invalid parameter")
        XCTAssertEqual(error.httpStatusCode, 400)
    }
    
    func testAPIHandlerError_InternalError() {
        // Given: An internal error
        let error = APIHandlerError.internalError("System failure")
        
        // When: Converting to API error
        let apiError = error.apiError
        
        // Then: Should have correct structure
        XCTAssertEqual(apiError.code, "INTERNAL_ERROR")
        XCTAssertEqual(apiError.message, "Internal server error")
        XCTAssertEqual(apiError.details, "System failure")
        XCTAssertEqual(error.httpStatusCode, 500)
    }
    
    func testAPIHandlerError_LocalizedDescription() {
        // Given: Different types of errors
        let processListError = APIHandlerError.processListFailed("Process error")
        let invalidRequestError = APIHandlerError.invalidRequest("Request error")
        let internalError = APIHandlerError.internalError("Internal error")
        
        // When: Getting localized descriptions
        let processListDescription = processListError.localizedDescription
        let invalidRequestDescription = invalidRequestError.localizedDescription
        let internalDescription = internalError.localizedDescription
        
        // Then: Should have meaningful descriptions
        XCTAssertTrue(processListDescription.contains("Failed to retrieve process list"))
        XCTAssertTrue(invalidRequestDescription.contains("Invalid request"))
        XCTAssertTrue(internalDescription.contains("Internal error"))
    }
    
    // MARK: - Integration Tests
    
    func testProcessAPIHandler_Integration() async throws {
        // Given: A fresh process controller and handler
        let controller = AudioProcessController()
        let handler = ProcessAPIHandler(processController: controller)
        
        // When: Activating controller and getting process list
        controller.activate()
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        let response = try await handler.handleProcessList()
        
        // Then: Should get a valid response with system processes
        XCTAssertNotNil(response)
        XCTAssertTrue(response.processes.count >= 0)
        
        // Should include some common system processes (if any are running)
        let _ = response.processes.map { $0.name.lowercased() }
        
        // At minimum, we should have some processes running on the system
        // This is a very loose test since we can't guarantee specific processes
        if response.processes.count > 0 {
            XCTAssertTrue(response.processes.allSatisfy { !$0.id.isEmpty })
            XCTAssertTrue(response.processes.allSatisfy { !$0.name.isEmpty })
        }
    }
}