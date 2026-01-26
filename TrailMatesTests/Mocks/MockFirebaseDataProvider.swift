import Foundation
import CoreLocation
import UIKit
@testable import TrailMatesATX

/// A mock implementation of FirebaseDataProvider for testing purposes.
/// This mock allows tests to control Firebase responses without actual network calls.
class MockFirebaseDataProvider {
    // MARK: - Mock Data Storage
    var users: [String: User] = [:]
    var events: [String: Event] = [:]
    var friendRequests: [String: [FriendRequest]] = [:]

    // MARK: - Call Tracking
    var fetchCurrentUserCallCount = 0
    var fetchUserByIdCallCount = 0
    var fetchUserByPhoneCallCount = 0
    var saveUserCallCount = 0
    var saveInitialUserCallCount = 0
    var fetchAllEventsCallCount = 0
    var fetchEventByIdCallCount = 0
    var saveEventCallCount = 0
    var deleteEventCallCount = 0
    var checkUserExistsCallCount = 0
    var isUsernameTakenCallCount = 0
    var addFriendCallCount = 0
    var removeFriendCallCount = 0
    var sendFriendRequestCallCount = 0

    // MARK: - Mock Behavior Configuration
    var shouldFailOnSave = false
    var shouldFailOnFetch = false
    var mockError: Error?
    var mockCurrentUserId: String?
    var mockUsernameTaken = false
    var mockUserExists = false

    // MARK: - Generated IDs
    private var nextEventId = 1

    // MARK: - User Operations

    func fetchCurrentUser() async -> User? {
        fetchCurrentUserCallCount += 1
        if shouldFailOnFetch { return nil }
        guard let userId = mockCurrentUserId else { return nil }
        return users[userId]
    }

    func fetchUser(by id: String) async -> User? {
        fetchUserByIdCallCount += 1
        if shouldFailOnFetch { return nil }
        return users[id]
    }

    func fetchUser(byPhoneNumber phoneNumber: String) async -> User? {
        fetchUserByPhoneCallCount += 1
        if shouldFailOnFetch { return nil }
        let hashedNumber = PhoneNumberHasher.shared.hashPhoneNumber(phoneNumber)
        return users.values.first { $0.hashedPhoneNumber == hashedNumber }
    }

    func fetchAllUsers() async -> [User] {
        if shouldFailOnFetch { return [] }
        return Array(users.values)
    }

    func fetchFriends(for user: User) async -> [User] {
        if shouldFailOnFetch { return [] }
        return user.friends.compactMap { users[$0] }
    }

    func saveInitialUser(_ user: User) async throws {
        saveInitialUserCallCount += 1
        if shouldFailOnSave {
            throw mockError ?? MockError.saveFailed
        }
        users[user.id] = user
    }

    func saveUser(_ user: User) async throws {
        saveUserCallCount += 1
        if shouldFailOnSave {
            throw mockError ?? MockError.saveFailed
        }
        users[user.id] = user
    }

    func checkUserExists(phoneNumber: String) async -> Bool {
        checkUserExistsCallCount += 1
        if mockUserExists { return true }
        let hashedNumber = PhoneNumberHasher.shared.hashPhoneNumber(phoneNumber)
        return users.values.contains { $0.hashedPhoneNumber == hashedNumber }
    }

    func isUsernameTaken(_ username: String, excludingUserId: String?) async -> Bool {
        isUsernameTakenCallCount += 1
        if mockUsernameTaken { return true }
        return users.values.contains { user in
            user.username == username && user.id != excludingUserId
        }
    }

    func findUsersByPhoneNumbers(_ phoneNumbers: [String]) async throws -> [User] {
        if shouldFailOnFetch {
            throw mockError ?? MockError.fetchFailed
        }
        let hashedNumbers = phoneNumbers.map { PhoneNumberHasher.shared.hashPhoneNumber($0) }
        return users.values.filter { hashedNumbers.contains($0.hashedPhoneNumber) }
    }

    // MARK: - Event Operations

    func fetchAllEvents() async -> [Event] {
        fetchAllEventsCallCount += 1
        if shouldFailOnFetch { return [] }
        return Array(events.values)
    }

    func fetchEvent(by id: String) async -> Event? {
        fetchEventByIdCallCount += 1
        if shouldFailOnFetch { return nil }
        return events[id]
    }

    func saveEvent(_ event: Event) async throws {
        saveEventCallCount += 1
        if shouldFailOnSave {
            throw mockError ?? MockError.saveFailed
        }
        events[event.id] = event
    }

    func deleteEvent(_ eventId: String) async throws {
        deleteEventCallCount += 1
        if shouldFailOnSave {
            throw mockError ?? MockError.deleteFailed
        }
        events.removeValue(forKey: eventId)
    }

    func generateNewEventReference() -> (reference: Any, id: String) {
        let id = "mock-event-\(nextEventId)"
        nextEventId += 1
        return (NSObject(), id)
    }

    // MARK: - Friend Operations

    func sendFriendRequest(fromUserId: String, to targetUserId: String) async throws {
        sendFriendRequestCallCount += 1
        if shouldFailOnSave {
            throw mockError ?? MockError.saveFailed
        }
        let request = FriendRequest(
            id: UUID().uuidString,
            fromUserId: fromUserId,
            timestamp: Date(),
            status: .pending
        )
        var requests = friendRequests[targetUserId] ?? []
        requests.append(request)
        friendRequests[targetUserId] = requests
    }

    func acceptFriendRequest(requestId: String, userId: String, friendId: String) async throws {
        if shouldFailOnSave {
            throw mockError ?? MockError.saveFailed
        }
        try await addFriend(friendId, to: userId)
    }

    func rejectFriendRequest(requestId: String) async throws {
        if shouldFailOnSave {
            throw mockError ?? MockError.saveFailed
        }
        // Remove request from all users' request lists
        for (userId, requests) in friendRequests {
            friendRequests[userId] = requests.filter { $0.id != requestId }
        }
    }

    func addFriend(_ friendId: String, to userId: String) async throws {
        addFriendCallCount += 1
        if shouldFailOnSave {
            throw mockError ?? MockError.saveFailed
        }
        if var user = users[userId], var friend = users[friendId] {
            if !user.friends.contains(friendId) {
                user.friends.append(friendId)
                users[userId] = user
            }
            if !friend.friends.contains(userId) {
                friend.friends.append(userId)
                users[friendId] = friend
            }
        }
    }

    func removeFriend(_ friendId: String, from userId: String) async throws {
        removeFriendCallCount += 1
        if shouldFailOnSave {
            throw mockError ?? MockError.saveFailed
        }
        if var user = users[userId], var friend = users[friendId] {
            user.friends.removeAll { $0 == friendId }
            friend.friends.removeAll { $0 == userId }
            users[userId] = user
            users[friendId] = friend
        }
    }

    // MARK: - Observer Methods (No-ops for testing)

    func observeUser(id: String, onChange: @escaping (User?) -> Void) {
        // Immediately call with current user for testing
        onChange(users[id])
    }

    func stopObservingUser(id: String) {
        // No-op for testing
    }

    // MARK: - Location Operations

    func updateUserLocation(userId: String, location: CLLocationCoordinate2D) async throws {
        if shouldFailOnSave {
            throw mockError ?? MockError.saveFailed
        }
        if var user = users[userId] {
            user.location = location
            users[userId] = user
        }
    }

    // MARK: - Profile Image Operations

    func uploadProfileImage(_ image: UIImage, for userId: String) async throws -> (fullUrl: String, thumbnailUrl: String) {
        if shouldFailOnSave {
            throw mockError ?? MockError.uploadFailed
        }
        let fullUrl = "https://mock-storage.example.com/\(userId)/full.jpg"
        let thumbnailUrl = "https://mock-storage.example.com/\(userId)/thumbnail.jpg"
        return (fullUrl: fullUrl, thumbnailUrl: thumbnailUrl)
    }

    func downloadProfileImage(from url: String) async throws -> UIImage {
        if shouldFailOnFetch {
            throw mockError ?? MockError.downloadFailed
        }
        // Return a simple 1x1 pixel image for testing
        return UIImage(systemName: "person.circle") ?? UIImage()
    }

    func prefetchProfileImages(urls: [String]) async {
        // No-op for testing
    }

    // MARK: - Landmark Operations

    func fetchTotalLandmarks() async -> Int {
        return 10 // Mock value
    }

    func markLandmarkVisited(userId: String, landmarkId: String) async {
        if var user = users[userId] {
            if !user.visitedLandmarkIds.contains(landmarkId) {
                user.visitedLandmarkIds.append(landmarkId)
                users[userId] = user
            }
        }
    }

    func unmarkLandmarkVisited(userId: String, landmarkId: String) async {
        if var user = users[userId] {
            user.visitedLandmarkIds.removeAll { $0 == landmarkId }
            users[userId] = user
        }
    }

    // MARK: - Reset

    func reset() {
        users.removeAll()
        events.removeAll()
        friendRequests.removeAll()
        resetCallCounts()
        resetMockBehavior()
    }

    func resetCallCounts() {
        fetchCurrentUserCallCount = 0
        fetchUserByIdCallCount = 0
        fetchUserByPhoneCallCount = 0
        saveUserCallCount = 0
        saveInitialUserCallCount = 0
        fetchAllEventsCallCount = 0
        fetchEventByIdCallCount = 0
        saveEventCallCount = 0
        deleteEventCallCount = 0
        checkUserExistsCallCount = 0
        isUsernameTakenCallCount = 0
        addFriendCallCount = 0
        removeFriendCallCount = 0
        sendFriendRequestCallCount = 0
    }

    func resetMockBehavior() {
        shouldFailOnSave = false
        shouldFailOnFetch = false
        mockError = nil
        mockCurrentUserId = nil
        mockUsernameTaken = false
        mockUserExists = false
    }
}

// MARK: - Mock Errors

enum MockError: LocalizedError {
    case saveFailed
    case fetchFailed
    case deleteFailed
    case uploadFailed
    case downloadFailed
    case userNotFound
    case eventNotFound

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "Mock save operation failed"
        case .fetchFailed:
            return "Mock fetch operation failed"
        case .deleteFailed:
            return "Mock delete operation failed"
        case .uploadFailed:
            return "Mock upload operation failed"
        case .downloadFailed:
            return "Mock download operation failed"
        case .userNotFound:
            return "Mock user not found"
        case .eventNotFound:
            return "Mock event not found"
        }
    }
}
