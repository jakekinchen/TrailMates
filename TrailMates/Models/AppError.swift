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
/// // Converting from other errors
/// catch let error {
///     throw AppError.from(error)
/// }
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

    /// Converts any error to an AppError for consistent handling.
    ///
    /// Use this to wrap errors from Firebase, URLSession, or other sources
    /// into the unified AppError type for consistent user messaging.
    ///
    /// - Parameter error: The original error to convert
    /// - Returns: An appropriate AppError case
    static func from(_ error: Error) -> AppError {
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
            lastError = error

            // Check if error is retryable
            let appError = AppError.from(error)
            guard appError.isRetryable && attempt < maxAttempts else {
                throw appError
            }

            // Log retry attempt (only for debugging, not user-facing)
            #if DEBUG
            print("Retry attempt \(attempt)/\(maxAttempts) after error: \(error.localizedDescription)")
            #endif

            // Wait with exponential backoff before retrying
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            delay *= 2 // Exponential backoff
        }
    }

    throw lastError ?? AppError.unknown()
}
