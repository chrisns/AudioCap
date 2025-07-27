# Implementation Plan

- [x] 1. Refactor ServerConfiguration to remove `enabled` flag
  - Strip `enabled` property from the struct and all usages.
  - Update `load()` to ignore the obsolete key when decoding persisted data.
  - Adjust `validateAndSanitize()` and related logic to drop checks involving `enabled`.
  - _Requirements: R1 Acceptance 1, R1 Acceptance 2_

- [x] 1.1 Update configuration persistence tests
  - Modify any tests that rely on `enabled` to ensure they compile and pass.
  - _Requirements: R1 Acceptance 1_

- [x] 2. Implement fail-fast helper in HTTPServerManager
  - Add `startOrTerminate()` which wraps `start()` and, upon thrown error, logs and terminates with `exit(EXIT_FAILURE)`.
  - Extend `listener.stateUpdateHandler` to invoke termination if state transitions to `.failed` after startup.
  - _Requirements: R2 Acceptance 1, R2 Acceptance 3_

- [x] 2.1 Unit tests for start failure behaviour
  - Inject a mock configuration with an occupied port; assert that `start()` throws and `startOrTerminate()` terminates the process (use testable wrapper to simulate termination).
  - _Requirements: R2 Acceptance 1_

- [x] 3. Always start HTTP server at application launch
  - In `AudioCapApp.init`, spawn a `Task` that calls `httpServerManager.startOrTerminate()`.
  - Remove lazy start logic from `RootView`.
  - _Requirements: R1 Acceptance 1, R2 Acceptance 1_

- [x] 3.1 Update app termination handling
  - Ensure `NSApplication.shared.terminate` uses non-zero exit code when quitting due to server failure; adjust tests if necessary.
  - _Requirements: R2 Acceptance 1_

- [x] 4. Remove UI toggle for enabling/disabling server
  - Delete the “Enable HTTP Server” switch and related bindings from `APISettingsView`.
  - Remove conditional UI logic or disabled states in `RootView` that rely on `configuration.enabled`.
  - _Requirements: R1 Acceptance 2_

- [x] 4.1 Update UI tests and snapshots
  - Regenerate snapshots and fix failing tests that expect the toggle.
  - _Requirements: R1 Acceptance 2_

- [x] 5. Clean up configuration update paths
  - Refactor `HTTPServerManager.updateServerWithNewConfiguration()` to no longer stop/start based on `enabled` flag.
  - Ensure configuration edits (e.g., port change) restart the server as before.
  - _Requirements: R1 Acceptance 1_

- [x] 6. Integration test: Application quits on port conflict
  - Launch app in a test harness while a dummy server occupies the configured port; verify app exits with failure status and logs appropriate message.
  - _Requirements: R2 Acceptance 1, R2 Acceptance 2_ 