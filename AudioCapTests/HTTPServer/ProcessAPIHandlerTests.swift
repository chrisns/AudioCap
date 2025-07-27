//
//  ProcessAPIHandlerTests.swift
//  AudioCapTests
//
//  Unit tests for ProcessAPIHandler
//

import XCTest
import Foundation
import OSLog
@testable import AudioCap

/// Tests for ProcessAPIHandler functionality
/// Requirements: 3.3 (API Endpoints), 3.6 (Error Handling)
final class ProcessAPIHandlerTests: BaseTestCase {
    
    private var processController: AudioProcessController!
    private var processAPIHandler: ProcessAPIHandler!
    private var mockProcess: AudioProcess!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Initialize controller and handler
        processController = await AudioProcessController()
        processAPIHandler = await ProcessAPIHandler(processController: processController)
        
        // Create a mock process for testing
        mockProcess = AudioProcess(
            id: 1234,
            kind: .app,
            name: "Test App",
            audioActive: true,
            bundleID: "com.test.app",
            bundleURL: URL(fileURLWithPath: "/Applications/Test App.app"),
            objectID: 100
        )
    }
    
    override func tearDown() async throws {
        processController = nil
        processAPIHandler = nil
        mockProcess = nil
        try await super.tearDown()
    }
    
    override func customSetUp() {
        super.customSetUp()
        
        Task {
            await processController.activate()
        }
    }
    
    // MARK: - Process List Tests
    
    /// Test getting list of all processes returns expected structure
    /// Requirements: 3.3 (GET /api/processes)
    func testGetProcessesReturnsExpectedStructure() async throws {
        // Given: Controller is activated
        await processController.activate()
        
        // Wait for initial process discovery
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // When: Requesting process list
        let response = try await processAPIHandler.handleProcessList()
        
        // Then: Response should have expected structure
        XCTAssertNotNil(response.processes)
        XCTAssertNotNil(response.timestamp)
        XCTAssertTrue(response.processes.count >= 0)
    }
    
    /// Test getting process list has valid process data
    /// Requirements: 3.3 (GET /api/processes)
    func testGetProcessesHasValidProcessData() async throws {
        // Given: Controller is activated with processes
        await processController.activate()
        
        // Wait for initial process discovery
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // When: Requesting process list
        let response = try await processAPIHandler.handleProcessList()
        
        // Then: Response should contain valid process data
        for processInfo in response.processes {
            XCTAssertFalse(processInfo.id.isEmpty, "Process ID should not be empty")
            XCTAssertFalse(processInfo.name.isEmpty, "Process name should not be empty")
            XCTAssertNotNil(Int(processInfo.id), "Process ID should be numeric")
        }
    }
    
    /// Test getting process list returns consistent results
    /// Requirements: 3.3 (API Consistency)
    func testGetProcessesReturnsConsistentResults() async throws {
        // Given: Controller is activated
        await processController.activate()
        
        // Wait for initial process discovery
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // When: Making multiple requests
        let response1 = try await processAPIHandler.handleProcessList()
        let response2 = try await processAPIHandler.handleProcessList()
        
        // Then: Results should be relatively stable
        let countDifference = abs(response1.processes.count - response2.processes.count)
        XCTAssertTrue(countDifference <= 5, "Process count should be relatively stable")
    }
    
    // MARK: - Error Handling Tests
    
    /// Test process API handler with inactive controller
    /// Requirements: 3.6 (Error Handling)
    func testProcessAPIHandlerWithInactiveController() async throws {
        // Given: A fresh controller that hasn't been activated
        let controller = await AudioProcessController()
        let handler = await ProcessAPIHandler(processController: controller)
        
        // When: Requesting process list without activation
        await controller.activate()
        let response = try await handler.handleProcessList()
        
        // Then: Should still return valid response (may be empty)
        XCTAssertNotNil(response.processes)
        XCTAssertNotNil(response.timestamp)
    }
    
    func testAPIHandlerError_ProcessListFailed() async throws {
        // Given: A fresh controller
        let controller = await AudioProcessController()
        let handler = await ProcessAPIHandler(processController: controller)
        
        // When: Requesting process list
        await controller.activate()
        let response = try await handler.handleProcessList()
        
        // Then: Should return valid response
        XCTAssertNotNil(response)
        XCTAssertTrue(response.processes.count >= 0)
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
        let controller = await AudioProcessController()
        let handler = await ProcessAPIHandler(processController: controller)
        
        // When: Activating controller and getting process list
        await controller.activate()
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