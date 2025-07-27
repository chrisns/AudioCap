# Requirements Document

## Introduction

The AudioCap application currently provides an embedded HTTP server that exposes APIs for controlling recording processes and fetching captured audio. This feature must become a **non-optional core service**: the HTTP server shall always be enabled at runtime and the application shall immediately terminate if the server cannot start (e.g., because the configured port is unavailable or insufficient permissions). This change removes any user-facing setting that disables the HTTP server and hardens startup behaviour to guarantee predictable API availability.

## Requirements

### Requirement 1 – HTTP server always enabled

**User Story:** As a user, I want the embedded HTTP server to be always enabled, so that remote integrations work without additional configuration.

#### Acceptance Criteria

1. WHEN the application starts THEN the system SHALL start the HTTP server automatically without requiring any user action.
2. IF any configuration flag or user preference attempts to disable the HTTP server THEN the system SHALL ignore that flag and still start the server.

### Requirement 2 – Fail-fast on server startup error

**User Story:** As a system administrator, I want the application to quit with a clear error if the HTTP server cannot start, so that I can resolve port conflicts or permission issues immediately.

#### Acceptance Criteria

1. WHEN the HTTP server fails to bind to the configured port THEN the system SHALL log a critical error message and terminate the application with a non-zero exit code.
2. WHEN the HTTP server cannot start due to insufficient privileges (e.g., port below 1024 without elevated rights) THEN the system SHALL log a descriptive error and terminate the application.
3. WHEN the HTTP server terminates unexpectedly during runtime THEN the system SHALL log the cause and terminate the application. 