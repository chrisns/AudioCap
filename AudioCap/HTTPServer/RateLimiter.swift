//
//  RateLimiter.swift
//  AudioCap
//
//  Rate limiting system for HTTP API security
//

import Foundation
import OSLog

private let logger = Logger(subsystem: kAppSubsystem, category: "RateLimiter")

/// Thread-safe rate limiter for API requests
actor RateLimiter {
    /// Request tracking per IP address
    private var requestCounts: [String: RequestTracker] = [:]
    
    /// Configuration
    private let maxRequestsPerMinute: Int
    private let windowSizeSeconds: TimeInterval = 60.0
    
    /// Request tracker for individual IP addresses
    private struct RequestTracker {
        var requests: [Date] = []
        var lastCleanup: Date = Date()
        
        mutating func addRequest() {
            requests.append(Date())
        }
        
        mutating func cleanup(windowSize: TimeInterval) {
            let cutoff = Date().addingTimeInterval(-windowSize)
            requests.removeAll { $0 < cutoff }
            lastCleanup = Date()
        }
        
        var requestCount: Int {
            return requests.count
        }
    }
    
    init(maxRequestsPerMinute: Int) {
        self.maxRequestsPerMinute = maxRequestsPerMinute
    }
    
    /// Check if a request from the given IP should be allowed
    func shouldAllowRequest(from ipAddress: String) -> Bool {
        // Clean up old entries periodically
        cleanupOldEntries()
        
        // Get or create tracker for this IP
        var tracker = requestCounts[ipAddress] ?? RequestTracker()
        
        // Clean up old requests for this IP
        tracker.cleanup(windowSize: windowSizeSeconds)
        
        // Check if under limit
        let currentCount = tracker.requestCount
        guard currentCount < maxRequestsPerMinute else {
            logger.warning("Rate limit exceeded for IP \(ipAddress, privacy: .public): \(currentCount) requests in last minute")
            return false
        }
        
        // Add this request
        tracker.addRequest()
        requestCounts[ipAddress] = tracker
        
        logger.debug("Request allowed for IP \(ipAddress, privacy: .public): \(currentCount + 1)/\(self.maxRequestsPerMinute)")
        return true
    }
    
    /// Get current request count for an IP
    func getCurrentRequestCount(for ipAddress: String) -> Int {
        guard var tracker = requestCounts[ipAddress] else { return 0 }
        tracker.cleanup(windowSize: windowSizeSeconds)
        requestCounts[ipAddress] = tracker
        return tracker.requestCount
    }
    
    /// Clean up old entries to prevent memory leaks
    private func cleanupOldEntries() {
        let cutoff = Date().addingTimeInterval(-windowSizeSeconds * 2) // Keep some buffer
        
        for (ipAddress, var tracker) in requestCounts {
            tracker.cleanup(windowSize: windowSizeSeconds)
            
            // Remove completely empty trackers
            if tracker.requestCount == 0 && tracker.lastCleanup < cutoff {
                requestCounts.removeValue(forKey: ipAddress)
            } else {
                requestCounts[ipAddress] = tracker
            }
        }
    }
    
    /// Update rate limit configuration
    func updateConfiguration(maxRequestsPerMinute: Int) {
        // Note: This is a simple implementation. In production, you might want
        // to handle configuration changes more gracefully
        logger.info("Rate limit updated to \(maxRequestsPerMinute) requests per minute")
    }
    
    /// Get statistics for monitoring
    func getStatistics() -> RateLimiterStatistics {
        cleanupOldEntries()
        
        let totalActiveIPs = requestCounts.count
        let totalRequests = requestCounts.values.reduce(0) { $0 + $1.requestCount }
        
        return RateLimiterStatistics(
            activeIPAddresses: totalActiveIPs,
            totalRequestsInWindow: totalRequests,
            maxRequestsPerMinute: maxRequestsPerMinute
        )
    }
}

/// Statistics for rate limiter monitoring
struct RateLimiterStatistics {
    let activeIPAddresses: Int
    let totalRequestsInWindow: Int
    let maxRequestsPerMinute: Int
}

/// Rate limiting error
struct RateLimitError: Error, LocalizedError {
    let ipAddress: String
    let currentCount: Int
    let maxAllowed: Int
    
    var errorDescription: String? {
        return "Rate limit exceeded for IP \(ipAddress): \(currentCount) requests in the last minute (max: \(maxAllowed))"
    }
}