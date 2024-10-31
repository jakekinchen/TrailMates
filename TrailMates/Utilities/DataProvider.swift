import Foundation
import CoreLocation
import UIKit

// MARK: - DataProvider Protocol
@MainActor
protocol DataProvider {
    // User operations
    func fetchCurrentUser() async -> User?
    func fetchUser(byPhoneNumber: String) async -> User?
    func fetchUser(by id: UUID) async -> User?
    func fetchFriends(for user: User) async -> [User]
    func fetchAllUsers() async -> [User]
    func saveUser(_ user: User) async
    
    // Event operations
    func fetchAllEvents() async -> [Event]
    func fetchEvent(by id: UUID) async -> Event?
    func fetchUserEvents(for userId: UUID) async -> [Event]
    func saveEvent(_ event: Event) async
    func deleteEvent(_ eventId: UUID) async
    
    // Combined operations
    func addFriend(_ friendId: UUID, to userId: UUID) async
    func removeFriend(_ friendId: UUID, from userId: UUID) async
}

// MARK: - MockDataProvider Implementation
class MockDataProvider: DataProvider {
    // MARK: - Properties
    private var users: [UUID: User]
    private var events: [UUID: Event]
    private let currentUserId: UUID
    
    // MARK: - Initialization
    init() {
        self.users = MockData.users
        self.events = MockData.events
        self.currentUserId = MockData.currentUserId
    }
    
    // MARK: - User Operations
    func fetchCurrentUser() async -> User? {
        return users[currentUserId]
    }
    
    func fetchUser(byPhoneNumber phoneNumber: String) async -> User? {
        return users.values.first { $0.phoneNumber == phoneNumber }
    }
    
    func fetchUser(by id: UUID) async -> User? {
        return users[id]
    }

    func fetchFriends(for user: User) async -> [User] {
        return user.friends.compactMap { users[$0] }
    }
    
    func fetchAllUsers() async -> [User] {
        return Array(users.values)
    }
    
    func saveUser(_ user: User) async {
        users[user.id] = user
    }
    
    // MARK: - Event Operations
    func fetchAllEvents() async -> [Event] {
        return Array(events.values)
    }
    
    func fetchEvent(by id: UUID) async -> Event? {
        return events[id]
    }
    
    func fetchUserEvents(for userId: UUID) async -> [Event] {
        return events.values.filter { event in
            event.hostId == userId || event.attendeeIds.contains(userId)
        }
    }
    
    func saveEvent(_ event: Event) async {
        events[event.id] = event
    }
    
    func deleteEvent(_ eventId: UUID) async {
        events.removeValue(forKey: eventId)
    }
    
    // MARK: - Combined Operations
    func addFriend(_ friendId: UUID, to userId: UUID) async {
        users[userId]?.friends.append(friendId)
        users[friendId]?.friends.append(userId)
    }
    
    func removeFriend(_ friendId: UUID, from userId: UUID) async {
        users[userId]?.friends.removeAll { $0 == friendId }
        users[friendId]?.friends.removeAll { $0 == userId }
    }
}

// MARK: - Preview Helpers
extension MockDataProvider {
    static var preview: MockDataProvider {
        return MockDataProvider()
    }
}
