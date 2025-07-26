import Foundation

// MARK: - Process Models

/// Information about an available audio process
struct AudioProcessInfo: Codable {
    let id: String
    let name: String
    let hasAudioCapability: Bool
}

/// Response for process listing endpoint
struct ProcessListResponse: Codable {
    let processes: [AudioProcessInfo]
    let timestamp: Date
}

// MARK: - Recording Request Models

/// Request to start recording from a specific process
struct StartRecordingRequest: Codable {
    let processId: String
    let outputFormat: String?
}

// MARK: - Recording Response Models

/// Recording session information
struct RecordingSession: Codable {
    let sessionId: String
    let processId: String
    let processName: String
    let startTime: Date
    let status: RecordingStatus
}

/// Complete recording metadata returned when recording stops
struct RecordingMetadata: Codable {
    let sessionId: String
    let filePath: String
    let duration: TimeInterval
    let channelCount: Int
    let sampleRate: Double
    let fileSize: Int64
    let endTime: Date
}

/// Response for recording status queries
struct RecordingStatusResponse: Codable {
    let status: RecordingStatus
    let currentSession: RecordingSession?
    let elapsedTime: TimeInterval?
}

// MARK: - Recording Status Enum

/// Current state of the recording system
enum RecordingStatus: String, Codable {
    case idle
    case recording
    case stopping
}

// MARK: - Error Models

/// Structured error response for API failures
struct APIError: Codable {
    let code: String
    let message: String
    let details: String?
}

/// Wrapper for error responses to match expected JSON structure
struct ErrorResponse: Codable {
    let error: APIError
}