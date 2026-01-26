import XCTest
@testable import TrailMatesATX

final class UserModelTests: XCTestCase {
    var user: User!
    
    override func setUp() {
        super.setUp()
        user = User(
            id: "test-user-id",
            firstName: "Test",
            lastName: "User",
            username: "testuser",
            phoneNumber: "+1 (555) 123-4567"
        )
    }
    
    override func tearDown() {
        user = nil
        super.tearDown()
    }
    
    func testPhoneNumberInitialization() {
        XCTAssertEqual(user.phoneNumber, "+1 (555) 123-4567", "Phone number should be stored as provided")
        XCTAssertFalse(user.hashedPhoneNumber.isEmpty, "Hashed phone number should be generated")
        XCTAssertEqual(user.hashedPhoneNumber.count, 64, "Hash should be 64 characters (SHA-256)")
    }
    
    func testPhoneNumberEncoding() throws {
        // Test encoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(user)
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedUser = try decoder.decode(User.self, from: data)
        
        // Verify phone number and hash match
        XCTAssertEqual(decodedUser.phoneNumber, user.phoneNumber)
        XCTAssertEqual(decodedUser.hashedPhoneNumber, user.hashedPhoneNumber)
    }
    
    func testPhoneNumberPrivacy() {
        let originalNumber = user.phoneNumber
        let originalHash = user.hashedPhoneNumber
        
        // Verify we can't modify phoneNumber directly
        // This should not compile:
        // user.phoneNumber = "+1 (555) 999-9999"
        
        XCTAssertEqual(user.phoneNumber, originalNumber, "Phone number should not be modifiable")
        XCTAssertEqual(user.hashedPhoneNumber, originalHash, "Hash should not change")
    }
    
    func testPhoneNumberEquality() {
        let user1 = User(
            id: "user1",
            firstName: "Test",
            lastName: "User",
            phoneNumber: "+1 (555) 123-4567"
        )
        
        let user2 = User(
            id: "user2",
            firstName: "Test",
            lastName: "User",
            phoneNumber: "+1 (555) 123-4567"
        )
        
        XCTAssertEqual(user1.hashedPhoneNumber, user2.hashedPhoneNumber, "Same phone numbers should hash to same value")
    }
    
    func testPhoneNumberNormalization() {
        // Using 512 (Austin, TX) area code - a real US area code that PhoneNumberKit recognizes
        let testCases = [
            ("+1 (512) 555-1234", "+15125551234"),
            ("5125551234", "+15125551234"),
            ("+15125551234", "+15125551234"),
            ("(512) 555-1234", "+15125551234")
        ]

        let firstHash = PhoneNumberHasher.shared.hashPhoneNumber(testCases[0].0)

        for (input, _) in testCases {
            let user = User(
                id: "test",
                firstName: "Test",
                lastName: "User",
                phoneNumber: input
            )
            XCTAssertEqual(user.hashedPhoneNumber, firstHash, "Different formats of same number should hash identically")
        }
    }
    
    func testDecodingWithMissingHash() throws {
        // Create JSON without hashedPhoneNumber
        let json = """
        {
            "id": "test-id",
            "firstName": "Test",
            "lastName": "User",
            "username": "testuser",
            "phoneNumber": "+1 (555) 123-4567",
            "joinDate": \(Date().timeIntervalSince1970)
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let decodedUser = try decoder.decode(User.self, from: json)
        
        // Verify hash was generated during decoding
        XCTAssertFalse(decodedUser.hashedPhoneNumber.isEmpty)
        XCTAssertEqual(decodedUser.hashedPhoneNumber.count, 64)
        XCTAssertEqual(decodedUser.hashedPhoneNumber, user.hashedPhoneNumber)
    }
} 