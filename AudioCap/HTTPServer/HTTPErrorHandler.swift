//
//  HTTPErrorHandler.swift
//  AudioCap
//
//  Comprehensive error handling utilities for HTTP API
//

import Foundation
import OSLog

/// Centralized error handling for HTTP API responses
struct HTTPErrorHandler {
    private static let logger = Logger(subsystem: "com.audiocap.app", category: "HTTPErrorHandler")
    
    /// Convert any error to a structured HTTP error response
    static func handleError(_ error: Error) -> (statusCode: Int, errorResponse: ErrorResponse) {
        logger.error("Handling API error: \(error.localizedDescription, privacy: .public)")
        
        switch error {
        case let apiError as APIHandlerError:
            return (statusCode: apiError.httpStatusCode, errorResponse: ErrorResponse(error: apiError.apiError))
            
        case let recordingError as RecordingAPIError:
            return (statusCode: recordingError.httpStatusCode, errorResponse: ErrorResponse(error: recordingError.apiError))
            
        case let validationError as ValidationError:
            return handleValidationError(validationError)
            
        case let nsError as NSError:
            return handleNSError(nsError)
            
        default:
            return handleGenericError(error)
        }
    }
    
    /// Handle NSError instances with specific domain mapping
    private static func handleNSError(_ error: NSError) -> (statusCode: Int, errorResponse: ErrorResponse) {
        logger.error("Handling NSError: domain=\(error.domain, privacy: .public), code=\(error.code), description=\(error.localizedDescription, privacy: .public)")
        
        let apiError: APIError
        let statusCode: Int
        
        switch error.domain {
        case NSCocoaErrorDomain:
            switch error.code {
            case NSFileReadNoSuchFileError, NSFileNoSuchFileError:
                apiError = APIError(
                    code: "FILE_NOT_FOUND",
                    message: "Required file not found",
                    details: error.localizedDescription
                )
                statusCode = 404
                
            case NSFileReadNoPermissionError, NSFileWriteNoPermissionError:
                apiError = APIError(
                    code: "FILE_PERMISSION_ERROR",
                    message: "File permission denied",
                    details: error.localizedDescription
                )
                statusCode = 403
                
            case NSFileWriteOutOfSpaceError:
                apiError = APIError(
                    code: "DISK_FULL",
                    message: "Insufficient disk space",
                    details: error.localizedDescription
                )
                statusCode = 507 // Insufficient Storage
                
            default:
                apiError = APIError(
                    code: "FILE_SYSTEM_ERROR",
                    message: "File system operation failed",
                    details: error.localizedDescription
                )
                statusCode = 500
            }
            
        case "com.apple.coreaudio.avfaudio":
            apiError = APIError(
                code: "AUDIO_SYSTEM_ERROR",
                message: "Audio system error",
                details: error.localizedDescription
            )
            statusCode = 500
            
        case NSURLErrorDomain:
            apiError = APIError(
                code: "NETWORK_ERROR",
                message: "Network operation failed",
                details: error.localizedDescription
            )
            statusCode = 502 // Bad Gateway
            
        default:
            apiError = APIError(
                code: "SYSTEM_ERROR",
                message: "System error occurred",
                details: "\(error.domain): \(error.localizedDescription)"
            )
            statusCode = 500
        }
        
        return (statusCode: statusCode, errorResponse: ErrorResponse(error: apiError))
    }
    
    /// Handle generic errors that don't fit specific categories
    private static func handleGenericError(_ error: Error) -> (statusCode: Int, errorResponse: ErrorResponse) {
        logger.error("Handling generic error: \(error.localizedDescription, privacy: .public)")
        
        let apiError = APIError(
            code: "UNKNOWN_ERROR",
            message: "An unexpected error occurred",
            details: error.localizedDescription
        )
        
        return (statusCode: 500, errorResponse: ErrorResponse(error: apiError))
    }
    
    /// Validate request data and throw appropriate errors
    static func validateJSONRequest<T: Codable>(_ data: Data, as type: T.Type) throws -> T {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(type, from: data)
        } catch let decodingError as DecodingError {
            logger.error("JSON decoding error: \(decodingError.localizedDescription, privacy: .public)")
            
            let details: String
            switch decodingError {
            case .dataCorrupted(let context):
                details = "Data corrupted: \(context.debugDescription)"
            case .keyNotFound(let key, let context):
                details = "Missing required field: \(key.stringValue) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
            case .typeMismatch(let type, let context):
                details = "Type mismatch for field at \(context.codingPath.map { $0.stringValue }.joined(separator: ".")): expected \(type)"
            case .valueNotFound(let type, let context):
                details = "Missing value for required field at \(context.codingPath.map { $0.stringValue }.joined(separator: ".")): expected \(type)"
            @unknown default:
                details = decodingError.localizedDescription
            }
            
            throw ValidationError.invalidJSON(details)
        } catch {
            logger.error("Unexpected JSON parsing error: \(error.localizedDescription, privacy: .public)")
            throw ValidationError.invalidJSON(error.localizedDescription)
        }
    }
    
    /// Validate that required fields are present and valid
    static func validateRequired<T>(_ value: T?, fieldName: String) throws -> T {
        guard let value = value else {
            throw ValidationError.missingRequiredField(fieldName)
        }
        return value
    }
    
    /// Validate string is not empty
    static func validateNonEmpty(_ string: String, fieldName: String) throws -> String {
        guard !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptyField(fieldName)
        }
        return string
    }
    
    /// Validate numeric range
    static func validateRange<T: Comparable>(_ value: T, min: T, max: T, fieldName: String) throws -> T {
        guard value >= min && value <= max else {
            throw ValidationError.valueOutOfRange(fieldName, "Value must be between \(min) and \(max)")
        }
        return value
    }
}

/// Validation errors for request processing
enum ValidationError: Error, LocalizedError {
    case invalidJSON(String)
    case missingRequiredField(String)
    case emptyField(String)
    case valueOutOfRange(String, String)
    case invalidFormat(String, String)
    
    var errorDescription: String? {
        switch self {
        case .invalidJSON(let details):
            return "Invalid JSON format: \(details)"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .emptyField(let field):
            return "Field cannot be empty: \(field)"
        case .valueOutOfRange(let field, let details):
            return "Value out of range for field \(field): \(details)"
        case .invalidFormat(let field, let details):
            return "Invalid format for field \(field): \(details)"
        }
    }
    
    /// Convert to API error response
    var apiError: APIError {
        switch self {
        case .invalidJSON(let details):
            return APIError(
                code: "INVALID_JSON",
                message: "Request body contains invalid JSON",
                details: details
            )
        case .missingRequiredField(let field):
            return APIError(
                code: "MISSING_REQUIRED_FIELD",
                message: "Missing required field",
                details: "Field '\(field)' is required but was not provided"
            )
        case .emptyField(let field):
            return APIError(
                code: "EMPTY_FIELD",
                message: "Field cannot be empty",
                details: "Field '\(field)' cannot be empty or contain only whitespace"
            )
        case .valueOutOfRange(let field, let details):
            return APIError(
                code: "VALUE_OUT_OF_RANGE",
                message: "Field value is out of valid range",
                details: "Field '\(field)': \(details)"
            )
        case .invalidFormat(let field, let details):
            return APIError(
                code: "INVALID_FORMAT",
                message: "Field has invalid format",
                details: "Field '\(field)': \(details)"
            )
        }
    }
    
    /// HTTP status code for validation errors
    var httpStatusCode: Int {
        return 400 // Bad Request
    }
}

/// Extension to handle ValidationError in HTTPErrorHandler
extension HTTPErrorHandler {
    static func handleValidationError(_ error: ValidationError) -> (statusCode: Int, errorResponse: ErrorResponse) {
        logger.error("Handling validation error: \(error.localizedDescription, privacy: .public)")
        return (statusCode: error.httpStatusCode, errorResponse: ErrorResponse(error: error.apiError))
    }
}