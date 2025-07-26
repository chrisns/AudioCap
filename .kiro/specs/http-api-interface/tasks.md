# Implementation Plan

- [x] 1. Create HTTP server foundation and configuration models
  - Create `ServerConfiguration` struct with Codable conformance for API settings
  - Create `HTTPServerManager` class with @Observable for server lifecycle management
  - Implement basic start/stop server functionality with async/await pattern
  - Add configuration persistence using UserDefaults or similar
  - _Requirements: 2.1, 2.2, 2.3, 2.4_

- [x] 2. Implement API data models and JSON serialization
  - Create `ProcessInfo`, `ProcessListResponse` structs with Codable conformance
  - Create `StartRecordingRequest`, `RecordingSession`, `RecordingMetadata` structs
  - Create `RecordingStatusResponse` and `RecordingStatus` enum
  - Create `APIError` struct for consistent error responses
  - Write unit tests for all data model serialization/deserialization
  - _Requirements: 1.2, 4.1, 4.2, 4.3, 4.4_

- [x] 3. Create process listing API endpoint handler
  - Implement `ProcessAPIHandler` class that integrates with existing `AudioProcessController`
  - Create `/processes` endpoint that returns JSON list of available processes
  - Add process ID, name, and audio capability information to responses
  - Handle errors and return appropriate HTTP status codes
  - Write unit tests for process listing functionality
  - _Requirements: 1.2, 3.1, 4.4_

- [x] 4. Implement recording control API endpoints
  - Create `RecordingAPIHandler` class that integrates with existing `ProcessTap`
  - Implement `/recording/start` POST endpoint with process ID validation
  - Implement `/recording/stop` POST endpoint with metadata response
  - Implement `/recording/status` GET endpoint for current recording state
  - Add proper error handling for invalid states and system errors
  - _Requirements: 1.3, 1.4, 3.2, 3.3, 4.1, 4.2, 4.3_

- [x] 5. Create OpenAPI documentation endpoint
  - Implement `DocumentationHandler` for `/docs` endpoint
  - Generate OpenAPI specification from route definitions
  - Create interactive API documentation interface
  - Serve HTML page with API explorer functionality
  - _Requirements: 1.5_

- [x] 6. Integrate HTTP server with main application
  - Add HTTP server initialization to main app lifecycle
  - Integrate server state with existing SwiftUI @Observable pattern
  - Ensure proper cleanup on app termination
  - Add OSLog integration for consistent logging
  - Handle server startup errors gracefully
  - _Requirements: 1.1, 2.5_

- [x] 7. Create GUI configuration interface
  - Add API settings section to existing settings view
  - Implement enable/disable toggle for HTTP server
  - Add IP address and port configuration fields
  - Display server status and current endpoint URL
  - Implement real-time configuration updates without app restart
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

- [x] 8. Implement comprehensive error handling
  - Add HTTP status code mapping for all error conditions
  - Implement structured error responses with codes and messages
  - Handle permission errors, validation errors, and system errors
  - Add proper error logging with OSLog
  - Test error scenarios and edge cases
  - _Requirements: 3.5, 4.4_

- [x] 9. Create API integration tests
  - Write test suite using URLSession for HTTP endpoint testing
  - Test process listing via HTTP requests
  - Test recording start/stop workflow via API calls
  - Verify JSON response schemas match expected formats
  - Test error conditions and HTTP status codes
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [x] 10. Add concurrent access testing and validation
  - Test simultaneous GUI and API usage scenarios
  - Verify recording state synchronization between interfaces
  - Test multiple concurrent API clients
  - Validate thread safety of shared recording engine
  - Ensure no resource conflicts between GUI and API
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

- [x] 11. Implement security and input validation
  - Add JSON schema validation for all API requests
  - Implement process ID validation against current process list
  - Add configuration parameter bounds checking
  - Implement localhost-only binding by default with security warnings
  - Add CORS header support for web client access
  - _Requirements: 1.1, 3.2, 3.5_

- [x] 12. Final integration and testing
  - Verify all endpoints work with curl commands as specified
  - Test complete workflow: server start, process list, record start/stop
  - Validate metadata responses include all required fields
  - Ensure GUI and API feature parity is maintained
  - Run full test suite and verify all tests pass
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 4.1, 4.2, 4.3, 6.1, 6.2, 6.3, 6.4, 6.5_