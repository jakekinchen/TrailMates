import Foundation
import CryptoKit
import PhoneNumberKit

/// Utility class for securely hashing phone numbers
class PhoneNumberHasher {
    // Shared instance
    static let shared = PhoneNumberHasher()
    
    // Private instance of PhoneNumberKit
    private let phoneNumberKit = PhoneNumberKit()
    
    private init() {}
    
    /// Hashes a phone number using SHA-256
    /// - Parameters:
    ///   - phoneNumber: The phone number to hash
    ///   - pepper: Optional server-side pepper for additional security
    /// - Returns: A SHA-256 hash of the normalized phone number
    func hashPhoneNumber(_ phoneNumber: String, pepper: String = "") -> String {
        // First normalize the phone number to E.164 format
        guard let normalized = PhoneNumberUtility.cleanseSingleNumber(phoneNumber) else {
            // If normalization fails, hash the raw input
            return hashValue(phoneNumber + pepper)
        }
        
        // Hash the normalized number with pepper
        return hashValue(normalized + pepper)
    }
    
    /// Internal method to create SHA-256 hash
    private func hashValue(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Batch hashes multiple phone numbers
    /// - Parameters:
    ///   - phoneNumbers: Array of phone numbers to hash
    ///   - pepper: Optional server-side pepper
    /// - Returns: Array of hashed phone numbers
    func hashPhoneNumbers(_ phoneNumbers: [String], pepper: String = "") -> [String] {
        return phoneNumbers.map { hashPhoneNumber($0, pepper: pepper) }
    }
} 