//
//  RecordingAPIHandler.swift
//  AudioCap
//
//  API handler for recording control endpoints
//

import Foundation
import OSLog
import AVFoundation

/// Handler for recording-related API endpoints
@MainActor
final class RecordingAPIHandler {
    
    private let logger = Logger(subsystem: "com.audiocap.app", category: String(describing: RecordingAPIHandler.self))
    private let processController: AudioProcessController
    private let permissionHandler: AudioRecordingPermission
    
    /// Current recording session information
    private var currentSession: RecordingSession?
    
    /// Current process tap recorder
    private var currentRecorder: ProcessTapRecorder?
    
    /// Session start time for elapsed time calculation
    private var sessionStartTime: Date?
    
    init(processController: AudioProcessController, permissionHandler: AudioRecordingPermission = AudioRecordingPermission()) {
        self.processController = processController
        self.permissionHandler = permissionHandler
        logger.debug("RecordingAPIHandler initialized")
    }
    
    /// Handle POST /recording/start endpoint with JSON validation
    /// Validates JSON structure and content before processing
    func handleStartRecordingFromJSON(_ jsonData: Data) async throws -> RecordingSession {
        logger.debug("Handling start recording request from JSON data")
        
        // Validate JSON structure and parse request
        let request: StartRecordingRequest
        do {
            request = try RequestValidator.validateStartRecordingRequestJSON(jsonData)
        } catch let validationError as ValidationError {
            logger.error("JSON validation failed: \(validationError.localizedDescription)")
            throw RecordingAPIError.invalidRequest(validationError.localizedDescription)
        }
        
        // Process the validated request
        return try await handleStartRecording(request: request)
    }
    
    /// Check if audio recording permission is granted
    private func checkPermissions() throws {
        switch permissionHandler.status {
        case .denied:
            logger.error("Audio recording permission denied")
            throw RecordingAPIError.permissionDenied
        case .unknown:
            logger.warning("Audio recording permission status unknown, proceeding with caution")
            // Allow to proceed - permission might be granted during recording attempt
        case .authorized:
            logger.debug("Audio recording permission granted")
            // All good
        }
    }
    
    /// Handle POST /recording/start endpoint
    /// Starts recording from the specified process
    func handleStartRecording(request: StartRecordingRequest) async throws -> RecordingSession {
        logger.debug("Handling start recording request for process ID: \(request.processId)")
        
        // Check if already recording
        if currentSession?.status == .recording {
            logger.warning("Attempted to start recording while already recording")
            throw RecordingAPIError.alreadyRecording
        }
        
        // Check audio recording permissions
        try checkPermissions()
        
        // Use comprehensive validation system
        do {
            try RequestValidator.validateStartRecordingRequest(request, against: processController)
        } catch let validationError as ValidationError {
            // Convert validation errors to recording API errors
            // First check for specific error types by examining the error description
            if let errorDescription = validationError.errorDescription {
                if errorDescription.contains("not found") {
                    throw RecordingAPIError.processNotFound(request.processId)
                } else if errorDescription.contains("audio capability") {
                    // Extract process name from validation error if possible
                    let processName = processController.processes.first(where: { String($0.id) == request.processId })?.name ?? "Unknown"
                    throw RecordingAPIError.processHasNoAudio(request.processId, processName)
                }
            }
            
            // Then handle by validation error type
            switch validationError {
            case .emptyField(let field) where field == "processId":
                throw RecordingAPIError.invalidProcessId(request.processId)
            case .invalidFormat(let field, _) where field == "processId":
                throw RecordingAPIError.invalidProcessId(request.processId)
            case .valueOutOfRange(let field, _) where field == "processId":
                throw RecordingAPIError.invalidProcessId(request.processId)
            default:
                throw RecordingAPIError.invalidProcessId(request.processId)
            }
        }
        
        // Get validated process (we know it exists after validation)
        let processId = Int32(request.processId)!
        let targetProcess = processController.processes.first(where: { $0.id == processId })!
        
        do {
            // Generate session ID and file URL
            let sessionId = UUID().uuidString
            let timestamp = Date()
            
            // Sanitize process name for filename
            let sanitizedProcessName = targetProcess.name.replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "_", options: String.CompareOptions.regularExpression)
            let fileName = "recording_\(sanitizedProcessName)_\(Int(timestamp.timeIntervalSince1970)).wav"
            
            // Ensure documents directory exists
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true, attributes: nil)
            
            let fileURL = documentsURL.appendingPathComponent(fileName)
            
            // Create process tap
            let processTap = ProcessTap(process: targetProcess, muteWhenRunning: false)
            
            // Create recorder
            let recorder = ProcessTapRecorder(fileURL: fileURL, tap: processTap)
            
            // Start recording - this may fail due to permissions or system errors
            try recorder.start()
            
            // Create session
            let session = RecordingSession(
                sessionId: sessionId,
                processId: request.processId,
                processName: targetProcess.name,
                startTime: timestamp,
                status: .recording
            )
            
            // Store current state
            currentSession = session
            currentRecorder = recorder
            sessionStartTime = timestamp
            
            logger.info("Successfully started recording session \(sessionId, privacy: .public) for process \(targetProcess.name, privacy: .public)")
            return session
            
        } catch let error as NSError {
            logger.error("Failed to start recording: \(error.localizedDescription, privacy: .public) (domain: \(error.domain, privacy: .public), code: \(error.code))")
            
            // Map specific error types to appropriate API errors
            if error.domain == "com.apple.coreaudio.avfaudio" || error.localizedDescription.contains("permission") {
                throw RecordingAPIError.permissionDenied
            } else if error.localizedDescription.contains("file") || error.localizedDescription.contains("directory") {
                throw RecordingAPIError.fileSystemError(error.localizedDescription)
            } else {
                throw RecordingAPIError.recordingStartFailed(error.localizedDescription)
            }
        } catch {
            logger.error("Failed to start recording with unknown error: \(error.localizedDescription, privacy: .public)")
            throw RecordingAPIError.recordingStartFailed(error.localizedDescription)
        }
    }
    
    /// Handle POST /recording/stop endpoint
    /// Stops the current recording and returns metadata
    func handleStopRecording() async throws -> RecordingMetadata {
        logger.debug("Handling stop recording request")
        
        guard let session = currentSession,
              let recorder = currentRecorder,
              let startTime = sessionStartTime else {
            logger.warning("Attempted to stop recording when not recording")
            throw RecordingAPIError.notRecording
        }
        
        do {
            // Stop the recorder
            recorder.stop()
            
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            
            // Validate duration is reasonable
            guard duration >= 0 else {
                logger.error("Invalid recording duration: \(duration)")
                throw RecordingAPIError.invalidRecordingState("Recording duration is negative")
            }
            
            // Get file information
            let fileURL = recorder.fileURL
            
            // Verify file exists
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                logger.error("Recording file does not exist: \(fileURL.path, privacy: .private)")
                throw RecordingAPIError.fileSystemError("Recording file was not created")
            }
            
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            
            // Get audio format information from the recorder's process tap
            var channelCount = 2 // Default stereo
            var sampleRate = 44100.0 // Default sample rate
            
            do {
                let tapDescription = try recorder.process.objectID.readAudioTapStreamBasicDescription()
                channelCount = Int(tapDescription.mChannelsPerFrame)
                sampleRate = tapDescription.mSampleRate
                
                // Validate audio format values
                if channelCount <= 0 || channelCount > 32 {
                    logger.warning("Invalid channel count from tap: \(channelCount), using default")
                    channelCount = 2
                }
                
                if sampleRate <= 0 || sampleRate > 192000 {
                    logger.warning("Invalid sample rate from tap: \(sampleRate), using default")
                    sampleRate = 44100.0
                }
                
            } catch {
                logger.warning("Failed to read tap stream description: \(error.localizedDescription, privacy: .public), using defaults")
                // Use defaults - this is not a fatal error
            }
            
            // Create metadata response
            let metadata = RecordingMetadata(
                sessionId: session.sessionId,
                filePath: fileURL.path,
                duration: duration,
                channelCount: channelCount,
                sampleRate: sampleRate,
                fileSize: fileSize,
                endTime: endTime
            )
            
            // Clear current state
            currentSession = nil
            currentRecorder = nil
            sessionStartTime = nil
            
            logger.info("Successfully stopped recording session \(session.sessionId, privacy: .public), duration: \(String(format: "%.2f", duration))s, file size: \(fileSize) bytes")
            return metadata
            
        } catch let error as RecordingAPIError {
            // Re-throw API errors as-is
            throw error
        } catch let error as NSError {
            logger.error("Failed to stop recording: \(error.localizedDescription, privacy: .public) (domain: \(error.domain, privacy: .public), code: \(error.code))")
            
            // Map specific error types
            if error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
                throw RecordingAPIError.fileSystemError("Recording file not found")
            } else if error.localizedDescription.contains("file") || error.localizedDescription.contains("directory") {
                throw RecordingAPIError.fileSystemError(error.localizedDescription)
            } else {
                throw RecordingAPIError.recordingStopFailed(error.localizedDescription)
            }
        } catch {
            logger.error("Failed to stop recording with unknown error: \(error.localizedDescription, privacy: .public)")
            throw RecordingAPIError.recordingStopFailed(error.localizedDescription)
        }
    }
    
    /// Handle GET /recording/status endpoint
    /// Returns current recording status
    func handleRecordingStatus() async throws -> RecordingStatusResponse {
        logger.debug("Handling recording status request")
        
        do {
            let elapsedTime: TimeInterval?
            if let startTime = sessionStartTime, currentSession?.status == .recording {
                let elapsed = Date().timeIntervalSince(startTime)
                // Validate elapsed time is reasonable
                elapsedTime = elapsed >= 0 ? elapsed : nil
                if elapsed < 0 {
                    logger.warning("Negative elapsed time detected: \(elapsed), returning nil")
                }
            } else {
                elapsedTime = nil
            }
            
            let status = currentSession?.status ?? .idle
            
            // Validate state consistency
            if status == .recording && currentRecorder == nil {
                logger.error("Inconsistent state: status is recording but no recorder exists")
                throw RecordingAPIError.invalidRecordingState("Recording state is inconsistent")
            }
            
            let response = RecordingStatusResponse(
                status: status,
                currentSession: currentSession,
                elapsedTime: elapsedTime
            )
            
            logger.debug("Recording status: \(status.rawValue, privacy: .public), elapsed time: \(elapsedTime ?? 0)")
            return response
            
        } catch let error as RecordingAPIError {
            // Re-throw API errors as-is
            throw error
        } catch {
            logger.error("Failed to get recording status: \(error.localizedDescription, privacy: .public)")
            throw RecordingAPIError.internalError("Failed to retrieve recording status: \(error.localizedDescription)")
        }
    }
}

/// Errors that can occur in the RecordingAPIHandler
enum RecordingAPIError: Error, LocalizedError {
    case invalidProcessId(String)
    case processNotFound(String)
    case processHasNoAudio(String, String) // processId, processName
    case alreadyRecording
    case notRecording
    case recordingStartFailed(String)
    case recordingStopFailed(String)
    case permissionDenied
    case fileSystemError(String)
    case invalidRecordingState(String)
    case invalidRequest(String)
    case internalError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidProcessId(let processId):
            return "Invalid process ID format: \(processId)"
        case .processNotFound(let processId):
            return "Process not found: \(processId)"
        case .processHasNoAudio(let processId, let processName):
            return "Process '\(processName)' (ID: \(processId)) does not have audio capability"
        case .alreadyRecording:
            return "Recording is already in progress"
        case .notRecording:
            return "No recording is currently active"
        case .recordingStartFailed(let message):
            return "Failed to start recording: \(message)"
        case .recordingStopFailed(let message):
            return "Failed to stop recording: \(message)"
        case .permissionDenied:
            return "Audio recording permission denied"
        case .fileSystemError(let message):
            return "File system error: \(message)"
        case .invalidRecordingState(let message):
            return "Invalid recording state: \(message)"
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        case .internalError(let message):
            return "Internal error: \(message)"
        }
    }
    
    /// Convert to API error response
    var apiError: APIError {
        switch self {
        case .invalidProcessId(let processId):
            return APIError(
                code: "INVALID_PROCESS_ID",
                message: "Invalid process ID format",
                details: "Process ID '\(processId)' is not a valid numeric identifier or is not positive"
            )
        case .processNotFound(let processId):
            return APIError(
                code: "PROCESS_NOT_FOUND",
                message: "The specified process was not found",
                details: "Process ID '\(processId)' is not in the current process list"
            )
        case .processHasNoAudio(let processId, let processName):
            return APIError(
                code: "PROCESS_NO_AUDIO",
                message: "Process does not have audio capability",
                details: "Process '\(processName)' (ID: \(processId)) is not currently producing audio"
            )
        case .alreadyRecording:
            return APIError(
                code: "ALREADY_RECORDING",
                message: "Recording is already in progress",
                details: "Stop the current recording before starting a new one"
            )
        case .notRecording:
            return APIError(
                code: "NOT_RECORDING",
                message: "No recording is currently active",
                details: "Start a recording before attempting to stop or query status"
            )
        case .recordingStartFailed(let message):
            return APIError(
                code: "RECORDING_START_FAILED",
                message: "Failed to start recording",
                details: message
            )
        case .recordingStopFailed(let message):
            return APIError(
                code: "RECORDING_STOP_FAILED",
                message: "Failed to stop recording",
                details: message
            )
        case .permissionDenied:
            return APIError(
                code: "PERMISSION_DENIED",
                message: "Audio recording permission denied",
                details: "Grant audio recording permission in System Preferences > Privacy & Security > Microphone"
            )
        case .fileSystemError(let message):
            return APIError(
                code: "FILE_SYSTEM_ERROR",
                message: "File system operation failed",
                details: message
            )
        case .invalidRecordingState(let message):
            return APIError(
                code: "INVALID_RECORDING_STATE",
                message: "Recording system is in an invalid state",
                details: message
            )
        case .invalidRequest(let message):
            return APIError(
                code: "INVALID_REQUEST",
                message: "Request validation failed",
                details: message
            )
        case .internalError(let message):
            return APIError(
                code: "INTERNAL_ERROR",
                message: "Internal server error",
                details: message
            )
        }
    }
    
    /// HTTP status code for this error
    var httpStatusCode: Int {
        switch self {
        case .invalidProcessId, .processNotFound, .processHasNoAudio:
            return 400 // Bad Request
        case .alreadyRecording, .notRecording:
            return 409 // Conflict
        case .permissionDenied:
            return 403 // Forbidden
        case .invalidRequest:
            return 400 // Bad Request
        case .recordingStartFailed, .recordingStopFailed, .fileSystemError, .invalidRecordingState, .internalError:
            return 500 // Internal Server Error
        }
    }
}

