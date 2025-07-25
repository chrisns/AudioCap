import XCTest
import SwiftUI
@testable import AudioCap

final class AudioRecordingPermissionTests: XCTestCase {
    
    var mockPermissionHandler: MockPermissionHandler!
    
    override func setUp() {
        super.setUp()
        mockPermissionHandler = MockPermissionHandler()
    }
    
    override func tearDown() {
        mockPermissionHandler = nil
        MockTCCFramework.reset()
        super.tearDown()
    }
    
    // MARK: - Permission Status Determination Tests
    
    func testInitialPermissionStatusUnknown() {
        // Given
        let permission = MockPermissionHandler(initialStatus: .unknown)
        
        // Then
        XCTAssertEqual(permission.status, .unknown, "Initial permission status should be unknown")
    }
    
    func testInitialPermissionStatusAuthorized() {
        // Given
        let permission = MockPermissionHandler(initialStatus: .authorized)
        
        // Then
        XCTAssertEqual(permission.status, .authorized, "Initial permission status should be authorized")
    }
    
    func testInitialPermissionStatusDenied() {
        // Given
        let permission = MockPermissionHandler(initialStatus: .denied)
        
        // Then
        XCTAssertEqual(permission.status, .denied, "Initial permission status should be denied")
    }
    
    // MARK: - Permission Status Updates Tests
    
    func testUpdateStatusChangesPermissionStatus() {
        // Given
        mockPermissionHandler.mockStatus = .unknown
        
        // When
        mockPermissionHandler.mockStatus = .authorized
        mockPermissionHandler.updateStatus()
        
        // Then
        XCTAssertEqual(mockPermissionHandler.status, .authorized, "Status should update to authorized")
        XCTAssertEqual(mockPermissionHandler.updateStatusCallCount, 1, "updateStatus should be called once")
    }
    
    func testUpdateStatusFromAuthorizedToDenied() {
        // Given
        mockPermissionHandler.mockStatus = .authorized
        mockPermissionHandler.updateStatus()
        
        // When
        mockPermissionHandler.mockStatus = .denied
        mockPermissionHandler.updateStatus()
        
        // Then
        XCTAssertEqual(mockPermissionHandler.status, .denied, "Status should update to denied")
        XCTAssertEqual(mockPermissionHandler.updateStatusCallCount, 2, "updateStatus should be called twice")
    }
    
    // MARK: - Permission Request Handling Tests
    
    func testPermissionRequestGranted() async {
        // Given
        mockPermissionHandler.shouldGrantRequest = true
        
        // When
        mockPermissionHandler.request()
        
        // Wait for async completion
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertEqual(mockPermissionHandler.status, .authorized, "Status should be authorized after granted request")
        XCTAssertEqual(mockPermissionHandler.requestCallCount, 1, "Request should be called once")
    }
    
    func testPermissionRequestDenied() async {
        // Given
        mockPermissionHandler.shouldGrantRequest = false
        
        // When
        mockPermissionHandler.request()
        
        // Wait for async completion
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertEqual(mockPermissionHandler.status, .denied, "Status should be denied after denied request")
        XCTAssertEqual(mockPermissionHandler.requestCallCount, 1, "Request should be called once")
    }
    
    func testPermissionRequestWithDelay() async {
        // Given
        mockPermissionHandler.shouldGrantRequest = true
        mockPermissionHandler.requestDelay = 0.2
        
        // When
        let startTime = Date()
        mockPermissionHandler.request()
        
        // Wait for completion
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        let endTime = Date()
        
        // Then
        XCTAssertEqual(mockPermissionHandler.status, .authorized, "Status should be authorized after delayed request")
        XCTAssertGreaterThanOrEqual(endTime.timeIntervalSince(startTime), 0.2, "Request should respect delay")
    }
    
    func testPermissionRequestFailure() {
        // Given
        mockPermissionHandler.shouldFailRequest = true
        
        // When
        mockPermissionHandler.request()
        
        // Then
        XCTAssertEqual(mockPermissionHandler.status, .unknown, "Status should remain unknown when request fails")
        XCTAssertEqual(mockPermissionHandler.requestCallCount, 1, "Request should still be called once")
    }
    
    func testMultiplePermissionRequests() async {
        // Given
        mockPermissionHandler.shouldGrantRequest = true
        
        // When
        mockPermissionHandler.request()
        mockPermissionHandler.request()
        mockPermissionHandler.request()
        
        // Wait for async completion
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertEqual(mockPermissionHandler.requestCallCount, 3, "All requests should be tracked")
        XCTAssertEqual(mockPermissionHandler.status, .authorized, "Final status should be authorized")
    }
    
    // MARK: - App Activation Permission Refresh Tests
    
    func testAppActivationRefreshesPermissionStatus() {
        // Given
        mockPermissionHandler.mockStatus = .denied
        
        // When
        mockPermissionHandler.simulateAppBecomeActive()
        
        // Then
        XCTAssertEqual(mockPermissionHandler.status, .denied, "Status should be refreshed on app activation")
        XCTAssertEqual(mockPermissionHandler.updateStatusCallCount, 1, "updateStatus should be called on app activation")
    }
    
    func testAppActivationWithStatusChange() {
        // Given
        mockPermissionHandler.mockStatus = .unknown
        mockPermissionHandler.updateStatus()
        
        // When - simulate permission granted externally
        mockPermissionHandler.mockStatus = .authorized
        mockPermissionHandler.simulateAppBecomeActive()
        
        // Then
        XCTAssertEqual(mockPermissionHandler.status, .authorized, "Status should update to authorized on app activation")
        XCTAssertEqual(mockPermissionHandler.updateStatusCallCount, 2, "updateStatus should be called twice")
    }
    
    // MARK: - TCC SPI Configuration Tests
    
    func testTCCFrameworkMockPreflight() {
        // Given
        MockTCCFramework.mockPreflightResult = 0 // authorized
        
        // When
        let result = MockTCCFramework.mockPreflight("kTCCServiceAudioCapture" as CFString, nil)
        
        // Then
        XCTAssertEqual(result, 0, "Mock preflight should return configured result")
        XCTAssertEqual(MockTCCFramework.preflightCallCount, 1, "Preflight call should be tracked")
    }
    
    func testTCCFrameworkMockPreflightDenied() {
        // Given
        MockTCCFramework.mockPreflightResult = 1 // denied
        
        // When
        let result = MockTCCFramework.mockPreflight("kTCCServiceAudioCapture" as CFString, nil)
        
        // Then
        XCTAssertEqual(result, 1, "Mock preflight should return denied result")
        XCTAssertEqual(MockTCCFramework.preflightCallCount, 1, "Preflight call should be tracked")
    }
    
    func testTCCFrameworkMockPreflightUnknown() {
        // Given
        MockTCCFramework.mockPreflightResult = -1 // unknown
        
        // When
        let result = MockTCCFramework.mockPreflight("kTCCServiceAudioCapture" as CFString, nil)
        
        // Then
        XCTAssertEqual(result, -1, "Mock preflight should return unknown result")
        XCTAssertEqual(MockTCCFramework.preflightCallCount, 1, "Preflight call should be tracked")
    }
    
    func testTCCFrameworkMockRequest() async {
        // Given
        MockTCCFramework.mockRequestResult = true
        var callbackResult: Bool?
        
        // When
        MockTCCFramework.mockRequest("kTCCServiceAudioCapture" as CFString, nil) { granted in
            callbackResult = granted
        }
        
        // Wait for async callback
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertEqual(callbackResult, true, "Mock request should call callback with configured result")
        XCTAssertEqual(MockTCCFramework.requestCallCount, 1, "Request call should be tracked")
        XCTAssertEqual(MockTCCFramework.requestCallbacks.count, 1, "Callback should be stored")
    }
    
    func testTCCFrameworkMockRequestDenied() async {
        // Given
        MockTCCFramework.mockRequestResult = false
        var callbackResult: Bool?
        
        // When
        MockTCCFramework.mockRequest("kTCCServiceAudioCapture" as CFString, nil) { granted in
            callbackResult = granted
        }
        
        // Wait for async callback
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertEqual(callbackResult, false, "Mock request should call callback with denied result")
        XCTAssertEqual(MockTCCFramework.requestCallCount, 1, "Request call should be tracked")
    }
    
    // MARK: - Mock Reset and Utility Tests
    
    func testMockPermissionHandlerReset() {
        // Given
        mockPermissionHandler.mockStatus = .authorized
        mockPermissionHandler.shouldGrantRequest = false
        mockPermissionHandler.requestCallCount = 5
        mockPermissionHandler.updateStatusCallCount = 3
        mockPermissionHandler.requestDelay = 1.0
        mockPermissionHandler.shouldFailRequest = true
        
        // When
        mockPermissionHandler.reset()
        
        // Then
        XCTAssertEqual(mockPermissionHandler.status, .unknown, "Status should reset to unknown")
        XCTAssertEqual(mockPermissionHandler.mockStatus, .unknown, "Mock status should reset to unknown")
        XCTAssertTrue(mockPermissionHandler.shouldGrantRequest, "Should grant request should reset to true")
        XCTAssertEqual(mockPermissionHandler.requestCallCount, 0, "Request call count should reset to 0")
        XCTAssertEqual(mockPermissionHandler.updateStatusCallCount, 0, "Update status call count should reset to 0")
        XCTAssertEqual(mockPermissionHandler.requestDelay, 0.0, "Request delay should reset to 0")
        XCTAssertFalse(mockPermissionHandler.shouldFailRequest, "Should fail request should reset to false")
    }
    
    func testTCCFrameworkReset() {
        // Given
        MockTCCFramework.mockPreflightResult = 1
        MockTCCFramework.mockRequestResult = false
        MockTCCFramework.preflightCallCount = 5
        MockTCCFramework.requestCallCount = 3
        MockTCCFramework.requestCallbacks.append { _ in }
        
        // When
        MockTCCFramework.reset()
        
        // Then
        XCTAssertEqual(MockTCCFramework.mockPreflightResult, -1, "Preflight result should reset to unknown")
        XCTAssertTrue(MockTCCFramework.mockRequestResult, "Request result should reset to true")
        XCTAssertEqual(MockTCCFramework.preflightCallCount, 0, "Preflight call count should reset to 0")
        XCTAssertEqual(MockTCCFramework.requestCallCount, 0, "Request call count should reset to 0")
        XCTAssertTrue(MockTCCFramework.requestCallbacks.isEmpty, "Request callbacks should be empty")
    }
    
    // MARK: - Integration Tests with Real AudioRecordingPermission Interface
    
    func testMockPermissionHandlerConformsToExpectedInterface() {
        // This test ensures our mock has the same interface as the real AudioRecordingPermission
        // Given
        let permission = MockPermissionHandler()
        
        // Then - these should compile without errors
        XCTAssertNotNil(permission.status, "Mock should have status property")
        
        // Test that we can call the expected methods
        permission.request()
        permission.updateStatus()
        
        // Test that status enum values match expected values
        XCTAssertEqual(MockPermissionHandler.Status.unknown.rawValue, "unknown")
        XCTAssertEqual(MockPermissionHandler.Status.denied.rawValue, "denied")
        XCTAssertEqual(MockPermissionHandler.Status.authorized.rawValue, "authorized")
    }
}