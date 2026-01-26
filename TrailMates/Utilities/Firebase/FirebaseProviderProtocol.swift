import Foundation
import CoreLocation
import UIKit

// MARK: - Firebase Provider Protocols
// These protocols define the contract for Firebase data providers,
// enabling dependency injection and testability.

/// Protocol for user-related Firebase operations
protocol UserDataProviding {
    // Current user operations
    func fetchCurrentUser() async -> User?
    func isUserAuthenticated() -> Bool

    // User CRUD operations
    func fetchUser(by id: String) async -> User?
    func fetchAllUsers() async -> [User]
    func saveInitialUser(_ user: User) async throws
    func saveUser(_ user: User) async throws

    // User queries
    func fetchFriends(for user: User) async -> [User]
    func fetchUser(byPhoneNumber phoneNumber: String) async -> User?
    func checkUserExists(phoneNumber: String) async -> Bool
    func findUsersByPhoneNumbers(_ phoneNumbers: [String]) async throws -> [User]

    // Username operations
    func isUsernameTaken(_ username: String, excludingUserId: String?) async -> Bool
    func isUsernameTakenCloudFunction(_ username: String, excludingUserId: String?) async -> Bool

    // User observation
    func observeUser(id: String, onChange: @escaping (User?) -> Void)
    func stopObservingUser(id: String)
    func stopObservingAllUsers()
}

/// Protocol for event-related Firebase operations
protocol EventDataProviding {
    // Event CRUD operations
    func fetchAllEvents() async -> [Event]
    func fetchEvent(by id: String) async -> Event?
    func saveEvent(_ event: Event) async throws
    func deleteEvent(_ eventId: String) async throws
    func updateEventStatus(_ event: Event) async -> Event

    // Event queries
    func fetchUserEvents(for userId: String) async -> [Event]
    func fetchCircleEvents(for userId: String, friendIds: [String]) async -> [Event]
    func fetchPublicEvents() async -> [Event]
    func fetchAttendingEvents(for userId: String) async -> [Event]
    func fetchEvents(from startDate: Date, to endDate: Date) async -> [Event]

    // Utilities
    func generateNewEventReferenceAny() -> (reference: Any, id: String)
}

/// Protocol for friend-related Firebase operations
protocol FriendDataProviding {
    // Friend request operations
    func sendFriendRequest(fromUserId: String, to targetUserId: String) async throws
    func acceptFriendRequest(requestId: String, userId: String, friendId: String) async throws
    func rejectFriendRequest(requestId: String) async throws
    func updateFriendRequestStatus(requestId: String, targetUserId: String, status: FriendRequestStatus) async throws

    // Friend relationship operations
    func addFriend(_ friendId: String, to userId: String) async throws
    func removeFriend(_ friendId: String, from userId: String) async throws

    // Friend request observation
    func observeFriendRequests(for userId: String, completion: @escaping ([FriendRequest]) -> Void)
}

/// Protocol for image storage operations
protocol ImageStorageProviding {
    // Upload operations
    func uploadProfileImage(_ image: UIImage, for userId: String) async throws -> (fullUrl: String, thumbnailUrl: String)
    func deleteOldProfileImage(for userId: String) async

    // Download operations
    func downloadProfileImage(from url: String) async throws -> UIImage

    // Prefetch operations
    func prefetchProfileImages(urls: [String]) async

    // Cache management
    func clearCache()
    func removeFromCache(url: String)
}

/// Protocol for landmark-related Firebase operations
protocol LandmarkDataProviding {
    // Landmark queries
    func fetchTotalLandmarks() async -> Int
    func fetchAllLandmarks() async -> [Landmark]
    func fetchLandmark(by id: String) async -> Landmark?

    // User landmark operations
    func markLandmarkVisited(userId: String, landmarkId: String) async
    func unmarkLandmarkVisited(userId: String, landmarkId: String) async
    func fetchVisitedLandmarks(for userId: String) async -> [String]
}

/// Protocol for location-related Firebase operations
protocol LocationDataProviding {
    // Location update operations
    func updateUserLocation(userId: String, location: CLLocationCoordinate2D) async throws

    // Location observation
    func observeUserLocation(userId: String, completion: @escaping (CLLocationCoordinate2D?) -> Void)
    func stopObservingUserLocation(userId: String)
    func stopObservingAllLocations()
}

/// Protocol for notification-related Firebase operations
protocol NotificationDataProviding {
    // Send operations
    func sendNotification(to userId: String, type: NotificationType, fromUserId: String, content: String, relatedEventId: String?) async throws

    // Observation
    func observeNotifications(for userId: String, completion: @escaping ([TrailNotification]) -> Void)

    // Fetch operations
    func fetchNotifications(forId id: String, userID: String) async throws -> [TrailNotification]

    // Update operations
    func markNotificationAsRead(id: String, notificationId: String) async throws
    func deleteNotification(id: String, notificationId: String) async throws
}

// MARK: - Protocol Conformance Extensions

extension UserDataProvider: UserDataProviding {}

extension EventDataProvider: EventDataProviding {}

extension FriendDataProvider: FriendDataProviding {}
extension ImageStorageProvider: ImageStorageProviding {}
extension LandmarkDataProvider: LandmarkDataProviding {}
extension LocationDataProvider: LocationDataProviding {}
extension NotificationDataProvider: NotificationDataProviding {}

// MARK: - Provider Container for Dependency Injection

/// Container that holds all Firebase provider dependencies.
/// Use this for dependency injection in ViewModels and services.
///
/// Example usage:
/// ```swift
/// // Production code
/// let container = FirebaseProviderContainer.shared
///
/// // Test code
/// let mockContainer = FirebaseProviderContainer(
///     userProvider: MockUserDataProvider(),
///     eventProvider: MockEventDataProvider(),
///     ...
/// )
/// ```
final class FirebaseProviderContainer {
    // MARK: - Singleton (for production use)
    static let shared = FirebaseProviderContainer()

    // MARK: - Providers
    let userProvider: UserDataProviding
    let eventProvider: EventDataProviding
    let friendProvider: FriendDataProviding
    let imageProvider: ImageStorageProviding
    let landmarkProvider: LandmarkDataProviding
    let locationProvider: LocationDataProviding
    let notificationProvider: NotificationDataProviding

    // MARK: - Initialization

    /// Default initializer using production singletons
    private init() {
        self.userProvider = UserDataProvider.shared
        self.eventProvider = EventDataProvider.shared
        self.friendProvider = FriendDataProvider.shared
        self.imageProvider = ImageStorageProvider.shared
        self.landmarkProvider = LandmarkDataProvider.shared
        self.locationProvider = LocationDataProvider.shared
        self.notificationProvider = NotificationDataProvider.shared
    }

    /// Initializer for dependency injection (primarily for testing)
    init(
        userProvider: UserDataProviding,
        eventProvider: EventDataProviding,
        friendProvider: FriendDataProviding,
        imageProvider: ImageStorageProviding,
        landmarkProvider: LandmarkDataProviding,
        locationProvider: LocationDataProviding,
        notificationProvider: NotificationDataProviding
    ) {
        self.userProvider = userProvider
        self.eventProvider = eventProvider
        self.friendProvider = friendProvider
        self.imageProvider = imageProvider
        self.landmarkProvider = landmarkProvider
        self.locationProvider = locationProvider
        self.notificationProvider = notificationProvider
    }
}
