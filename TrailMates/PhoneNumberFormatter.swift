import Foundation

struct PhoneNumberFormatter {
    static func formatPhoneNumber(_ number: String) -> String {
        let digitsOnly = number.filter { $0.isNumber }
        let formattedNumber: String

        if digitsOnly.count <= 3 {
            formattedNumber = "(\(digitsOnly)"
        } else if digitsOnly.count <= 6 {
            let areaCode = String(digitsOnly.prefix(3))
            let middle = String(digitsOnly.suffix(digitsOnly.count - 3))
            formattedNumber = "(\(areaCode)) \(middle)"
        } else {
            let areaCode = String(digitsOnly.prefix(3))
            let middle = String(digitsOnly[3..<6])
            let last = String(digitsOnly.suffix(digitsOnly.count - 6))
            formattedNumber = "(\(areaCode)) \(middle)-\(last)"
        }

        return formattedNumber
    }
}

extension String {
    subscript (range: Range<Int>) -> String {
        let startIndex = self.index(self.startIndex, offsetBy: range.lowerBound)
        let endIndex = self.index(self.startIndex, offsetBy: range.upperBound)
        return String(self[startIndex..<endIndex])
    }
}