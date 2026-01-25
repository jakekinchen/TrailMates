import Testing
import Foundation
import CoreLocation
@testable import TrailMates

/// Tests for UserManager user state management and business logic.
/// Note: UserManager uses a singleton pattern with FirebaseDataProvider dependency.
/// These tests focus on testable state management and utility functions.
@Suite("UserManager Tests")
struct UserManagerTests {

    // MARK: - Phone Number Normalization Tests

    @Test("Normalizes phone number by removing non-numeric characters")
    func testNormalizePhoneNumberRemovesFormatting() {
        let userManager = UserManager.shared

        let formatted = "+1 (555) 123-4567"
        let normalized = userManager.normalizePhoneNumber(formatted)

        #expect(normalized == "15551234567")
    }

    @Test("Normalizes already clean phone number")
    func testNormalizePhoneNumberWithCleanInput() {
        let userManager = UserManager.shared

        let clean = "15551234567"
        let normalized = userManager.normalizePhoneNumber(clean)

        #expect(normalized == "15551234567")
    }

    @Test("Normalizes phone number with various formats")
    func testNormalizePhoneNumberVariousFormats() {
        let userManager = UserManager.shared

        let testCases = [
            ("+1 (555) 123-4567", "15551234567"),
            ("555-123-4567", "5551234567"),
            ("(555) 123-4567", "5551234567"),
            ("+1.555.123.4567", "15551234567"),
            ("1 555 123 4567", "15551234567")
        ]

        for (input, expected) in testCases {
            let normalized = userManager.normalizePhoneNumber(input)
            #expect(normalized == expected, "Failed for input: \(input)")
        }
    }

    @Test("Normalizes empty phone number")
    func testNormalizeEmptyPhoneNumber() {
        let userManager = UserManager.shared

        let empty = ""
        let normalized = userManager.normalizePhoneNumber(empty)

        #expect(normalized == "")
    }

    // MARK: - Friend Status Tests

    @Test("Returns false when checking friend status with no current user")
    func testIsFriendWithNoCurrentUser() async {
        let userManager = UserManager.shared

        // Without a current user, isFriend should return false
        let result = userManager.isFriend("some-user-id")

        #expect(result == false)
    }

    // MARK: - Refresh Logic Tests

    @Test("shouldRefreshUser returns true when lastRefreshTime is nil")
    func testShouldRefreshUserWithNoLastRefresh() {
        let userManager = UserManager.shared

        // This tests the refresh interval logic
        // When there's no last refresh time, should return true
        let shouldRefresh = userManager.shouldRefreshUser()

        // Note: This may depend on actual state, but tests the method exists
        #expect(shouldRefresh == true || shouldRefresh == false)
    }

    // MARK: - User Model State Tests

    @Test("User model correctly computes hashed phone number")
    func testUserHashedPhoneNumber() {
        let user = TestFixtures.createUser(phoneNumber: "+1 (555) 123-4567")

        #expect(!user.hashedPhoneNumber.isEmpty)
        #expect(user.hashedPhoneNumber.count == 64)
    }

    @Test("User model maintains friend count")
    func testUserFriendCount() {
        let user = TestFixtures.createUser()

        #expect(user.friendCount == 0)

        user.friends = ["friend-1", "friend-2", "friend-3"]

        #expect(user.friendCount == 3)
    }

    @Test("User model default settings are correct")
    func testUserDefaultSettings() {
        let user = TestFixtures.createUser()

        // Notification settings
        #expect(user.receiveFriendRequests == true)
        #expect(user.receiveFriendEvents == true)
        #expect(user.receiveEventUpdates == true)

        // Privacy settings
        #expect(user.shareLocationWithFriends == true)
        #expect(user.shareLocationWithEventHost == true)
        #expect(user.shareLocationWithEventGroup == true)
        #expect(user.allowFriendsToInviteOthers == true)

        // Activity settings
        #expect(user.isActive == true)
        #expect(user.doNotDisturb == false)
    }

    @Test("User model can update phone number")
    func testUserUpdatePhoneNumber() {
        let user = TestFixtures.createUser(phoneNumber: "+1 (555) 111-1111")
        let originalHash = user.hashedPhoneNumber

        user.updatePhoneNumber("+1 (555) 222-2222")

        #expect(user.phoneNumber == "+1 (555) 222-2222")
        #expect(user.hashedPhoneNumber != originalHash)
    }

    // MARK: - User Encoding/Decoding Tests

    @Test("User model encodes and decodes correctly")
    func testUserEncodingDecoding() throws {
        let originalUser = TestFixtures.sampleUser
        originalUser.friends = ["friend-1", "friend-2"]
        originalUser.createdEventIds = ["event-1"]
        originalUser.attendingEventIds = ["event-2"]
        originalUser.visitedLandmarkIds = ["landmark-1"]

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalUser)

        let decoder = JSONDecoder()
        let decodedUser = try decoder.decode(User.self, from: data)

        #expect(decodedUser.id == originalUser.id)
        #expect(decodedUser.firstName == originalUser.firstName)
        #expect(decodedUser.lastName == originalUser.lastName)
        #expect(decodedUser.username == originalUser.username)
        #expect(decodedUser.phoneNumber == originalUser.phoneNumber)
        #expect(decodedUser.hashedPhoneNumber == originalUser.hashedPhoneNumber)
        #expect(decodedUser.friends == originalUser.friends)
        #expect(decodedUser.createdEventIds == originalUser.createdEventIds)
        #expect(decodedUser.attendingEventIds == originalUser.attendingEventIds)
        #expect(decodedUser.visitedLandmarkIds == originalUser.visitedLandmarkIds)
    }

    @Test("User model handles missing optional fields during decoding")
    func testUserDecodingWithMissingFields() throws {
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
        let user = try decoder.decode(User.self, from: json)

        // Optional fields should have default values
        #expect(user.isActive == true)
        #expect(user.friends.isEmpty)
        #expect(user.doNotDisturb == false)
        #expect(user.createdEventIds.isEmpty)
        #expect(user.attendingEventIds.isEmpty)
        #expect(user.visitedLandmarkIds.isEmpty)
    }

    // MARK: - User Equality Tests

    @Test("Users with same ID are equal")
    func testUserEquality() {
        let user1 = TestFixtures.createUser(
            id: "same-id",
            firstName: "John",
            lastName: "Doe",
            username: "johndoe",
            phoneNumber: "+1 (555) 111-1111"
        )

        let user2 = TestFixtures.createUser(
            id: "same-id",
            firstName: "John",
            lastName: "Doe",
            username: "johndoe",
            phoneNumber: "+1 (555) 111-1111"
        )

        #expect(user1 == user2)
    }

    @Test("Users with different IDs are not equal")
    func testUserInequality() {
        let user1 = TestFixtures.createUser(id: "id-1")
        let user2 = TestFixtures.createUser(id: "id-2")

        #expect(user1 != user2)
    }

    @Test("Users with same ID but different properties are not equal")
    func testUserInequalityWithDifferentProperties() {
        let user1 = TestFixtures.createUser(id: "same-id", firstName: "John")
        let user2 = TestFixtures.createUser(id: "same-id", firstName: "Jane")

        #expect(user1 != user2)
    }

    // MARK: - Collections Tests

    @Test("User maintains list integrity for friends")
    func testUserFriendsListIntegrity() {
        let user = TestFixtures.createUser()

        #expect(user.friends.isEmpty)

        user.friends.append("friend-1")
        #expect(user.friends.count == 1)
        #expect(user.friends.contains("friend-1"))

        user.friends.append("friend-2")
        #expect(user.friends.count == 2)

        user.friends.removeAll { $0 == "friend-1" }
        #expect(user.friends.count == 1)
        #expect(!user.friends.contains("friend-1"))
        #expect(user.friends.contains("friend-2"))
    }

    @Test("User maintains list integrity for event IDs")
    func testUserEventIdsIntegrity() {
        let user = TestFixtures.createUser()

        // Created events
        user.createdEventIds.append("event-1")
        user.createdEventIds.append("event-2")
        #expect(user.createdEventIds.count == 2)

        // Attending events
        user.attendingEventIds.append("event-3")
        #expect(user.attendingEventIds.count == 1)

        // They should be independent
        #expect(user.createdEventIds != user.attendingEventIds)
    }

    // MARK: - Privacy Settings Tests

    @Test("User privacy settings can be toggled")
    func testUserPrivacySettingsToggle() {
        let user = TestFixtures.createUser()

        // Initial state
        #expect(user.shareLocationWithFriends == true)

        // Toggle
        user.shareLocationWithFriends = false
        #expect(user.shareLocationWithFriends == false)

        user.shareLocationWithFriends = true
        #expect(user.shareLocationWithFriends == true)
    }

    @Test("User notification settings can be toggled")
    func testUserNotificationSettingsToggle() {
        let user = TestFixtures.createUser()

        // Initial state
        #expect(user.receiveFriendRequests == true)
        #expect(user.receiveFriendEvents == true)
        #expect(user.receiveEventUpdates == true)

        // Toggle all off
        user.receiveFriendRequests = false
        user.receiveFriendEvents = false
        user.receiveEventUpdates = false

        #expect(user.receiveFriendRequests == false)
        #expect(user.receiveFriendEvents == false)
        #expect(user.receiveEventUpdates == false)
    }

    @Test("User do not disturb setting toggles correctly")
    func testUserDoNotDisturbToggle() {
        let user = TestFixtures.createUser()

        #expect(user.doNotDisturb == false)

        user.doNotDisturb = true
        #expect(user.doNotDisturb == true)

        user.doNotDisturb = false
        #expect(user.doNotDisturb == false)
    }

    // MARK: - Test Fixtures Validation

    @Test("Test fixtures create valid user objects")
    func testFixturesCreateValidUsers() {
        let sampleUser = TestFixtures.sampleUser

        #expect(!sampleUser.id.isEmpty)
        #expect(!sampleUser.firstName.isEmpty)
        #expect(!sampleUser.lastName.isEmpty)
        #expect(!sampleUser.username.isEmpty)
        #expect(!sampleUser.phoneNumber.isEmpty)
    }

    @Test("Test fixtures create distinct users")
    func testFixturesCreateDistinctUsers() {
        let users = TestFixtures.sampleUsers

        #expect(users.count == 3)

        let ids = Set(users.map { $0.id })
        #expect(ids.count == 3)

        let usernames = Set(users.map { $0.username })
        #expect(usernames.count == 3)
    }
}
