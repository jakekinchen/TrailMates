//
//  AppError.swift
//  TrailMates
//
//  Created as part of code cleanup on 2025-01-25.
//
//  Unified error types for the TrailMates application.
//  Provides consistent error handling across all layers.
//

import Foundation
import FirebaseFirestore

/// Unified error type for the TrailMates application.
///
/// Use `AppError` for all error handling to ensure consistent user-facing messages
/// and enable proper retry logic for recoverable errors.
///
/// ## Usage
/// ```swift
/// // Throwing typed errors
/// throw AppError.notAuthenticated()
///
/// // Converting from other errors (in async/throwing contexts)
/// catch let error {
///     throw try AppError.from(error)
/// }
///
/// // Converting from other errors (in non-throwing contexts like callbacks)
/// let appError = AppError.classify(error)
///
/// // Checking if retry is appropriate
/// if error.isRetryable {
///     await retry(operation)
/// }
/// ```
///
/// ## Error Categories
/// - **Authentication**: User session and credential issues
/// - **Network**: Connection and server communication failures
/// - **Validation**: Input and data format issues
/// - **Resource**: Missing or inaccessible data
/// - **Image**: Profile image operations
enum AppError: LocalizedError {

    // MARK: - Authentication Errors

    /// User is not authenticated or session expired
    case notAuthenticated(String? = nil)
    /// Authentication failed (wrong credentials, etc.)
    case authenticationFailed(String? = nil)

    // MARK: - Network Errors

    /// Network request failed (no connection, timeout, etc.)
    case networkError(String? = nil)
    /// Server returned an error response
    case serverError(String? = nil)
    /// Operation timed out
    case timeout(String? = nil)

    // MARK: - Validation Errors

    /// Input validation failed
    case invalidInput(String)
    /// Required field is empty
    case emptyField(String)
    /// Required fields are missing
    case missingRequiredFields(String)
    /// Data format is invalid
    case invalidData(String)

    // MARK: - Resource Errors

    /// Requested resource was not found
    case notFound(String)
    /// User is not authorized to access this resource
    case unauthorized(String? = nil)
    /// Resource already exists (e.g., duplicate user)
    case alreadyExists(String)

    // MARK: - Image Errors

    /// Image URL is invalid
    case invalidImageUrl(String? = nil)
    /// Failed to download image
    case imageDownloadFailed(String? = nil)
    /// Image processing failed
    case imageProcessingFailed(String? = nil)

    // MARK: - General Errors

    /// An unknown error occurred
    case unknown(Error? = nil)

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        // Authentication
        case .notAuthenticated(let message):
            return message ?? "You are not signed in. Please sign in to continue."
        case .authenticationFailed(let message):
            return message ?? "Authentication failed. Please try again."

        // Network
        case .networkError(let message):
            return message ?? "A network error occurred. Please check your connection."
        case .serverError(let message):
            return message ?? "A server error occurred. Please try again later."
        case .timeout(let message):
            return message ?? "The operation timed out. Please try again."

        // Validation
        case .invalidInput(let message):
            return message
        case .emptyField(let field):
            return "\(field) cannot be empty."
        case .missingRequiredFields(let message):
            return message
        case .invalidData(let message):
            return message

        // Resource
        case .notFound(let resource):
            return "\(resource) was not found."
        case .unauthorized(let message):
            return message ?? "You are not authorized to perform this action."
        case .alreadyExists(let resource):
            return "\(resource) already exists."

        // Image
        case .invalidImageUrl(let message):
            return message ?? "Invalid image URL."
        case .imageDownloadFailed(let message):
            return message ?? "Failed to download image."
        case .imageProcessingFailed(let message):
            return message ?? "Failed to process image."

        // General
        case .unknown(let error):
            return error?.localizedDescription ?? "An unexpected error occurred."
        }
    }

    /// A user-friendly title for the error suitable for alert titles
    var title: String {
        switch self {
        case .notAuthenticated, .authenticationFailed:
            return "Authentication Error"
        case .networkError, .timeout:
            return "Connection Error"
        case .serverError:
            return "Server Error"
        case .invalidInput, .emptyField, .missingRequiredFields, .invalidData:
            return "Validation Error"
        case .notFound:
            return "Not Found"
        case .unauthorized:
            return "Access Denied"
        case .alreadyExists:
            return "Already Exists"
        case .invalidImageUrl, .imageDownloadFailed, .imageProcessingFailed:
            return "Image Error"
        case .unknown:
            return "Error"
        }
    }

    /// Whether the user should be prompted to retry the operation
    var isRetryable: Bool {
        switch self {
        case .networkError, .serverError, .timeout, .imageDownloadFailed:
            return true
        default:
            return false
        }
    }

    /// Suggested number of retry attempts for this error type
    var suggestedRetryCount: Int {
        switch self {
        case .networkError, .timeout:
            return 3
        case .serverError:
            return 2
        case .imageDownloadFailed:
            return 2
        default:
            return 0
        }
    }

    // MARK: - Error Conversion

    /// Converts any error to an AppError, re-throwing `CancellationError` so that
    /// Swift Concurrency cancellation propagates correctly instead of being wrapped.
    ///
    /// Use this in async/throwing contexts (e.g., inside `withRetry`, provider methods
    /// that `throw`). For non-throwing contexts like completion-handler callbacks,
    /// use `classify(_:)` instead.
    ///
    /// Classifies Firestore errors into appropriate AppError cases so that transient
    /// errors (unavailable, deadline-exceeded, aborted) are marked retryable.
    ///
    /// - Parameter error: The original error to convert
    /// - Returns: An appropriate AppError case
    /// - Throws: Re-throws `CancellationError` to preserve cancellation semantics
    static func from(_ error: Error) throws -> AppError {
        // Let cancellation propagate -- never wrap it
        if error is CancellationError {
            throw error
        }

        return classify(error)
    }

    /// Converts any error to an AppError without throwing.
    ///
    /// Use this in non-throwing contexts such as completion-handler callbacks,
    /// snapshot listeners, or logging-only catch blocks where CancellationError
    /// is not expected.
    ///
    /// - Parameter error: The original error to convert
    /// - Returns: An appropriate AppError case
    static func classify(_ error: Error) -> AppError {
        // Already an AppError
        if let appError = error as? AppError {
            return appError
        }

        // Check for common error patterns
        let nsError = error as NSError

        // Network errors (URLSession, etc.)
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorNetworkConnectionLost:
                return .networkError("No internet connection. Please check your network settings.")
            case NSURLErrorTimedOut:
                return .timeout()
            case NSURLErrorCannotFindHost,
                 NSURLErrorCannotConnectToHost:
                return .serverError("Unable to reach the server. Please try again later.")
            default:
                return .networkError(error.localizedDescription)
            }
        }

        // Firebase Auth errors
        if nsError.domain == "FIRAuthErrorDomain" {
            return .authenticationFailed(error.localizedDescription)
        }

        // Firestore errors
        if nsError.domain == FirestoreErrorDomain {
            if let code = FirestoreErrorCode.Code(rawValue: nsError.code) {
                switch code {
                case .permissionDenied:
                    return .unauthorized("You do not have permission to perform this operation.")
                case .notFound:
                    return .notFound("Requested resource")
                case .unavailable:
                    return .networkError("The service is temporarily unavailable. Please try again.")
                case .deadlineExceeded:
                    return .timeout("The operation timed out. Please try again.")
                case .alreadyExists:
                    return .alreadyExists("Resource")
                case .unauthenticated:
                    return .notAuthenticated("Your session has expired. Please sign in again.")
                case .resourceExhausted:
                    return .serverError("Too many requests. Please wait a moment and try again.")
                case .aborted:
                    // Transaction aborted -- retryable
                    return .serverError("The operation was interrupted. Please try again.")
                case .cancelled:
                    // Firestore-level cancellation -- treat as a retryable network issue
                    return .networkError("The request was cancelled. Please try again.")
                default:
                    return .unknown(error)
                }
            }
        }

        // Default to unknown
        return .unknown(error)
    }
}

// MARK: - Retry Helper

/// Executes an async operation with automatic retry for recoverable errors.
///
/// This function implements exponential backoff for retrying network operations
/// that fail due to temporary issues like network connectivity or server errors.
///
/// - Parameters:
///   - maxAttempts: Maximum number of attempts (default: 3)
///   - initialDelay: Initial delay between retries in seconds (default: 1.0)
///   - operation: The async operation to execute
/// - Returns: The result of the successful operation
/// - Throws: The last error if all attempts fail
func withRetry<T>(
    maxAttempts: Int = 3,
    initialDelay: TimeInterval = 1.0,
    operation: () async throws -> T
) async throws -> T {
    var lastError: Error?
    var delay = initialDelay

    for attempt in 1...maxAttempts {
        do {
            return try await operation()
        } catch let error {
            // Let cancellation propagate immediately -- never retry a cancelled task
            if error is CancellationError {
                throw error
            }

            lastError = error

            // Check if error is retryable
            let appError = try AppError.from(error)
            guard appError.isRetryable && attempt < maxAttempts else {
                throw appError
            }

            // Log retry attempt (only for debugging, not user-facing)
            #if DEBUG
            print("Retry attempt \(attempt)/\(maxAttempts) after error: \(error.localizedDescription)")
            #endif

            // Check for cancellation before retrying
            try Task.checkCancellation()

            // Wait with exponential backoff before retrying
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            delay *= 2 // Exponential backoff
        }
    }

    throw lastError ?? AppError.unknown()
}
