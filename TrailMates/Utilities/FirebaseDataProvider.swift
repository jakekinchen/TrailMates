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
        imageCache.removeAllObjects()
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

    // MARK: - Friend Request Operations
    func sendFriendRequest(fromUserId: String, to targetUserId: String) async throws {
        // Verify the current user is sending the request
        guard let currentUser = Auth.auth().currentUser,
              currentUser.uid == fromUserId else {
            throw ValidationError.userNotAuthenticated("Cannot send request on behalf of another user")
        }
        
        let requestId = UUID().uuidString
        let requestRef = rtdb.child("friend_requests")
            .child(targetUserId)
            .child(requestId)
        
        let requestData: [String: Any] = [
            "fromUserId": fromUserId,  // Use Firebase UID for RTDB
            "timestamp": ServerValue.timestamp(),
            "status": "pending"
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            requestRef.setValue(requestData) { error, _ in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    func acceptFriendRequest(requestId: String, userId: String, friendId: String) async throws {
        let callable = functions.httpsCallable("acceptFriendRequest")
        _ = try await callable.call(["requestId": requestId])
    }
    
    func rejectFriendRequest(requestId: String) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw ValidationError.userNotAuthenticated("No authenticated user")
        }
        
        // Remove friend request and its notification from RTDB
        let updates: [String: Any?] = [
            "friend_requests/\(currentUser.uid)/\(requestId)": nil,
            "notifications/\(currentUser.uid)/\(requestId)": nil
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            rtdb.updateChildValues(updates as [AnyHashable : Any]) { error, _ in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    internal func addFriend(_ friendId: String, to userId: String) async throws {
        let userRef = db.collection("users").document(userId)
        let friendRef = db.collection("users").document(friendId)
        
        _ = try await db.runTransaction { transaction, errorPointer in
            let userDoc: DocumentSnapshot
            let friendDoc: DocumentSnapshot
            
            do {
                userDoc = try transaction.getDocument(userRef)
                friendDoc = try transaction.getDocument(friendRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            // Get current friend lists
            var userFriends = userDoc.get("friends") as? [String] ?? []
            var friendFriends = friendDoc.get("friends") as? [String] ?? []
            
            // Add friend IDs if not already present
            if !userFriends.contains(friendId) {
                userFriends.append(friendId)
            }
            if !friendFriends.contains(userId) {
                friendFriends.append(userId)
            }
            
            // Update both documents
            transaction.updateData(["friends": userFriends], forDocument: userRef)
            transaction.updateData(["friends": friendFriends], forDocument: friendRef)
            
            return nil
        }
    }
    
    func removeFriend(_ friendId: String, from userId: String) async throws {
        let callable = functions.httpsCallable("removeFriend")
        _ = try await callable.call(["friendId": friendId])
    }
    
    // MARK: - Landmark Operations
    func fetchTotalLandmarks() async -> Int {
        do {
            let snapshot = try await db.collection("landmarks").getDocuments()
            return snapshot.documents.count
        } catch {
            print("Error fetching total landmarks: \(error)")
            return 0
        }
    }
    
    func markLandmarkVisited(userId: String, landmarkId: String) async {
        do {
            let userRef = db.collection("users").document(userId)
            try await userRef.updateData([
                "visitedLandmarkIds": FieldValue.arrayUnion([landmarkId])
            ])
        } catch {
            print("Error marking landmark as visited: \(error)")
        }
    }
    
    func unmarkLandmarkVisited(userId: String, landmarkId: String) async {
        do {
            let userRef = db.collection("users").document(userId)
            try await userRef.updateData([
                "visitedLandmarkIds": FieldValue.arrayRemove([landmarkId])
            ])
        } catch {
            print("Error unmarking landmark as visited: \(error)")
        }
    }
    
    // MARK: - Real-time Database Operations
    
    // MARK: - Location Operations
    // MARK: - Location Operations
func updateUserLocation(userId: String, location: CLLocationCoordinate2D) async throws {
    // 1. Verify the current user is updating their own location
    guard let currentUser = Auth.auth().currentUser else {
        throw ValidationError.userNotAuthenticated("No authenticated user")
    }
    
    // 2. Ensure the userId matches the currentUser's UID
    guard userId == currentUser.uid else {
        throw ValidationError.invalidData("Cannot update location for another user")
    }
    
    // 3. Get fresh ID token to ensure auth is valid
    let token = try await currentUser.getIDToken()
    
    print("\nFirebase Location Debug:")
    print("1. Auth Check:")
    print("   - UID: \(currentUser.uid)")
    print("   - Token valid: \(token.prefix(10))...")
    print("   - Provider: \(currentUser.providerID)")
    print("   - Anonymous: \(currentUser.isAnonymous)")
    
    // 4. Reference the user's location node in RTDB
    let locationRef = rtdb.child("locations").child(currentUser.uid)
    print("   - Path: \(locationRef.url)")
    
    // 5. Verify database connection
    let connectedRef = rtdb.child(".info/connected")
    let isConnected = try await withCheckedThrowingContinuation { continuation in
        connectedRef.observeSingleEvent(of: .value) { snapshot in
            continuation.resume(returning: snapshot.value as? Bool ?? false)
        }
    }
    print("2. Connection Check:")
    print("   - Connected: \(isConnected)")
    
    // 6. Write location data to RTDB
    return try await withCheckedThrowingContinuation { continuation in
        let locationData: [String: Any] = [
            "latitude": location.latitude,
            "longitude": location.longitude,
            "timestamp": ServerValue.timestamp(),
            "lastUpdated": ServerValue.timestamp()
        ]
        
        print("3. Data Validation:")
        print("   - Fields: \(locationData.keys.sorted().joined(separator: ", "))")
        print("   - Location: (\(location.latitude), \(location.longitude))")
        
        locationRef.setValue(locationData) { error, _ in
            if let error = error {
                print("4. Write Result: Failed")
                print("   - Error: \(error.localizedDescription)")
                continuation.resume(throwing: error)
            } else {
                print("4. Write Result: Success")
                continuation.resume()
            }
        }
    }
}
    
    func observeUserLocation(userId: String, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        // First get the Firebase UID for the target user
        Task {
            // Fetch the user document to get their Firebase UID
            if let userDoc = try? await db.collection("users").document(userId).getDocument(),
               let id = userDoc.get("id") as? String {
                let path = "locations/\(id)"
                
                // Remove existing listener if any
                if let existingHandle = activeListeners[path] {
                    rtdb.child(path).removeObserver(withHandle: existingHandle)
                    activeListeners.removeValue(forKey: path)
                }
                
                // Add new listener
                let handle = rtdb.child(path).observe(.value) { snapshot in
                    guard let locationData = snapshot.value as? [String: Any],
                          let latitude = locationData["latitude"] as? Double,
                          let longitude = locationData["longitude"] as? Double else {
                        completion(nil)
                        return
                    }
                    
                    let location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    completion(location)
                }
                
                activeListeners[path] = handle
            } else {
                print("Could not find Firebase UID for user \(userId)")
                completion(nil)
            }
        }
    }
    
    // MARK: - Friend Requests
    func observeFriendRequests(for userId: String, completion: @escaping ([FriendRequest]) -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            print("No authenticated user for friend requests")
            completion([])
            return
        }
        
        let requestsRef = rtdb.child("friend_requests").child(currentUser.uid)
        
        requestsRef.observe(.value, with: { snapshot in
            var requests: [FriendRequest] = []
            
            for child in snapshot.children {
                guard let snapshot = child as? DataSnapshot,
                      let data = snapshot.value as? [String: Any],
                      let fromUserId = data["fromUserId"] as? String,
                      let timestamp = data["timestamp"] as? TimeInterval,
                      let status = data["status"] as? String else {
                    continue
                }
                
                let request = FriendRequest(
                    id: snapshot.key,
                    fromUserId: fromUserId,
                    timestamp: Date(timeIntervalSince1970: timestamp / 1000),
                    status: FriendRequestStatus(rawValue: status) ?? .pending
                )
                requests.append(request)
            }
            
            completion(requests)
        })
    }


    
    func updateFriendRequestStatus(requestId: String, targetUserId: String, status: FriendRequestStatus) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw ValidationError.userNotAuthenticated("No authenticated user")
        }
        
        let requestRef = rtdb.child("friend_requests")
            .child(currentUser.uid)
            .child(requestId)
        
        return try await withCheckedThrowingContinuation { continuation in
            requestRef.updateChildValues(["status": status.rawValue]) { error, _ in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    
    // MARK: - Notification Operations
    func sendNotification(to userId: String, type: NotificationType, fromUserId: String, content: String, relatedEventId: String? = nil) async throws {
        // We already have userId as a string, so no need to fetch a doc for conversion.
        let notificationRef = rtdb.child("notifications")
            .child(userId)
            .child(UUID().uuidString)
        
        let notificationData: [String: Any] = [
            "type": type.rawValue,
            "fromUserId": fromUserId,
            "content": content,
            "timestamp": ServerValue.timestamp(),
            "read": false,
            "relatedEventId": relatedEventId
        ].compactMapValues { $0 }
        
        return try await withCheckedThrowingContinuation { continuation in
            notificationRef.setValue(notificationData) { error, _ in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    
    func observeNotifications(for userId: String, completion: @escaping ([TrailNotification]) -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            print("No authenticated user for notifications")
            completion([])
            return
        }
        
        let notificationsRef = rtdb.child("notifications").child(currentUser.uid)
        
        notificationsRef.observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            var notifications: [TrailNotification] = []
            
            for child in snapshot.children {
                let childSnapshot = child as! DataSnapshot
                guard let data = childSnapshot.value as? [String: Any],
                      let typeStr = data["type"] as? String,
                      let type = NotificationType(rawValue: typeStr),
                      let content = data["content"] as? String,
                      let timestamp = data["timestamp"] as? TimeInterval,
                      let fromUserId = data["fromUserId"] as? String,
                      let read = data["read"] as? Bool else {
                    continue
                }
                
                let relatedEventId = data["relatedEventId"] as? String
                
                let notification = TrailNotification(
                    id: childSnapshot.key,
                    type: type,
                    title: self.getTitleForNotificationType(type),
                    message: content,
                    timestamp: Date(timeIntervalSince1970: timestamp / 1000),
                    isRead: read,
                    userId: userId,
                    fromUserId: fromUserId,
                    relatedEventId: relatedEventId
                )
                notifications.append(notification)
            }
            
            completion(notifications.sorted { $0.timestamp > $1.timestamp })
        }
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
    
    func markNotificationAsRead(id: String, notificationId: String) async throws {
        let notificationRef = rtdb.child("notifications")
            .child(id)
            .child(notificationId)
        
        return try await withCheckedThrowingContinuation { continuation in
            notificationRef.updateChildValues(["read": true]) { error, _ in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    func fetchNotifications(forid id: String, userID: String) async throws -> [TrailNotification] {
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume(throwing: ValidationError.invalidData("FirebaseDataProvider instance was deallocated"))
                return
            }
            
            let notificationsRef = rtdb.child("notifications").child(id)
            
            notificationsRef.getData { error, snapshot in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                var notifications: [TrailNotification] = []
                
                if let snapshot = snapshot {
                    for child in snapshot.children {
                        let childSnapshot = child as! DataSnapshot
                        guard let data = childSnapshot.value as? [String: Any],
                              let typeStr = data["type"] as? String,
                              let type = NotificationType(rawValue: typeStr),
                              let content = data["content"] as? String,
                              let timestamp = data["timestamp"] as? TimeInterval,
                              let fromUserId = data["fromUserId"] as? String,
                              let read = data["read"] as? Bool else {
                            continue
                        }
                        
                        let relatedEventId = data["relatedEventId"] as? String
                        
                        let notification = TrailNotification(
                            id: childSnapshot.key,
                            type: type,
                            title: self.getTitleForNotificationType(type),
                            message: content,
                            timestamp: Date(timeIntervalSince1970: timestamp / 1000),
                            isRead: read,
                            userId: userID,
                            fromUserId: fromUserId,
                            relatedEventId: relatedEventId
                        )
                        notifications.append(notification)
                    }
                }
                
                continuation.resume(returning: notifications.sorted { $0.timestamp > $1.timestamp })
            }
        }
    }

    
    func deleteNotification(id: String, notificationId: String) async throws {
        let notificationRef = rtdb.child("notifications")
            .child(id)
            .child(notificationId)
        
        return try await withCheckedThrowingContinuation { continuation in
            notificationRef.removeValue { error, _ in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
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
