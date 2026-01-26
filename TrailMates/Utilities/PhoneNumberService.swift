//
//  PhoneNumberService.swift
//  TrailMates
//
//  Created as part of code cleanup on 2025-01-25.
//
//  Unified phone number service that consolidates all phone number operations.
//  Uses PhoneNumberKit for E.164 formatting and validation.
//

import Foundation
import PhoneNumberKit

/// Unified service for all phone number operations.
/// Provides formatting, validation, and normalization using PhoneNumberKit.
/// This class is thread-safe as PhoneNumberKit is designed to be used from any thread.
final class PhoneNumberService: Sendable {

    // MARK: - Singleton

    /// Shared instance - safe to access from any thread
    static let shared = PhoneNumberService()

    // MARK: - Types

    /// Format type for phone number output
    enum FormatType: Sendable {
        /// Human-readable display format (e.g., "+1 (555) 123-4567")
        case display
        /// E.164 format for database storage (e.g., "+15551234567")
        case storage
        /// Digits only, no formatting (e.g., "15551234567")
        case digitsOnly
    }

    // MARK: - Private Properties

    /// PhoneNumberKit instance - expensive to create, so we keep one instance.
    /// PhoneNumberKit is thread-safe by design, so we use nonisolated(unsafe).
    nonisolated(unsafe) private let phoneNumberKit = PhoneNumberKit()

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Formats a phone number according to the specified format type.
    /// - Parameters:
    ///   - phoneNumber: The phone number string to format
    ///   - formatType: The desired output format
    ///   - defaultRegion: The default region for parsing (default: "US")
    /// - Returns: The formatted phone number, or nil if the number is invalid
    func format(_ phoneNumber: String, for formatType: FormatType, defaultRegion: String = "US") -> String? {
        switch formatType {
        case .display:
            return formatForDisplay(phoneNumber, defaultRegion: defaultRegion)
        case .storage:
            return formatForStorage(phoneNumber, defaultRegion: defaultRegion)
        case .digitsOnly:
            return normalizeToDigits(phoneNumber)
        }
    }

    /// Validates if a phone number string is valid.
    /// - Parameters:
    ///   - phoneNumber: The phone number to validate
    ///   - defaultRegion: The default region for validation (default: "US")
    /// - Returns: True if the phone number is valid
    func validate(_ phoneNumber: String, defaultRegion: String = "US") -> Bool {
        return phoneNumberKit.isValidPhoneNumber(phoneNumber, withRegion: defaultRegion)
    }

    /// Cleanses and formats a single phone number to E.164 format.
    /// Only returns numbers that are mobile or fixed line types.
    /// - Parameters:
    ///   - phoneNumber: The phone number to cleanse
    ///   - defaultRegion: The default region for parsing (default: "US")
    /// - Returns: E.164 formatted string, or nil if invalid or not a valid phone type
    func cleanseSingleNumber(_ phoneNumber: String, defaultRegion: String = "US") -> String? {
        do {
            let parsedNumber = try phoneNumberKit.parse(phoneNumber, withRegion: defaultRegion)

            // Filter out non-mobile/fixed line numbers
            guard parsedNumber.type == .mobile ||
                  parsedNumber.type == .fixedLine ||
                  parsedNumber.type == .fixedOrMobile else {
                return nil
            }

            return phoneNumberKit.format(parsedNumber, toType: .e164)
        } catch {
            return nil
        }
    }

    /// Cleanses an array of phone numbers, removing duplicates and invalid numbers.
    /// - Parameters:
    ///   - phoneNumbers: Array of phone numbers to cleanse
    ///   - defaultRegion: The default region for parsing (default: "US")
    /// - Returns: Array of E.164 formatted strings
    func cleansePhoneNumbers(_ phoneNumbers: [String], defaultRegion: String = "US") -> [String] {
        let parsedNumbers = phoneNumberKit.parse(phoneNumbers, withRegion: defaultRegion, ignoreType: false)

        return Array(Set(parsedNumbers.compactMap { parsedNumber in
            // Filter out non-mobile/fixed line numbers
            guard parsedNumber.type == .mobile ||
                  parsedNumber.type == .fixedLine ||
                  parsedNumber.type == .fixedOrMobile else {
                return nil
            }

            return phoneNumberKit.format(parsedNumber, toType: .e164)
        }))
    }

    // MARK: - Private Methods

    /// Formats a phone number for human-readable display.
    private func formatForDisplay(_ phoneNumber: String, defaultRegion: String) -> String? {
        do {
            let parsedNumber = try phoneNumberKit.parse(phoneNumber, withRegion: defaultRegion)
            return phoneNumberKit.format(parsedNumber, toType: .national)
        } catch {
            return nil
        }
    }

    /// Formats a phone number to E.164 for database storage.
    private func formatForStorage(_ phoneNumber: String, defaultRegion: String) -> String? {
        do {
            let parsedNumber = try phoneNumberKit.parse(phoneNumber, withRegion: defaultRegion)
            return phoneNumberKit.format(parsedNumber, toType: .e164)
        } catch {
            return nil
        }
    }

    /// Strips all non-digit characters from a phone number.
    private func normalizeToDigits(_ phoneNumber: String) -> String? {
        let digits = phoneNumber.filter { $0.isNumber }
        return digits.isEmpty ? nil : digits
    }
}
