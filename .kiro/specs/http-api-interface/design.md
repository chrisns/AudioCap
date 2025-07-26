# HTTP API Interface Design

## Overview

The HTTP API interface extends AudioCap's existing GUI functionality by providing a REST API that exposes the same audio recording capabilities programmatically. The design follows a shared business logic approach where both the GUI and API utilize the same underlying recording engine, ensuring feature parity and consistency.

The API server will be embedded within the existing AudioCap application, running as a background service that can be controlled through the GUI. This approach maintains the application's single-process architecture while adding network accessibility.

## Architecture

### High-Level Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GUI Client    │    │   HTTP Client   │    │   curl/scripts  │
│   (SwiftUI)     │    │  (External App) │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   HTTP Server   │
                    │   (Embedded)    │
                    └─────────────────┘
                                 │
                    ┌─────────────────┐
                    │ Shared Business │
                    │     Logic       │
                    └─────────────────┘
                                 │
                    ┌─────────────────┐
                    │  CoreAudio API  │
                    │ (ProcessTap)    │
                    └─────────────────┘
```

### Design Rationale

1. **Embedded Server**: The HTTP server runs within the main AudioCap process to avoid complexity of inter-process communication and maintain access to existing CoreAudio resources.

2. **Shared Business Logic**: Both GUI and API use the same underlying controllers and services, ensuring automatic feature parity as new capabilities are added.

3. **Asynchronous Design**: The API uses Swift's async/await pattern to handle potentially long-running operations like recording start/stop without blocking the HTTP server.

## Components and Interfaces

### HTTP Server Component

**HTTPServerManager**
- Manages the lifecycle of the embedded HTTP server
- Configurable IP address and port (default: 127.0.0.1:5742)
- Start/stop functionality controlled by GUI settings
- Thread-safe server state management

```swift
@Observable
class HTTPServerManager {
    var isRunning: Bool = false
    var configuration: ServerConfiguration
    
    func start() async throws
    func stop() async
    func updateConfiguration(_ config: ServerConfiguration)
}
```

### API Route Handlers

**ProcessAPIHandler**
- Handles `/processes` endpoint
- Integrates with existing `AudioProcessController`
- Returns JSON representation of available audio processes

**RecordingAPIHandler**
- Handles `/recording/*` endpoints
- Integrates with existing `ProcessTap` and recording logic
- Manages recording session state
- Provides recording metadata and status

**DocumentationHandler**
- Serves OpenAPI documentation at `/docs`
- Auto-generated from route definitions
- Interactive API explorer interface

### Shared Business Logic Integration

The API will reuse existing components:
- `AudioProcessController` for process enumeration
- `ProcessTap` for recording functionality
- `AudioRecordingPermission` for permission checks
- Existing error handling and logging patterns

### Configuration Management

**APIConfiguration**
- Extends existing app configuration
- Persistent storage of API server settings
- GUI integration for configuration changes
- Real-time configuration updates without restart

## Data Models

### API Request/Response Models

```swift
// Process listing
struct ProcessInfo: Codable {
    let id: String
    let name: String
    let hasAudioCapability: Bool
}

struct ProcessListResponse: Codable {
    let processes: [ProcessInfo]
    let timestamp: Date
}

// Recording operations
struct StartRecordingRequest: Codable {
    let processId: String
    let outputFormat: String? // Optional, defaults to existing format
}

struct RecordingSession: Codable {
    let sessionId: String
    let processId: String
    let processName: String
    let startTime: Date
    let status: RecordingStatus
}

struct RecordingMetadata: Codable {
    let sessionId: String
    let filePath: String
    let duration: TimeInterval
    let channelCount: Int
    let sampleRate: Double
    let fileSize: Int64
    let endTime: Date
}

struct RecordingStatusResponse: Codable {
    let status: RecordingStatus
    let currentSession: RecordingSession?
    let elapsedTime: TimeInterval?
}

enum RecordingStatus: String, Codable {
    case idle
    case recording
    case stopping
}

// Error responses
struct APIError: Codable {
    let code: String
    let message: String
    let details: String?
}
```

### Configuration Models

```swift
struct ServerConfiguration: Codable {
    var enabled: Bool = false
    var ipAddress: String = "127.0.0.1"
    var port: Int = 5742
    var enableCORS: Bool = true
}
```

## Error Handling

### HTTP Status Code Strategy

- **200 OK**: Successful operations
- **201 Created**: Recording started successfully
- **400 Bad Request**: Invalid request parameters
- **404 Not Found**: Process not found or invalid endpoint
- **409 Conflict**: Recording already in progress
- **500 Internal Server Error**: System errors (permissions, CoreAudio failures)
- **503 Service Unavailable**: Server not running or shutting down

### Error Response Format

All errors return consistent JSON structure:
```json
{
    "error": {
        "code": "PROCESS_NOT_FOUND",
        "message": "The specified process ID was not found",
        "details": "Process ID '12345' is not in the current process list"
    }
}
```

### Error Categories

1. **Validation Errors**: Invalid request format or parameters
2. **Permission Errors**: Audio recording permissions not granted
3. **State Errors**: Invalid operations (e.g., stopping when not recording)
4. **System Errors**: CoreAudio failures, file system issues
5. **Configuration Errors**: Invalid server configuration

## API Endpoints Specification

### GET /processes
Returns list of available audio processes.

**Response**: `ProcessListResponse`
**Errors**: 500 if process enumeration fails

### POST /recording/start
Starts recording from specified process.

**Request**: `StartRecordingRequest`
**Response**: `RecordingSession`
**Errors**: 400 (invalid process), 409 (already recording), 500 (system error)

### POST /recording/stop
Stops current recording.

**Response**: `RecordingMetadata`
**Errors**: 409 (not recording), 500 (system error)

### GET /recording/status
Returns current recording status.

**Response**: `RecordingStatusResponse`
**Errors**: 500 (system error)

### GET /docs
Serves OpenAPI documentation interface.

**Response**: HTML page with interactive API documentation
**Errors**: 500 (documentation generation error)

## Testing Strategy

### Unit Testing
- Mock HTTP server for API handler testing
- Isolated testing of request/response serialization
- Configuration management testing
- Error handling validation

### Integration Testing
- End-to-end API workflow testing
- GUI and API interaction testing
- Permission handling across both interfaces
- Configuration change propagation testing

### API Testing Framework
- Dedicated test suite using URLSession for HTTP calls
- JSON schema validation for all responses
- Error condition testing (invalid requests, permission failures)
- Concurrent access testing (GUI + API simultaneously)

### Test Data Management
- Mock process data for consistent testing
- Temporary file handling for recording tests
- Network isolation for reliable test execution

## Security Considerations

### Network Security
- Default binding to localhost (127.0.0.1) only
- Configurable IP binding with security warnings for non-localhost
- No authentication required for localhost access
- CORS headers configurable for web client access

### Permission Integration
- API respects existing audio recording permissions
- Permission status included in error responses
- Graceful handling of permission revocation during operation

### Input Validation
- Strict JSON schema validation for all requests
- Process ID validation against current process list
- Configuration parameter bounds checking
- Path traversal protection for file operations

## Performance Considerations

### Server Performance
- Lightweight HTTP server implementation
- Minimal memory footprint when idle
- Efficient JSON serialization using Codable
- Connection pooling for multiple concurrent clients

### Recording Performance
- No performance impact on existing recording functionality
- Shared recording engine prevents resource duplication
- Asynchronous API operations don't block recording

### Memory Management
- Proper cleanup of HTTP connections
- Recording buffer management shared with GUI
- Configuration caching to avoid repeated file I/O

## GUI Integration

### Settings Interface
New API configuration section in existing settings:
- Enable/disable API server toggle
- IP address configuration field
- Port number configuration field
- Server status indicator
- Current endpoint URL display

### Status Display
- API server running indicator in main interface
- Active API connections counter
- Integration with existing recording status display

### Real-time Updates
- Configuration changes apply immediately
- Server restart handling without app restart
- Status synchronization between GUI and API

## Implementation Notes

### Framework Selection
- Use Swift's built-in HTTP server capabilities or lightweight framework
- Leverage existing SwiftUI @Observable pattern for server state
- Integrate with existing OSLog logging system

### Threading Model
- HTTP server runs on background queue
- API handlers use MainActor for UI state access
- Recording operations maintain existing thread safety

### Backwards Compatibility
- No changes to existing GUI functionality
- Optional API server doesn't affect core app behavior
- Existing configuration and data formats preserved