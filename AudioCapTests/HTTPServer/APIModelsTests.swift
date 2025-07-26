import XCTest
@testable import AudioCap

final class APIModelsTests: XCTestCase {
    
    // MARK: - AudioProcessInfo Tests
    
    func testAudioProcessInfoSerialization() throws {
        let processInfo = AudioProcessInfo(
            id: "12345",
            name: "TestApp",
            hasAudioCapability: true
        )
        
        let data = try JSONEncoder().encode(processInfo)
        let decoded = try JSONDecoder().decode(AudioProcessInfo.self, from: data)
        
        XCTAssertEqual(decoded.id, "12345")
        XCTAssertEqual(decoded.name, "TestApp")
        XCTAssertTrue(decoded.hasAudioCapability)
    }
    
    func testAudioProcessInfoJSONFormat() throws {
        let processInfo = AudioProcessInfo(
            id: "12345",
            name: "TestApp",
            hasAudioCapability: false
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(processInfo)
        let jsonString = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(jsonString.contains("\"hasAudioCapability\":false"))
        XCTAssertTrue(jsonString.contains("\"id\":\"12345\""))
        XCTAssertTrue(jsonString.contains("\"name\":\"TestApp\""))
    }
    
    // MARK: - ProcessListResponse Tests
    
    func testProcessListResponseSerialization() throws {
        let processes = [
            AudioProcessInfo(id: "1", name: "App1", hasAudioCapability: true),
            AudioProcessInfo(id: "2", name: "App2", hasAudioCapability: false)
        ]
        let timestamp = Date()
        
        let response = ProcessListResponse(processes: processes, timestamp: timestamp)
        
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(ProcessListResponse.self, from: data)
        
        XCTAssertEqual(decoded.processes.count, 2)
        XCTAssertEqual(decoded.processes[0].id, "1")
        XCTAssertEqual(decoded.processes[1].name, "App2")
        XCTAssertEqual(decoded.timestamp.timeIntervalSince1970, timestamp.timeIntervalSince1970, accuracy: 1.0)
    }
    
    func testEmptyProcessListSerialization() throws {
        let response = ProcessListResponse(processes: [], timestamp: Date())
        
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(ProcessListResponse.self, from: data)
        
        XCTAssertTrue(decoded.processes.isEmpty)
    }
    
    // MARK: - StartRecordingRequest Tests
    
    func testStartRecordingRequestWithFormat() throws {
        let request = StartRecordingRequest(processId: "12345", outputFormat: "wav")
        
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(StartRecordingRequest.self, from: data)
        
        XCTAssertEqual(decoded.processId, "12345")
        XCTAssertEqual(decoded.outputFormat, "wav")
    }
    
    func testStartRecordingRequestWithoutFormat() throws {
        let request = StartRecordingRequest(processId: "12345", outputFormat: nil)
        
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(StartRecordingRequest.self, from: data)
        
        XCTAssertEqual(decoded.processId, "12345")
        XCTAssertNil(decoded.outputFormat)
    }
    
    func testStartRecordingRequestFromJSON() throws {
        let jsonString = """
        {
            "processId": "67890"
        }
        """
        
        let data = jsonString.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(StartRecordingRequest.self, from: data)
        
        XCTAssertEqual(decoded.processId, "67890")
        XCTAssertNil(decoded.outputFormat)
    }
    
    // MARK: - RecordingSession Tests
    
    func testRecordingSessionSerialization() throws {
        let startTime = Date()
        let session = RecordingSession(
            sessionId: "session-123",
            processId: "proc-456",
            processName: "TestProcess",
            startTime: startTime,
            status: .recording
        )
        
        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(RecordingSession.self, from: data)
        
        XCTAssertEqual(decoded.sessionId, "session-123")
        XCTAssertEqual(decoded.processId, "proc-456")
        XCTAssertEqual(decoded.processName, "TestProcess")
        XCTAssertEqual(decoded.startTime.timeIntervalSince1970, startTime.timeIntervalSince1970, accuracy: 1.0)
        XCTAssertEqual(decoded.status, .recording)
    }
    
    // MARK: - RecordingMetadata Tests
    
    func testRecordingMetadataSerialization() throws {
        let endTime = Date()
        let metadata = RecordingMetadata(
            sessionId: "session-123",
            filePath: "/path/to/recording.wav",
            duration: 120.5,
            channelCount: 2,
            sampleRate: 44100.0,
            fileSize: 1024000,
            endTime: endTime
        )
        
        let data = try JSONEncoder().encode(metadata)
        let decoded = try JSONDecoder().decode(RecordingMetadata.self, from: data)
        
        XCTAssertEqual(decoded.sessionId, "session-123")
        XCTAssertEqual(decoded.filePath, "/path/to/recording.wav")
        XCTAssertEqual(decoded.duration, 120.5, accuracy: 0.1)
        XCTAssertEqual(decoded.channelCount, 2)
        XCTAssertEqual(decoded.sampleRate, 44100.0, accuracy: 0.1)
        XCTAssertEqual(decoded.fileSize, 1024000)
        XCTAssertEqual(decoded.endTime.timeIntervalSince1970, endTime.timeIntervalSince1970, accuracy: 1.0)
    }
    
    // MARK: - RecordingStatusResponse Tests
    
    func testRecordingStatusResponseIdle() throws {
        let response = RecordingStatusResponse(
            status: .idle,
            currentSession: nil,
            elapsedTime: nil
        )
        
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(RecordingStatusResponse.self, from: data)
        
        XCTAssertEqual(decoded.status, .idle)
        XCTAssertNil(decoded.currentSession)
        XCTAssertNil(decoded.elapsedTime)
    }
    
    func testRecordingStatusResponseRecording() throws {
        let session = RecordingSession(
            sessionId: "session-123",
            processId: "proc-456",
            processName: "TestProcess",
            startTime: Date(),
            status: .recording
        )
        
        let response = RecordingStatusResponse(
            status: .recording,
            currentSession: session,
            elapsedTime: 45.2
        )
        
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(RecordingStatusResponse.self, from: data)
        
        XCTAssertEqual(decoded.status, .recording)
        XCTAssertNotNil(decoded.currentSession)
        XCTAssertEqual(decoded.currentSession?.sessionId, "session-123")
        XCTAssertEqual(decoded.elapsedTime!, 45.2, accuracy: 0.1)
    }
    
    // MARK: - RecordingStatus Tests
    
    func testRecordingStatusRawValues() {
        XCTAssertEqual(RecordingStatus.idle.rawValue, "idle")
        XCTAssertEqual(RecordingStatus.recording.rawValue, "recording")
        XCTAssertEqual(RecordingStatus.stopping.rawValue, "stopping")
    }
    
    func testRecordingStatusFromRawValue() {
        XCTAssertEqual(RecordingStatus(rawValue: "idle"), .idle)
        XCTAssertEqual(RecordingStatus(rawValue: "recording"), .recording)
        XCTAssertEqual(RecordingStatus(rawValue: "stopping"), .stopping)
        XCTAssertNil(RecordingStatus(rawValue: "invalid"))
    }
    
    func testRecordingStatusSerialization() throws {
        let statuses: [RecordingStatus] = [.idle, .recording, .stopping]
        
        for status in statuses {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(RecordingStatus.self, from: data)
            XCTAssertEqual(decoded, status)
        }
    }
    
    // MARK: - APIError Tests
    
    func testAPIErrorSerialization() throws {
        let error = APIError(
            code: "PROCESS_NOT_FOUND",
            message: "The specified process was not found",
            details: "Process ID '12345' is not in the current process list"
        )
        
        let data = try JSONEncoder().encode(error)
        let decoded = try JSONDecoder().decode(APIError.self, from: data)
        
        XCTAssertEqual(decoded.code, "PROCESS_NOT_FOUND")
        XCTAssertEqual(decoded.message, "The specified process was not found")
        XCTAssertEqual(decoded.details, "Process ID '12345' is not in the current process list")
    }
    
    func testAPIErrorWithoutDetails() throws {
        let error = APIError(
            code: "INVALID_REQUEST",
            message: "The request format is invalid",
            details: nil
        )
        
        let data = try JSONEncoder().encode(error)
        let decoded = try JSONDecoder().decode(APIError.self, from: data)
        
        XCTAssertEqual(decoded.code, "INVALID_REQUEST")
        XCTAssertEqual(decoded.message, "The request format is invalid")
        XCTAssertNil(decoded.details)
    }
    
    // MARK: - ErrorResponse Tests
    
    func testErrorResponseSerialization() throws {
        let apiError = APIError(
            code: "SYSTEM_ERROR",
            message: "An internal system error occurred",
            details: "CoreAudio initialization failed"
        )
        let errorResponse = ErrorResponse(error: apiError)
        
        let data = try JSONEncoder().encode(errorResponse)
        let decoded = try JSONDecoder().decode(ErrorResponse.self, from: data)
        
        XCTAssertEqual(decoded.error.code, "SYSTEM_ERROR")
        XCTAssertEqual(decoded.error.message, "An internal system error occurred")
        XCTAssertEqual(decoded.error.details, "CoreAudio initialization failed")
    }
    
    func testErrorResponseJSONFormat() throws {
        let apiError = APIError(code: "TEST_ERROR", message: "Test message", details: nil)
        let errorResponse = ErrorResponse(error: apiError)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(errorResponse)
        let jsonString = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(jsonString.contains("\"error\":{"))
        XCTAssertTrue(jsonString.contains("\"code\":\"TEST_ERROR\""))
        XCTAssertTrue(jsonString.contains("\"message\":\"Test message\""))
    }
    
    // MARK: - Date Handling Tests
    
    func testDateSerializationConsistency() throws {
        let originalDate = Date()
        
        // Test with ProcessListResponse
        let processResponse = ProcessListResponse(processes: [], timestamp: originalDate)
        let processData = try JSONEncoder().encode(processResponse)
        let decodedProcessResponse = try JSONDecoder().decode(ProcessListResponse.self, from: processData)
        
        // Test with RecordingSession
        let session = RecordingSession(
            sessionId: "test",
            processId: "test",
            processName: "test",
            startTime: originalDate,
            status: .idle
        )
        let sessionData = try JSONEncoder().encode(session)
        let decodedSession = try JSONDecoder().decode(RecordingSession.self, from: sessionData)
        
        // Verify dates are preserved with reasonable accuracy
        XCTAssertEqual(
            decodedProcessResponse.timestamp.timeIntervalSince1970,
            originalDate.timeIntervalSince1970,
            accuracy: 1.0
        )
        XCTAssertEqual(
            decodedSession.startTime.timeIntervalSince1970,
            originalDate.timeIntervalSince1970,
            accuracy: 1.0
        )
    }
    
    // MARK: - Edge Cases and Validation
    
    func testLargeNumberHandling() throws {
        let metadata = RecordingMetadata(
            sessionId: "test",
            filePath: "/test/path",
            duration: Double.greatestFiniteMagnitude,
            channelCount: Int.max,
            sampleRate: 192000.0,
            fileSize: Int64.max,
            endTime: Date()
        )
        
        let data = try JSONEncoder().encode(metadata)
        let decoded = try JSONDecoder().decode(RecordingMetadata.self, from: data)
        
        XCTAssertEqual(decoded.duration, Double.greatestFiniteMagnitude)
        XCTAssertEqual(decoded.channelCount, Int.max)
        XCTAssertEqual(decoded.fileSize, Int64.max)
    }
    
    func testSpecialCharactersInStrings() throws {
        let processInfo = AudioProcessInfo(
            id: "special-chars-123!@#$%^&*()",
            name: "App with émojis 🎵 and unicode ñ",
            hasAudioCapability: true
        )
        
        let data = try JSONEncoder().encode(processInfo)
        let decoded = try JSONDecoder().decode(AudioProcessInfo.self, from: data)
        
        XCTAssertEqual(decoded.id, "special-chars-123!@#$%^&*()")
        XCTAssertEqual(decoded.name, "App with émojis 🎵 and unicode ñ")
    }
}