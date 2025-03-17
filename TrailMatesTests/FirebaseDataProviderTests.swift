import XCTest
@testable import TrailMates
import Firebase
import FirebaseAuth
import FirebaseFunctions

final class FirebaseDataProviderTests: XCTestCase {
    var dataProvider: FirebaseDataProvider!
    var mockAuth: MockAuth!
    var mockFunctions: MockFunctions!
    
    override func setUp() {
        super.setUp()
        mockAuth = MockAuth()
        mockFunctions = MockFunctions()
        dataProvider = FirebaseDataProvider.shared
    }
    
    override func tearDown() {
        mockAuth = nil
        mockFunctions = nil
        dataProvider = nil
        super.tearDown()
    }
    
    func testFetchUserByHashedNumber() async throws {
        let phoneNumber = "+1 (555) 123-4567"
        let expectedHash = PhoneNumberHasher.shared.hashPhoneNumber(phoneNumber)
        
        // Test successful fetch
        let user = await dataProvider.fetchUser(byPhoneNumber: phoneNumber)
        XCTAssertNotNil(user)
        XCTAssertEqual(user?.hashedPhoneNumber, expectedHash)
        
        // Test non-existent number
        let nonExistentUser = await dataProvider.fetchUser(byPhoneNumber: "+1 (555) 999-9999")
        XCTAssertNil(nonExistentUser)
    }
    
    func testFindUsersByHashedNumbers() async throws {
        let phoneNumbers = [
            "+1 (555) 123-4567",
            "+1 (555) 234-5678",
            "+1 (555) 345-6789"
        ]
        
        let users = try await dataProvider.findUsersByPhoneNumbers(phoneNumbers)
        
        // Verify hashes match
        let expectedHashes = phoneNumbers.map { PhoneNumberHasher.shared.hashPhoneNumber($0) }
        let resultHashes = users.map { $0.hashedPhoneNumber }
        
        XCTAssertEqual(Set(resultHashes), Set(expectedHashes))
    }
    
    func testCheckUserExists() async {
        let phoneNumber = "+1 (555) 123-4567"
        let exists = await dataProvider.checkUserExists(phoneNumber: phoneNumber)
        XCTAssertTrue(exists)
        
        let nonExistentNumber = "+1 (555) 999-9999"
        let doesNotExist = await dataProvider.checkUserExists(phoneNumber: nonExistentNumber)
        XCTAssertFalse(doesNotExist)
    }
    
    func testSaveInitialUser() async throws {
        let phoneNumber = "+1 (555) 123-4567"
        let user = User(
            id: "test-user-id",
            firstName: "Test",
            lastName: "User",
            username: "testuser",
            phoneNumber: phoneNumber
        )
        
        try await dataProvider.saveInitialUser(user)
        
        // Verify user was saved with hashed phone number
        let savedUser = await dataProvider.fetchUser(byPhoneNumber: phoneNumber)
        XCTAssertNotNil(savedUser)
        XCTAssertEqual(savedUser?.hashedPhoneNumber, user.hashedPhoneNumber)
    }
}

// MARK: - Mock Classes
class MockAuth: Auth {
    var mockCurrentUser: User?
    
    override var currentUser: User? {
        return mockCurrentUser
    }
}

class MockFunctions: Functions {
    var mockResults: [String: Any] = [:]
    
    override func httpsCallable(_ name: String) -> HTTPSCallable {
        return MockCallable(mockResults: mockResults)
    }
}

class MockCallable: HTTPSCallable {
    let mockResults: [String: Any]
    
    init(mockResults: [String: Any]) {
        self.mockResults = mockResults
    }
    
    override func call(_ data: Any?, completion: @escaping (Result<HTTPSCallableResult, Error>) -> Void) {
        // Implement mock behavior
    }
} 