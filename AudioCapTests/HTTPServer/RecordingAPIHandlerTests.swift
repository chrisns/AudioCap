//
//  RecordingAPIHandlerTests.swift
//  AudioCapTests
//
//  Unit tests for RecordingAPIHandler
//

import XCTest
import Foundation
import OSLog
@testable import AudioCap

/// Tests for RecordingAPIHandler functionality
/// Requirements: 3.3 (API Endpoints), 3.6 (Error Handling)
final class RecordingAPIHandlerTests: BaseTestCase {
    
    private var processController: AudioProcessController!
    private var recordingAPIHandler: RecordingAPIHandler!
    
    override func setUp() async throws {
        // Skip the entire test suite when running in Continuous Integration environments.
        // CI servers usually set the "CI" environment variable, which we use as the signal.
        // This prevents failures on hosts that do not have audio capture capabilities or
        // the necessary entitlements to run these integration-heavy tests.
        if ProcessInfo.processInfo.environment["CI"] != nil {
            throw XCTSkip("Skipping RecordingAPIHandlerTests in CI environment")
        }

        try await super.setUp()

        processController = await AudioProcessController()
        recordingAPIHandler = await RecordingAPIHandler(processController: processController)

        // Activate process controller to populate processes
        await processController.activate()
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
    }
    
    override func tearDown() async throws {
        recordingAPIHandler = nil
        processController = nil
        try await super.tearDown()
    }
    
    // MARK: - Recording Status Tests
    
    func testHandleRecordingStatus_InitialState() async throws {
        // When: Getting initial recording status
        let response = try await recordingAPIHandler.handleRecordingStatus()
        
        // Then: Should be idle with no session
        XCTAssertEqual(response.status, .idle)
        XCTAssertNil(response.currentSession)
        XCTAssertNil(response.elapsedTime)
    }
    
    // MARK: - Start Recording Tests
    
    func testHandleStartRecording_InvalidProcessId() async throws {
        // Given: Invalid process ID request
        let request = StartRecordingRequest(processId: "invalid", outputFormat: nil)
        
        // When/Then: Should throw invalid process ID error
        do {
            _ = try await recordingAPIHandler.handleStartRecording(request: request)
            XCTFail("Expected error to be thrown")
        } catch let error as RecordingAPIError {
            XCTAssertEqual(error.httpStatusCode, 400)
            XCTAssertEqual(error.apiError.code, "INVALID_PROCESS_ID")
        }
    }
    
    func testHandleStartRecording_EmptyProcessId() async throws {
        // Given: Empty process ID request
        let request = StartRecordingRequest(processId: "", outputFormat: nil)
        
        // When/Then: Should throw invalid process ID error
        do {
            _ = try await recordingAPIHandler.handleStartRecording(request: request)
            XCTFail("Expected error to be thrown")
        } catch let error as RecordingAPIError {
            XCTAssertEqual(error.httpStatusCode, 400)
            XCTAssertEqual(error.apiError.code, "INVALID_PROCESS_ID")
        }
    }
    
    func testHandleStartRecording_WhitespaceProcessId() async throws {
        // Given: Whitespace-only process ID request
        let request = StartRecordingRequest(processId: "   \n\t  ", outputFormat: nil)
        
        // When/Then: Should throw invalid process ID error
        do {
            _ = try await recordingAPIHandler.handleStartRecording(request: request)
            XCTFail("Expected error to be thrown")
        } catch let error as RecordingAPIError {
            XCTAssertEqual(error.httpStatusCode, 400)
            XCTAssertEqual(error.apiError.code, "INVALID_PROCESS_ID")
        }
    }
    
    func testHandleStartRecording_NegativeProcessId() async throws {
        // Given: Negative process ID request
        let request = StartRecordingRequest(processId: "-123", outputFormat: nil)
        
        // When/Then: Should throw invalid process ID error
        do {
            _ = try await recordingAPIHandler.handleStartRecording(request: request)
            XCTFail("Expected error to be thrown")
        } catch let error as RecordingAPIError {
            XCTAssertEqual(error.httpStatusCode, 400)
            XCTAssertEqual(error.apiError.code, "INVALID_PROCESS_ID")
        }
    }
    
    func testHandleStartRecording_ZeroProcessId() async throws {
        // Given: Zero process ID request
        let request = StartRecordingRequest(processId: "0", outputFormat: nil)
        
        // When/Then: Should throw invalid process ID error
        do {
            _ = try await recordingAPIHandler.handleStartRecording(request: request)
            XCTFail("Expected error to be thrown")
        } catch let error as RecordingAPIError {
            XCTAssertEqual(error.httpStatusCode, 400)
            XCTAssertEqual(error.apiError.code, "INVALID_PROCESS_ID")
        }
    }
    
    func testHandleStartRecording_ProcessNotFound() async throws {
        // Given: Non-existent process ID request
        let request = StartRecordingRequest(processId: "99999", outputFormat: nil)
        
        // When/Then: Should throw process not found error
        do {
            _ = try await recordingAPIHandler.handleStartRecording(request: request)
            XCTFail("Expected error to be thrown")
        } catch let error as RecordingAPIError {
            XCTAssertEqual(error.httpStatusCode, 400)
            XCTAssertEqual(error.apiError.code, "PROCESS_NOT_FOUND")
        }
    }
    
    func testHandleStartRecording_ValidProcess() async throws {
        // Given: A valid process from the process list
        guard let firstProcess = await processController.processes.first else {
            throw XCTSkip("No processes available for testing")
        }
        
        let request = StartRecordingRequest(processId: String(firstProcess.id), outputFormat: nil)
        
        // When: Starting recording
        let session = try await recordingAPIHandler.handleStartRecording(request: request)
        
        // Then: Should return valid session
        XCTAssertFalse(session.sessionId.isEmpty)
        XCTAssertEqual(session.processId, String(firstProcess.id))
        XCTAssertEqual(session.processName, firstProcess.name)
        XCTAssertEqual(session.status, .recording)
        XCTAssertTrue(session.startTime.timeIntervalSinceNow > -5) // Started within last 5 seconds
        
        // Clean up - stop recording
        _ = try await recordingAPIHandler.handleStopRecording()
    }
    
    func testHandleStartRecording_AlreadyRecording() async throws {
        // Given: A recording is already in progress
        guard let firstProcess = await processController.processes.first else {
            throw XCTSkip("No processes available for testing")
        }
        
        let request = StartRecordingRequest(processId: String(firstProcess.id), outputFormat: nil)
        
        // Start first recording
        _ = try await recordingAPIHandler.handleStartRecording(request: request)
        
        // When/Then: Attempting to start another recording should fail
        do {
            _ = try await recordingAPIHandler.handleStartRecording(request: request)
            XCTFail("Expected error to be thrown")
        } catch let error as RecordingAPIError {
            XCTAssertEqual(error.httpStatusCode, 409)
            XCTAssertEqual(error.apiError.code, "ALREADY_RECORDING")
        }
        
        // Clean up
        _ = try await recordingAPIHandler.handleStopRecording()
    }
    
    // MARK: - Stop Recording Tests
    
    func testHandleStopRecording_NotRecording() async throws {
        // When/Then: Stopping when not recording should fail
        do {
            _ = try await recordingAPIHandler.handleStopRecording()
            XCTFail("Expected error to be thrown")
        } catch let error as RecordingAPIError {
            XCTAssertEqual(error.httpStatusCode, 409)
            XCTAssertEqual(error.apiError.code, "NOT_RECORDING")
        }
    }
    
    func testHandleStopRecording_ValidRecording() async throws {
        // Given: A recording is in progress
        guard let firstProcess = await processController.processes.first else {
            throw XCTSkip("No processes available for testing")
        }
        
        let request = StartRecordingRequest(processId: String(firstProcess.id), outputFormat: nil)
        let session = try await recordingAPIHandler.handleStartRecording(request: request)
        
        // Wait a brief moment to ensure some recording time
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // When: Stopping recording
        let metadata = try await recordingAPIHandler.handleStopRecording()
        
        // Then: Should return valid metadata
        XCTAssertEqual(metadata.sessionId, session.sessionId)
        XCTAssertFalse(metadata.filePath.isEmpty)
        XCTAssertTrue(metadata.duration > 0)
        XCTAssertTrue(metadata.channelCount > 0)
        XCTAssertTrue(metadata.sampleRate > 0)
        XCTAssertTrue(metadata.fileSize >= 0)
        XCTAssertTrue(metadata.endTime.timeIntervalSinceNow > -5) // Ended within last 5 seconds
        
        // Verify file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: metadata.filePath))
        
        // Clean up - remove test file
        try? FileManager.default.removeItem(atPath: metadata.filePath)
    }
    
    // MARK: - Recording Status During Recording Tests
    
    func testHandleRecordingStatus_DuringRecording() async throws {
        // Given: A recording is in progress
        guard let firstProcess = await processController.processes.first else {
            throw XCTSkip("No processes available for testing")
        }
        
        let request = StartRecordingRequest(processId: String(firstProcess.id), outputFormat: nil)
        let session = try await recordingAPIHandler.handleStartRecording(request: request)
        
        // Wait a brief moment
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // When: Getting recording status
        let response = try await recordingAPIHandler.handleRecordingStatus()
        
        // Then: Should show recording status
        XCTAssertEqual(response.status, .recording)
        XCTAssertNotNil(response.currentSession)
        XCTAssertEqual(response.currentSession?.sessionId, session.sessionId)
        XCTAssertNotNil(response.elapsedTime)
        XCTAssertTrue(response.elapsedTime! > 0)
        
        // Clean up
        _ = try await recordingAPIHandler.handleStopRecording()
    }
    
    func testHandleRecordingStatus_AfterStopping() async throws {
        // Given: A recording was started and stopped
        guard let firstProcess = await processController.processes.first else {
            throw XCTSkip("No processes available for testing")
        }
        
        let request = StartRecordingRequest(processId: String(firstProcess.id), outputFormat: nil)
        _ = try await recordingAPIHandler.handleStartRecording(request: request)
        let metadata = try await recordingAPIHandler.handleStopRecording()
        
        // When: Getting recording status after stopping
        let response = try await recordingAPIHandler.handleRecordingStatus()
        
        // Then: Should be idle again
        XCTAssertEqual(response.status, .idle)
        XCTAssertNil(response.currentSession)
        XCTAssertNil(response.elapsedTime)
        
        // Clean up
        try? FileManager.default.removeItem(atPath: metadata.filePath)
    }
    
    // MARK: - Error Handling Tests
    
    func testRecordingAPIError_InvalidProcessId() {
        // Given: Invalid process ID error
        let error = RecordingAPIError.invalidProcessId("abc")
        
        // When: Converting to API error
        let apiError = error.apiError
        
        // Then: Should have correct structure
        XCTAssertEqual(apiError.code, "INVALID_PROCESS_ID")
        XCTAssertEqual(apiError.message, "Invalid process ID format")
        XCTAssertTrue(apiError.details?.contains("abc") == true)
        XCTAssertEqual(error.httpStatusCode, 400)
    }
    
    func testRecordingAPIError_ProcessNotFound() {
        // Given: Process not found error
        let error = RecordingAPIError.processNotFound("12345")
        
        // When: Converting to API error
        let apiError = error.apiError
        
        // Then: Should have correct structure
        XCTAssertEqual(apiError.code, "PROCESS_NOT_FOUND")
        XCTAssertEqual(apiError.message, "The specified process was not found")
        XCTAssertTrue(apiError.details?.contains("12345") == true)
        XCTAssertEqual(error.httpStatusCode, 400)
    }
    
    func testRecordingAPIError_AlreadyRecording() {
        // Given: Already recording error
        let error = RecordingAPIError.alreadyRecording
        
        // When: Converting to API error
        let apiError = error.apiError
        
        // Then: Should have correct structure
        XCTAssertEqual(apiError.code, "ALREADY_RECORDING")
        XCTAssertEqual(apiError.message, "Recording is already in progress")
        XCTAssertEqual(error.httpStatusCode, 409)
    }
    
    func testRecordingAPIError_NotRecording() {
        // Given: Not recording error
        let error = RecordingAPIError.notRecording
        
        // When: Converting to API error
        let apiError = error.apiError
        
        // Then: Should have correct structure
        XCTAssertEqual(apiError.code, "NOT_RECORDING")
        XCTAssertEqual(apiError.message, "No recording is currently active")
        XCTAssertEqual(error.httpStatusCode, 409)
    }
    
    func testRecordingAPIError_RecordingStartFailed() {
        // Given: Recording start failed error
        let error = RecordingAPIError.recordingStartFailed("Permission denied")
        
        // When: Converting to API error
        let apiError = error.apiError
        
        // Then: Should have correct structure
        XCTAssertEqual(apiError.code, "RECORDING_START_FAILED")
        XCTAssertEqual(apiError.message, "Failed to start recording")
        XCTAssertEqual(apiError.details, "Permission denied")
        XCTAssertEqual(error.httpStatusCode, 500)
    }
    
    func testRecordingAPIError_RecordingStopFailed() {
        // Given: Recording stop failed error
        let error = RecordingAPIError.recordingStopFailed("File write error")
        
        // When: Converting to API error
        let apiError = error.apiError
        
        // Then: Should have correct structure
        XCTAssertEqual(apiError.code, "RECORDING_STOP_FAILED")
        XCTAssertEqual(apiError.message, "Failed to stop recording")
        XCTAssertEqual(apiError.details, "File write error")
        XCTAssertEqual(error.httpStatusCode, 500)
    }
    
    func testRecordingAPIError_PermissionDenied() {
        // Given: Permission denied error
        let error = RecordingAPIError.permissionDenied
        
        // When: Converting to API error
        let apiError = error.apiError
        
        // Then: Should have correct structure
        XCTAssertEqual(apiError.code, "PERMISSION_DENIED")
        XCTAssertEqual(apiError.message, "Audio recording permission denied")
        XCTAssertEqual(error.httpStatusCode, 403)
    }
    
    func testRecordingAPIError_ProcessHasNoAudio() {
        // Given: Process has no audio error
        let error = RecordingAPIError.processHasNoAudio("12345", "TestApp")
        
        // When: Converting to API error
        let apiError = error.apiError
        
        // Then: Should have correct structure
        XCTAssertEqual(apiError.code, "PROCESS_NO_AUDIO")
        XCTAssertEqual(apiError.message, "Process does not have audio capability")
        XCTAssertTrue(apiError.details?.contains("TestApp") == true)
        XCTAssertTrue(apiError.details?.contains("12345") == true)
        XCTAssertEqual(error.httpStatusCode, 400)
    }
    
    func testRecordingAPIError_FileSystemError() {
        // Given: File system error
        let error = RecordingAPIError.fileSystemError("Disk full")
        
        // When: Converting to API error
        let apiError = error.apiError
        
        // Then: Should have correct structure
        XCTAssertEqual(apiError.code, "FILE_SYSTEM_ERROR")
        XCTAssertEqual(apiError.message, "File system operation failed")
        XCTAssertEqual(apiError.details, "Disk full")
        XCTAssertEqual(error.httpStatusCode, 500)
    }
    
    func testRecordingAPIError_InvalidRecordingState() {
        // Given: Invalid recording state error
        let error = RecordingAPIError.invalidRecordingState("State mismatch")
        
        // When: Converting to API error
        let apiError = error.apiError
        
        // Then: Should have correct structure
        XCTAssertEqual(apiError.code, "INVALID_RECORDING_STATE")
        XCTAssertEqual(apiError.message, "Recording system is in an invalid state")
        XCTAssertEqual(apiError.details, "State mismatch")
        XCTAssertEqual(error.httpStatusCode, 500)
    }
    
    func testRecordingAPIError_InternalError() {
        // Given: Internal error
        let error = RecordingAPIError.internalError("System failure")
        
        // When: Converting to API error
        let apiError = error.apiError
        
        // Then: Should have correct structure
        XCTAssertEqual(apiError.code, "INTERNAL_ERROR")
        XCTAssertEqual(apiError.message, "Internal server error")
        XCTAssertEqual(apiError.details, "System failure")
        XCTAssertEqual(error.httpStatusCode, 500)
    }
    
    // MARK: - Integration Tests
    
    func testRecordingAPIHandler_FullWorkflow() async throws {
        // Given: A valid process
        guard let firstProcess = await processController.processes.first else {
            throw XCTSkip("No processes available for testing")
        }
        
        let request = StartRecordingRequest(processId: String(firstProcess.id), outputFormat: nil)
        
        // When: Full recording workflow
        
        // 1. Check initial status
        var status = try await recordingAPIHandler.handleRecordingStatus()
        XCTAssertEqual(status.status, .idle)
        
        // 2. Start recording
        let session = try await recordingAPIHandler.handleStartRecording(request: request)
        XCTAssertEqual(session.status, .recording)
        
        // 3. Check status during recording
        status = try await recordingAPIHandler.handleRecordingStatus()
        XCTAssertEqual(status.status, .recording)
        XCTAssertNotNil(status.currentSession)
        XCTAssertNotNil(status.elapsedTime)
        
        // 4. Stop recording
        let metadata = try await recordingAPIHandler.handleStopRecording()
        XCTAssertEqual(metadata.sessionId, session.sessionId)
        XCTAssertTrue(metadata.duration > 0)
        
        // 5. Check final status
        status = try await recordingAPIHandler.handleRecordingStatus()
        XCTAssertEqual(status.status, .idle)
        XCTAssertNil(status.currentSession)
        
        // Clean up
        try? FileManager.default.removeItem(atPath: metadata.filePath)
    }
}