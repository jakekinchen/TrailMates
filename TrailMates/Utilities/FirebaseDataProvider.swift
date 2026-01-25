import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import FirebaseDatabase
import CoreLocation
import SwiftUI
import FirebaseStorage

/// FirebaseDataProvider serves as a facade/coordinator for all Firebase operations.
/// For new code, prefer using the focused sub-providers directly:
/// - UserDataProvider: User CRUD, authentication, username operations
/// - EventDataProvider: Event CRUD and queries
/// - FriendDataProvider: Friend requests and relationships
/// - ImageStorageProvider: Profile image upload/download
/// - LandmarkDataProvider: Landmark operations
/// - LocationDataProvider: Real-time location updates
/// - NotificationDataProvider: Push notifications
///
/// Methods in this class are being progressively deprecated in favor of sub-providers.
class FirebaseDataProvider {
    // MARK: - Singleton
    static let shared = FirebaseDataProvider()

    // MARK: - Sub-providers (preferred for new code)
    private let userProvider = UserDataProvider.shared
    private let eventProvider = EventDataProvider.shared
    private let friendProvider = FriendDataProvider.shared
    private let imageProvider = ImageStorageProvider.shared
    private let landmarkProvider = LandmarkDataProvider.shared
    private let locationProvider = LocationDataProvider.shared
    private let notificationProvider = NotificationDataProvider.shared

    // MARK: - Legacy Firebase services (used for operations not yet migrated)
    private lazy var db = Firestore.firestore()
    private lazy var functions: Functions = {
        let functions = Functions.functions(region: "us-central1")
        #if DEBUG
        print("🔥 Initializing Firebase Functions in DEBUG mode")
        functions.useEmulator(withHost: "127.0.0.1", port: 5001)
        #endif
        return functions
    }()
    let functionURL = URL(string: "https://us-central1-trailmates-atx.cloudfunctions.net/checkUserExists")!
    private lazy var rtdb = Database.database().reference()
    private lazy var storage = Storage.storage().reference()
    private lazy var auth = Auth.auth()
    
    // Store active listeners
    private var activeListeners: [String: DatabaseHandle] = [:]
    private var firestoreListeners: [String: ListenerRegistration] = [:]
    private var userListeners = [String: ListenerRegistration]()

    
    // Add property to store auth listener
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    private init() {
        // Initialize Firebase references
        rtdb = Database.database().reference()
        db = Firestore.firestore()
        auth = Auth.auth()

        // Configure Firestore settings
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings()
        db.settings = settings

        // Store auth listener to prevent it from being deallocated
        authStateListener = auth.addStateDidChangeListener { (auth, user) in
            if let user = user {
                print("🔥 Auth: User signed in - \(user.uid)")
            } else {
                print("🔥 Auth: User signed out")
            }
        }

        // Set up memory warning observer to clear image cache under pressure
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }

        print("🔥 FirebaseDataProvider init started - Services will be initialized on first use")
    }

    private func handleMemoryWarning() {
        print("⚠️ Memory warning received - clearing image cache")
        imageProvider.clearCache()
    }
    
    deinit {
        // Remove auth listener when provider is deallocated
        if let listener = authStateListener {
            auth.removeStateDidChangeListener(listener)
        }

        // Remove memory warning observer
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        // Clean up all active listeners
        removeAllListeners()
    }
    
    private func removeAllListeners() {
        // Clean up RTDB listeners
        activeListeners.forEach { path, handle in
            rtdb.child(path).removeObserver(withHandle: handle)
        }
        activeListeners.removeAll()

        // Clean up Firestore listeners
        firestoreListeners.forEach { _, listener in
            listener.remove()
        }
        firestoreListeners.removeAll()

        // Clean up user-specific Firestore listeners
        userListeners.forEach { _, listener in
            listener.remove()
        }
        userListeners.removeAll()

        print("FirebaseDataProvider: Removed all listeners (RTDB: \(activeListeners.count), Firestore: \(firestoreListeners.count), Users: \(userListeners.count))")
    }
    
    // MARK: - User Operations (Deprecated - use UserDataProvider.shared instead)

    @available(*, deprecated, message: "Use UserDataProvider.shared.fetchCurrentUser() instead")
    func fetchCurrentUser() async -> User? {
        return await userProvider.fetchCurrentUser()
    }

    @available(*, deprecated, message: "Use UserDataProvider.shared.isUserAuthenticated() instead")
    func isUserAuthenticated() -> Bool {
        return userProvider.isUserAuthenticated()
    }

    @available(*, deprecated, message: "Use UserDataProvider.shared.isUsernameTakenCloudFunction() instead")
    func isUsernameTakenCloudFunction(_ username: String, excludingUserId: String?) async -> Bool {
        return await userProvider.isUsernameTakenCloudFunction(username, excludingUserId: excludingUserId)
    }

    @available(*, deprecated, message: "Use UserDataProvider.shared.findUsersByPhoneNumbers() instead")
    func findUsersByPhoneNumbers(_ phoneNumbers: [String]) async throws -> [User] {
        return try await userProvider.findUsersByPhoneNumbers(phoneNumbers)
    }

    @available(*, deprecated, message: "Use UserDataProvider.shared.fetchUser(byPhoneNumber:) instead")
    func fetchUser(byPhoneNumber phoneNumber: String) async -> User? {
        return await userProvider.fetchUser(byPhoneNumber: phoneNumber)
    }

    @available(*, deprecated, message: "Use UserDataProvider.shared.checkUserExists() instead")
    func checkUserExists(phoneNumber: String) async -> Bool {
        return await userProvider.checkUserExists(phoneNumber: phoneNumber)
    }

    @available(*, deprecated, message: "Use UserDataProvider.shared.fetchUser(by:) instead")
    func fetchUser(by id: String) async -> User? {
        return await userProvider.fetchUser(by: id)
    }

    @available(*, deprecated, message: "Use UserDataProvider.shared.fetchFriends() instead")
    func fetchFriends(for user: User) async -> [User] {
        return await userProvider.fetchFriends(for: user)
    }

    @available(*, deprecated, message: "Use UserDataProvider.shared.fetchAllUsers() instead")
    func fetchAllUsers() async -> [User] {
        return await userProvider.fetchAllUsers()
    }
    
    @available(*, deprecated, message: "Use UserDataProvider.shared.saveInitialUser() instead")
    func saveInitialUser(_ user: User) async throws {
        try await userProvider.saveInitialUser(user)
    }

    @available(*, deprecated, message: "Use UserDataProvider.shared.saveUser() instead")
    func saveUser(_ user: User) async throws {
        try await userProvider.saveUser(user)
    }

    @available(*, deprecated, message: "Use UserDataProvider.shared.observeUser() instead")
    func observeUser(id: String, onChange: @escaping (User?) -> Void) {
        userProvider.observeUser(id: id, onChange: onChange)
    }

    @available(*, deprecated, message: "Use UserDataProvider.shared.stopObservingUser() instead")
    func stopObservingUser(id: String) {
        userProvider.stopObservingUser(id: id)
    }
    
    // MARK: - Event Operations (Deprecated - use EventDataProvider.shared instead)

    @available(*, deprecated, message: "Use EventDataProvider.shared.fetchAllEvents() instead")
    func fetchAllEvents() async -> [Event] {
        return await eventProvider.fetchAllEvents()
    }

    @available(*, deprecated, message: "Use EventDataProvider.shared.fetchEvent(by:) instead")
    func fetchEvent(by id: String) async -> Event? {
        return await eventProvider.fetchEvent(by: id)
    }

    @available(*, deprecated, message: "Use EventDataProvider.shared.fetchUserEvents() instead")
    func fetchUserEvents(for userId: String) async -> [Event] {
        return await eventProvider.fetchUserEvents(for: userId)
    }

    @available(*, deprecated, message: "Use EventDataProvider.shared.fetchCircleEvents() instead")
    func fetchCircleEvents(for userId: String, friendIds: [String]) async -> [Event] {
        return await eventProvider.fetchCircleEvents(for: userId, friendIds: friendIds)
    }

    @available(*, deprecated, message: "Use EventDataProvider.shared.fetchPublicEvents() instead")
    func fetchPublicEvents() async -> [Event] {
        return await eventProvider.fetchPublicEvents()
    }

    @available(*, deprecated, message: "Use EventDataProvider.shared.saveEvent() instead")
    func saveEvent(_ event: Event) async throws {
        try await eventProvider.saveEvent(event)
    }

    @available(*, deprecated, message: "Use EventDataProvider.shared.deleteEvent() instead")
    func deleteEvent(_ eventId: String) async throws {
        try await eventProvider.deleteEvent(eventId)
    }

    @available(*, deprecated, message: "Use EventDataProvider.shared.updateEventStatus() instead")
    func updateEventStatus(_ event: Event) async -> Event {
        return await eventProvider.updateEventStatus(event)
    }

    @available(*, deprecated, message: "Use EventDataProvider.shared.generateNewEventReference() instead")
    func generateNewEventReference() -> (reference: DocumentReference, id: String) {
        return eventProvider.generateNewEventReference()
    }
    
    // MARK: - Profile Image Operations (Deprecated - use ImageStorageProvider.shared instead)

    @available(*, deprecated, message: "Use ImageStorageProvider.shared.uploadProfileImage() instead")
    func uploadProfileImage(_ image: UIImage, for userId: String) async throws -> (fullUrl: String, thumbnailUrl: String) {
        return try await imageProvider.uploadProfileImage(image, for: userId)
    }

    private func deleteOldProfileImage(for userId: String) async {
        await imageProvider.deleteOldProfileImage(for: userId)
    }

    // Memory warning observer token
    private var memoryWarningObserver: NSObjectProtocol?

    @available(*, deprecated, message: "Use ImageStorageProvider.shared.downloadProfileImage() instead")
    func downloadProfileImage(from url: String) async throws -> UIImage {
        return try await imageProvider.downloadProfileImage(from: url)
    }

    @available(*, deprecated, message: "Use ImageStorageProvider.shared.prefetchProfileImages() instead")
    func prefetchProfileImages(urls: [String]) async {
        await imageProvider.prefetchProfileImages(urls: urls)
    }

    // MARK: - Utility Operations (Deprecated - use UserDataProvider.shared instead)

    @available(*, deprecated, message: "Use UserDataProvider.shared.isUsernameTaken() instead")
    func isUsernameTaken(_ username: String, excludingUserId: String?) async -> Bool {
        return await userProvider.isUsernameTaken(username, excludingUserId: excludingUserId)
    }

    // MARK: - Friend Request Operations (Deprecated - use FriendDataProvider.shared instead)

    @available(*, deprecated, message: "Use FriendDataProvider.shared.sendFriendRequest() instead")
    func sendFriendRequest(fromUserId: String, to targetUserId: String) async throws {
        try await friendProvider.sendFriendRequest(fromUserId: fromUserId, to: targetUserId)
    }

    @available(*, deprecated, message: "Use FriendDataProvider.shared.acceptFriendRequest() instead")
    func acceptFriendRequest(requestId: String, userId: String, friendId: String) async throws {
        try await friendProvider.acceptFriendRequest(requestId: requestId, userId: userId, friendId: friendId)
    }

    @available(*, deprecated, message: "Use FriendDataProvider.shared.rejectFriendRequest() instead")
    func rejectFriendRequest(requestId: String) async throws {
        try await friendProvider.rejectFriendRequest(requestId: requestId)
    }

    @available(*, deprecated, message: "Use FriendDataProvider.shared.addFriend() instead")
    internal func addFriend(_ friendId: String, to userId: String) async throws {
        try await friendProvider.addFriend(friendId, to: userId)
    }

    @available(*, deprecated, message: "Use FriendDataProvider.shared.removeFriend() instead")
    func removeFriend(_ friendId: String, from userId: String) async throws {
        try await friendProvider.removeFriend(friendId, from: userId)
    }
    
    // MARK: - Landmark Operations (Deprecated - use LandmarkDataProvider.shared instead)

    @available(*, deprecated, message: "Use LandmarkDataProvider.shared.fetchTotalLandmarks() instead")
    func fetchTotalLandmarks() async -> Int {
        return await landmarkProvider.fetchTotalLandmarks()
    }

    @available(*, deprecated, message: "Use LandmarkDataProvider.shared.markLandmarkVisited() instead")
    func markLandmarkVisited(userId: String, landmarkId: String) async {
        await landmarkProvider.markLandmarkVisited(userId: userId, landmarkId: landmarkId)
    }

    @available(*, deprecated, message: "Use LandmarkDataProvider.shared.unmarkLandmarkVisited() instead")
    func unmarkLandmarkVisited(userId: String, landmarkId: String) async {
        await landmarkProvider.unmarkLandmarkVisited(userId: userId, landmarkId: landmarkId)
    }
    
    // MARK: - Location Operations (Deprecated - use LocationDataProvider.shared instead)

    @available(*, deprecated, message: "Use LocationDataProvider.shared.updateUserLocation() instead")
    func updateUserLocation(userId: String, location: CLLocationCoordinate2D) async throws {
        try await locationProvider.updateUserLocation(userId: userId, location: location)
    }

    @available(*, deprecated, message: "Use LocationDataProvider.shared.observeUserLocation() instead")
    func observeUserLocation(userId: String, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        locationProvider.observeUserLocation(userId: userId, completion: completion)
    }
    
    // MARK: - Friend Requests Observation (Deprecated - use FriendDataProvider.shared instead)

    @available(*, deprecated, message: "Use FriendDataProvider.shared.observeFriendRequests() instead")
    func observeFriendRequests(for userId: String, completion: @escaping ([FriendRequest]) -> Void) {
        friendProvider.observeFriendRequests(for: userId, completion: completion)
    }

    @available(*, deprecated, message: "Use FriendDataProvider.shared.updateFriendRequestStatus() instead")
    func updateFriendRequestStatus(requestId: String, targetUserId: String, status: FriendRequestStatus) async throws {
        try await friendProvider.updateFriendRequestStatus(requestId: requestId, targetUserId: targetUserId, status: status)
    }

    
    // MARK: - Notification Operations (Deprecated - use NotificationDataProvider.shared instead)

    @available(*, deprecated, message: "Use NotificationDataProvider.shared.sendNotification() instead")
    func sendNotification(to userId: String, type: NotificationType, fromUserId: String, content: String, relatedEventId: String? = nil) async throws {
        try await notificationProvider.sendNotification(to: userId, type: type, fromUserId: fromUserId, content: content, relatedEventId: relatedEventId)
    }

    @available(*, deprecated, message: "Use NotificationDataProvider.shared.observeNotifications() instead")
    func observeNotifications(for userId: String, completion: @escaping ([TrailNotification]) -> Void) {
        notificationProvider.observeNotifications(for: userId, completion: completion)
    }

    private func getTitleForNotificationType(_ type: NotificationType) -> String {
        switch type {
        case .friendRequest:
            return "New Friend Request"
        case .friendAccepted:
            return "Friend Request Accepted"
        case .eventInvite:
            return "New Event Invitation"
        case .eventUpdate:
            return "Event Update"
        case .general:
            return "Notification"
        }
    }

    @available(*, deprecated, message: "Use NotificationDataProvider.shared.markNotificationAsRead() instead")
    func markNotificationAsRead(id: String, notificationId: String) async throws {
        try await notificationProvider.markNotificationAsRead(id: id, notificationId: notificationId)
    }

    @available(*, deprecated, message: "Use NotificationDataProvider.shared.fetchNotifications() instead")
    func fetchNotifications(forid id: String, userID: String) async throws -> [TrailNotification] {
        return try await notificationProvider.fetchNotifications(forId: id, userID: userID)
    }

    @available(*, deprecated, message: "Use NotificationDataProvider.shared.deleteNotification() instead")
    func deleteNotification(id: String, notificationId: String) async throws {
        try await notificationProvider.deleteNotification(id: id, notificationId: notificationId)
    }
    
    enum ValidationError: LocalizedError {
        case emptyField(String)
        case missingRequiredFields(String)
        case invalidUrl(String)
        case failedToDownloadImage(String)
        case userNotAuthenticated(String)
        case invalidData(String)
        
        var errorDescription: String? {
            switch self {
            case .emptyField(let message),
                    .missingRequiredFields(let message),
                    .invalidUrl(let message),
                    .failedToDownloadImage(let message),
                    .userNotAuthenticated(let message),
                    .invalidData(let message):
                return message
            }
        }
    }
    
    func stopObservingUser() {
        // Clean up all Firestore listeners
        firestoreListeners.forEach { _, listener in
            listener.remove()
        }
        firestoreListeners.removeAll()

        // Clean up all RTDB listeners
        activeListeners.forEach { path, handle in
            rtdb.child(path).removeObserver(withHandle: handle)
        }
        activeListeners.removeAll()
    }

    // MARK: - Listener Tracking (for debugging/monitoring)

    /// Returns the count of currently active listeners for monitoring purposes
    var activeListenerCount: (rtdb: Int, firestore: Int, users: Int) {
        return (activeListeners.count, firestoreListeners.count, userListeners.count)
    }

    /// Prints current listener status for debugging
    func printListenerStatus() {
        let counts = activeListenerCount
        print("🔥 Active Listeners - RTDB: \(counts.rtdb), Firestore: \(counts.firestore), Users: \(counts.users)")
    }
}
