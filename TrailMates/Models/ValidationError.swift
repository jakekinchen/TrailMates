import Foundation

enum ValidationError: LocalizedError {
    case userNotAuthenticated(String)
    case invalidInput(String)
    case networkError(String)
    case serverError(String)
    case imageError(String)
    case invalidData(String)
    case missingRequiredFields(String)
    case emptyField(String)
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated(let message),
             .invalidInput(let message),
             .networkError(let message),
             .serverError(let message),
             .imageError(let message),
             .invalidData(let message),
             .missingRequiredFields(let message),
             .emptyField(let message):
            return message
        }
    }
} 
