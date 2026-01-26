import XCTest
@testable import TrailMatesATX

final class PhoneNumberHasherTests: XCTestCase {
    var hasher: PhoneNumberHasher!
    
    override func setUp() {
        super.setUp()
        hasher = PhoneNumberHasher.shared
    }
    
    override func tearDown() {
        hasher = nil
        super.tearDown()
    }
    
    func testHashPhoneNumberWithValidNumbers() {
        // Test various valid phone number formats
        let testCases = [
            "+1 (555) 123-4567",
            "5551234567",
            "+15551234567",
            "(555) 123-4567"
        ]
        
        // All these formats should hash to the same value since they represent the same number
        let expectedHash = hasher.hashPhoneNumber(testCases[0])
        
        for phoneNumber in testCases {
            let hash = hasher.hashPhoneNumber(phoneNumber)
            XCTAssertEqual(hash, expectedHash, "Hash mismatch for \(phoneNumber)")
            XCTAssertEqual(hash.count, 64, "Hash should be 64 characters (SHA-256)")
        }
    }
    
    func testHashPhoneNumberWithInvalidNumbers() {
        // Test invalid phone numbers
        let testCases = [
            "",
            "abc",
            "123",
            "+",
            "+1"
        ]
        
        for phoneNumber in testCases {
            let hash = hasher.hashPhoneNumber(phoneNumber)
            XCTAssertNotEqual(hash, "", "Hash should not be empty even for invalid numbers")
            XCTAssertEqual(hash.count, 64, "Hash should still be 64 characters")
        }
    }
    
    func testHashPhoneNumberWithPepper() {
        let phoneNumber = "+1 (555) 123-4567"
        let pepper = "secret_pepper"
        
        let hashWithoutPepper = hasher.hashPhoneNumber(phoneNumber)
        let hashWithPepper = hasher.hashPhoneNumber(phoneNumber, pepper: pepper)
        
        XCTAssertNotEqual(hashWithPepper, hashWithoutPepper, "Pepper should change the hash value")
        XCTAssertEqual(hashWithPepper.count, 64, "Hash with pepper should be 64 characters")
    }
    
    func testBatchHashingWithValidNumbers() {
        let phoneNumbers = [
            "+1 (555) 123-4567",
            "+1 (555) 234-5678",
            "+1 (555) 345-6789"
        ]
        
        let hashes = hasher.hashPhoneNumbers(phoneNumbers)
        
        XCTAssertEqual(hashes.count, phoneNumbers.count, "Should hash all numbers")
        XCTAssertEqual(Set(hashes).count, phoneNumbers.count, "Each hash should be unique")
        
        // Verify each hash individually matches
        for (index, phoneNumber) in phoneNumbers.enumerated() {
            let individualHash = hasher.hashPhoneNumber(phoneNumber)
            XCTAssertEqual(hashes[index], individualHash, "Batch hash should match individual hash")
        }
    }
    
    func testBatchHashingWithMixedValidity() {
        let phoneNumbers = [
            "+1 (555) 123-4567",  // valid
            "invalid",            // invalid
            "+1 (555) 234-5678"   // valid
        ]
        
        let hashes = hasher.hashPhoneNumbers(phoneNumbers)
        
        XCTAssertEqual(hashes.count, phoneNumbers.count, "Should hash all numbers regardless of validity")
        XCTAssertTrue(hashes.allSatisfy { $0.count == 64 }, "All hashes should be 64 characters")
    }
    
    func testBatchHashingWithPepper() {
        let phoneNumbers = ["+1 (555) 123-4567", "+1 (555) 234-5678"]
        let pepper = "secret_pepper"
        
        let hashesWithoutPepper = hasher.hashPhoneNumbers(phoneNumbers)
        let hashesWithPepper = hasher.hashPhoneNumbers(phoneNumbers, pepper: pepper)
        
        XCTAssertEqual(hashesWithPepper.count, hashesWithoutPepper.count, "Should hash same number of items")
        
        for (peppered, plain) in zip(hashesWithPepper, hashesWithoutPepper) {
            XCTAssertNotEqual(peppered, plain, "Peppered hash should differ from plain hash")
        }
    }
    
    func testHashConsistency() {
        let phoneNumber = "+1 (555) 123-4567"
        let firstHash = hasher.hashPhoneNumber(phoneNumber)
        
        // Test multiple hashes of the same number
        for _ in 1...10 {
            let nextHash = hasher.hashPhoneNumber(phoneNumber)
            XCTAssertEqual(nextHash, firstHash, "Hash should be consistent for same input")
        }
    }
    
    func testInternationalNumbers() {
        let testCases = [
            ("+44 20 7123 4567", "UK"),
            ("+81 3-1234-5678", "Japan"),
            ("+61 2 3456 7890", "Australia"),
            ("+33 1 23 45 67 89", "France")
        ]
        
        var hashes = Set<String>()
        
        for (number, country) in testCases {
            let hash = hasher.hashPhoneNumber(number)
            XCTAssertEqual(hash.count, 64, "Hash should be 64 characters for \(country) number")
            hashes.insert(hash)
        }
        
        XCTAssertEqual(hashes.count, testCases.count, "Each international number should hash uniquely")
    }
} 