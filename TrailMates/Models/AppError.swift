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
/// Use these errors for consistent error handling and user-facing messages.
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
        case .networkError:
            return "Connection Error"
        case .serverError:
            return "Server Error"
        case .invalidInput, .emptyField, .missingRequiredFields, .invalidData:
            return "Validation Error"
        case .notFound:
            return "Not Found"
        case .unauthorized:
            return "Access Denied"
        case .invalidImageUrl, .imageDownloadFailed, .imageProcessingFailed:
            return "Image Error"
        case .unknown:
            return "Error"
        }
    }

    /// Whether the user should be prompted to retry the operation
    var isRetryable: Bool {
        switch self {
        case .networkError, .serverError, .imageDownloadFailed:
            return true
        default:
            return false
        }
    }
}
