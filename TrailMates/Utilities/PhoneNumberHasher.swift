//
//  PhoneNumberHasher.swift
//  TrailMates
//
//  Secure phone number hashing utility using SHA-256.
//  Uses PhoneNumberService for E.164 normalization before hashing.
//
//  ## Why Hash Phone Numbers?
//  Phone numbers are used for contact matching (finding friends who are already
//  on the platform). Rather than storing raw phone numbers from contacts,
//  we hash them to protect user privacy. The server stores hashed phone numbers
//  from registered users, and clients can compare hashed contact numbers to
//  find matches without exposing the actual numbers.
//

import Foundation
import CryptoKit

/// Utility class for securely hashing phone numbers.
///
/// ## Hashing Algorithm
/// 1. **Normalize**: Convert phone number to E.164 format (e.g., "+15551234567")
///    to ensure consistent hashing regardless of input format
/// 2. **Pepper**: Optionally append a server-side pepper for additional security
/// 3. **Hash**: Apply SHA-256 to produce a 64-character hex string
///
/// ## Security Considerations
/// - Phone numbers have low entropy (~10 billion combinations), making them
///   vulnerable to rainbow table attacks. Use a pepper in production.
/// - E.164 normalization ensures "(555) 123-4567" and "+1 555-123-4567"
///   produce the same hash.
///
/// This class is thread-safe as it only performs stateless hashing operations.
final class PhoneNumberHasher: Sendable {
    /// Shared instance - safe to access from any thread
    static let shared = PhoneNumberHasher()

    private init() {}

    /// Hashes a phone number using SHA-256.
    ///
    /// The hashing process:
    /// 1. Normalize the phone number to E.164 format for consistency
    /// 2. Append the pepper (if provided) for additional security
    /// 3. Compute SHA-256 hash and return as lowercase hex string
    ///
    /// - Parameters:
    ///   - phoneNumber: The phone number to hash (any format accepted)
    ///   - pepper: Optional server-side pepper for additional security
    /// - Returns: A 64-character lowercase hex SHA-256 hash
    func hashPhoneNumber(_ phoneNumber: String, pepper: String = "") -> String {
        // Normalize to E.164 format to ensure consistent hashing.
        // E.g., "(555) 123-4567" and "+1 555-123-4567" both become "+15551234567"
        guard let normalized = PhoneNumberService.shared.cleanseSingleNumber(phoneNumber) else {
            // If normalization fails (invalid number), hash the raw input.
            // This maintains consistent behavior but may not match server hashes.
            return hashValue(phoneNumber + pepper)
        }

        // Hash the normalized number concatenated with pepper.
        // The pepper adds protection against pre-computed rainbow tables.
        return hashValue(normalized + pepper)
    }

    /// Creates a SHA-256 hash of the input string.
    ///
    /// - Parameter input: The string to hash (typically normalized phone + pepper)
    /// - Returns: 64-character lowercase hexadecimal representation of the hash
    private func hashValue(_ input: String) -> String {
        // Convert string to UTF-8 bytes for hashing
        let inputData = Data(input.utf8)

        // Compute SHA-256 hash using Apple's CryptoKit
        let hashed = SHA256.hash(data: inputData)

        // Convert each byte to 2-character hex string and join
        // e.g., [0xAB, 0xCD] -> "abcd"
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Batch hashes multiple phone numbers.
    /// - Parameters:
    ///   - phoneNumbers: Array of phone numbers to hash
    ///   - pepper: Optional server-side pepper
    /// - Returns: Array of hashed phone numbers
    func hashPhoneNumbers(_ phoneNumbers: [String], pepper: String = "") -> [String] {
        return phoneNumbers.map { hashPhoneNumber($0, pepper: pepper) }
    }
} 