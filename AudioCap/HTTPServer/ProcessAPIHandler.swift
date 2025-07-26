//
//  ProcessAPIHandler.swift
//  AudioCap
//
//  API handler for process listing endpoint
//

import Foundation
import OSLog

/// Handler for process-related API endpoints
@MainActor
final class ProcessAPIHandler {
    
    private let logger = Logger(subsystem: "com.audiocap.app", category: String(describing: ProcessAPIHandler.self))
    private let processController: AudioProcessController
    
    init(processController: AudioProcessController) {
        self.processController = processController
        logger.debug("ProcessAPIHandler initialized")
    }
    
    /// Handle GET /processes endpoint
    /// Returns a JSON list of available audio processes
    func handleProcessList() async throws -> ProcessListResponse {
        logger.debug("Handling process list request")
        
        do {
            // Ensure process controller is active
            guard processController.processes.count >= 0 else {
                logger.error("Process controller returned invalid process list")
                throw APIHandlerError.internalError("Process enumeration failed")
            }
            
            let processes = processController.processes
            logger.debug("Found \(processes.count) processes")
            
            let processInfos = processes.compactMap { process -> AudioProcessInfo? in
                // Validate process data
                guard process.id > 0 else {
                    logger.warning("Skipping process with invalid ID: \(process.id)")
                    return nil
                }
                
                guard !process.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    logger.warning("Skipping process with empty name: ID \(process.id)")
                    return nil
                }
                
                return AudioProcessInfo(
                    id: String(process.id),
                    name: process.name,
                    hasAudioCapability: process.audioActive
                )
            }
            
            let response = ProcessListResponse(
                processes: processInfos,
                timestamp: Date()
            )
            
            logger.info("Successfully returned \(processInfos.count) valid processes in response")
            return response
            
        } catch let error as APIHandlerError {
            // Re-throw API handler errors as-is
            throw error
        } catch {
            logger.error("Failed to retrieve process list: \(error.localizedDescription, privacy: .public)")
            throw APIHandlerError.processListFailed(error.localizedDescription)
        }
    }
}

/// Errors that can occur in the ProcessAPIHandler
enum APIHandlerError: Error, LocalizedError {
    case processListFailed(String)
    case invalidRequest(String)
    case internalError(String)
    
    var errorDescription: String? {
        switch self {
        case .processListFailed(let message):
            return "Failed to retrieve process list: \(message)"
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        case .internalError(let message):
            return "Internal error: \(message)"
        }
    }
    
    /// Convert to API error response
    var apiError: APIError {
        switch self {
        case .processListFailed(let message):
            return APIError(
                code: "PROCESS_LIST_FAILED",
                message: "Failed to retrieve process list",
                details: message
            )
        case .invalidRequest(let message):
            return APIError(
                code: "INVALID_REQUEST",
                message: "Invalid request parameters",
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
        switch self {
        case .processListFailed:
            return 500
        case .invalidRequest:
            return 400
        case .internalError:
            return 500
        }
    }
}