# Requirements Document

## Introduction

This feature adds a HTTP REST API interface to AudioCap that provides the same audio recording capabilities as the existing GUI. The API will allow external applications and scripts to control AudioCap programmatically, including listing available processes, starting/stopping recordings, and retrieving recording metadata. The API will include a self-documenting OpenAPI interface and be configurable through the existing GUI.

## Requirements

### Requirement 1

**User Story:** As a developer, I want to control AudioCap programmatically via HTTP API, so that I can integrate audio recording functionality into my own applications and scripts.

#### Acceptance Criteria

1. WHEN the HTTP API server is started THEN it SHALL listen on a configurable IP address and port (default 127.0.0.1:5742)
2. WHEN a GET request is made to `/processes` THEN the system SHALL return a JSON list of available audio processes with their IDs and names
3. WHEN a POST request is made to `/recording/start` with a process ID THEN the system SHALL start recording from that process and return recording metadata
4. WHEN a POST request is made to `/recording/stop` THEN the system SHALL stop the current recording and return final recording metadata including file path, duration, and channel count
5. WHEN the API is accessed THEN it SHALL provide an OpenAPI documentation interface at `/docs`

### Requirement 2

**User Story:** As a user, I want to configure the HTTP API server settings through the GUI, so that I can control when the API is available and on which port it runs.

#### Acceptance Criteria

1. WHEN I access the GUI settings THEN I SHALL be able to enable/disable the HTTP API server
2. WHEN I access the GUI settings THEN I SHALL be able to configure the listening port (default 5742)
3. WHEN I access the GUI settings THEN I SHALL be able to configure the listening IP address (default 127.0.0.1)
4. WHEN I change API server settings THEN the changes SHALL take effect immediately without requiring app restart
5. WHEN the API server is running THEN the GUI SHALL display the server status and endpoint URL

### Requirement 3

**User Story:** As a system administrator, I want to use curl commands to control AudioCap recordings, so that I can automate audio capture in scripts and CI/CD pipelines.

#### Acceptance Criteria

1. WHEN I execute `curl -X GET http://127.0.0.1:5742/processes` THEN I SHALL receive a JSON response with available processes
2. WHEN I execute `curl -X POST http://127.0.0.1:5742/recording/start -d '{"processId": "123"}'` THEN recording SHALL start and return recording session metadata
3. WHEN I execute `curl -X POST http://127.0.0.1:5742/recording/stop` THEN recording SHALL stop and return final file metadata including absolute path, duration, and channel count
4. WHEN I execute `curl -X GET http://127.0.0.1:5742/recording/status` THEN I SHALL receive current recording status information
5. WHEN API calls fail THEN appropriate HTTP status codes and error messages SHALL be returned

### Requirement 4

**User Story:** As a developer, I want the API responses to include comprehensive recording metadata, so that I can programmatically access file information and recording details.

#### Acceptance Criteria

1. WHEN a recording is started THEN the API SHALL return recording session ID, start time, and target process information
2. WHEN a recording is stopped THEN the API SHALL return absolute file path, recording duration in seconds, number of audio channels, sample rate, and file size
3. WHEN querying recording status THEN the API SHALL return current state (idle, recording), elapsed time if recording, and target process if applicable
4. WHEN an error occurs THEN the API SHALL return structured error responses with error codes and descriptive messages
5. WHEN listing processes THEN the API SHALL return process ID, name, and audio capability status for each available process

### Requirement 5

**User Story:** As a QA engineer, I want the existing test suite to include API testing, so that I can verify the HTTP interface works correctly alongside the GUI functionality.

#### Acceptance Criteria

1. WHEN running the test suite THEN it SHALL include tests that call the REST API endpoints
2. WHEN API tests run THEN they SHALL verify process listing functionality via HTTP
3. WHEN API tests run THEN they SHALL verify recording start/stop functionality via HTTP
4. WHEN API tests run THEN they SHALL verify error handling and edge cases via HTTP
5. WHEN API tests run THEN they SHALL verify that API responses match expected JSON schemas

### Requirement 6

**User Story:** As a future developer, I want the system architecture to ensure GUI and API feature parity, so that any new features added to the GUI are automatically available via the REST API.

#### Acceptance Criteria

1. WHEN new recording features are added to the GUI THEN they SHALL also be exposed via the REST API
2. WHEN the underlying recording engine is modified THEN both GUI and API SHALL have access to the same functionality
3. WHEN process selection capabilities are enhanced THEN both interfaces SHALL support the same process filtering and selection options
4. WHEN recording configuration options are added THEN they SHALL be configurable via both GUI and API
5. WHEN the system architecture is designed THEN it SHALL use shared business logic between GUI and API interfaces