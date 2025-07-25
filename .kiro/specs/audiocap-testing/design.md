# Design Document

## Overview

The AudioCap testing suite will provide comprehensive test coverage for a macOS audio recording application that uses CoreAudio process tap functionality. The design follows Swift testing best practices using XCTest framework, with a focus on unit tests, UI tests, integration tests, and mock objects to enable isolated testing of complex audio functionality.

## Architecture

### Test Target Structure

The testing suite will be organized into multiple test targets within the Xcode project:

1. **AudioCapTests** - Unit tests for core functionality
2. **AudioCapUITests** - UI automation tests  
3. **AudioCapIntegrationTests** - End-to-end integration tests

### Test Organization

Tests will be organized by functional area:

```
AudioCapTests/
├── Core/
│   ├── ProcessTapTests.swift
│   ├── ProcessTapRecorderTests.swift
│   └── CoreAudioUtilsTests.swift
├── UI/
│   ├── RootViewTests.swift
│   ├── ProcessSelectionViewTests.swift
│   ├── RecordingViewTests.swift
│   └── RecordingIndicatorTests.swift
├── Controllers/
│   ├── AudioProcessControllerTests.swift
│   └── AudioRecordingPermissionTests.swift
├── Mocks/
│   ├── MockAudioProcess.swift
│   ├── MockProcessTap.swift
│   └── MockPermissionHandler.swift
└── Utilities/
    ├── TestHelpers.swift
    └── AudioTestUtilities.swift
```

## Components and Interfaces

### Mock Objects

#### MockAudioProcess
```swift
class MockAudioProcess {
    static func createMockProcess(
        id: pid_t = 1234,
        name: String = "Test App",
        audioActive: Bool = true,
        bundleID: String? = "com.test.app"
    ) -> AudioProcess
}
```

#### MockProcessTap
```swift
class MockProcessTap: ProcessTap {
    var shouldFailActivation: Bool = false
    var shouldFailRecording: Bool = false
    var mockStreamDescription: AudioStreamBasicDescription?
}
```

#### MockPermissionHandler
```swift
class MockPermissionHandler: AudioRecordingPermission {
    var mockStatus: Status = .unknown
    var requestCallCount: Int = 0
}
```

### Test Utilities

#### AudioTestUtilities
```swift
class AudioTestUtilities {
    static func createTestAudioFile() -> URL
    static func createMockAudioStreamDescription() -> AudioStreamBasicDescription
    static func verifyAudioFileIntegrity(at url: URL) -> Bool
    static func cleanupTestFiles()
}
```

#### TestHelpers
```swift
class TestHelpers {
    static func waitForAsyncOperation<T>(
        timeout: TimeInterval = 5.0,
        operation: @escaping () async throws -> T
    ) async throws -> T
    
    static func createTemporaryDirectory() -> URL
    static func mockRunningApplications() -> [NSRunningApplication]
}
```

### Core Component Tests

#### ProcessTap Testing Strategy
- Use dependency injection to provide mock CoreAudio functions
- Test activation/deactivation lifecycle
- Verify proper resource cleanup
- Test error handling scenarios
- Mock aggregate device creation

#### ProcessTapRecorder Testing Strategy  
- Mock AVAudioFile operations
- Test recording start/stop lifecycle
- Verify file creation and writing
- Test concurrent recording prevention
- Mock audio buffer processing

#### CoreAudioUtils Testing Strategy
- Mock AudioObjectID property reading
- Test property address construction
- Verify error handling for invalid objects
- Test data type conversions

### UI Component Tests

#### SwiftUI Testing Approach
Using ViewInspector framework for SwiftUI component testing:

```swift
import ViewInspector
import SwiftUI

extension RootView: Inspectable { }
extension ProcessSelectionView: Inspectable { }
extension RecordingView: Inspectable { }
```

#### State Management Testing
- Test @Observable object state changes
- Verify UI updates based on state
- Test user interaction handling
- Mock external dependencies

### Permission System Tests

#### TCC Framework Mocking
```swift
class MockTCCFramework {
    static var mockPreflightResult: Int = 0
    static var mockRequestResult: Bool = true
    static var requestCallbacks: [(Bool) -> Void] = []
}
```

## Data Models

### Test Data Structures

#### TestAudioProcess
```swift
struct TestAudioProcess {
    let process: AudioProcess
    let expectedIcon: NSImage
    let expectedGrouping: AudioProcess.Kind
}
```

#### TestRecordingSession
```swift
struct TestRecordingSession {
    let process: AudioProcess
    let expectedFileURL: URL
    let duration: TimeInterval
    let expectedFormat: AudioStreamBasicDescription
}
```

### Test Configuration

#### TestConfiguration
```swift
struct TestConfiguration {
    static let testTimeout: TimeInterval = 10.0
    static let shortTimeout: TimeInterval = 2.0
    static let testAudioDuration: TimeInterval = 1.0
    static let mockProcessCount: Int = 5
}
```

## Error Handling

### Test Error Categories

1. **Setup Errors** - Test environment preparation failures
2. **Mock Errors** - Mock object configuration issues  
3. **Assertion Errors** - Test expectation failures
4. **Timeout Errors** - Async operation timeouts
5. **Resource Errors** - File system or audio resource issues

### Error Handling Strategy

```swift
enum TestError: Error, LocalizedError {
    case setupFailed(String)
    case mockConfigurationFailed(String)
    case assertionFailed(String)
    case timeoutExceeded(TimeInterval)
    case resourceUnavailable(String)
    
    var errorDescription: String? {
        switch self {
        case .setupFailed(let message): return "Test setup failed: \(message)"
        case .mockConfigurationFailed(let message): return "Mock configuration failed: \(message)"
        case .assertionFailed(let message): return "Assertion failed: \(message)"
        case .timeoutExceeded(let timeout): return "Operation timed out after \(timeout) seconds"
        case .resourceUnavailable(let resource): return "Resource unavailable: \(resource)"
        }
    }
}
```

## Testing Strategy

### Unit Test Approach
- Test individual components in isolation
- Use dependency injection for external dependencies
- Mock all CoreAudio and system interactions
- Focus on business logic and state management
- Achieve >90% code coverage for core components

### Integration Test Approach  
- Test component interactions
- Use real file system operations with temporary directories
- Mock only system-level audio operations
- Verify end-to-end workflows
- Test error propagation between components

### UI Test Approach
- Use XCUITest for user interaction simulation
- Test accessibility and VoiceOver compatibility
- Verify visual state changes
- Test keyboard navigation
- Mock backend services for predictable UI states

### Performance Test Approach
- Memory leak detection using XCTMemoryMetric
- CPU usage monitoring during recording
- File I/O performance measurement
- Concurrent operation stress testing
- Resource cleanup verification

## Test Execution Strategy

### Continuous Integration
- Run unit tests on every commit
- Run integration tests on pull requests
- Run UI tests on release candidates
- Generate code coverage reports
- Fail builds on test failures OR warnings
- Enforce zero-warning policy - treat warnings as build failures

### Local Development
- Fast unit test execution (<30 seconds)
- Selective test running during development
- Test debugging support with breakpoints
- Mock data generation for rapid iteration
- Zero-warning enforcement during development
- Immediate warning resolution required before task completion

### Test Data Management
- Temporary file cleanup after each test
- Mock data reset between test cases
- Isolated test environments
- Deterministic test execution order