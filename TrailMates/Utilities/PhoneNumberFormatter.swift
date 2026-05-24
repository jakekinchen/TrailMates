//  PhoneNumberFormatter.swift
//  TrailMates
//
//  Created by Jake Kinchen on 10/8/24.

import Foundation
import SwiftUI

struct PhoneNumberFormatter: ViewModifier {
    @Binding var text: String

    func body(content: Content) -> some View {
        content
            .onChange(of: text) { oldValue, newValue in
                text = PhoneNumberFormatter.formatPhoneNumber(newValue)
            }
    }

    /// Formats a phone number for display, delegating to PhoneNumberService
    /// for complete numbers and falling back to simple digit grouping for
    /// partial input during as-you-type entry.
    static func formatPhoneNumber(_ number: String) -> String {
        let digitsOnly = number.filter { $0.isNumber }
        if digitsOnly.isEmpty { return "" }

        // For complete numbers, delegate to PhoneNumberService
        if let formatted = PhoneNumberService.shared.format(number, for: .display) {
            return formatted
        }

        // Fall back to simple digit grouping for partial input (as-you-type)
        let startsWithCountryCode = digitsOnly.prefix(1) == "1"

        if startsWithCountryCode {
            let localDigits = String(digitsOnly.dropFirst())
            switch localDigits.count {
            case 0:
                return "+1"
            case 1...3:
                return "+1 (\(localDigits)"
            case 4...6:
                let areaCode = String(localDigits.prefix(3))
                let rest = String(localDigits.dropFirst(3))
                return "+1 (\(areaCode)) \(rest)"
            default:
                let areaCode = String(localDigits.prefix(3))
                let middle = String(localDigits.dropFirst(3).prefix(3))
                let last = String(localDigits.dropFirst(6))
                return "+1 (\(areaCode)) \(middle)-\(last)"
            }
        } else {
            switch digitsOnly.count {
            case 1...3:
                return digitsOnly
            case 4...6:
                let areaCode = String(digitsOnly.prefix(3))
                let rest = String(digitsOnly.dropFirst(3))
                return "(\(areaCode)) \(rest)"
            default:
                let areaCode = String(digitsOnly.prefix(3))
                let middle = String(digitsOnly.dropFirst(3).prefix(3))
                let last = String(digitsOnly.dropFirst(6))
                return "(\(areaCode)) \(middle)-\(last)"
            }
        }
    }
}