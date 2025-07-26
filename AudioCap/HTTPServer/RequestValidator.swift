//
//  RequestValidator.swift
//  AudioCap
//
//  Comprehensive request validation and JSON schema validation
//

import Foundation
import OSLog

private let logger = Logger(subsystem: kAppSubsystem, category: "RequestValidator")

/// Comprehensive validation error types
enum ValidationError: Error, LocalizedError {
    case emptyField(String)
    case missingRequiredField(String)
    case invalidFormat(String, String)
    case valueOutOfRange(String, String)
    case invalidJSON(String)
    
    var errorDescription: String? {
        switch self {
        case .emptyField(let field):
            return "Field '\(field)' cannot be empty"
        case .missingRequiredField(let field):
            return "Required field '\(field)' is missing"
        case .invalidFormat(let field, let details):
            return "Invalid format for field '\(field)': \(details)"
        case .valueOutOfRange(let field, let details):
            return "Value out of range for field '\(field)': \(details)"
        case .invalidJSON(let details):
            return "Invalid JSON: \(details)"
        }
    }
}

/// JSON Schema definitions for API requests
struct JSONSchema {
    /// Schema for StartRecordingRequest
    static let startRecordingRequest: [String: Any] = [
        "type": "object",
        "required": ["processId"],
        "properties": [
            "processId": [
                "type": "string",
                "pattern": "^[1-9][0-9]*$",
                "minLength": 1,
                "maxLength": 10
            ],
            "outputFormat": [
                "type": "string",
                "enum": ["wav", "aiff", "m4a", "caf"],
                "minLength": 1,
                "maxLength": 10
            ]
        ],
        "additionalProperties": false
    ]
}

/// Comprehensive request validation system
struct RequestValidator {
    
    /// Validate StartRecordingRequest with comprehensive checks
    @MainActor
    static func validateStartRecordingRequest(_ request: StartRecordingRequest, against processController: AudioProcessController) throws {
        logger.debug("Validating start recording request")
        
        // Validate process ID format and value
        let processIdString = request.processId.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for empty process ID
        guard !processIdString.isEmpty else {
            logger.error("Empty process ID provided")
            throw ValidationError.emptyField("processId")
        }
        
        // Validate process ID is numeric
        guard let processId = Int32(processIdString) else {
            logger.error("Invalid process ID format: \(request.processId, privacy: .public)")
            throw ValidationError.invalidFormat("processId", "Process ID must be a positive integer")
        }
        
        // Validate process ID is positive
        guard processId > 0 else {
            logger.error("Process ID must be positive: \(request.processId, privacy: .public)")
            throw ValidationError.valueOutOfRange("processId", "Process ID must be greater than 0")
        }
        
        // Validate process ID is within reasonable bounds (prevent overflow attacks)
        guard processId <= Int32.max - 1000 else {
            logger.error("Process ID too large: \(request.processId, privacy: .public)")
            throw ValidationError.valueOutOfRange("processId", "Process ID is too large")
        }
        
        // Validate process exists in current process list
        guard let targetProcess = processController.processes.first(where: { $0.id == processId }) else {
            logger.error("Process not found in current process list: \(request.processId, privacy: .public)")
            throw ValidationError.processNotFound(request.processId)
        }
        
        // Validate process has audio capability
        guard targetProcess.audioActive else {
            logger.warning("Process does not have audio capability: \(targetProcess.name, privacy: .public)")
            throw ValidationError.processHasNoAudio(request.processId, targetProcess.name)
        }
        
        // Validate output format if provided
        if let outputFormat = request.outputFormat {
            try validateOutputFormat(outputFormat)
        }
        
        logger.debug("Start recording request validation passed for process \(targetProcess.name, privacy: .public)")
    }
    
    /// Validate output format parameter
    private static func validateOutputFormat(_ format: String) throws {
        let trimmedFormat = format.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedFormat.isEmpty else {
            throw ValidationError.emptyField("outputFormat")
        }
        
        // Define allowed output formats
        let allowedFormats = ["wav", "aiff", "m4a", "caf"]
        let lowercaseFormat = trimmedFormat.lowercased()
        
        guard allowedFormats.contains(lowercaseFormat) else {
            throw ValidationError.invalidFormat("outputFormat", "Output format must be one of: \(allowedFormats.joined(separator: ", "))")
        }
    }
    
    /// Validate server configuration parameters
    static func validateServerConfiguration(_ config: ServerConfiguration) throws {
        logger.debug("Validating server configuration")
        
        // Validate port range
        guard config.port > 0 && config.port <= 65535 else {
            throw ValidationError.valueOutOfRange("port", "Port must be between 1 and 65535")
        }
        
        // Validate reserved ports (system ports that shouldn't be used)
        let reservedPorts = [22, 23, 25, 53, 80, 110, 143, 443, 993, 995]
        if reservedPorts.contains(config.port) {
            logger.warning("Using reserved port \(config.port)")
            throw ValidationError.valueOutOfRange("port", "Port \(config.port) is reserved for system services")
        }
        
        // Validate IP address format
        try validateIPAddress(config.ipAddress)
        
        // Validate timeout bounds
        guard config.requestTimeoutSeconds > 0 && config.requestTimeoutSeconds <= 300 else {
            throw ValidationError.valueOutOfRange("requestTimeoutSeconds", "Timeout must be between 0.1 and 300 seconds")
        }
        
        // Validate request body size
        guard config.maxRequestBodySize > 0 && config.maxRequestBodySize <= 10 * 1024 * 1024 else {
            throw ValidationError.valueOutOfRange("maxRequestBodySize", "Request body size must be between 1 byte and 10MB")
        }
        
        // Validate CORS origins if specified
        for origin in config.corsOrigins {
            try validateCORSOrigin(origin)
        }
        
        logger.debug("Server configuration validation passed")
    }
    
    /// Validate IP address format and security implications
    private static func validateIPAddress(_ ipAddress: String) throws {
        let trimmed = ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            throw ValidationError.emptyField("ipAddress")
        }
        
        // Basic IPv4 format validation
        let components = trimmed.components(separatedBy: ".")
        guard components.count == 4 else {
            throw ValidationError.invalidFormat("ipAddress", "IP address must be in IPv4 format (e.g., 127.0.0.1)")
        }
        
        for component in components {
            guard let value = Int(component), value >= 0 && value <= 255 else {
                throw ValidationError.invalidFormat("ipAddress", "Each IP address component must be between 0 and 255")
            }
        }
        
        // Check for potentially dangerous IP addresses
        if trimmed.hasPrefix("0.") {
            throw ValidationError.invalidFormat("ipAddress", "IP addresses starting with 0. are not allowed")
        }
        
        // Warn about non-localhost addresses (but don't fail validation)
        if trimmed != "127.0.0.1" && trimmed != "localhost" {
            logger.warning("Non-localhost IP address configured: \(trimmed, privacy: .public). This allows external access.")
        }
    }
    
    /// Validate CORS origin format
    private static func validateCORSOrigin(_ origin: String) throws {
        let trimmed = origin.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            throw ValidationError.emptyField("corsOrigin")
        }
        
        // Basic URL format validation for CORS origins
        if trimmed != "*" {
            // Must be a valid URL or domain
            if !trimmed.hasPrefix("http://") && !trimmed.hasPrefix("https://") {
                throw ValidationError.invalidFormat("corsOrigin", "CORS origin must be '*' or a valid URL (http:// or https://)")
            }
            
            // Basic URL validation
            guard URL(string: trimmed) != nil else {
                throw ValidationError.invalidFormat("corsOrigin", "CORS origin must be a valid URL")
            }
        }
    }
    
    /// Validate request body size against configuration limits
    static func validateRequestBodySize(_ data: Data, maxSize: Int) throws {
        guard data.count <= maxSize else {
            logger.error("Request body too large: \(data.count) bytes (max: \(maxSize))")
            throw ValidationError.requestTooLarge(data.count, maxSize)
        }
    }
    
    /// Validate JSON against schema and parse StartRecordingRequest
    static func validateStartRecordingRequestJSON(_ data: Data) throws -> StartRecordingRequest {
        logger.debug("Validating StartRecordingRequest JSON structure")
        
        // Parse JSON
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ValidationError.invalidJSON("Request body must be valid JSON object")
        }
        
        // Validate against JSON schema
        try validateJSONAgainstSchema(json, schema: JSONSchema.startRecordingRequest, rootName: "StartRecordingRequest")
        
        // Use standard JSON decoder for final parsing
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(StartRecordingRequest.self, from: data)
        } catch {
            throw ValidationError.invalidJSON("Failed to parse request: \(error.localizedDescription)")
        }
    }
    
    /// Validate JSON object against a schema definition
    private static func validateJSONAgainstSchema(_ json: [String: Any], schema: [String: Any], rootName: String) throws {
        // Validate type
        guard let expectedType = schema["type"] as? String else {
            throw ValidationError.invalidJSON("Schema missing type definition")
        }
        
        guard expectedType == "object" else {
            throw ValidationError.invalidJSON("Root type must be object")
        }
        
        // Validate required fields
        if let requiredFields = schema["required"] as? [String] {
            for field in requiredFields {
                guard json[field] != nil else {
                    throw ValidationError.missingRequiredField(field)
                }
            }
        }
        
        // Validate properties
        if let properties = schema["properties"] as? [String: [String: Any]] {
            for (fieldName, fieldSchema) in properties {
                if let fieldValue = json[fieldName] {
                    try validateFieldAgainstSchema(fieldValue, schema: fieldSchema, fieldName: fieldName)
                }
            }
        }
        
        // Check for additional properties if not allowed
        if let additionalProperties = schema["additionalProperties"] as? Bool, !additionalProperties {
            let properties = schema["properties"] as? [String: Any] ?? [:]
            let allowedFields = Set(properties.keys)
            let providedFields = Set(json.keys)
            let unexpectedFields = providedFields.subtracting(allowedFields)
            
            if !unexpectedFields.isEmpty {
                throw ValidationError.invalidFormat("request", "Unexpected fields: \(unexpectedFields.joined(separator: ", "))")
            }
        }
    }
    
    /// Validate individual field against its schema
    private static func validateFieldAgainstSchema(_ value: Any, schema: [String: Any], fieldName: String) throws {
        // Validate type
        if let expectedType = schema["type"] as? String {
            switch expectedType {
            case "string":
                guard value is String else {
                    throw ValidationError.invalidFormat(fieldName, "Must be a string")
                }
                let stringValue = value as! String
                
                // Validate string length
                if let minLength = schema["minLength"] as? Int, stringValue.count < minLength {
                    throw ValidationError.invalidFormat(fieldName, "Must be at least \(minLength) characters long")
                }
                
                if let maxLength = schema["maxLength"] as? Int, stringValue.count > maxLength {
                    throw ValidationError.invalidFormat(fieldName, "Must be at most \(maxLength) characters long")
                }
                
                // Validate pattern
                if let pattern = schema["pattern"] as? String {
                    let regex = try NSRegularExpression(pattern: pattern)
                    let range = NSRange(location: 0, length: stringValue.utf16.count)
                    if regex.firstMatch(in: stringValue, options: [], range: range) == nil {
                        throw ValidationError.invalidFormat(fieldName, "Does not match required pattern")
                    }
                }
                
                // Validate enum values
                if let enumValues = schema["enum"] as? [String] {
                    if !enumValues.contains(stringValue) {
                        throw ValidationError.invalidFormat(fieldName, "Must be one of: \(enumValues.joined(separator: ", "))")
                    }
                }
                
            case "number", "integer":
                guard value is NSNumber else {
                    throw ValidationError.invalidFormat(fieldName, "Must be a number")
                }
                
            default:
                break
            }
        }
    }
    
    /// Validate that a process ID exists in the current process list
    @MainActor
    static func validateProcessExists(_ processId: String, in processController: AudioProcessController) throws {
        guard let processIdInt = Int32(processId) else {
            throw ValidationError.invalidFormat("processId", "Process ID must be a valid integer")
        }
        
        guard processController.processes.contains(where: { $0.id == processIdInt }) else {
            throw ValidationError.processNotFound(processId)
        }
    }
    
    /// Get process by ID with validation
    @MainActor
    static func getValidatedProcess(_ processId: String, from processController: AudioProcessController) throws -> AudioProcess {
        guard let processIdInt = Int32(processId) else {
            throw ValidationError.invalidFormat("processId", "Process ID must be a valid integer")
        }
        
        guard let process = processController.processes.first(where: { $0.id == processIdInt }) else {
            throw ValidationError.processNotFound(processId)
        }
        
        return process
    }
    
    /// Validate HTTP method for endpoint
    static func validateHTTPMethod(_ method: String, allowedMethods: [String]) throws {
        guard allowedMethods.contains(method.uppercased()) else {
            throw ValidationError.methodNotAllowed(method, allowedMethods)
        }
    }
    
    /// Validate Content-Type header for JSON requests
    static func validateContentType(_ contentType: String?) throws {
        guard let contentType = contentType else {
            throw ValidationError.missingContentType
        }
        
        let normalizedContentType = contentType.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Accept various JSON content types
        let validContentTypes = [
            "application/json",
            "application/json; charset=utf-8",
            "text/json"
        ]
        
        let isValid = validContentTypes.contains { validType in
            normalizedContentType.hasPrefix(validType)
        }
        
        guard isValid else {
            throw ValidationError.invalidContentType(contentType)
        }
    }
    
    /// Validate request origin for security
    static func validateRequestOrigin(_ origin: String?, allowedOrigins: [String]) throws {
        // If no CORS origins are configured, allow any origin
        guard !allowedOrigins.isEmpty else { return }
        
        guard let origin = origin else {
            // No origin header is acceptable for same-origin requests
            return
        }
        
        let normalizedOrigin = origin.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if origin is in allowed list
        let isAllowed = allowedOrigins.contains { allowedOrigin in
            if allowedOrigin == "*" {
                return true
            }
            return normalizedOrigin == allowedOrigin
        }
        
        guard isAllowed else {
            throw ValidationError.originNotAllowed(origin, allowedOrigins)
        }
    }
    
    /// Validate request path for security (prevent path traversal)
    static func validateRequestPath(_ path: String) throws {
        let normalizedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for path traversal attempts
        let dangerousPatterns = ["../", "..\\", "%2e%2e", "%2E%2E", "..%2f", "..%5c"]
        for pattern in dangerousPatterns {
            if normalizedPath.lowercased().contains(pattern) {
                throw ValidationError.pathTraversalAttempt(path)
            }
        }
        
        // Validate path length
        guard normalizedPath.count <= 1000 else {
            throw ValidationError.pathTooLong(path)
        }
        
        // Ensure path starts with /
        guard normalizedPath.hasPrefix("/") else {
            throw ValidationError.invalidPath(path, "Path must start with /")
        }
    }
    
    /// Validate request headers for security
    static func validateSecurityHeaders(_ headers: [String: String]) throws {
        // Check for suspicious headers that might indicate attacks
        let suspiciousHeaders = ["x-forwarded-for", "x-real-ip", "x-forwarded-proto"]
        
        for (headerName, headerValue) in headers {
            let normalizedName = headerName.lowercased()
            
            // Check for excessively long header values
            guard headerValue.count <= 8192 else {
                throw ValidationError.headerTooLong(headerName, headerValue.count)
            }
            
            // Log suspicious headers for monitoring
            if suspiciousHeaders.contains(normalizedName) {
                logger.warning("Suspicious header detected: \(headerName, privacy: .public) = \(headerValue, privacy: .public)")
            }
        }
    }
}

/// Extended validation errors
extension ValidationError {
    static func processNotFound(_ processId: String) -> ValidationError {
        return .invalidFormat("processId", "Process ID '\(processId)' not found in current process list")
    }
    
    static func processHasNoAudio(_ processId: String, _ processName: String) -> ValidationError {
        return .invalidFormat("processId", "Process '\(processName)' (ID: \(processId)) does not have audio capability")
    }
    
    static func requestTooLarge(_ size: Int, _ maxSize: Int) -> ValidationError {
        return .valueOutOfRange("requestBody", "Request body size (\(size) bytes) exceeds maximum allowed size (\(maxSize) bytes)")
    }
    
    static func methodNotAllowed(_ method: String, _ allowedMethods: [String]) -> ValidationError {
        return .invalidFormat("httpMethod", "HTTP method '\(method)' not allowed. Allowed methods: \(allowedMethods.joined(separator: ", "))")
    }
    
    static let missingContentType = ValidationError.missingRequiredField("Content-Type")
    
    static func invalidContentType(_ contentType: String) -> ValidationError {
        return .invalidFormat("Content-Type", "Content type '\(contentType)' not supported. Use 'application/json'")
    }
    
    static func originNotAllowed(_ origin: String, _ allowedOrigins: [String]) -> ValidationError {
        return .invalidFormat("Origin", "Origin '\(origin)' not allowed. Allowed origins: \(allowedOrigins.joined(separator: ", "))")
    }
    
    static func pathTraversalAttempt(_ path: String) -> ValidationError {
        return .invalidFormat("path", "Path contains potential directory traversal: '\(path)'")
    }
    
    static func pathTooLong(_ path: String) -> ValidationError {
        return .valueOutOfRange("path", "Path too long (\(path.count) characters, max 1000)")
    }
    
    static func invalidPath(_ path: String, _ reason: String) -> ValidationError {
        return .invalidFormat("path", "\(reason): '\(path)'")
    }
    
    static func headerTooLong(_ headerName: String, _ length: Int) -> ValidationError {
        return .valueOutOfRange("header", "Header '\(headerName)' too long (\(length) characters, max 8192)")
    }
}