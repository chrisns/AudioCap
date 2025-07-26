//
//  DocumentationHandler.swift
//  AudioCap
//
//  Handler for serving OpenAPI documentation
//

import Foundation
import OSLog

/// Handler for documentation-related endpoints
@MainActor
final class DocumentationHandler {
    
    private let logger = Logger(subsystem: "com.audiocap.app", category: String(describing: DocumentationHandler.self))
    
    init() {
        logger.debug("DocumentationHandler initialized")
    }
    
    /// Handle GET /docs endpoint
    /// Returns HTML page with interactive API documentation
    func handleDocumentation() async throws -> String {
        logger.debug("Handling documentation request")
        
        let openAPISpec = generateOpenAPISpecification()
        let htmlContent = generateSwaggerUIHTML(openAPISpec: openAPISpec)
        
        logger.debug("Generated documentation HTML (\(htmlContent.count) characters)")
        return htmlContent
    }
    
    /// Generate OpenAPI specification from route definitions
    private func generateOpenAPISpecification() -> [String: Any] {
        return [
            "openapi": "3.0.0",
            "info": [
                "title": "AudioCap HTTP API",
                "description": "REST API for controlling AudioCap audio recording functionality",
                "version": "1.0.0",
                "contact": [
                    "name": "AudioCap",
                    "url": "https://github.com/audiocap/audiocap"
                ]
            ],
            "servers": [
                [
                    "url": "http://127.0.0.1:5742",
                    "description": "Local development server"
                ]
            ],
            "paths": generatePaths(),
            "components": generateComponents()
        ]
    }
    
    /// Generate API paths specification
    private func generatePaths() -> [String: Any] {
        return [
            "/processes": [
                "get": [
                    "summary": "List available audio processes",
                    "description": "Returns a list of all processes that can be recorded from",
                    "responses": [
                        "200": [
                            "description": "Successful response",
                            "content": [
                                "application/json": [
                                    "schema": [
                                        "$ref": "#/components/schemas/ProcessListResponse"
                                    ]
                                ]
                            ]
                        ],
                        "500": [
                            "description": "Internal server error",
                            "content": [
                                "application/json": [
                                    "schema": [
                                        "$ref": "#/components/schemas/ErrorResponse"
                                    ]
                                ]
                            ]
                        ]
                    ]
                ]
            ],
            "/recording/start": [
                "post": [
                    "summary": "Start recording from a process",
                    "description": "Begins audio recording from the specified process",
                    "requestBody": [
                        "required": true,
                        "content": [
                            "application/json": [
                                "schema": [
                                    "$ref": "#/components/schemas/StartRecordingRequest"
                                ]
                            ]
                        ]
                    ],
                    "responses": [
                        "201": [
                            "description": "Recording started successfully",
                            "content": [
                                "application/json": [
                                    "schema": [
                                        "$ref": "#/components/schemas/RecordingSession"
                                    ]
                                ]
                            ]
                        ],
                        "400": [
                            "description": "Invalid request parameters",
                            "content": [
                                "application/json": [
                                    "schema": [
                                        "$ref": "#/components/schemas/ErrorResponse"
                                    ]
                                ]
                            ]
                        ],
                        "409": [
                            "description": "Recording already in progress",
                            "content": [
                                "application/json": [
                                    "schema": [
                                        "$ref": "#/components/schemas/ErrorResponse"
                                    ]
                                ]
                            ]
                        ],
                        "500": [
                            "description": "Internal server error",
                            "content": [
                                "application/json": [
                                    "schema": [
                                        "$ref": "#/components/schemas/ErrorResponse"
                                    ]
                                ]
                            ]
                        ]
                    ]
                ]
            ],
            "/recording/stop": [
                "post": [
                    "summary": "Stop current recording",
                    "description": "Stops the current recording and returns metadata",
                    "responses": [
                        "200": [
                            "description": "Recording stopped successfully",
                            "content": [
                                "application/json": [
                                    "schema": [
                                        "$ref": "#/components/schemas/RecordingMetadata"
                                    ]
                                ]
                            ]
                        ],
                        "409": [
                            "description": "No recording in progress",
                            "content": [
                                "application/json": [
                                    "schema": [
                                        "$ref": "#/components/schemas/ErrorResponse"
                                    ]
                                ]
                            ]
                        ],
                        "500": [
                            "description": "Internal server error",
                            "content": [
                                "application/json": [
                                    "schema": [
                                        "$ref": "#/components/schemas/ErrorResponse"
                                    ]
                                ]
                            ]
                        ]
                    ]
                ]
            ],
            "/recording/status": [
                "get": [
                    "summary": "Get recording status",
                    "description": "Returns the current recording status and session information",
                    "responses": [
                        "200": [
                            "description": "Successful response",
                            "content": [
                                "application/json": [
                                    "schema": [
                                        "$ref": "#/components/schemas/RecordingStatusResponse"
                                    ]
                                ]
                            ]
                        ],
                        "500": [
                            "description": "Internal server error",
                            "content": [
                                "application/json": [
                                    "schema": [
                                        "$ref": "#/components/schemas/ErrorResponse"
                                    ]
                                ]
                            ]
                        ]
                    ]
                ]
            ],
            "/docs": [
                "get": [
                    "summary": "API Documentation",
                    "description": "Interactive API documentation interface",
                    "responses": [
                        "200": [
                            "description": "HTML documentation page",
                            "content": [
                                "text/html": [
                                    "schema": [
                                        "type": "string"
                                    ]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]
    }
    
    /// Generate component schemas
    private func generateComponents() -> [String: Any] {
        return [
            "schemas": [
                "AudioProcessInfo": [
                    "type": "object",
                    "required": ["id", "name", "hasAudioCapability"],
                    "properties": [
                        "id": [
                            "type": "string",
                            "description": "Unique process identifier"
                        ],
                        "name": [
                            "type": "string",
                            "description": "Process name"
                        ],
                        "hasAudioCapability": [
                            "type": "boolean",
                            "description": "Whether the process has audio capability"
                        ]
                    ]
                ],
                "ProcessListResponse": [
                    "type": "object",
                    "required": ["processes", "timestamp"],
                    "properties": [
                        "processes": [
                            "type": "array",
                            "items": [
                                "$ref": "#/components/schemas/AudioProcessInfo"
                            ]
                        ],
                        "timestamp": [
                            "type": "string",
                            "format": "date-time",
                            "description": "Response generation timestamp"
                        ]
                    ]
                ],
                "StartRecordingRequest": [
                    "type": "object",
                    "required": ["processId"],
                    "properties": [
                        "processId": [
                            "type": "string",
                            "description": "ID of the process to record from"
                        ],
                        "outputFormat": [
                            "type": "string",
                            "description": "Optional output format specification",
                            "nullable": true
                        ]
                    ]
                ],
                "RecordingSession": [
                    "type": "object",
                    "required": ["sessionId", "processId", "processName", "startTime", "status"],
                    "properties": [
                        "sessionId": [
                            "type": "string",
                            "description": "Unique session identifier"
                        ],
                        "processId": [
                            "type": "string",
                            "description": "ID of the process being recorded"
                        ],
                        "processName": [
                            "type": "string",
                            "description": "Name of the process being recorded"
                        ],
                        "startTime": [
                            "type": "string",
                            "format": "date-time",
                            "description": "Recording start timestamp"
                        ],
                        "status": [
                            "$ref": "#/components/schemas/RecordingStatus"
                        ]
                    ]
                ],
                "RecordingMetadata": [
                    "type": "object",
                    "required": ["sessionId", "filePath", "duration", "channelCount", "sampleRate", "fileSize", "endTime"],
                    "properties": [
                        "sessionId": [
                            "type": "string",
                            "description": "Session identifier"
                        ],
                        "filePath": [
                            "type": "string",
                            "description": "Absolute path to the recorded file"
                        ],
                        "duration": [
                            "type": "number",
                            "format": "double",
                            "description": "Recording duration in seconds"
                        ],
                        "channelCount": [
                            "type": "integer",
                            "description": "Number of audio channels"
                        ],
                        "sampleRate": [
                            "type": "number",
                            "format": "double",
                            "description": "Audio sample rate in Hz"
                        ],
                        "fileSize": [
                            "type": "integer",
                            "format": "int64",
                            "description": "File size in bytes"
                        ],
                        "endTime": [
                            "type": "string",
                            "format": "date-time",
                            "description": "Recording end timestamp"
                        ]
                    ]
                ],
                "RecordingStatusResponse": [
                    "type": "object",
                    "required": ["status"],
                    "properties": [
                        "status": [
                            "$ref": "#/components/schemas/RecordingStatus"
                        ],
                        "currentSession": [
                            "$ref": "#/components/schemas/RecordingSession",
                            "nullable": true,
                            "description": "Current recording session if active"
                        ],
                        "elapsedTime": [
                            "type": "number",
                            "format": "double",
                            "nullable": true,
                            "description": "Elapsed recording time in seconds"
                        ]
                    ]
                ],
                "RecordingStatus": [
                    "type": "string",
                    "enum": ["idle", "recording", "stopping"],
                    "description": "Current recording status"
                ],
                "APIError": [
                    "type": "object",
                    "required": ["code", "message"],
                    "properties": [
                        "code": [
                            "type": "string",
                            "description": "Error code identifier"
                        ],
                        "message": [
                            "type": "string",
                            "description": "Human-readable error message"
                        ],
                        "details": [
                            "type": "string",
                            "nullable": true,
                            "description": "Additional error details"
                        ]
                    ]
                ],
                "ErrorResponse": [
                    "type": "object",
                    "required": ["error"],
                    "properties": [
                        "error": [
                            "$ref": "#/components/schemas/APIError"
                        ]
                    ]
                ]
            ]
        ]
    }
    
    /// Generate Swagger UI HTML page
    private func generateSwaggerUIHTML(openAPISpec: [String: Any]) -> String {
        let specJSON: String
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: openAPISpec, options: [.prettyPrinted])
            specJSON = String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            logger.error("Failed to serialize OpenAPI spec: \(error)")
            specJSON = "{}"
        }
        
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>AudioCap API Documentation</title>
            <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui.css" />
            <style>
                html {
                    box-sizing: border-box;
                    overflow: -moz-scrollbars-vertical;
                    overflow-y: scroll;
                }
                *, *:before, *:after {
                    box-sizing: inherit;
                }
                body {
                    margin:0;
                    background: #fafafa;
                }
                .swagger-ui .topbar {
                    background-color: #1f2937;
                }
                .swagger-ui .topbar .download-url-wrapper {
                    display: none;
                }
            </style>
        </head>
        <body>
            <div id="swagger-ui"></div>
            <script src="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui-bundle.js"></script>
            <script src="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui-standalone-preset.js"></script>
            <script>
                window.onload = function() {
                    const ui = SwaggerUIBundle({
                        url: '',
                        spec: \(specJSON),
                        dom_id: '#swagger-ui',
                        deepLinking: true,
                        presets: [
                            SwaggerUIBundle.presets.apis,
                            SwaggerUIStandalonePreset
                        ],
                        plugins: [
                            SwaggerUIBundle.plugins.DownloadUrl
                        ],
                        layout: "StandaloneLayout",
                        validatorUrl: null,
                        tryItOutEnabled: true,
                        supportedSubmitMethods: ['get', 'post', 'put', 'delete', 'patch'],
                        onComplete: function() {
                            console.log('AudioCap API Documentation loaded');
                        }
                    });
                };
            </script>
        </body>
        </html>
        """
    }
}

/// Errors that can occur in the DocumentationHandler
enum DocumentationError: Error, LocalizedError {
    case specGenerationFailed(String)
    case htmlGenerationFailed(String)
    case internalError(String)
    
    var errorDescription: String? {
        switch self {
        case .specGenerationFailed(let message):
            return "Failed to generate OpenAPI specification: \(message)"
        case .htmlGenerationFailed(let message):
            return "Failed to generate HTML documentation: \(message)"
        case .internalError(let message):
            return "Internal error: \(message)"
        }
    }
    
    /// Convert to API error response
    var apiError: APIError {
        switch self {
        case .specGenerationFailed(let message):
            return APIError(
                code: "SPEC_GENERATION_FAILED",
                message: "Failed to generate API specification",
                details: message
            )
        case .htmlGenerationFailed(let message):
            return APIError(
                code: "HTML_GENERATION_FAILED",
                message: "Failed to generate documentation HTML",
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
        return 500 // Internal Server Error
    }
}