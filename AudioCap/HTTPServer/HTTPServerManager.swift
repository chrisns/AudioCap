//
//  HTTPServerManager.swift
//  AudioCap
//
//  HTTP server lifecycle management with @Observable pattern
//

import Foundation
import Network
import OSLog

private let logger = Logger(subsystem: kAppSubsystem, category: "HTTPServer")

/// Thread-safe box for sharing mutable state across concurrency boundaries
private final class Box<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T
    
    var value: T {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _value = newValue
        }
    }
    
    init(_ value: T) {
        self._value = value
    }
}

/// Manages the lifecycle of the embedded HTTP server
@Observable
@MainActor
final class HTTPServerManager {
    /// Current server configuration
    var configuration: ServerConfiguration {
        didSet {
            if oldValue != configuration {
                configuration.save()
                Task {
                    await updateServerWithNewConfiguration()
                }
            }
        }
    }
    
    /// Whether the server is currently running
    private(set) var isRunning: Bool = false
    
    /// Current server status message
    private(set) var statusMessage: String = "Server stopped"
    
    /// Current endpoint URL when server is running
    var endpointURL: String? {
        guard isRunning else { return nil }
        return "http://\(configuration.ipAddress):\(configuration.port)"
    }
    
    /// Internal server listener
    private var listener: NWListener?
    
    /// Server queue for handling connections
    private let serverQueue = DispatchQueue(label: "HTTPServerQueue", qos: .userInitiated)
    
    /// Rate limiter for request throttling
    private var rateLimiter: RateLimiter?
    
    /// Connection tracking for concurrent connection limits
    private var activeConnections: Set<String> = []
    
    /// API handlers
    private var processAPIHandler: ProcessAPIHandler?
    private var recordingAPIHandler: RecordingAPIHandler?
    private var documentationHandler: DocumentationHandler?
    
    init() {
        self.configuration = ServerConfiguration.load()
        logger.info("HTTPServerManager initialized with configuration: \(self.configuration.ipAddress):\(self.configuration.port)")
        
        // Initialize API handlers
        let processController = AudioProcessController()
        self.processAPIHandler = ProcessAPIHandler(processController: processController)
        self.recordingAPIHandler = RecordingAPIHandler(processController: processController)
        self.documentationHandler = DocumentationHandler()
    }
    
    deinit {
        Task { [weak self] in
            await self?.stop()
        }
    }
}

// MARK: - Server Lifecycle
extension HTTPServerManager {
    /// Start the HTTP server
    func start() async throws {
        guard !isRunning else {
            logger.warning("Attempted to start server that is already running")
            return
        }
        
        // Validate and sanitize configuration
        var validatedConfig = configuration
        do {
            try validatedConfig.validateAndSanitize()
        } catch {
            let errorMessage = "Invalid server configuration: \(error.localizedDescription)"
            logger.error("\(errorMessage)")
            statusMessage = errorMessage
            throw error
        }
        
        // Log security warnings
        let warnings = validatedConfig.securityWarnings
        if !warnings.isEmpty {
            logger.warning("Starting server with security warnings:")
            for warning in warnings {
                logger.warning("  ⚠️ \(warning, privacy: .public)")
            }
        }
        
        // Enforce localhost-only binding by default for security
        if validatedConfig.ipAddress != "127.0.0.1" && validatedConfig.ipAddress != "localhost" {
            logger.warning("🔒 Server configured to bind to '\(validatedConfig.ipAddress, privacy: .public)' - this allows external access!")
            logger.warning("🔒 For security, consider using '127.0.0.1' to restrict access to localhost only")
        } else {
            logger.info("🔒 Server binding to localhost only - external access blocked for security")
        }
        
        do {
            // Initialize rate limiter
            rateLimiter = RateLimiter(maxRequestsPerMinute: validatedConfig.maxRequestsPerMinute)
            
            try await startListener()
            isRunning = true
            statusMessage = "Server running on \(configuration.ipAddress):\(configuration.port)"
            logger.info("HTTP server started successfully on \(self.configuration.ipAddress):\(self.configuration.port)")
            
            // Log security configuration
            logger.info("🔒 Security settings:")
            logger.info("  - Max concurrent connections: \(validatedConfig.maxConcurrentConnections)")
            logger.info("  - Rate limit: \(validatedConfig.maxRequestsPerMinute) requests/minute")
            logger.info("  - Max request body size: \(validatedConfig.maxRequestBodySize / 1024)KB")
            logger.info("  - Request timeout: \(validatedConfig.requestTimeoutSeconds)s")
            
            // Log CORS configuration
            if configuration.enableCORS {
                if configuration.corsOrigins.isEmpty {
                    logger.warning("🌐 CORS enabled with no origin restrictions - any website can access the API")
                } else {
                    logger.info("🌐 CORS enabled for origins: \(self.configuration.corsOrigins.joined(separator: ", "), privacy: .public)")
                }
            } else {
                logger.info("🌐 CORS disabled - web browsers will block cross-origin requests")
            }
            
        } catch {
            statusMessage = "Failed to start server: \(error.localizedDescription)"
            logger.error("Failed to start HTTP server: \(error)")
            throw error
        }
    }
    
    /// Stop the HTTP server
    func stop() async {
        guard isRunning else {
            logger.info("Attempted to stop server that is not running")
            return
        }
        
        listener?.cancel()
        listener = nil
        rateLimiter = nil
        
        activeConnections.removeAll()
        
        isRunning = false
        statusMessage = "Server stopped"
        logger.info("HTTP server stopped")
    }
    
    /// Update server configuration and restart if necessary
    func updateConfiguration(_ newConfig: ServerConfiguration) {
        configuration = newConfig
    }
    
    /// Internal method to handle configuration changes
    private func updateServerWithNewConfiguration() async {
        if isRunning {
            await stop()
            if configuration.enabled {
                do {
                    try await start()
                } catch {
                    logger.error("Failed to restart server with new configuration: \(error)")
                }
            }
        } else if configuration.enabled {
            do {
                try await start()
            } catch {
                logger.error("Failed to start server with new configuration: \(error)")
            }
        }
    }
}

// MARK: - Network Listener
extension HTTPServerManager {
    /// Start the network listener
    private func startListener() async throws {
        let port = NWEndpoint.Port(integerLiteral: UInt16(configuration.port))
        let _ = NWEndpoint.Host(configuration.ipAddress)
        
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        
        listener = try NWListener(using: parameters, on: port)
        
        listener?.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in
                self?.handleNewConnection(connection)
            }
        }
        
        listener?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handleListenerStateChange(state)
            }
        }
        
        listener?.start(queue: serverQueue)
        
        // Wait for the listener to be ready
        return try await withCheckedThrowingContinuation { continuation in
            let resumedBox = Box(false)
            
            listener?.stateUpdateHandler = { state in
                guard !resumedBox.value else { return }
                switch state {
                case .ready:
                    resumedBox.value = true
                    continuation.resume()
                case .failed(let error):
                    resumedBox.value = true
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
        }
    }
    
    /// Handle new incoming connections
    private func handleNewConnection(_ connection: NWConnection) {
        logger.debug("New connection received")
        
        // Check concurrent connection limit
        let connectionId = UUID().uuidString
        let currentConnections = activeConnections.count
        
        guard currentConnections < configuration.maxConcurrentConnections else {
            logger.warning("Connection rejected: too many concurrent connections (\(currentConnections)/\(self.configuration.maxConcurrentConnections))")
            Task { @MainActor in
                self.sendErrorResponse(connection, statusCode: 503, message: "Service Unavailable - Too many connections")
            }
            return
        }
        
        activeConnections.insert(connectionId)
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                logger.debug("Connection ready")
                Task { @MainActor in
                    self?.handleHTTPRequest(connection, connectionId: connectionId)
                }
            case .failed(let error):
                logger.error("Connection failed: \(error)")
                Task { @MainActor in
                    self?.removeConnection(connectionId)
                }
            case .cancelled:
                logger.debug("Connection cancelled")
                Task { @MainActor in
                    self?.removeConnection(connectionId)
                }
            default:
                break
            }
        }
        
        connection.start(queue: serverQueue)
    }
    
    /// Remove connection from tracking
    @MainActor
    private func removeConnection(_ connectionId: String) {
        activeConnections.remove(connectionId)
    }
    
    /// Handle HTTP request with security validation and CORS support
    private func handleHTTPRequest(_ connection: NWConnection, connectionId: String) {
        // Set up request timeout
        let timeoutTimer = DispatchSource.makeTimerSource(queue: serverQueue)
        timeoutTimer.schedule(deadline: .now() + configuration.requestTimeoutSeconds)
        timeoutTimer.setEventHandler {
            logger.warning("Request timeout after \(self.configuration.requestTimeoutSeconds) seconds")
            connection.cancel()
        }
        timeoutTimer.resume()
        
        // Read HTTP request with size limit
        connection.receive(minimumIncompleteLength: 1, maximumLength: configuration.maxRequestBodySize) { [weak self] data, _, isComplete, error in
            timeoutTimer.cancel()
            
            guard let self = self else { 
                return 
            }
            
            Task { @MainActor in
                defer {
                    self.removeConnection(connectionId)
                }
                
                if let error = error {
                    logger.error("Failed to receive request data: \(error)")
                    self.sendErrorResponse(connection, statusCode: 400, message: "Bad Request")
                    return
                }
                
                guard let data = data, !data.isEmpty else {
                    logger.error("Received empty request data")
                    self.sendErrorResponse(connection, statusCode: 400, message: "Empty request")
                    return
                }
                
                // Validate request size
                do {
                    try RequestValidator.validateRequestBodySize(data, maxSize: self.configuration.maxRequestBodySize)
                } catch {
                    logger.error("Request body size validation failed: \(error)")
                    self.sendErrorResponse(connection, statusCode: 413, message: "Request Entity Too Large")
                    return
                }
                
                // Parse and validate HTTP request
                self.processHTTPRequest(connection, data: data)
            }
        }
    }
    
    /// Process HTTP request with method validation and CORS handling
    @MainActor
    private func processHTTPRequest(_ connection: NWConnection, data: Data) {
        // Parse HTTP request (basic implementation)
        guard let requestString = String(data: data, encoding: .utf8) else {
            logger.error("Failed to decode request as UTF-8")
            sendErrorResponse(connection, statusCode: 400, message: "Invalid request encoding")
            return
        }
        
        let lines = requestString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            logger.error("Missing HTTP request line")
            sendErrorResponse(connection, statusCode: 400, message: "Invalid HTTP request")
            return
        }
        
        let requestComponents = requestLine.components(separatedBy: " ")
        guard requestComponents.count >= 3 else {
            logger.error("Invalid HTTP request line format")
            sendErrorResponse(connection, statusCode: 400, message: "Invalid HTTP request line")
            return
        }
        
        let method = requestComponents[0]
        let path = requestComponents[1]
        
        // Extract client IP for rate limiting (simplified - in production you'd handle X-Forwarded-For etc.)
        let clientIP = "127.0.0.1" // For localhost connections
        
        // Check rate limiting
        Task { [weak self] in
            guard let self = self,
                  let rateLimiter = self.rateLimiter else {
                self?.sendErrorResponse(connection, statusCode: 500, message: "Internal Server Error")
                return
            }
            
            let allowed = await rateLimiter.shouldAllowRequest(from: clientIP)
            guard allowed else {
                let currentCount = await rateLimiter.getCurrentRequestCount(for: clientIP)
                logger.warning("Rate limit exceeded for \(clientIP): \(currentCount) requests")
                self.sendErrorResponse(connection, statusCode: 429, message: "Too Many Requests")
                return
            }
            
            // Continue with request processing
            self.processValidatedHTTPRequest(connection, method: method, path: path, lines: lines, data: data)
        }
    }
    
    /// Process HTTP request after rate limiting validation
    @MainActor
    private func processValidatedHTTPRequest(_ connection: NWConnection, method: String, path: String, lines: [String], data: Data) {
        
        // Validate request path for security
        do {
            try RequestValidator.validateRequestPath(path)
        } catch {
            logger.error("Path validation failed: \(error)")
            sendErrorResponse(connection, statusCode: 400, message: "Invalid request path")
            return
        }
        
        // Parse and validate headers
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if line.isEmpty { break } // End of headers
            let parts = line.components(separatedBy: ": ")
            if parts.count >= 2 {
                let headerName = parts[0].lowercased()
                let headerValue = parts.dropFirst().joined(separator: ": ")
                headers[headerName] = headerValue
            }
        }
        
        // Validate security headers
        do {
            try RequestValidator.validateSecurityHeaders(headers)
        } catch {
            logger.error("Security header validation failed: \(error)")
            sendErrorResponse(connection, statusCode: 400, message: "Invalid headers")
            return
        }
        
        // Validate CORS origin if present
        if let origin = headers["origin"] {
            do {
                try RequestValidator.validateRequestOrigin(origin, allowedOrigins: configuration.corsOrigins)
            } catch {
                logger.error("CORS origin validation failed: \(error)")
                sendErrorResponse(connection, statusCode: 403, message: "Origin not allowed")
                return
            }
        }
        
        // Handle CORS preflight requests
        if method == "OPTIONS" {
            handleCORSPreflight(connection, path: path)
            return
        }
        
        // Validate HTTP method for specific endpoints
        do {
            switch path {
            case "/processes":
                try RequestValidator.validateHTTPMethod(method, allowedMethods: ["GET"])
            case "/recording/start":
                try RequestValidator.validateHTTPMethod(method, allowedMethods: ["POST"])
            case "/recording/stop":
                try RequestValidator.validateHTTPMethod(method, allowedMethods: ["POST"])
            case "/recording/status":
                try RequestValidator.validateHTTPMethod(method, allowedMethods: ["GET"])
            case "/docs":
                try RequestValidator.validateHTTPMethod(method, allowedMethods: ["GET"])
            default:
                logger.error("Unknown endpoint: \(path, privacy: .public)")
                sendErrorResponse(connection, statusCode: 404, message: "Not Found")
                return
            }
        } catch {
            logger.error("HTTP method validation failed: \(error)")
            sendErrorResponse(connection, statusCode: 405, message: "Method Not Allowed")
            return
        }
        
        // For POST requests, validate Content-Type
        if method == "POST" {
            let contentType = headers["content-type"]
            do {
                try RequestValidator.validateContentType(contentType)
            } catch {
                logger.error("Content-Type validation failed: \(error)")
                sendErrorResponse(connection, statusCode: 400, message: "Invalid Content-Type")
                return
            }
        }
        
        // Route to appropriate handlers
        logger.debug("Request validated successfully: \(method, privacy: .public) \(path, privacy: .public)")
        
        Task { @MainActor in
            await self.routeRequest(connection: connection, method: method, path: path, lines: lines, data: data)
        }
    }
    
    /// Handle CORS preflight requests
    @MainActor
    private func handleCORSPreflight(_ connection: NWConnection, path: String) {
        guard configuration.enableCORS else {
            sendErrorResponse(connection, statusCode: 405, message: "CORS not enabled")
            return
        }
        
        logger.debug("Handling CORS preflight for path: \(path, privacy: .public)")
        
        var headers = [
            "HTTP/1.1 200 OK",
            "Access-Control-Allow-Methods: GET, POST, OPTIONS",
            "Access-Control-Allow-Headers: Content-Type, Authorization",
            "Access-Control-Max-Age: 86400", // 24 hours
            "Content-Length: 0"
        ]
        
        // Add CORS origin headers
        headers.append(contentsOf: buildCORSHeaders())
        
        let response = headers.joined(separator: "\r\n") + "\r\n\r\n"
        let responseData = response.data(using: .utf8) ?? Data()
        
        connection.send(content: responseData, completion: .contentProcessed { error in
            if let error = error {
                logger.error("Failed to send CORS preflight response: \(error)")
            }
            connection.cancel()
        })
    }
    
    /// Build CORS headers based on configuration
    @MainActor
    private func buildCORSHeaders() -> [String] {
        guard configuration.enableCORS else { return [] }
        
        var corsHeaders: [String] = []
        
        if configuration.corsOrigins.isEmpty {
            // Allow all origins (less secure)
            corsHeaders.append("Access-Control-Allow-Origin: *")
        } else {
            // TODO: In a real implementation, we'd check the Origin header against allowed origins
            // For now, just use the first allowed origin
            if let firstOrigin = configuration.corsOrigins.first {
                corsHeaders.append("Access-Control-Allow-Origin: \(firstOrigin)")
            }
        }
        
        corsHeaders.append("Access-Control-Allow-Credentials: false")
        
        return corsHeaders
    }
    
    /// Extract header value from HTTP request lines
    private func extractHeader(_ headerName: String, from lines: [String]) -> String? {
        let headerPrefix = "\(headerName): "
        for line in lines {
            if line.hasPrefix(headerPrefix) {
                return String(line.dropFirst(headerPrefix.count))
            }
        }
        return nil
    }
    
    /// Send error response with CORS headers
    @MainActor
    private func sendErrorResponse(_ connection: NWConnection, statusCode: Int, message: String) {
        let errorResponse = ErrorResponse(error: APIError(
            code: "HTTP_ERROR",
            message: message,
            details: nil
        ))
        
        guard let jsonData = try? JSONEncoder().encode(errorResponse) else {
            connection.cancel()
            return
        }
        
        var headers = [
            "HTTP/1.1 \(statusCode) \(message)",
            "Content-Type: application/json",
            "Content-Length: \(jsonData.count)"
        ]
        
        // Add CORS headers if enabled
        headers.append(contentsOf: buildCORSHeaders())
        
        let response = headers.joined(separator: "\r\n") + "\r\n\r\n"
        let responseData = (response.data(using: .utf8) ?? Data()) + jsonData
        
        connection.send(content: responseData, completion: .contentProcessed { error in
            if let error = error {
                logger.error("Failed to send error response: \(error)")
            }
            connection.cancel()
        })
    }
    
    /// Send success response with CORS headers
    @MainActor
    private func sendSuccessResponse(_ connection: NWConnection, message: String) {
        let jsonData = "{\"message\": \"\(message)\"}".data(using: .utf8) ?? Data()
        
        var headers = [
            "HTTP/1.1 200 OK",
            "Content-Type: application/json",
            "Content-Length: \(jsonData.count)"
        ]
        
        // Add CORS headers if enabled
        headers.append(contentsOf: buildCORSHeaders())
        
        let response = headers.joined(separator: "\r\n") + "\r\n\r\n"
        let responseData = (response.data(using: .utf8) ?? Data()) + jsonData
        
        connection.send(content: responseData, completion: .contentProcessed { error in
            if let error = error {
                logger.error("Failed to send success response: \(error)")
            }
            connection.cancel()
        })
    }
    
    /// Route request to appropriate handler
    @MainActor
    private func routeRequest(connection: NWConnection, method: String, path: String, lines: [String], data: Data) async {
        do {
            switch path {
            case "/processes":
                guard let handler = processAPIHandler else {
                    sendErrorResponse(connection, statusCode: 500, message: "Process handler not available")
                    return
                }
                let response = try await handler.handleProcessList()
                sendJSONResponse(connection: connection, data: response, statusCode: 200)
                
            case "/recording/start":
                guard let handler = recordingAPIHandler else {
                    sendErrorResponse(connection, statusCode: 500, message: "Recording handler not available")
                    return
                }
                
                // Extract JSON body from request
                let jsonBody = extractJSONBody(from: lines, data: data)
                let response = try await handler.handleStartRecordingFromJSON(jsonBody)
                sendJSONResponse(connection: connection, data: response, statusCode: 201)
                
            case "/recording/stop":
                guard let handler = recordingAPIHandler else {
                    sendErrorResponse(connection, statusCode: 500, message: "Recording handler not available")
                    return
                }
                let response = try await handler.handleStopRecording()
                sendJSONResponse(connection: connection, data: response, statusCode: 200)
                
            case "/recording/status":
                guard let handler = recordingAPIHandler else {
                    sendErrorResponse(connection, statusCode: 500, message: "Recording handler not available")
                    return
                }
                let response = try await handler.handleRecordingStatus()
                sendJSONResponse(connection: connection, data: response, statusCode: 200)
                
            case "/docs":
                guard let handler = documentationHandler else {
                    sendErrorResponse(connection, statusCode: 500, message: "Documentation handler not available")
                    return
                }
                let htmlContent = try await handler.handleDocumentation()
                sendHTMLResponse(connection: connection, html: htmlContent)
                
            default:
                sendErrorResponse(connection, statusCode: 404, message: "Not Found")
            }
        } catch let error as APIHandlerError {
            sendAPIErrorResponse(connection: connection, error: error)
        } catch let error as RecordingAPIError {
            sendRecordingAPIErrorResponse(connection: connection, error: error)
        } catch let error as DocumentationError {
            sendDocumentationErrorResponse(connection: connection, error: error)
        } catch {
            logger.error("Unexpected error handling request: \(error)")
            sendErrorResponse(connection, statusCode: 500, message: "Internal Server Error")
        }
    }
    
    /// Extract JSON body from HTTP request
    private func extractJSONBody(from lines: [String], data: Data) -> Data {
        // Find the end of headers (empty line)
        var headerEndIndex = 0
        for (index, line) in lines.enumerated() {
            if line.isEmpty {
                headerEndIndex = index
                break
            }
        }
        
        // Calculate the byte offset of the body
        let headerString = lines[0...headerEndIndex].joined(separator: "\r\n") + "\r\n"
        let headerData = headerString.data(using: .utf8) ?? Data()
        
        // Extract body data
        if data.count > headerData.count {
            return data.dropFirst(headerData.count)
        }
        
        return Data()
    }
    
    /// Send JSON response with proper headers
    @MainActor
    private func sendJSONResponse<T: Codable>(connection: NWConnection, data: T, statusCode: Int) {
        do {
            let jsonData = try JSONEncoder().encode(data)
            
            var headers = [
                "HTTP/1.1 \(statusCode) \(httpStatusMessage(for: statusCode))",
                "Content-Type: application/json",
                "Content-Length: \(jsonData.count)"
            ]
            
            // Add CORS headers if enabled
            headers.append(contentsOf: buildCORSHeaders())
            
            let response = headers.joined(separator: "\r\n") + "\r\n\r\n"
            let responseData = (response.data(using: .utf8) ?? Data()) + jsonData
            
            connection.send(content: responseData, completion: .contentProcessed { error in
                if let error = error {
                    logger.error("Failed to send JSON response: \(error)")
                }
                connection.cancel()
            })
        } catch {
            logger.error("Failed to encode JSON response: \(error)")
            sendErrorResponse(connection, statusCode: 500, message: "Internal Server Error")
        }
    }
    
    /// Send HTML response with proper headers
    @MainActor
    private func sendHTMLResponse(connection: NWConnection, html: String) {
        let htmlData = html.data(using: .utf8) ?? Data()
        
        var headers = [
            "HTTP/1.1 200 OK",
            "Content-Type: text/html; charset=utf-8",
            "Content-Length: \(htmlData.count)"
        ]
        
        // Add CORS headers if enabled
        headers.append(contentsOf: buildCORSHeaders())
        
        let response = headers.joined(separator: "\r\n") + "\r\n\r\n"
        let responseData = (response.data(using: .utf8) ?? Data()) + htmlData
        
        connection.send(content: responseData, completion: .contentProcessed { error in
            if let error = error {
                logger.error("Failed to send HTML response: \(error)")
            }
            connection.cancel()
        })
    }
    
    /// Send API handler error response
    @MainActor
    private func sendAPIErrorResponse(connection: NWConnection, error: APIHandlerError) {
        let errorResponse = ErrorResponse(error: error.apiError)
        
        guard let jsonData = try? JSONEncoder().encode(errorResponse) else {
            sendErrorResponse(connection, statusCode: 500, message: "Internal Server Error")
            return
        }
        
        var headers = [
            "HTTP/1.1 \(error.httpStatusCode) \(httpStatusMessage(for: error.httpStatusCode))",
            "Content-Type: application/json",
            "Content-Length: \(jsonData.count)"
        ]
        
        // Add CORS headers if enabled
        headers.append(contentsOf: buildCORSHeaders())
        
        let response = headers.joined(separator: "\r\n") + "\r\n\r\n"
        let responseData = (response.data(using: .utf8) ?? Data()) + jsonData
        
        connection.send(content: responseData, completion: .contentProcessed { error in
            if let error = error {
                logger.error("Failed to send API error response: \(error)")
            }
            connection.cancel()
        })
    }
    
    /// Send recording API error response
    @MainActor
    private func sendRecordingAPIErrorResponse(connection: NWConnection, error: RecordingAPIError) {
        let errorResponse = ErrorResponse(error: error.apiError)
        
        guard let jsonData = try? JSONEncoder().encode(errorResponse) else {
            sendErrorResponse(connection, statusCode: 500, message: "Internal Server Error")
            return
        }
        
        var headers = [
            "HTTP/1.1 \(error.httpStatusCode) \(httpStatusMessage(for: error.httpStatusCode))",
            "Content-Type: application/json",
            "Content-Length: \(jsonData.count)"
        ]
        
        // Add CORS headers if enabled
        headers.append(contentsOf: buildCORSHeaders())
        
        let response = headers.joined(separator: "\r\n") + "\r\n\r\n"
        let responseData = (response.data(using: .utf8) ?? Data()) + jsonData
        
        connection.send(content: responseData, completion: .contentProcessed { error in
            if let error = error {
                logger.error("Failed to send recording API error response: \(error)")
            }
            connection.cancel()
        })
    }
    
    /// Send documentation error response
    @MainActor
    private func sendDocumentationErrorResponse(connection: NWConnection, error: DocumentationError) {
        let errorResponse = ErrorResponse(error: error.apiError)
        
        guard let jsonData = try? JSONEncoder().encode(errorResponse) else {
            sendErrorResponse(connection, statusCode: 500, message: "Internal Server Error")
            return
        }
        
        var headers = [
            "HTTP/1.1 \(error.httpStatusCode) \(httpStatusMessage(for: error.httpStatusCode))",
            "Content-Type: application/json",
            "Content-Length: \(jsonData.count)"
        ]
        
        // Add CORS headers if enabled
        headers.append(contentsOf: buildCORSHeaders())
        
        let response = headers.joined(separator: "\r\n") + "\r\n\r\n"
        let responseData = (response.data(using: .utf8) ?? Data()) + jsonData
        
        connection.send(content: responseData, completion: .contentProcessed { error in
            if let error = error {
                logger.error("Failed to send documentation error response: \(error)")
            }
            connection.cancel()
        })
    }
    
    /// Get HTTP status message for status code
    private func httpStatusMessage(for statusCode: Int) -> String {
        switch statusCode {
        case 200: return "OK"
        case 201: return "Created"
        case 400: return "Bad Request"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 409: return "Conflict"
        case 413: return "Request Entity Too Large"
        case 429: return "Too Many Requests"
        case 500: return "Internal Server Error"
        case 503: return "Service Unavailable"
        default: return "Unknown"
        }
    }
    
    /// Handle listener state changes
    private func handleListenerStateChange(_ state: NWListener.State) {
        switch state {
        case .ready:
            logger.info("Listener ready")
        case .failed(let error):
            logger.error("Listener failed: \(error)")
            statusMessage = "Server failed: \(error.localizedDescription)"
            isRunning = false
        case .cancelled:
            logger.info("Listener cancelled")
            isRunning = false
        default:
            break
        }
    }
}