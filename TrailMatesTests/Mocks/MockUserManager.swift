import Foundation
import CoreLocation
import UIKit
@testable import TrailMatesATX

/// A mock implementation of UserManager for testing purposes.
/// This mock allows tests to control user state and operations without actual Firebase calls.
@MainActor
class MockUserManager: ObservableObject {
    // MARK: - Published Properties (matching UserManager interface)
    @Published var currentUser: User?
    @Published var isLoggedIn: Bool = false
    @Published var isOnboardingComplete: Bool = false
    @Published var isWelcomeComplete: Bool = false
    @Published var isPermissionsGranted: Bool = false
    @Published var hasAddedFriends: Bool = false
    @Published private(set) var isRefreshing: Bool = false

    // MARK: - Mock Data Storage
    var users: [String: User] = [:]
    var friends: [User] = []
    var friendRequests: [FriendRequest] = []

    // MARK: - Call Tracking
    var fetchFriendsCallCount = 0
    var fetchAllUsersCallCount = 0
    var fetchUserCallCount = 0
    var saveProfileCallCount = 0
    var sendFriendRequestCallCount = 0
    var acceptFriendRequestCallCount = 0
    var rejectFriendRequestCallCount = 0
    var addFriendCallCount = 0
    var removeFriendCallCount = 0
    var updateLocationCallCount = 0
    var signOutCallCount = 0
    var createNewUserCallCount = 0
    var loginCallCount = 0
    var refreshUserDataCallCount = 0
    var prefetchProfileImagesCallCount = 0

    // MARK: - Mock Behavior Configuration
    var shouldFailOnSave = false
    var shouldFailOnFetch = false
    var shouldFailOnAuth = false
    var mockError: Error?
    var mockUsernameTaken = false
    var mockUserExists = false

    // MARK: - Initialization
    init() {}

    init(currentUser: User?) {
        self.currentUser = currentUser
        self.isLoggedIn = currentUser != nil
        if let user = currentUser {
            users[user.id] = user
        }
    }

    // MARK: - User Operations

    func initializeIfNeeded() async {
        // No-op for testing - initialization is controlled by test setup
    }

    func fetchFriends() async -> [User] {
        fetchFriendsCallCount += 1
        if shouldFailOnFetch { return [] }
        return friends
    }

    func fetchAllUsers() async -> [User] {
        fetchAllUsersCallCount += 1
        if shouldFailOnFetch { return [] }
        return Array(users.values)
    }

    func fetchUser(_ userId: String) async -> User? {
        fetchUserCallCount += 1
        if shouldFailOnFetch { return nil }
        return users[userId]
    }

    func saveProfile(updatedUser: User) async throws {
        saveProfileCallCount += 1
        if shouldFailOnSave {
            throw mockError ?? MockError.saveFailed
        }
        users[updatedUser.id] = updatedUser
        if currentUser?.id == updatedUser.id {
            currentUser = updatedUser
        }
    }

    func saveInitialProfile(updatedUser: User) async throws {
        try await saveProfile(updatedUser: updatedUser)
    }

    // MARK: - Authentication Operations

    func createNewUser(phoneNumber: String, id: String) async throws {
        createNewUserCallCount += 1
        if shouldFailOnAuth {
            throw mockError ?? MockError.saveFailed
        }
        if mockUserExists {
            throw ValidationError.invalidData("Phone number already registered")
        }

        let newUser = User(
            id: id,
            firstName: "",
            lastName: "",
            username: "",
            phoneNumber: phoneNumber,
            joinDate: Date()
        )
        users[id] = newUser
        currentUser = newUser
        isLoggedIn = true
    }

    func login(phoneNumber: String, id: String) async throws {
        loginCallCount += 1
        if shouldFailOnAuth {
            throw mockError ?? MockError.fetchFailed
        }

        guard let user = users[id] else {
            throw ValidationError.invalidData("No account found with this UID")
        }

        currentUser = user
        isLoggedIn = true
    }

    func signOut() async {
        signOutCallCount += 1
        currentUser = nil
        isLoggedIn = false
        isOnboardingComplete = false
        isWelcomeComplete = false
        isPermissionsGranted = false
        hasAddedFriends = false
    }

    func checkUserExists(phoneNumber: String) async -> Bool {
        if mockUserExists { return true }
        let normalizedPhone = normalizePhoneNumber(phoneNumber)
        return users.values.contains { normalizePhoneNumber($0.phoneNumber) == normalizedPhone }
    }

    func isUsernameTaken(_ username: String) async -> Bool {
        if mockUsernameTaken { return true }
        return users.values.contains { user in
            user.username == username && user.id != currentUser?.id
        }
    }

    // MARK: - Friend Operations

    func sendFriendRequest(to userId: String) async throws {
        sendFriendRequestCallCount += 1
        if shouldFailOnSave {
            throw mockError ?? MockError.saveFailed
        }
        guard let currentUserId = currentUser?.id else { return }

        let request = FriendRequest(
            id: UUID().uuidString,
            fromUserId: currentUserId,
            timestamp: Date(),
            status: .pending
        )
        friendRequests.append(request)
    }

    func acceptFriendRequest(requestId: String, fromUserId: String) async throws {
        acceptFriendRequestCallCount += 1
        if shouldFailOnSave {
            throw mockError ?? MockError.saveFailed
        }
        try await addFriend(fromUserId)
    }

    func rejectFriendRequest(requestId: String) async throws {
        rejectFriendRequestCallCount += 1
        if shouldFailOnSave {
            throw mockError ?? MockError.saveFailed
        }
        friendRequests.removeAll { $0.id == requestId }
    }

    func addFriend(_ friendId: String) async throws {
        addFriendCallCount += 1
        if shouldFailOnSave {
            throw mockError ?? MockError.saveFailed
        }

        guard let currentUserId = currentUser?.id else { return }

        if var user = users[currentUserId], var friend = users[friendId] {
            if !user.friends.contains(friendId) {
                user.friends.append(friendId)
                users[currentUserId] = user
                currentUser = user
            }
            if !friend.friends.contains(currentUserId) {
                friend.friends.append(currentUserId)
                users[friendId] = friend
            }

            // Add to friends list
            if !friends.contains(where: { $0.id == friendId }) {
                friends.append(friend)
            }
        }
    }

    func removeFriend(_ friendId: String) async throws {
        removeFriendCallCount += 1
        if shouldFailOnSave {
            throw mockError ?? MockError.saveFailed
        }

        guard let currentUserId = currentUser?.id else { return }

        if var user = users[currentUserId], var friend = users[friendId] {
            user.friends.removeAll { $0 == friendId }
            friend.friends.removeAll { $0 == currentUserId }
            users[currentUserId] = user
            users[friendId] = friend
            currentUser = user

            // Remove from friends list
            friends.removeAll { $0.id == friendId }
        }
    }

    func isFriend(_ userId: String) -> Bool {
        currentUser?.friends.contains(userId) ?? false
    }

    // MARK: - Location Operations

    func updateLocation(_ location: CLLocationCoordinate2D) async {
        updateLocationCallCount += 1
        currentUser?.location = location
    }

    func updateUserLocation(_ location: CLLocationCoordinate2D) async throws {
        updateLocationCallCount += 1
        if shouldFailOnSave {
            throw mockError ?? MockError.saveFailed
        }
        currentUser?.location = location
    }

    // MARK: - Profile Operations

    func refreshUserData() async {
        refreshUserDataCallCount += 1
        // Simulate refresh by reloading from users dictionary
        if let userId = currentUser?.id, let user = users[userId] {
            currentUser = user
        }
    }

    func refreshCurrentUser() async throws {
        await refreshUserData()
    }

    func shouldRefreshUser() -> Bool {
        // Always allow refresh in tests
        return true
    }

    func prefetchProfileImages(for users: [User], preferredSize: UserManager.ImageSize) async {
        prefetchProfileImagesCallCount += 1
        // No-op for testing
    }

    func fetchProfileImage(for user: User, preferredSize: UserManager.ImageSize, forceRefresh: Bool) async throws -> UIImage? {
        if shouldFailOnFetch {
            throw mockError ?? MockError.fetchFailed
        }
        // Return a placeholder image
        return UIImage(systemName: "person.circle")
    }

    func setProfileImage(_ image: UIImage) async throws {
        if shouldFailOnSave {
            throw mockError ?? MockError.saveFailed
        }
        // No-op for testing
    }

    // MARK: - Settings Operations

    func updatePrivacySettings(
        shareWithFriends: Bool? = nil,
        shareWithHost: Bool? = nil,
        shareWithGroup: Bool? = nil,
        allowFriendsInvite: Bool? = nil
    ) async throws {
        if shouldFailOnSave {
            throw mockError ?? MockError.saveFailed
        }

        if let shareWithFriends = shareWithFriends {
            currentUser?.shareLocationWithFriends = shareWithFriends
        }
        if let shareWithHost = shareWithHost {
            currentUser?.shareLocationWithEventHost = shareWithHost
        }
        if let shareWithGroup = shareWithGroup {
            currentUser?.shareLocationWithEventGroup = shareWithGroup
        }
        if let allowFriendsInvite = allowFriendsInvite {
            currentUser?.allowFriendsToInviteOthers = allowFriendsInvite
        }
    }

    func updateNotificationSettings(
        friendRequests: Bool? = nil,
        friendEvents: Bool? = nil,
        eventUpdates: Bool? = nil
    ) async throws {
        if shouldFailOnSave {
            throw mockError ?? MockError.saveFailed
        }

        if let friendRequests = friendRequests {
            currentUser?.receiveFriendRequests = friendRequests
        }
        if let friendEvents = friendEvents {
            currentUser?.receiveFriendEvents = friendEvents
        }
        if let eventUpdates = eventUpdates {
            currentUser?.receiveEventUpdates = eventUpdates
        }
    }

    func toggleDoNotDisturb() async throws {
        if shouldFailOnSave {
            throw mockError ?? MockError.saveFailed
        }
        currentUser?.doNotDisturb.toggle()
    }

    // MARK: - Event Operations

    func attendEvent(_ eventId: String) async throws {
        if shouldFailOnSave {
            throw mockError ?? MockError.saveFailed
        }
        guard let user = currentUser else { return }
        if !user.attendingEventIds.contains(eventId) {
            user.attendingEventIds.append(eventId)
        }
    }

    func leaveEvent(_ eventId: String) async throws {
        if shouldFailOnSave {
            throw mockError ?? MockError.saveFailed
        }
        guard let user = currentUser else { return }
        user.attendingEventIds.removeAll { $0 == eventId }
    }

    // MARK: - Utility Methods

    func normalizePhoneNumber(_ phoneNumber: String) -> String {
        return phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
    }

    func findUserByPhoneNumber(_ phoneNumber: String) async -> User? {
        let normalized = normalizePhoneNumber(phoneNumber)
        return users.values.first { normalizePhoneNumber($0.phoneNumber) == normalized }
    }

    func findUsersByPhoneNumbers(_ phoneNumbers: [String]) async throws -> [User] {
        if shouldFailOnFetch {
            throw mockError ?? MockError.fetchFailed
        }
        let normalizedNumbers = phoneNumbers.map { normalizePhoneNumber($0) }
        return users.values.filter { normalizedNumbers.contains(normalizePhoneNumber($0.phoneNumber)) }
    }

    // MARK: - Stats Operations

    func getUserStats(for userId: String) async -> UserStats? {
        guard let user = users[userId] else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        return UserStats(
            joinDate: formatter.string(from: user.joinDate),
            landmarkCompletion: 50, // Mock value
            friendCount: user.friends.count,
            hostedEventCount: user.createdEventIds.count,
            attendedEventCount: user.attendingEventIds.count
        )
    }

    func getUserStats() async -> UserStats? {
        guard let userId = currentUser?.id else { return nil }
        return await getUserStats(for: userId)
    }

    // MARK: - Landmark Operations

    func visitLandmark(_ landmarkId: String) async {
        guard let user = currentUser else { return }
        if !user.visitedLandmarkIds.contains(landmarkId) {
            user.visitedLandmarkIds.append(landmarkId)
        }
    }

    func unvisitLandmark(_ landmarkId: String) async {
        currentUser?.visitedLandmarkIds.removeAll { $0 == landmarkId }
    }

    // MARK: - Reset

    func reset() {
        currentUser = nil
        isLoggedIn = false
        isOnboardingComplete = false
        isWelcomeComplete = false
        isPermissionsGranted = false
        hasAddedFriends = false
        isRefreshing = false
        users.removeAll()
        friends.removeAll()
        friendRequests.removeAll()
        resetCallCounts()
        resetMockBehavior()
    }

    func resetCallCounts() {
        fetchFriendsCallCount = 0
        fetchAllUsersCallCount = 0
        fetchUserCallCount = 0
        saveProfileCallCount = 0
        sendFriendRequestCallCount = 0
        acceptFriendRequestCallCount = 0
        rejectFriendRequestCallCount = 0
        addFriendCallCount = 0
        removeFriendCallCount = 0
        updateLocationCallCount = 0
        signOutCallCount = 0
        createNewUserCallCount = 0
        loginCallCount = 0
        refreshUserDataCallCount = 0
        prefetchProfileImagesCallCount = 0
    }

    func resetMockBehavior() {
        shouldFailOnSave = false
        shouldFailOnFetch = false
        shouldFailOnAuth = false
        mockError = nil
        mockUsernameTaken = false
        mockUserExists = false
    }
}

// MARK: - Test Setup Helpers

extension MockUserManager {

    /// Sets up a mock user manager with a logged-in user
    static func withLoggedInUser(_ user: User? = nil) -> MockUserManager {
        let manager = MockUserManager()
        let testUser = user ?? TestFixtures.sampleUser
        manager.users[testUser.id] = testUser
        manager.currentUser = testUser
        manager.isLoggedIn = true
        manager.isOnboardingComplete = true
        return manager
    }

    /// Sets up a mock user manager with multiple users
    static func withUsers(_ users: [User]) -> MockUserManager {
        let manager = MockUserManager()
        for user in users {
            manager.users[user.id] = user
        }
        if let first = users.first {
            manager.currentUser = first
            manager.isLoggedIn = true
        }
        return manager
    }

    /// Sets up a mock user manager with friends
    static func withFriends(_ friends: [User], currentUser: User? = nil) -> MockUserManager {
        let manager = MockUserManager()
        let user = currentUser ?? TestFixtures.sampleUser
        manager.users[user.id] = user
        manager.currentUser = user
        manager.isLoggedIn = true
        manager.friends = friends

        // Also add friends to users dictionary
        for friend in friends {
            manager.users[friend.id] = friend
        }

        return manager
    }
}
