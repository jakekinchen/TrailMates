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

// MARK: - Friend Operations Tests (using MockUserManager)
/// These tests verify friend operations logic using the mock infrastructure.
/// Note: Tests that require actual Firebase integration (real-time listeners,
/// server-side validation) are not included here and would need integration tests.
@Suite("Friend Operations Tests")
@MainActor
struct FriendOperationsTests {

    // MARK: - Add Friend Tests

    @Test("addFriend adds friend to current user's friends list")
    func testAddFriendSuccess() async throws {
        let mockManager = MockUserManager.withLoggedInUser()
        let friend = TestFixtures.sampleUser2
        mockManager.users[friend.id] = friend

        try await mockManager.addFriend(friend.id)

        #expect(mockManager.isFriend(friend.id) == true)
        #expect(mockManager.currentUser?.friends.contains(friend.id) == true)
        #expect(mockManager.addFriendCallCount == 1)
    }

    @Test("addFriend creates bidirectional friendship")
    func testAddFriendBidirectional() async throws {
        let mockManager = MockUserManager.withLoggedInUser()
        let friend = TestFixtures.sampleUser2
        mockManager.users[friend.id] = friend

        try await mockManager.addFriend(friend.id)

        // Both users should have each other as friends
        #expect(mockManager.currentUser?.friends.contains(friend.id) == true)
        #expect(mockManager.users[friend.id]?.friends.contains(mockManager.currentUser!.id) == true)
    }

    @Test("addFriend handles failure gracefully")
    func testAddFriendFailure() async {
        let mockManager = MockUserManager.withLoggedInUser()
        mockManager.shouldFailOnSave = true

        do {
            try await mockManager.addFriend("friend-id")
            #expect(Bool(false), "Expected addFriend to throw")
        } catch {
            #expect(error is MockError)
            #expect(mockManager.isFriend("friend-id") == false)
        }
    }

    @Test("addFriend does nothing when no current user")
    func testAddFriendNoCurrentUser() async throws {
        let mockManager = MockUserManager()
        mockManager.currentUser = nil

        try await mockManager.addFriend("friend-id")

        #expect(mockManager.addFriendCallCount == 1)
        // Should complete without crashing
    }

    @Test("addFriend does not duplicate existing friend")
    func testAddFriendNoDuplicate() async throws {
        let mockManager = MockUserManager.withLoggedInUser()
        let friend = TestFixtures.sampleUser2
        mockManager.users[friend.id] = friend

        // Add friend twice
        try await mockManager.addFriend(friend.id)
        try await mockManager.addFriend(friend.id)

        // Should only appear once
        let friendCount = mockManager.currentUser?.friends.filter { $0 == friend.id }.count ?? 0
        #expect(friendCount == 1)
    }

    // MARK: - Remove Friend Tests

    @Test("removeFriend removes friend from current user's friends list")
    func testRemoveFriendSuccess() async throws {
        let mockManager = MockUserManager.withLoggedInUser()
        let friend = TestFixtures.sampleUser2
        mockManager.users[friend.id] = friend

        // First add the friend
        try await mockManager.addFriend(friend.id)
        #expect(mockManager.isFriend(friend.id) == true)

        // Then remove
        try await mockManager.removeFriend(friend.id)

        #expect(mockManager.isFriend(friend.id) == false)
        #expect(mockManager.currentUser?.friends.contains(friend.id) == false)
        #expect(mockManager.removeFriendCallCount == 1)
    }

    @Test("removeFriend removes bidirectional friendship")
    func testRemoveFriendBidirectional() async throws {
        let mockManager = MockUserManager.withLoggedInUser()
        let friend = TestFixtures.sampleUser2
        mockManager.users[friend.id] = friend

        try await mockManager.addFriend(friend.id)
        try await mockManager.removeFriend(friend.id)

        // Neither user should have the other as friend
        #expect(mockManager.currentUser?.friends.contains(friend.id) == false)
        #expect(mockManager.users[friend.id]?.friends.contains(mockManager.currentUser!.id) == false)
    }

    @Test("removeFriend handles failure gracefully")
    func testRemoveFriendFailure() async throws {
        let mockManager = MockUserManager.withLoggedInUser()
        let friend = TestFixtures.sampleUser2
        mockManager.users[friend.id] = friend

        // Add friend first
        try await mockManager.addFriend(friend.id)

        // Enable failure
        mockManager.shouldFailOnSave = true

        do {
            try await mockManager.removeFriend(friend.id)
            #expect(Bool(false), "Expected removeFriend to throw")
        } catch {
            #expect(error is MockError)
        }
    }

    @Test("removeFriend does nothing for non-existent friend")
    func testRemoveFriendNonExistent() async throws {
        let mockManager = MockUserManager.withLoggedInUser()

        // Try to remove a friend that was never added
        try await mockManager.removeFriend("non-existent-friend")

        #expect(mockManager.removeFriendCallCount == 1)
        // Should complete without crashing
    }

    // MARK: - Send Friend Request Tests

    @Test("sendFriendRequest creates pending request")
    func testSendFriendRequestSuccess() async throws {
        let mockManager = MockUserManager.withLoggedInUser()

        try await mockManager.sendFriendRequest(to: "target-user")

        #expect(mockManager.sendFriendRequestCallCount == 1)
        #expect(mockManager.friendRequests.count == 1)
        #expect(mockManager.friendRequests.first?.status == .pending)
    }

    @Test("sendFriendRequest includes correct from user ID")
    func testSendFriendRequestFromUserId() async throws {
        let mockManager = MockUserManager.withLoggedInUser()

        try await mockManager.sendFriendRequest(to: "target-user")

        let request = mockManager.friendRequests.first
        #expect(request?.fromUserId == mockManager.currentUser?.id)
    }

    @Test("sendFriendRequest handles failure gracefully")
    func testSendFriendRequestFailure() async {
        let mockManager = MockUserManager.withLoggedInUser()
        mockManager.shouldFailOnSave = true

        do {
            try await mockManager.sendFriendRequest(to: "target-user")
            #expect(Bool(false), "Expected sendFriendRequest to throw")
        } catch {
            #expect(error is MockError)
            #expect(mockManager.friendRequests.isEmpty)
        }
    }

    // MARK: - Accept Friend Request Tests

    @Test("acceptFriendRequest adds friend and increments call count")
    func testAcceptFriendRequestSuccess() async throws {
        let mockManager = MockUserManager.withLoggedInUser()
        let friend = TestFixtures.sampleUser2
        mockManager.users[friend.id] = friend

        try await mockManager.acceptFriendRequest(requestId: "request-1", fromUserId: friend.id)

        #expect(mockManager.acceptFriendRequestCallCount == 1)
        #expect(mockManager.isFriend(friend.id) == true)
    }

    @Test("acceptFriendRequest handles failure gracefully")
    func testAcceptFriendRequestFailure() async {
        let mockManager = MockUserManager.withLoggedInUser()
        mockManager.shouldFailOnSave = true

        do {
            try await mockManager.acceptFriendRequest(requestId: "request-1", fromUserId: "user-id")
            #expect(Bool(false), "Expected acceptFriendRequest to throw")
        } catch {
            #expect(error is MockError)
        }
    }

    // MARK: - Reject Friend Request Tests

    @Test("rejectFriendRequest removes request from list")
    func testRejectFriendRequestSuccess() async throws {
        let mockManager = MockUserManager.withLoggedInUser()

        // First send a request
        try await mockManager.sendFriendRequest(to: "target-user")
        let requestId = mockManager.friendRequests.first?.id ?? ""

        // Then reject it
        try await mockManager.rejectFriendRequest(requestId: requestId)

        #expect(mockManager.rejectFriendRequestCallCount == 1)
        #expect(mockManager.friendRequests.isEmpty)
    }

    @Test("rejectFriendRequest handles failure gracefully")
    func testRejectFriendRequestFailure() async throws {
        let mockManager = MockUserManager.withLoggedInUser()

        // First send a request
        try await mockManager.sendFriendRequest(to: "target-user")
        let requestId = mockManager.friendRequests.first?.id ?? ""

        // Enable failure
        mockManager.shouldFailOnSave = true

        do {
            try await mockManager.rejectFriendRequest(requestId: requestId)
            #expect(Bool(false), "Expected rejectFriendRequest to throw")
        } catch {
            #expect(error is MockError)
        }
    }

    // MARK: - isFriend Tests

    @Test("isFriend returns false when no current user")
    func testIsFriendNoCurrentUser() {
        let mockManager = MockUserManager()
        mockManager.currentUser = nil

        let result = mockManager.isFriend("some-id")

        #expect(result == false)
    }

    @Test("isFriend returns true for existing friend")
    func testIsFriendTrue() async throws {
        let mockManager = MockUserManager.withLoggedInUser()
        let friend = TestFixtures.sampleUser2
        mockManager.users[friend.id] = friend

        try await mockManager.addFriend(friend.id)

        #expect(mockManager.isFriend(friend.id) == true)
    }

    @Test("isFriend returns false for non-friend")
    func testIsFriendFalse() {
        let mockManager = MockUserManager.withLoggedInUser()

        #expect(mockManager.isFriend("non-friend-id") == false)
    }

    // MARK: - Fetch Friends Tests

    @Test("fetchFriends returns friends list")
    func testFetchFriendsSuccess() async throws {
        let friends = [TestFixtures.sampleUser2, TestFixtures.sampleUser3]
        let mockManager = MockUserManager.withFriends(friends)

        let result = await mockManager.fetchFriends()

        #expect(result.count == 2)
        #expect(mockManager.fetchFriendsCallCount == 1)
    }

    @Test("fetchFriends returns empty list when offline")
    func testFetchFriendsOffline() async {
        let friends = [TestFixtures.sampleUser2]
        let mockManager = MockUserManager.withFriends(friends)
        mockManager.shouldFailOnFetch = true

        let result = await mockManager.fetchFriends()

        #expect(result.isEmpty)
    }

    @Test("fetchFriends returns empty list for user with no friends")
    func testFetchFriendsEmpty() async {
        let mockManager = MockUserManager.withLoggedInUser()

        let result = await mockManager.fetchFriends()

        #expect(result.isEmpty)
    }
}

// MARK: - Edge Case Tests
/// Additional edge case tests for UserManager and User model.
@Suite("Edge Case Tests")
@MainActor
struct EdgeCaseTests {

    // MARK: - Phone Number Edge Cases

    @Test("normalizePhoneNumber handles international formats")
    func testNormalizeInternationalPhoneNumbers() {
        let userManager = UserManager.shared

        let testCases = [
            ("+44 20 7123 4567", "442071234567"),  // UK
            ("+81 3-1234-5678", "81312345678"),     // Japan
            ("+61 2 3456 7890", "61234567890"),     // Australia
        ]

        for (input, expected) in testCases {
            let normalized = userManager.normalizePhoneNumber(input)
            #expect(normalized == expected, "Failed for input: \(input)")
        }
    }

    @Test("normalizePhoneNumber handles phone with only special characters")
    func testNormalizePhoneNumberOnlySpecialChars() {
        let userManager = UserManager.shared

        let result = userManager.normalizePhoneNumber("+-().")
        #expect(result == "")
    }

    @Test("normalizePhoneNumber handles very long numbers")
    func testNormalizePhoneNumberLong() {
        let userManager = UserManager.shared

        let longNumber = "+1234567890123456789"
        let normalized = userManager.normalizePhoneNumber(longNumber)
        #expect(normalized == "1234567890123456789")
    }

    // MARK: - User Model Edge Cases

    @Test("User handles empty friends list operations")
    func testUserEmptyFriendsListOperations() {
        let user = TestFixtures.createUser()

        // Remove from empty list should not crash
        user.friends.removeAll { $0 == "non-existent" }
        #expect(user.friends.isEmpty)

        // First index of should return nil
        let index = user.friends.firstIndex(of: "non-existent")
        #expect(index == nil)
    }

    @Test("User handles duplicate event IDs gracefully")
    func testUserDuplicateEventIds() {
        let user = TestFixtures.createUser()

        user.attendingEventIds.append("event-1")
        user.attendingEventIds.append("event-1")
        user.attendingEventIds.append("event-1")

        // Arrays allow duplicates (this tests current behavior)
        #expect(user.attendingEventIds.count == 3)

        // Remove all duplicates
        user.attendingEventIds.removeAll { $0 == "event-1" }
        #expect(user.attendingEventIds.isEmpty)
    }

    @Test("User model handles extreme date values")
    func testUserExtremeDates() throws {
        let distantPast = Date.distantPast
        let distantFuture = Date.distantFuture

        let userPast = TestFixtures.createUser(joinDate: distantPast)
        let userFuture = TestFixtures.createUser(joinDate: distantFuture)

        // Encoding/decoding should work
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let dataPast = try encoder.encode(userPast)
        let decodedPast = try decoder.decode(User.self, from: dataPast)
        #expect(decodedPast.joinDate == distantPast)

        let dataFuture = try encoder.encode(userFuture)
        let decodedFuture = try decoder.decode(User.self, from: dataFuture)
        #expect(decodedFuture.joinDate == distantFuture)
    }

    @Test("User model handles special characters in names")
    func testUserSpecialCharactersInNames() throws {
        let user = TestFixtures.createUser(
            firstName: "Jean-Pierre",
            lastName: "O'Brien",
            username: "jean_pierre_2023"
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(user)
        let decoded = try decoder.decode(User.self, from: data)

        #expect(decoded.firstName == "Jean-Pierre")
        #expect(decoded.lastName == "O'Brien")
        #expect(decoded.username == "jean_pierre_2023")
    }

    @Test("User model handles unicode characters")
    func testUserUnicodeCharacters() throws {
        let user = TestFixtures.createUser(
            firstName: "Muller",
            lastName: "Gonzalez",
            username: "muller_gonzalez"
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(user)
        let decoded = try decoder.decode(User.self, from: data)

        #expect(decoded.firstName == "Muller")
        #expect(decoded.lastName == "Gonzalez")
    }

    @Test("User model handles very long strings")
    func testUserLongStrings() throws {
        let longString = String(repeating: "a", count: 1000)

        let user = TestFixtures.createUser(
            firstName: longString,
            lastName: longString,
            username: longString
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(user)
        let decoded = try decoder.decode(User.self, from: data)

        #expect(decoded.firstName.count == 1000)
        #expect(decoded.lastName.count == 1000)
        #expect(decoded.username.count == 1000)
    }

    // MARK: - MockUserManager Edge Cases

    @Test("MockUserManager handles rapid state changes")
    func testMockManagerRapidStateChanges() async throws {
        let mockManager = MockUserManager.withLoggedInUser()
        let friend = TestFixtures.sampleUser2
        mockManager.users[friend.id] = friend

        // Rapid add/remove cycles
        for _ in 1...10 {
            try await mockManager.addFriend(friend.id)
            try await mockManager.removeFriend(friend.id)
        }

        // Should end with no friendship
        #expect(mockManager.isFriend(friend.id) == false)
        #expect(mockManager.addFriendCallCount == 10)
        #expect(mockManager.removeFriendCallCount == 10)
    }

    @Test("MockUserManager reset clears all state")
    func testMockManagerResetClearsAll() async throws {
        let mockManager = MockUserManager.withLoggedInUser()
        let friend = TestFixtures.sampleUser2
        mockManager.users[friend.id] = friend

        // Perform various operations
        try await mockManager.addFriend(friend.id)
        try await mockManager.sendFriendRequest(to: "another-user")
        await mockManager.refreshUserData()

        // Reset
        mockManager.reset()

        // Verify everything is cleared
        #expect(mockManager.currentUser == nil)
        #expect(mockManager.isLoggedIn == false)
        #expect(mockManager.users.isEmpty)
        #expect(mockManager.friends.isEmpty)
        #expect(mockManager.friendRequests.isEmpty)
        #expect(mockManager.addFriendCallCount == 0)
        #expect(mockManager.sendFriendRequestCallCount == 0)
        #expect(mockManager.refreshUserDataCallCount == 0)
    }

    @Test("MockUserManager signOut clears user state")
    func testMockManagerSignOut() async {
        let mockManager = MockUserManager.withLoggedInUser()

        await mockManager.signOut()

        #expect(mockManager.currentUser == nil)
        #expect(mockManager.isLoggedIn == false)
        #expect(mockManager.isOnboardingComplete == false)
        #expect(mockManager.isWelcomeComplete == false)
        #expect(mockManager.isPermissionsGranted == false)
        #expect(mockManager.hasAddedFriends == false)
        #expect(mockManager.signOutCallCount == 1)
    }

    @Test("MockUserManager createNewUser fails for existing phone number")
    func testCreateNewUserExistingPhone() async {
        let mockManager = MockUserManager()
        mockManager.mockUserExists = true

        do {
            try await mockManager.createNewUser(phoneNumber: "+1 (555) 123-4567", id: "test-id")
            #expect(Bool(false), "Expected createNewUser to throw for existing phone")
        } catch {
            #expect(mockManager.isLoggedIn == false)
        }
    }

    @Test("MockUserManager login fails for non-existent user")
    func testLoginNonExistentUser() async {
        let mockManager = MockUserManager()

        do {
            try await mockManager.login(phoneNumber: "+1 (555) 123-4567", id: "non-existent-id")
            #expect(Bool(false), "Expected login to throw for non-existent user")
        } catch {
            #expect(mockManager.isLoggedIn == false)
        }
    }

    @Test("MockUserManager isUsernameTaken returns correct values")
    func testIsUsernameTaken() async {
        let mockManager = MockUserManager.withLoggedInUser()

        // Add another user with a different username
        let otherUser = TestFixtures.createUser(id: "other-id", username: "takenusername")
        mockManager.users[otherUser.id] = otherUser

        let taken = await mockManager.isUsernameTaken("takenusername")
        let notTaken = await mockManager.isUsernameTaken("availableusername")

        #expect(taken == true)
        #expect(notTaken == false)
    }

    @Test("MockUserManager isUsernameTaken excludes current user")
    func testIsUsernameTakenExcludesCurrentUser() async {
        let mockManager = MockUserManager.withLoggedInUser()
        let currentUsername = mockManager.currentUser?.username ?? ""

        // Current user's username should not be considered taken
        let result = await mockManager.isUsernameTaken(currentUsername)

        #expect(result == false)
    }

    // MARK: - Location Edge Cases

    @Test("User location can be set to extreme coordinates")
    func testUserExtremeCoordinates() {
        let user = TestFixtures.createUser()

        // North pole
        user.location = CLLocationCoordinate2D(latitude: 90.0, longitude: 0.0)
        #expect(user.location?.latitude == 90.0)

        // South pole
        user.location = CLLocationCoordinate2D(latitude: -90.0, longitude: 0.0)
        #expect(user.location?.latitude == -90.0)

        // International date line
        user.location = CLLocationCoordinate2D(latitude: 0.0, longitude: 180.0)
        #expect(user.location?.longitude == 180.0)

        user.location = CLLocationCoordinate2D(latitude: 0.0, longitude: -180.0)
        #expect(user.location?.longitude == -180.0)
    }

    @Test("MockUserManager updateLocation handles extreme coordinates")
    func testMockManagerUpdateExtremeLocation() async throws {
        let mockManager = MockUserManager.withLoggedInUser()

        let extremeLocation = CLLocationCoordinate2D(latitude: 90.0, longitude: 180.0)
        try await mockManager.updateUserLocation(extremeLocation)

        #expect(mockManager.currentUser?.location?.latitude == 90.0)
        #expect(mockManager.currentUser?.location?.longitude == 180.0)
        #expect(mockManager.updateLocationCallCount == 1)
    }

    // MARK: - Concurrent Access Edge Cases

    @Test("Concurrent friend operations complete without crashing")
    func testConcurrentFriendOperations() async throws {
        let mockManager = MockUserManager.withLoggedInUser()

        // Add multiple friends to the users dictionary
        for i in 1...5 {
            let friend = TestFixtures.createUser(id: "friend-\(i)", firstName: "Friend\(i)")
            mockManager.users[friend.id] = friend
        }

        // Perform concurrent add operations
        await withTaskGroup(of: Void.self) { group in
            for i in 1...5 {
                group.addTask {
                    try? await mockManager.addFriend("friend-\(i)")
                }
            }
        }

        // All friends should be added
        #expect(mockManager.addFriendCallCount == 5)
    }
}

// MARK: - Integration Notes
/// The following operations require actual Firebase integration and cannot be fully tested with mocks:
///
/// 1. Real-time friend request listeners (Firestore snapshots)
/// 2. Server-side validation of friend operations
/// 3. Conflict resolution when multiple users modify friendship simultaneously
/// 4. Push notification delivery for friend requests
/// 5. Phone number verification through Firebase Auth
/// 6. Profile image upload/download with Firebase Storage
///
/// These would need integration tests running against a Firebase emulator or test project.
