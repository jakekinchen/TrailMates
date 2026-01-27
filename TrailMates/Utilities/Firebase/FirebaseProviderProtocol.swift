import Foundation
import CoreLocation
import UIKit

// MARK: - Firebase Provider Protocols
// These protocols define the contract for Firebase data providers,
// enabling dependency injection and testability.

/// Protocol for user-related Firebase operations.
///
/// Provides methods for user authentication state, CRUD operations,
/// and real-time observation of user data changes.
///
/// All methods are `@MainActor` isolated to ensure UI safety.
@MainActor
protocol UserDataProviding {
    // MARK: - Current User Operations

    /// Fetches the currently authenticated user from Firebase.
    /// - Returns: The current `User` if authenticated, `nil` otherwise.
    func fetchCurrentUser() async -> User?

    /// Checks if there is a currently authenticated user.
    /// - Returns: `true` if a user is authenticated, `false` otherwise.
    func isUserAuthenticated() -> Bool

    // MARK: - User CRUD Operations

    /// Fetches a user by their unique identifier.
    /// - Parameter id: The Firebase user ID.
    /// - Returns: The `User` if found, `nil` otherwise.
    func fetchUser(by id: String) async -> User?

    /// Fetches all users from the database.
    /// - Returns: Array of all `User` objects.
    func fetchAllUsers() async -> [User]

    /// Saves a new user to the database during initial registration.
    /// - Parameter user: The user to save.
    /// - Throws: `AppError` if the save operation fails.
    func saveInitialUser(_ user: User) async throws

    /// Updates an existing user in the database.
    /// - Parameter user: The user with updated data.
    /// - Throws: `AppError` if the update operation fails.
    func saveUser(_ user: User) async throws

    // MARK: - User Queries

    /// Fetches all friends for a given user.
    /// - Parameter user: The user whose friends to fetch.
    /// - Returns: Array of `User` objects representing friends.
    func fetchFriends(for user: User) async -> [User]

    /// Finds a user by their phone number.
    /// - Parameter phoneNumber: The phone number to search (E.164 format preferred).
    /// - Returns: The matching `User` if found, `nil` otherwise.
    func fetchUser(byPhoneNumber phoneNumber: String) async -> User?

    /// Checks if a user exists with the given phone number.
    /// - Parameter phoneNumber: The phone number to check (E.164 format preferred).
    /// - Returns: `true` if a user exists, `false` otherwise.
    func checkUserExists(phoneNumber: String) async -> Bool

    /// Ensures there is a Firestore user document at `/users/{uid}` for the currently
    /// authenticated user, migrating legacy records when needed.
    /// - Throws: `AppError` if the ensure/migration operation fails.
    func ensureUserDocument() async throws

    /// Finds multiple users by their phone numbers.
    /// - Parameter phoneNumbers: Array of phone numbers to search.
    /// - Returns: Array of matching `User` objects.
    /// - Throws: `AppError` if the query fails.
    func findUsersByPhoneNumbers(_ phoneNumbers: [String]) async throws -> [User]

    // MARK: - Username Operations

    /// Checks if a username is already taken (local query).
    /// - Parameters:
    ///   - username: The username to check.
    ///   - excludingUserId: Optional user ID to exclude (for updates).
    /// - Returns: `true` if the username is taken, `false` otherwise.
    func isUsernameTaken(_ username: String, excludingUserId: String?) async -> Bool

    /// Checks if a username is already taken using Cloud Function.
    /// More reliable for high-concurrency scenarios.
    /// - Parameters:
    ///   - username: The username to check.
    ///   - excludingUserId: Optional user ID to exclude (for updates).
    /// - Returns: `true` if the username is taken, `false` otherwise.
    func isUsernameTakenCloudFunction(_ username: String, excludingUserId: String?) async -> Bool

    // MARK: - User Observation

    /// Starts observing a user for real-time updates.
    /// - Parameters:
    ///   - id: The user ID to observe.
    ///   - onChange: Callback invoked when the user data changes.
    func observeUser(id: String, onChange: @escaping (User?) -> Void)

    /// Stops observing a specific user.
    /// - Parameter id: The user ID to stop observing.
    func stopObservingUser(id: String)

    /// Stops all active user observations.
    func stopObservingAllUsers()
}

/// Protocol for event-related Firebase operations.
///
/// Provides methods for creating, reading, updating, and deleting events,
/// as well as various query methods for filtering events.
@MainActor
protocol EventDataProviding {
    // MARK: - Event CRUD Operations

    /// Fetches all events from the database.
    /// - Returns: Array of all `Event` objects.
    func fetchAllEvents() async -> [Event]

    /// Fetches a single event by its ID.
    /// - Parameter id: The event's unique identifier.
    /// - Returns: The `Event` if found, `nil` otherwise.
    func fetchEvent(by id: String) async -> Event?

    /// Saves a new event or updates an existing event.
    /// - Parameter event: The event to save.
    /// - Throws: `AppError` if the save operation fails.
    func saveEvent(_ event: Event) async throws

    /// Deletes an event from the database.
    /// - Parameter eventId: The ID of the event to delete.
    /// - Throws: `AppError` if the delete operation fails.
    func deleteEvent(_ eventId: String) async throws

    /// Updates the status of an event (active, cancelled, completed).
    /// - Parameter event: The event to update.
    /// - Returns: The updated `Event` with new status.
    func updateEventStatus(_ event: Event) async -> Event

    // MARK: - Event Queries

    /// Fetches all events created by a specific user.
    /// - Parameter userId: The creator's user ID.
    /// - Returns: Array of events created by the user.
    func fetchUserEvents(for userId: String) async -> [Event]

    /// Fetches events visible in a user's circle (friends' events).
    /// - Parameters:
    ///   - userId: The current user's ID.
    ///   - friendIds: Array of friend user IDs.
    /// - Returns: Array of events from the user's circle.
    func fetchCircleEvents(for userId: String, friendIds: [String]) async -> [Event]

    /// Fetches all public events.
    /// - Returns: Array of public `Event` objects.
    func fetchPublicEvents() async -> [Event]

    /// Fetches events the user is attending.
    /// - Parameter userId: The user's ID.
    /// - Returns: Array of events the user is attending.
    func fetchAttendingEvents(for userId: String) async -> [Event]

    /// Fetches events within a date range.
    /// - Parameters:
    ///   - startDate: The start of the date range.
    ///   - endDate: The end of the date range.
    /// - Returns: Array of events within the date range.
    func fetchEvents(from startDate: Date, to endDate: Date) async -> [Event]

    // MARK: - Utilities

    /// Generates a new Firebase document reference for an event.
    /// - Returns: A tuple containing the Firestore reference and the generated ID.
    func generateNewEventReferenceAny() -> (reference: Any, id: String)
}

/// Protocol for friend-related Firebase operations.
///
/// Handles friend requests, friend relationships, and real-time
/// observation of incoming friend requests.
@MainActor
protocol FriendDataProviding {
    // MARK: - Friend Request Operations

    /// Sends a friend request from one user to another.
    /// - Parameters:
    ///   - fromUserId: The sender's user ID.
    ///   - targetUserId: The recipient's user ID.
    /// - Throws: `AppError` if the request fails or already exists.
    func sendFriendRequest(fromUserId: String, to targetUserId: String) async throws

    /// Accepts a pending friend request.
    /// - Parameters:
    ///   - requestId: The friend request document ID.
    ///   - userId: The accepting user's ID.
    ///   - friendId: The requesting user's ID.
    /// - Throws: `AppError` if the acceptance fails.
    func acceptFriendRequest(requestId: String, userId: String, friendId: String) async throws

    /// Rejects a pending friend request.
    /// - Parameter requestId: The friend request document ID.
    /// - Throws: `AppError` if the rejection fails.
    func rejectFriendRequest(requestId: String) async throws

    /// Updates the status of a friend request.
    /// - Parameters:
    ///   - requestId: The friend request document ID.
    ///   - targetUserId: The target user's ID.
    ///   - status: The new status (pending, accepted, rejected).
    /// - Throws: `AppError` if the update fails.
    func updateFriendRequestStatus(requestId: String, targetUserId: String, status: FriendRequestStatus) async throws

    // MARK: - Friend Relationship Operations

    /// Adds a friend relationship between two users.
    /// - Parameters:
    ///   - friendId: The friend's user ID.
    ///   - userId: The user's ID.
    /// - Throws: `AppError` if adding the friend fails.
    func addFriend(_ friendId: String, to userId: String) async throws

    /// Removes a friend relationship between two users.
    /// - Parameters:
    ///   - friendId: The friend's user ID to remove.
    ///   - userId: The user's ID.
    /// - Throws: `AppError` if removing the friend fails.
    func removeFriend(_ friendId: String, from userId: String) async throws

    // MARK: - Friend Request Observation

    /// Observes incoming friend requests for a user in real-time.
    /// - Parameters:
    ///   - userId: The user ID to observe requests for.
    ///   - completion: Callback invoked when friend requests change.
    func observeFriendRequests(for userId: String, completion: @escaping ([FriendRequest]) -> Void)
}

/// Protocol for image storage operations.
///
/// Handles profile image upload, download, caching, and prefetching
/// using Firebase Storage.
@MainActor
protocol ImageStorageProviding {
    // MARK: - Upload Operations

    /// Uploads a profile image to Firebase Storage.
    /// Creates both full-size and thumbnail versions.
    /// - Parameters:
    ///   - image: The image to upload.
    ///   - userId: The user's ID for storage path.
    /// - Returns: Tuple containing URLs for the full image and thumbnail.
    /// - Throws: `AppError.imageProcessingFailed` if upload fails.
    func uploadProfileImage(_ image: UIImage, for userId: String) async throws -> (fullUrl: String, thumbnailUrl: String)

    /// Deletes the old profile image when updating.
    /// - Parameter userId: The user's ID whose old image should be deleted.
    func deleteOldProfileImage(for userId: String) async

    // MARK: - Download Operations

    /// Downloads a profile image from a URL.
    /// - Parameter url: The image URL to download from.
    /// - Returns: The downloaded `UIImage`.
    /// - Throws: `AppError.imageDownloadFailed` if download fails.
    func downloadProfileImage(from url: String) async throws -> UIImage

    // MARK: - Prefetch Operations

    /// Prefetches multiple profile images for better performance.
    /// - Parameter urls: Array of image URLs to prefetch.
    func prefetchProfileImages(urls: [String]) async

    // MARK: - Cache Management

    /// Clears the entire image cache.
    func clearCache()

    /// Removes a specific image from the cache.
    /// - Parameter url: The URL of the image to remove from cache.
    func removeFromCache(url: String)
}

/// Protocol for landmark-related Firebase operations.
///
/// Manages trail landmarks and tracks user visits to landmarks.
@MainActor
protocol LandmarkDataProviding {
    // MARK: - Landmark Queries

    /// Fetches the total count of landmarks in the database.
    /// - Returns: The total number of landmarks.
    func fetchTotalLandmarks() async -> Int

    /// Fetches all landmarks from the database.
    /// - Returns: Array of all `Landmark` objects.
    func fetchAllLandmarks() async -> [Landmark]

    /// Fetches a single landmark by its ID.
    /// - Parameter id: The landmark's unique identifier.
    /// - Returns: The `Landmark` if found, `nil` otherwise.
    func fetchLandmark(by id: String) async -> Landmark?

    // MARK: - User Landmark Operations

    /// Marks a landmark as visited by the user.
    /// - Parameters:
    ///   - userId: The user's ID.
    ///   - landmarkId: The landmark's ID.
    func markLandmarkVisited(userId: String, landmarkId: String) async

    /// Removes the visited mark from a landmark.
    /// - Parameters:
    ///   - userId: The user's ID.
    ///   - landmarkId: The landmark's ID.
    func unmarkLandmarkVisited(userId: String, landmarkId: String) async

    /// Fetches all landmark IDs the user has visited.
    /// - Parameter userId: The user's ID.
    /// - Returns: Array of visited landmark IDs.
    func fetchVisitedLandmarks(for userId: String) async -> [String]
}

/// Protocol for location-related Firebase operations.
///
/// Handles real-time location updates and observation for users,
/// enabling features like friend location sharing on maps.
@MainActor
protocol LocationDataProviding {
    // MARK: - Location Update Operations

    /// Updates the user's current location in the database.
    /// - Parameters:
    ///   - userId: The user's ID.
    ///   - location: The user's current coordinates.
    /// - Throws: `AppError` if the update fails.
    func updateUserLocation(userId: String, location: CLLocationCoordinate2D) async throws

    // MARK: - Location Observation

    /// Starts observing a user's location for real-time updates.
    /// - Parameters:
    ///   - userId: The user ID to observe.
    ///   - completion: Callback invoked when location changes.
    func observeUserLocation(userId: String, completion: @escaping (CLLocationCoordinate2D?) -> Void)

    /// Stops observing a specific user's location.
    /// - Parameter userId: The user ID to stop observing.
    func stopObservingUserLocation(userId: String)

    /// Stops all active location observations.
    func stopObservingAllLocations()
}

/// Protocol for notification-related Firebase operations.
///
/// Handles in-app notifications for friend requests, event invites,
/// and other user interactions.
@MainActor
protocol NotificationDataProviding {
    // MARK: - Send Operations

    /// Sends a notification to a user.
    /// - Parameters:
    ///   - userId: The recipient's user ID.
    ///   - type: The notification type (friendRequest, eventInvite, etc.).
    ///   - fromUserId: The sender's user ID.
    ///   - content: The notification message content.
    ///   - relatedEventId: Optional event ID for event-related notifications.
    /// - Throws: `AppError` if sending fails.
    func sendNotification(to userId: String, type: NotificationType, fromUserId: String, content: String, relatedEventId: String?) async throws

    // MARK: - Observation

    /// Observes notifications for a user in real-time.
    /// - Parameters:
    ///   - userId: The user ID to observe notifications for.
    ///   - completion: Callback invoked when notifications change.
    func observeNotifications(for userId: String, completion: @escaping ([TrailNotification]) -> Void)

    // MARK: - Fetch Operations

    /// Fetches notifications for a specific user.
    /// - Parameters:
    ///   - id: The notification collection ID.
    ///   - userID: The user's ID.
    /// - Returns: Array of `TrailNotification` objects.
    /// - Throws: `AppError` if the fetch fails.
    func fetchNotifications(forId id: String, userID: String) async throws -> [TrailNotification]

    // MARK: - Update Operations

    /// Marks a notification as read.
    /// - Parameters:
    ///   - id: The notification collection ID.
    ///   - notificationId: The specific notification ID.
    /// - Throws: `AppError` if the update fails.
    func markNotificationAsRead(id: String, notificationId: String) async throws

    /// Deletes a notification.
    /// - Parameters:
    ///   - id: The notification collection ID.
    ///   - notificationId: The specific notification ID.
    /// - Throws: `AppError` if the deletion fails.
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
@MainActor
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
