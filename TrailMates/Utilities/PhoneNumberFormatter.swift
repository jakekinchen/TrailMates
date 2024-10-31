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

    // Function to format the phone number based on the number of digits
    static func formatPhoneNumber(_ number: String) -> String {
        let digitsOnly = number.filter { $0.isNumber }
        var formattedNumber: String

        if digitsOnly.isEmpty {
            return ""
        }

        // If the number starts with '1', assume country code
        if digitsOnly.prefix(1) == "1" {
            switch digitsOnly.count {
            case 1:
                formattedNumber = "+1"
            case 2...4:
                let areaCode = String(digitsOnly.suffix(from: digitsOnly.index(digitsOnly.startIndex, offsetBy: 1)))
                formattedNumber = "+1 (\(areaCode)"
            case 5...7:
                let areaCode = String(digitsOnly[1..<4])
                let rest = String(digitsOnly.suffix(digitsOnly.count - 4))
                formattedNumber = "+1 (\(areaCode)) \(rest)"
            default:
                let areaCode = String(digitsOnly[1..<4])
                let middle = String(digitsOnly[4..<7])
                let last = String(digitsOnly.suffix(digitsOnly.count - 7))
                formattedNumber = "+1 (\(areaCode)) \(middle)-\(last)"
            }
        } else {
            // Format as a standard 10-digit phone number without country code
            switch digitsOnly.count {
            case 1...3:
                formattedNumber = digitsOnly
            case 4...6:
                let areaCode = String(digitsOnly.prefix(3))
                let rest = String(digitsOnly.suffix(digitsOnly.count - 3))
                formattedNumber = "(\(areaCode)) \(rest)"
            case 7...10:
                let areaCode = String(digitsOnly.prefix(3))
                let middle = String(digitsOnly[3..<6])
                let last = String(digitsOnly.suffix(digitsOnly.count - 6))
                formattedNumber = "(\(areaCode)) \(middle)-\(last)"
            default:
                formattedNumber = digitsOnly
            }
        }

        return formattedNumber
    }
}

// Extension to make String slicing easier
extension String {
    subscript (range: Range<Int>) -> String {
        let startIndex = self.index(self.startIndex, offsetBy: range.lowerBound)
        let endIndex = self.index(self.startIndex, offsetBy: range.upperBound)
        return String(self[startIndex..<endIndex])
    }
}
