import Foundation
import PhoneNumberKit

class PhoneNumberUtility {
    // Shared instance for better performance
    static let shared = PhoneNumberUtility()
    
    // Private instance of PhoneNumberKit - expensive to create, so we keep one instance
    private let phoneNumberKit = PhoneNumberKit()
    
    private init() {} // Enforce singleton pattern
    
    /// Cleanses an array of phone numbers, removing duplicates and invalid numbers
    /// Returns array of E.164 formatted strings
    static func cleansePhoneNumbers(_ phoneNumbers: [String], defaultRegion: String = "US") -> [String] {
        // Use the shared instance's phoneNumberKit for batch processing
        let parsedNumbers = shared.phoneNumberKit.parse(phoneNumbers, withRegion: defaultRegion, ignoreType: false)
        
        // Convert to Set to remove duplicates, then format to E.164
        return Array(Set(parsedNumbers.compactMap { parsedNumber in
            // Filter out non-mobile/fixed line numbers
            guard parsedNumber.type == .mobile || 
                  parsedNumber.type == .fixedLine || 
                  parsedNumber.type == .fixedOrMobile else {
                return nil
            }
            
            // Format to E.164
            return shared.phoneNumberKit.format(parsedNumber, toType: .e164)
        }))
    }
    
    /// Attempts to parse and format a single phone number
    /// Returns nil if the number is invalid or not a mobile/fixed line
    static func cleanseSingleNumber(_ phoneNumber: String, defaultRegion: String = "US") -> String? {
        do {
            let parsedNumber = try shared.phoneNumberKit.parse(phoneNumber, withRegion: defaultRegion)
            
            // Filter out non-mobile/fixed line numbers
            guard parsedNumber.type == .mobile || 
                  parsedNumber.type == .fixedLine || 
                  parsedNumber.type == .fixedOrMobile else {
                return nil
            }
            
            // Format to E.164
            return shared.phoneNumberKit.format(parsedNumber, toType: .e164)
        } catch {
            return nil
        }
    }
    
    /// Validates if a phone number string is valid
    static func isValidPhoneNumber(_ phoneNumber: String, defaultRegion: String = "US") -> Bool {
        return shared.phoneNumberKit.isValidPhoneNumber(phoneNumber, withRegion: defaultRegion)
    }
} 