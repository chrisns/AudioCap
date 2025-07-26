//
//  HTTPErrorHandlerTests.swift
//  AudioCapTests
//
//  Unit tests for HTTPErrorHandler
//

import XCTest
@testable import AudioCap

final class HTTPErrorHandlerTests: XCTestCase {
    
    // MARK: - Error Handling Tests
    
    func testHandleAPIHandlerError() {
        // Given: An API handler error
        let originalError = APIHandlerError.processListFailed("Test error")
        
        // When: Handling the error
        let result = HTTPErrorHandler.handleError(originalError)
        
        // Then: Should return correct status code and error response
        XCTAssertEqual(result.statusCode, 500)
        XCTAssertEqual(result.errorResponse.error.code, "PROCESS_LIST_FAILED")
        XCTAssertEqual(result.errorResponse.error.message, "Failed to retrieve process list")
        XCTAssertEqual(result.errorResponse.error.details, "Test error")
    }
    
    func testHandleRecordingAPIError() {
        // Given: A recording API error
        let originalError = RecordingAPIError.processNotFound("12345")
        
        // When: Handling the error
        let result = HTTPErrorHandler.handleError(originalError)
        
        // Then: Should return correct status code and error response
        XCTAssertEqual(result.statusCode, 400)
        XCTAssertEqual(result.errorResponse.error.code, "PROCESS_NOT_FOUND")
        XCTAssertEqual(result.errorResponse.error.message, "The specified process was not found")
        XCTAssertTrue(result.errorResponse.error.details?.contains("12345") == true)
    }
    
    func testHandleValidationError() {
        // Given: A validation error
        let originalError = ValidationError.missingRequiredField("processId")
        
        // When: Handling the error
        let result = HTTPErrorHandler.handleError(originalError)
        
        // Then: Should return correct status code and error response
        XCTAssertEqual(result.statusCode, 400)
        XCTAssertEqual(result.errorResponse.error.code, "MISSING_REQUIRED_FIELD")
        XCTAssertEqual(result.errorResponse.error.message, "Missing required field")
        XCTAssertTrue(result.errorResponse.error.details?.contains("processId") == true)
    }
    
    func testHandleNSErrorFileNotFound() {
        // Given: A file not found NSError
        let originalError = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError, userInfo: [
            NSLocalizedDescriptionKey: "File not found"
        ])
        
        // When: Handling the error
        let result = HTTPErrorHandler.handleError(originalError)
        
        // Then: Should return correct status code and error response
        XCTAssertEqual(result.statusCode, 404)
        XCTAssertEqual(result.errorResponse.error.code, "FILE_NOT_FOUND")
        XCTAssertEqual(result.errorResponse.error.message, "Required file not found")
        XCTAssertEqual(result.errorResponse.error.details, "File not found")
    }
    
    func testHandleNSErrorPermission() {
        // Given: A permission NSError
        let originalError = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError, userInfo: [
            NSLocalizedDescriptionKey: "Permission denied"
        ])
        
        // When: Handling the error
        let result = HTTPErrorHandler.handleError(originalError)
        
        // Then: Should return correct status code and error response
        XCTAssertEqual(result.statusCode, 403)
        XCTAssertEqual(result.errorResponse.error.code, "FILE_PERMISSION_ERROR")
        XCTAssertEqual(result.errorResponse.error.message, "File permission denied")
        XCTAssertEqual(result.errorResponse.error.details, "Permission denied")
    }
    
    func testHandleNSErrorDiskFull() {
        // Given: A disk full NSError
        let originalError = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError, userInfo: [
            NSLocalizedDescriptionKey: "No space left on device"
        ])
        
        // When: Handling the error
        let result = HTTPErrorHandler.handleError(originalError)
        
        // Then: Should return correct status code and error response
        XCTAssertEqual(result.statusCode, 507)
        XCTAssertEqual(result.errorResponse.error.code, "DISK_FULL")
        XCTAssertEqual(result.errorResponse.error.message, "Insufficient disk space")
        XCTAssertEqual(result.errorResponse.error.details, "No space left on device")
    }
    
    func testHandleAudioSystemError() {
        // Given: An audio system NSError
        let originalError = NSError(domain: "com.apple.coreaudio.avfaudio", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "Audio device not available"
        ])
        
        // When: Handling the error
        let result = HTTPErrorHandler.handleError(originalError)
        
        // Then: Should return correct status code and error response
        XCTAssertEqual(result.statusCode, 500)
        XCTAssertEqual(result.errorResponse.error.code, "AUDIO_SYSTEM_ERROR")
        XCTAssertEqual(result.errorResponse.error.message, "Audio system error")
        XCTAssertEqual(result.errorResponse.error.details, "Audio device not available")
    }
    
    func testHandleGenericError() {
        // Given: A generic error
        struct CustomError: Error, LocalizedError {
            var errorDescription: String? { "Custom error occurred" }
        }
        let originalError = CustomError()
        
        // When: Handling the error
        let result = HTTPErrorHandler.handleError(originalError)
        
        // Then: Should return correct status code and error response
        XCTAssertEqual(result.statusCode, 500)
        XCTAssertEqual(result.errorResponse.error.code, "UNKNOWN_ERROR")
        XCTAssertEqual(result.errorResponse.error.message, "An unexpected error occurred")
        XCTAssertEqual(result.errorResponse.error.details, "Custom error occurred")
    }
    
    // MARK: - JSON Validation Tests
    
    func testValidateJSONRequestValid() throws {
        // Given: Valid JSON data
        let jsonString = """
        {
            "processId": "12345",
            "outputFormat": "wav"
        }
        """
        let data = jsonString.data(using: .utf8)!
        
        // When: Validating JSON request
        let result = try HTTPErrorHandler.validateJSONRequest(data, as: StartRecordingRequest.self)
        
        // Then: Should parse successfully
        XCTAssertEqual(result.processId, "12345")
        XCTAssertEqual(result.outputFormat, "wav")
    }
    
    func testValidateJSONRequestInvalidJSON() {
        // Given: Invalid JSON data
        let invalidJSON = "{ invalid json }"
        let data = invalidJSON.data(using: .utf8)!
        
        // When/Then: Should throw validation error
        XCTAssertThrowsError(try HTTPErrorHandler.validateJSONRequest(data, as: StartRecordingRequest.self)) { error in
            XCTAssertTrue(error is ValidationError)
            if case let ValidationError.invalidJSON(details) = error {
                XCTAssertFalse(details.isEmpty)
            } else {
                XCTFail("Expected ValidationError.invalidJSON")
            }
        }
    }
    
    func testValidateJSONRequestMissingField() {
        // Given: JSON missing required field
        let jsonString = """
        {
            "outputFormat": "wav"
        }
        """
        let data = jsonString.data(using: .utf8)!
        
        // When/Then: Should throw validation error
        XCTAssertThrowsError(try HTTPErrorHandler.validateJSONRequest(data, as: StartRecordingRequest.self)) { error in
            XCTAssertTrue(error is ValidationError)
            if case let ValidationError.invalidJSON(details) = error {
                XCTAssertTrue(details.contains("processId"))
            } else {
                XCTFail("Expected ValidationError.invalidJSON with processId details")
            }
        }
    }
    
    func testValidateJSONRequestTypeMismatch() {
        // Given: JSON with wrong type
        let jsonString = """
        {
            "processId": 12345
        }
        """
        let data = jsonString.data(using: .utf8)!
        
        // When/Then: Should throw validation error
        XCTAssertThrowsError(try HTTPErrorHandler.validateJSONRequest(data, as: StartRecordingRequest.self)) { error in
            XCTAssertTrue(error is ValidationError)
            if case let ValidationError.invalidJSON(details) = error {
                XCTAssertTrue(details.contains("type") || details.contains("mismatch"))
            } else {
                XCTFail("Expected ValidationError.invalidJSON with type mismatch details")
            }
        }
    }
    
    // MARK: - Field Validation Tests
    
    func testValidateRequiredValid() throws {
        // Given: A non-nil value
        let value = "test"
        
        // When: Validating required field
        let result = try HTTPErrorHandler.validateRequired(value, fieldName: "testField")
        
        // Then: Should return the value
        XCTAssertEqual(result, "test")
    }
    
    func testValidateRequiredNil() {
        // Given: A nil value
        let value: String? = nil
        
        // When/Then: Should throw validation error
        XCTAssertThrowsError(try HTTPErrorHandler.validateRequired(value, fieldName: "testField")) { error in
            XCTAssertTrue(error is ValidationError)
            if case let ValidationError.missingRequiredField(field) = error {
                XCTAssertEqual(field, "testField")
            } else {
                XCTFail("Expected ValidationError.missingRequiredField")
            }
        }
    }
    
    func testValidateNonEmptyValid() throws {
        // Given: A non-empty string
        let value = "test"
        
        // When: Validating non-empty field
        let result = try HTTPErrorHandler.validateNonEmpty(value, fieldName: "testField")
        
        // Then: Should return the value
        XCTAssertEqual(result, "test")
    }
    
    func testValidateNonEmptyEmpty() {
        // Given: An empty string
        let value = ""
        
        // When/Then: Should throw validation error
        XCTAssertThrowsError(try HTTPErrorHandler.validateNonEmpty(value, fieldName: "testField")) { error in
            XCTAssertTrue(error is ValidationError)
            if case let ValidationError.emptyField(field) = error {
                XCTAssertEqual(field, "testField")
            } else {
                XCTFail("Expected ValidationError.emptyField")
            }
        }
    }
    
    func testValidateNonEmptyWhitespace() {
        // Given: A whitespace-only string
        let value = "   \n\t  "
        
        // When/Then: Should throw validation error
        XCTAssertThrowsError(try HTTPErrorHandler.validateNonEmpty(value, fieldName: "testField")) { error in
            XCTAssertTrue(error is ValidationError)
            if case let ValidationError.emptyField(field) = error {
                XCTAssertEqual(field, "testField")
            } else {
                XCTFail("Expected ValidationError.emptyField")
            }
        }
    }
    
    func testValidateRangeValid() throws {
        // Given: A value within range
        let value = 5
        
        // When: Validating range
        let result = try HTTPErrorHandler.validateRange(value, min: 1, max: 10, fieldName: "testField")
        
        // Then: Should return the value
        XCTAssertEqual(result, 5)
    }
    
    func testValidateRangeTooLow() {
        // Given: A value below minimum
        let value = 0
        
        // When/Then: Should throw validation error
        XCTAssertThrowsError(try HTTPErrorHandler.validateRange(value, min: 1, max: 10, fieldName: "testField")) { error in
            XCTAssertTrue(error is ValidationError)
            if case let ValidationError.valueOutOfRange(field, details) = error {
                XCTAssertEqual(field, "testField")
                XCTAssertTrue(details.contains("1") && details.contains("10"))
            } else {
                XCTFail("Expected ValidationError.valueOutOfRange")
            }
        }
    }
    
    func testValidateRangeTooHigh() {
        // Given: A value above maximum
        let value = 15
        
        // When/Then: Should throw validation error
        XCTAssertThrowsError(try HTTPErrorHandler.validateRange(value, min: 1, max: 10, fieldName: "testField")) { error in
            XCTAssertTrue(error is ValidationError)
            if case let ValidationError.valueOutOfRange(field, details) = error {
                XCTAssertEqual(field, "testField")
                XCTAssertTrue(details.contains("1") && details.contains("10"))
            } else {
                XCTFail("Expected ValidationError.valueOutOfRange")
            }
        }
    }
    
    // MARK: - ValidationError Tests
    
    func testValidationErrorInvalidJSON() {
        // Given: Invalid JSON error
        let error = ValidationError.invalidJSON("Syntax error at line 1")
        
        // When: Converting to API error
        let apiError = error.apiError
        
        // Then: Should have correct structure
        XCTAssertEqual(apiError.code, "INVALID_JSON")
        XCTAssertEqual(apiError.message, "Request body contains invalid JSON")
        XCTAssertEqual(apiError.details, "Syntax error at line 1")
        XCTAssertEqual(error.httpStatusCode, 400)
    }
    
    func testValidationErrorMissingRequiredField() {
        // Given: Missing required field error
        let error = ValidationError.missingRequiredField("processId")
        
        // When: Converting to API error
        let apiError = error.apiError
        
        // Then: Should have correct structure
        XCTAssertEqual(apiError.code, "MISSING_REQUIRED_FIELD")
        XCTAssertEqual(apiError.message, "Missing required field")
        XCTAssertTrue(apiError.details?.contains("processId") == true)
        XCTAssertEqual(error.httpStatusCode, 400)
    }
    
    func testValidationErrorEmptyField() {
        // Given: Empty field error
        let error = ValidationError.emptyField("name")
        
        // When: Converting to API error
        let apiError = error.apiError
        
        // Then: Should have correct structure
        XCTAssertEqual(apiError.code, "EMPTY_FIELD")
        XCTAssertEqual(apiError.message, "Field cannot be empty")
        XCTAssertTrue(apiError.details?.contains("name") == true)
        XCTAssertEqual(error.httpStatusCode, 400)
    }
    
    func testValidationErrorValueOutOfRange() {
        // Given: Value out of range error
        let error = ValidationError.valueOutOfRange("port", "Must be between 1 and 65535")
        
        // When: Converting to API error
        let apiError = error.apiError
        
        // Then: Should have correct structure
        XCTAssertEqual(apiError.code, "VALUE_OUT_OF_RANGE")
        XCTAssertEqual(apiError.message, "Field value is out of valid range")
        XCTAssertTrue(apiError.details?.contains("port") == true)
        XCTAssertTrue(apiError.details?.contains("1") == true)
        XCTAssertTrue(apiError.details?.contains("65535") == true)
        XCTAssertEqual(error.httpStatusCode, 400)
    }
    
    func testValidationErrorInvalidFormat() {
        // Given: Invalid format error
        let error = ValidationError.invalidFormat("email", "Must be a valid email address")
        
        // When: Converting to API error
        let apiError = error.apiError
        
        // Then: Should have correct structure
        XCTAssertEqual(apiError.code, "INVALID_FORMAT")
        XCTAssertEqual(apiError.message, "Field has invalid format")
        XCTAssertTrue(apiError.details?.contains("email") == true)
        XCTAssertTrue(apiError.details?.contains("valid email") == true)
        XCTAssertEqual(error.httpStatusCode, 400)
    }
    
    // MARK: - Edge Cases
    
    func testHandleErrorWithNilDescription() {
        // Given: An error with nil description
        struct NilDescriptionError: Error, LocalizedError {
            var errorDescription: String? { nil }
        }
        let originalError = NilDescriptionError()
        
        // When: Handling the error
        let result = HTTPErrorHandler.handleError(originalError)
        
        // Then: Should handle gracefully
        XCTAssertEqual(result.statusCode, 500)
        XCTAssertEqual(result.errorResponse.error.code, "UNKNOWN_ERROR")
        XCTAssertNotNil(result.errorResponse.error.details)
    }
    
    func testHandleNSErrorUnknownDomain() {
        // Given: An NSError with unknown domain
        let originalError = NSError(domain: "com.unknown.domain", code: 999, userInfo: [
            NSLocalizedDescriptionKey: "Unknown error"
        ])
        
        // When: Handling the error
        let result = HTTPErrorHandler.handleError(originalError)
        
        // Then: Should handle as system error
        XCTAssertEqual(result.statusCode, 500)
        XCTAssertEqual(result.errorResponse.error.code, "SYSTEM_ERROR")
        XCTAssertEqual(result.errorResponse.error.message, "System error occurred")
        XCTAssertTrue(result.errorResponse.error.details?.contains("com.unknown.domain") == true)
    }
}