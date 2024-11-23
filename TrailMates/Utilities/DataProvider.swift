import Foundation
import CoreLocation
import UIKit

// MARK: - DataProvider Protocol
protocol DataProvider {
    // User operations
    func fetchCurrentUser() async -> User?
    func fetchUser(byPhoneNumber: String) async -> User?
    func fetchUser(by id: UUID) async -> User?
    func fetchFriends(for user: User) async -> [User]
    func fetchAllUsers() async -> [User]
    func saveUser(_ user: User) async throws
    func saveInitialUser(_ user: User) async throws
    
    // Event operations
    func fetchAllEvents() async -> [Event]
    func fetchEvent(by id: UUID) async -> Event?
    func fetchUserEvents(for userId: UUID) async -> [Event]
    func fetchCircleEvents(for userId: UUID, friendIds: [UUID]) async -> [Event]
    func fetchPublicEvents() async -> [Event]
    func saveEvent(_ event: Event) async throws
    func deleteEvent(_ eventId: UUID) async throws
    func updateEventStatus(_ event: Event) async -> Event
    
    // Friend operations
    func sendFriendRequest(from userId: UUID, to targetUserId: UUID) async throws
    func acceptFriendRequest(requestId: String, userId: UUID, friendId: UUID) async throws
    func rejectFriendRequest(requestId: String) async throws
    func addFriend(_ friendId: UUID, to userId: UUID) async throws
    func removeFriend(_ friendId: UUID, from userId: UUID) async throws
    
    // Location operations
    func updateUserLocation(userId: UUID, location: CLLocationCoordinate2D) async throws
    func observeUserLocation(userId: UUID, completion: @escaping (CLLocationCoordinate2D?) -> Void)
    
    // Landmark operations
    func fetchTotalLandmarks() async -> Int
    func markLandmarkVisited(userId: UUID, landmarkId: UUID) async
    func unmarkLandmarkVisited(userId: UUID, landmarkId: UUID) async
    
    // Notification operations
    func fetchNotifications(for userId: UUID) async throws -> [TrailNotification]
    func markNotificationAsRead(userId: UUID, notificationId: UUID) async throws
    func deleteNotification(userId: UUID, notificationId: UUID) async throws
    
    // Utility operations
    func isUsernameTaken(_ username: String, excludingUserId: UUID?) async -> Bool
    func fetchUsersByFacebookIds(_ facebookIds: [String]) async -> [User]
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
    
    func saveUser(_ user: User) async throws {
        users[user.id] = user
    }
    
    func saveInitialUser(_ user: User) async throws {
        // TO DO: implement save initial user logic
    }
    
    func isUsernameTaken(_ username: String, excludingUserId: UUID?) async -> Bool {
            let allUsers = Array(users.values)
            return allUsers.contains { user in
                user.username.lowercased() == username.lowercased() && user.id != excludingUserId
            }
        }
    
    // Facebook operations
    func fetchUsersByFacebookIds(_ facebookIds: [String]) async -> [User] {
            // Filter users who have matching Facebook IDs
            return Array(users.values).filter { user in
                guard let userFacebookId = user.facebookId else { return false }
                return facebookIds.contains(userFacebookId)
            }
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
    
    func fetchCircleEvents(for userId: UUID, friendIds: [UUID]) async -> [Event] {
        return events.values.filter { event in
            (event.hostId == userId || friendIds.contains(event.hostId)) &&
            (event.status == .upcoming || event.status == .active)
        }.sorted { $0.dateTime < $1.dateTime }
    }
    
    func fetchPublicEvents() async -> [Event] {
        return events.values.filter { event in
            !event.isPublic &&
            (event.status == .upcoming || event.status == .active)
        }.sorted { $0.dateTime < $1.dateTime }
    }
    
    func saveEvent(_ event: Event) async throws {
        events[event.id] = event
    }
    
    func deleteEvent(_ eventId: UUID) async throws {
        events.removeValue(forKey: eventId)
    }
    
    func updateEventStatus(_ event: Event) async -> Event {
        var updatedEvent = event
        let now = Date()
        
        if now > event.dateTime.addingTimeInterval(30 * 60) {
            updatedEvent.status = .completed
        } else if now >= event.dateTime &&
                  now <= event.dateTime.addingTimeInterval(30 * 60) {
            updatedEvent.status = .active
        } else {
            updatedEvent.status = .upcoming
        }
        
        events[event.id] = updatedEvent
        return updatedEvent
    }
    
    // MARK: - Combined Operations
    func addFriend(_ friendId: UUID, to userId: UUID) async throws {
        users[userId]?.friends.append(friendId)
        users[friendId]?.friends.append(userId)
    }
    
    func removeFriend(_ friendId: UUID, from userId: UUID) async throws {
        users[userId]?.friends.removeAll { $0 == friendId }
        users[friendId]?.friends.removeAll { $0 == userId }
    }
    
    // MARK: - Landmark Operations
    
    func fetchTotalLandmarks() async -> Int {
            return Locations.items.count
        }
        
        func markLandmarkVisited(userId: UUID, landmarkId: UUID) async {
            if var user = users[userId] {
                if !user.visitedLandmarkIds.contains(landmarkId) {
                    user.visitedLandmarkIds.append(landmarkId)
                    users[userId] = user
                }
            }
        }
        
        func unmarkLandmarkVisited(userId: UUID, landmarkId: UUID) async {
            if var user = users[userId] {
                user.visitedLandmarkIds.removeAll { $0 == landmarkId }
                users[userId] = user
            }
        }
        
        // MARK: - Location Operations
        func updateUserLocation(userId: UUID, location: CLLocationCoordinate2D) async throws {
            if var user = users[userId] {
                user.location = location
                users[userId] = user
            }
        }
    
    // MARK: - Friend Operations
    func sendFriendRequest(from userId: UUID, to targetUserId: UUID) async throws {
        // TO DO: implement friend request logic
    }
    
    func acceptFriendRequest(requestId: String, userId: UUID, friendId: UUID) async throws {
        // TO DO: implement accept friend request logic
    }
    
    func rejectFriendRequest(requestId: String) async throws {
        // TO DO: implement reject friend request logic
    }
    
    // MARK: - Notification Operations
    func fetchNotifications(for userId: UUID) async throws -> [TrailNotification] {
        // TO DO: implement fetch notifications logic
        return []
    }
    
    func markNotificationAsRead(userId: UUID, notificationId: UUID) async throws {
        // TO DO: implement mark notification as read logic
    }
    
    func deleteNotification(userId: UUID, notificationId: UUID) async throws {
        // TO DO: implement delete notification logic
    }
    
    // MARK: - Location Operations
    func observeUserLocation(userId: UUID, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        // TO DO: implement observe user location logic
    }
}

// MARK: - Preview Helpers
extension MockDataProvider {
    static var preview: MockDataProvider {
        return MockDataProvider()
    }
}
