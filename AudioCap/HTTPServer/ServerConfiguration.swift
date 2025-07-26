//
//  ServerConfiguration.swift
//  AudioCap
//
//  Configuration model for HTTP API server settings
//

import Foundation
import OSLog

private let logger = Logger(subsystem: kAppSubsystem, category: "ServerConfiguration")

/// Configuration settings for the HTTP API server
struct ServerConfiguration: Codable, Equatable {
    /// Whether the HTTP server is enabled
    var enabled: Bool = true
    
    /// IP address to bind the server to
    var ipAddress: String = "127.0.0.1"
    
    /// Port number for the server
    var port: Int = 5742
    
    /// Whether to enable CORS headers
    var enableCORS: Bool = true
    
    /// Allowed CORS origins (empty means all origins allowed)
    var corsOrigins: [String] = []
    
    /// Maximum request body size in bytes (default 1MB)
    var maxRequestBodySize: Int = 1024 * 1024
    
    /// Request timeout in seconds
    var requestTimeoutSeconds: Double = 30.0
    
    /// Whether to enforce localhost-only binding (security feature)
    var enforceLocalhostOnly: Bool = true
    
    /// Maximum number of concurrent connections
    var maxConcurrentConnections: Int = 10
    
    /// Rate limiting: maximum requests per minute per IP
    var maxRequestsPerMinute: Int = 60
    
    /// Default configuration
    static let `default` = ServerConfiguration()
    
    /// Validation for configuration values
    var isValid: Bool {
        return isPortValid && isIPAddressValid && isTimeoutValid && isRequestSizeValid && isConcurrentConnectionsValid && isRateLimitValid
    }
    
    /// Validate port number is in valid range
    private var isPortValid: Bool {
        return port > 0 && port <= 65535
    }
    
    /// Validate IP address format and security
    private var isIPAddressValid: Bool {
        guard !ipAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        
        // Basic IP address format validation
        let components = ipAddress.components(separatedBy: ".")
        guard components.count == 4 else {
            return false
        }
        
        for component in components {
            guard let value = Int(component), value >= 0 && value <= 255 else {
                return false
            }
        }
        
        return true
    }
    
    /// Validate timeout is reasonable
    private var isTimeoutValid: Bool {
        return requestTimeoutSeconds > 0 && requestTimeoutSeconds <= 300 // Max 5 minutes
    }
    
    /// Validate request size is reasonable
    private var isRequestSizeValid: Bool {
        return maxRequestBodySize > 0 && maxRequestBodySize <= 10 * 1024 * 1024 // Max 10MB
    }
    
    /// Validate concurrent connections limit
    private var isConcurrentConnectionsValid: Bool {
        return maxConcurrentConnections > 0 && maxConcurrentConnections <= 100
    }
    
    /// Validate rate limiting settings
    private var isRateLimitValid: Bool {
        return maxRequestsPerMinute > 0 && maxRequestsPerMinute <= 1000
    }
    
    /// Check if the configuration poses security risks
    var securityWarnings: [String] {
        var warnings: [String] = []
        
        // Check for non-localhost binding
        if ipAddress != "127.0.0.1" && ipAddress != "localhost" {
            if enforceLocalhostOnly {
                warnings.append("Localhost-only enforcement is enabled but IP address is set to '\(ipAddress)'. This configuration will be overridden for security.")
            } else {
                warnings.append("Server is configured to bind to '\(ipAddress)' which allows external access. This may pose security risks.")
            }
        }
        
        // Check for overly permissive CORS
        if enableCORS && corsOrigins.isEmpty {
            warnings.append("CORS is enabled with no origin restrictions. This allows any website to access the API.")
        }
        
        // Check for large request sizes
        if maxRequestBodySize > 5 * 1024 * 1024 { // 5MB
            warnings.append("Maximum request body size is set to \(maxRequestBodySize / (1024 * 1024))MB which may allow large requests.")
        }
        
        // Check for long timeouts
        if requestTimeoutSeconds > 60 {
            warnings.append("Request timeout is set to \(Int(requestTimeoutSeconds)) seconds which may allow slow attacks.")
        }
        
        // Check for high concurrent connections
        if maxConcurrentConnections > 50 {
            warnings.append("Maximum concurrent connections is set to \(maxConcurrentConnections) which may allow resource exhaustion.")
        }
        
        // Check for high rate limits
        if maxRequestsPerMinute > 300 {
            warnings.append("Rate limit is set to \(maxRequestsPerMinute) requests per minute which may allow abuse.")
        }
        
        return warnings
    }
    
    /// Validate and sanitize configuration values
    mutating func validateAndSanitize() throws {
        // Sanitize IP address
        ipAddress = ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Enforce localhost-only binding if enabled
        if enforceLocalhostOnly && ipAddress != "127.0.0.1" && ipAddress != "localhost" {
            let oldIP = ipAddress
            logger.warning("Enforcing localhost-only binding: changing IP from '\(oldIP)' to '127.0.0.1'")
            ipAddress = "127.0.0.1"
        }
        
        // Validate port range
        guard isPortValid else {
            throw ConfigurationError.invalidPort(port)
        }
        
        // Validate IP address
        guard isIPAddressValid else {
            throw ConfigurationError.invalidIPAddress(ipAddress)
        }
        
        // Clamp timeout to valid range
        if requestTimeoutSeconds <= 0 {
            let oldTimeout = requestTimeoutSeconds
            logger.warning("Request timeout too low (\(oldTimeout)), setting to 1 second")
            requestTimeoutSeconds = 1.0
        } else if requestTimeoutSeconds > 300 {
            let oldTimeout = requestTimeoutSeconds
            logger.warning("Request timeout too high (\(oldTimeout)), setting to 300 seconds")
            requestTimeoutSeconds = 300.0
        }
        
        // Clamp request size to valid range
        if maxRequestBodySize <= 0 {
            let oldSize = maxRequestBodySize
            logger.warning("Max request body size too low (\(oldSize)), setting to 1KB")
            maxRequestBodySize = 1024
        } else if maxRequestBodySize > 10 * 1024 * 1024 {
            let oldSize = maxRequestBodySize
            logger.warning("Max request body size too high (\(oldSize)), setting to 10MB")
            maxRequestBodySize = 10 * 1024 * 1024
        }
        
        // Clamp concurrent connections to valid range
        if maxConcurrentConnections <= 0 {
            let oldConnections = maxConcurrentConnections
            logger.warning("Max concurrent connections too low (\(oldConnections)), setting to 1")
            maxConcurrentConnections = 1
        } else if maxConcurrentConnections > 100 {
            let oldConnections = maxConcurrentConnections
            logger.warning("Max concurrent connections too high (\(oldConnections)), setting to 100")
            maxConcurrentConnections = 100
        }
        
        // Clamp rate limit to valid range
        if maxRequestsPerMinute <= 0 {
            let oldLimit = maxRequestsPerMinute
            logger.warning("Max requests per minute too low (\(oldLimit)), setting to 1")
            maxRequestsPerMinute = 1
        } else if maxRequestsPerMinute > 1000 {
            let oldLimit = maxRequestsPerMinute
            logger.warning("Max requests per minute too high (\(oldLimit)), setting to 1000")
            maxRequestsPerMinute = 1000
        }
        
        // Sanitize CORS origins
        corsOrigins = corsOrigins.compactMap { origin in
            let sanitized = origin.trimmingCharacters(in: .whitespacesAndNewlines)
            return sanitized.isEmpty ? nil : sanitized
        }
        
        // Log security warnings
        let warnings = securityWarnings
        if !warnings.isEmpty {
            logger.warning("Security warnings for server configuration:")
            for warning in warnings {
                logger.warning("  - \(warning, privacy: .public)")
            }
        }
    }
}

/// Configuration validation errors
enum ConfigurationError: Error, LocalizedError {
    case invalidPort(Int)
    case invalidIPAddress(String)
    case invalidTimeout(Double)
    case invalidRequestSize(Int)
    case invalidConcurrentConnections(Int)
    case invalidRateLimit(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidPort(let port):
            return "Invalid port number: \(port). Port must be between 1 and 65535."
        case .invalidIPAddress(let ip):
            return "Invalid IP address: '\(ip)'. Must be a valid IPv4 address."
        case .invalidTimeout(let timeout):
            return "Invalid timeout: \(timeout). Timeout must be between 0.1 and 300 seconds."
        case .invalidRequestSize(let size):
            return "Invalid request size: \(size). Size must be between 1 byte and 10MB."
        case .invalidConcurrentConnections(let connections):
            return "Invalid concurrent connections: \(connections). Must be between 1 and 100."
        case .invalidRateLimit(let limit):
            return "Invalid rate limit: \(limit). Must be between 1 and 1000 requests per minute."
        }
    }
}

// MARK: - Configuration Persistence
extension ServerConfiguration {
    private static let userDefaultsKey = "HTTPServerConfiguration"
    
    /// Load configuration from UserDefaults
    static func load() -> ServerConfiguration {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let config = try? JSONDecoder().decode(ServerConfiguration.self, from: data) else {
            return .default
        }
        return config
    }
    
    /// Save configuration to UserDefaults
    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
    }
}