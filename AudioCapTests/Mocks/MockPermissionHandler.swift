import SwiftUI
import Observation
import OSLog

/// Mock implementation of AudioRecordingPermission for testing purposes.
/// Provides configurable responses for permission status and request handling.
@Observable
final class MockPermissionHandler {
    private let logger = Logger(subsystem: kAppSubsystem, category: String(describing: MockPermissionHandler.self))

    enum Status: String {
        case unknown
        case denied
        case authorized
    }

    private(set) var status: Status = .unknown
    
    // Mock configuration properties
    var mockStatus: Status = .unknown {
        didSet {
            status = mockStatus
        }
    }
    
    var shouldGrantRequest: Bool = true
    var requestCallCount: Int = 0
    var updateStatusCallCount: Int = 0
    var requestDelay: TimeInterval = 0.0
    var shouldFailRequest: Bool = false
    
    // Callback tracking
    private var pendingRequestCallbacks: [(Bool) -> Void] = []
    
    init(initialStatus: Status = .unknown) {
        self.mockStatus = initialStatus
        self.status = initialStatus
    }
    
    func request() {
        logger.debug(#function)
        requestCallCount += 1
        
        if shouldFailRequest {
            logger.info("Mock request configured to fail")
            return
        }
        
        let granted = shouldGrantRequest
        
        if requestDelay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + requestDelay) { [weak self] in
                self?.completeRequest(granted: granted)
            }
        } else {
            completeRequest(granted: granted)
        }
    }
    
    private func completeRequest(granted: Bool) {
        logger.info("Mock request finished with result: \(granted, privacy: .public)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            
            if granted {
                self.status = .authorized
                self.mockStatus = .authorized
            } else {
                self.status = .denied
                self.mockStatus = .denied
            }
            
            // Execute any pending callbacks
            for callback in self.pendingRequestCallbacks {
                callback(granted)
            }
            self.pendingRequestCallbacks.removeAll()
        }
    }
    
    func updateStatus() {
        logger.debug(#function)
        updateStatusCallCount += 1
        status = mockStatus
    }
    
    // Test utility methods
    func reset() {
        status = .unknown
        mockStatus = .unknown
        shouldGrantRequest = true
        requestCallCount = 0
        updateStatusCallCount = 0
        requestDelay = 0.0
        shouldFailRequest = false
        pendingRequestCallbacks.removeAll()
    }
    
    func simulateAppBecomeActive() {
        updateStatus()
    }
    
    func addRequestCallback(_ callback: @escaping (Bool) -> Void) {
        pendingRequestCallbacks.append(callback)
    }
}

// MARK: - Mock TCC Framework Functions

/// Mock TCC framework functions for testing without actual system calls
class MockTCCFramework {
    static var mockPreflightResult: Int = -1 // -1 = unknown, 0 = authorized, 1 = denied
    static var mockRequestResult: Bool = true
    static var requestCallbacks: [(Bool) -> Void] = []
    static var preflightCallCount: Int = 0
    static var requestCallCount: Int = 0
    
    static func reset() {
        mockPreflightResult = -1
        mockRequestResult = true
        requestCallbacks.removeAll()
        preflightCallCount = 0
        requestCallCount = 0
    }
    
    static func mockPreflight(_ service: CFString, _ options: CFDictionary?) -> Int {
        preflightCallCount += 1
        return mockPreflightResult
    }
    
    static func mockRequest(_ service: CFString, _ options: CFDictionary?, _ callback: @escaping (Bool) -> Void) {
        requestCallCount += 1
        requestCallbacks.append(callback)
        
        // Simulate async callback
        DispatchQueue.main.async {
            callback(mockRequestResult)
        }
    }
}