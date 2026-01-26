import XCTest
@testable import TrailMatesATX

/// Integration tests for FirebaseDataProvider.
/// These tests require Firebase to be configured with test data and are SKIPPED by default.
/// To run these tests, set the environment variable ENABLE_FIREBASE_INTEGRATION_TESTS=1
/// For pure unit tests, see AsyncNetworkTests which uses MockFirebaseDataProvider.
final class FirebaseDataProviderTests: XCTestCase {
    var dataProvider: FirebaseDataProvider!

    /// Check if integration tests should run
    private var shouldRunIntegrationTests: Bool {
        ProcessInfo.processInfo.environment["ENABLE_FIREBASE_INTEGRATION_TESTS"] == "1"
    }

    override func setUp() {
        super.setUp()
        dataProvider = FirebaseDataProvider.shared
    }

    override func tearDown() {
        dataProvider = nil
        super.tearDown()
    }

    func testFetchUserByHashedNumber() async throws {
        try XCTSkipUnless(shouldRunIntegrationTests, "Skipping Firebase integration test")
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
        try XCTSkipUnless(shouldRunIntegrationTests, "Skipping Firebase integration test")
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
    
    func testCheckUserExists() async throws {
        try XCTSkipUnless(shouldRunIntegrationTests, "Skipping Firebase integration test")
        let phoneNumber = "+1 (555) 123-4567"
        let exists = await dataProvider.checkUserExists(phoneNumber: phoneNumber)
        XCTAssertTrue(exists)
        
        let nonExistentNumber = "+1 (555) 999-9999"
        let doesNotExist = await dataProvider.checkUserExists(phoneNumber: nonExistentNumber)
        XCTAssertFalse(doesNotExist)
    }
    
    func testSaveInitialUser() async throws {
        try XCTSkipUnless(shouldRunIntegrationTests, "Skipping Firebase integration test")
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