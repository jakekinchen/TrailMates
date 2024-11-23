import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseDatabase
import CoreLocation
import SwiftUI
import FirebaseStorage

class FirebaseDataProvider: DataProvider {
    private lazy var db = Firestore.firestore()
    private lazy var rtdb = Database.database().reference()
    private lazy var storage = Storage.storage().reference()
    
    // Store active listeners
    private var activeListeners: [String: DatabaseHandle] = [:]
    private var firestoreListeners: [String: ListenerRegistration] = [:]
    
    init() {
        // Ensure Firebase is configured
        if FirebaseApp.app() == nil {
           // FirebaseApp.configure()
        }
    }
    
    deinit {
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
    }
    
    // MARK: - User Operations
    func fetchCurrentUser() async -> User? {
        guard let uid = Auth.auth().currentUser?.uid,
              let uuid = UUID(uuidString: uid) else { return nil }
        return await fetchUser(by: uuid)
    }
    
    func fetchUser(byPhoneNumber phoneNumber: String) async -> User? {
        do {
            let snapshot = try await db.collection("users")
                .whereField("phoneNumber", isEqualTo: phoneNumber)
                .getDocuments()
            
            guard let document = snapshot.documents.first else { return nil }
            return try document.data(as: User.self)
        } catch {
            print("Error fetching user by phone number: \(error)")
            return nil
        }
    }
    
    func fetchUser(by id: UUID) async -> User? {
        do {
            let document = try await db.collection("users").document(id.uuidString).getDocument()
            var user = try document.data(as: User.self)
            
            // If there's a profile image URL, download the image
            if let imageUrl = user.profileImageUrl {
                user.profileImage = try await downloadProfileImage(from: imageUrl)
            }
            
            return user
        } catch {
            print("Error fetching user by ID: \(error)")
            return nil
        }
    }
    
    func fetchFriends(for user: User) async -> [User] {
        var friends: [User] = []
        for friendId in user.friends {
            if let friend = await fetchUser(by: friendId) {
                friends.append(friend)
            }
        }
        return friends
    }
    
    func fetchAllUsers() async -> [User] {
        do {
            let snapshot = try await db.collection("users").getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: User.self) }
        } catch {
            print("Error fetching all users: \(error)")
            return []
        }
    }
    
    func saveInitialUser(_ user: User) async throws {
        print("Starting initial user save")
        // Validate phone number and id
        guard !user.phoneNumber.isEmpty else {
            print("Error: Empty phone number")
            throw ValidationError.emptyField("Phone number cannot be empty")
        }
        
        print("Using document ID: \(user.id.uuidString)")
        let userRef = db.collection("users").document(user.id.uuidString)
        let initialData: [String: Any] = [
            "id": user.id.uuidString,  // Include id as required by rules
            "phoneNumber": user.phoneNumber,
            "joinDate": user.joinDate  // Include joinDate for record-keeping
        ]
        
        do {
            try await userRef.setData(initialData)
            print("Initial user data saved successfully")
        } catch {
            print("Error saving initial user data: \(error)")
            throw error
        }
    }
    
    func saveUser(_ user: User) async throws {
        print("Starting full user save")
        // Validate required fields for full profile update
        guard !user.firstName.isEmpty,
              !user.lastName.isEmpty,
              !user.username.isEmpty,
              !user.phoneNumber.isEmpty else {
            print("Error: Missing required fields")
            throw ValidationError.missingRequiredFields("All required fields must be non-empty")
        }
        
        var userData = user
        print("Using document ID: \(user.id.uuidString)")
        
        // If there's a profile image, upload it to Storage first
        if let image = user.profileImage {
            print("Profile image found, uploading...")
            // Delete old profile images
            await deleteOldProfileImage(for: user.id)
            
            // Upload new image and get URLs
            let urls = try await uploadProfileImage(image, for: user.id)
            print("Profile image uploaded successfully")
            
            // Store the URLs and clear the image data
            userData.profileImage = nil
            userData.profileImageUrl = urls.fullUrl
            userData.profileThumbnailUrl = urls.thumbnailUrl
        }
        
        // Save user data to Firestore
        let userRef = db.collection("users").document(user.id.uuidString)
        let data = try Firestore.Encoder().encode(userData)
        
        print("Attempting to save full user data")
        do {
            try await userRef.setData(data)
            print("Full user data saved successfully")
        } catch {
            print("Error saving full user: \(error.localizedDescription)")
            print("Error details: \(String(describing: error))")
            throw error
        }
    }
    
    func observeUser(id: UUID, onChange: @escaping (User?) -> Void) {
        let path = "users/\(id.uuidString)"
        
        // Remove existing listener if any
        firestoreListeners[path]?.remove()
        
        // Set up new listener
        let listener = db.collection("users").document(id.uuidString)
            .addSnapshotListener { documentSnapshot, error in
                guard let document = documentSnapshot,
                      let updatedUser = try? document.data(as: User.self) else {
                    print("Error observing user data: \(error?.localizedDescription ?? "unknown error")")
                    onChange(nil)
                    return
                }
                onChange(updatedUser)
            }
        
        firestoreListeners[path] = listener
    }
    
    func stopObservingUser(id: UUID) {
        let path = "users/\(id.uuidString)"
        firestoreListeners[path]?.remove()
        firestoreListeners.removeValue(forKey: path)
    }
    
    // MARK: - Event Operations
    func fetchAllEvents() async -> [Event] {
        do {
            let snapshot = try await db.collection("events").getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: Event.self) }
        } catch {
            print("Error fetching all events: \(error)")
            return []
        }
    }
    
    func fetchEvent(by id: UUID) async -> Event? {
        do {
            let document = try await db.collection("events").document(id.uuidString).getDocument()
            return try document.data(as: Event.self)
        } catch {
            print("Error fetching event: \(error)")
            return nil
        }
    }
    
    func fetchUserEvents(for userId: UUID) async -> [Event] {
        do {
            let snapshot = try await db.collection("events")
                .whereField("creatorId", isEqualTo: userId.uuidString)
                .getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: Event.self) }
        } catch {
            print("Error fetching user events: \(error)")
            return []
        }
    }
    
    func fetchCircleEvents(for userId: UUID, friendIds: [UUID]) async -> [Event] {
        do {
            let friendIdsStrings = friendIds.map { $0.uuidString }
            let snapshot = try await db.collection("events")
                .whereField("creatorId", in: [userId.uuidString] + friendIdsStrings)
                .getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: Event.self) }
        } catch {
            print("Error fetching circle events: \(error)")
            return []
        }
    }
    
    func fetchPublicEvents() async -> [Event] {
        do {
            let snapshot = try await db.collection("events")
                .whereField("isPublic", isEqualTo: true)
                .getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: Event.self) }
        } catch {
            print("Error fetching public events: \(error)")
            return []
        }
    }
    
    func saveEvent(_ event: Event) async throws {
        let eventRef = db.collection("events").document(event.id.uuidString)
        let data = try Firestore.Encoder().encode(event)
        try await eventRef.setData(data)
    }
    
    func deleteEvent(_ eventId: UUID) async throws {
        try await db.collection("events").document(eventId.uuidString).delete()
    }
    
    func updateEventStatus(_ event: Event) async -> Event {
        do {
            let updatedEvent = event
            try await saveEvent(updatedEvent)
            return updatedEvent
        } catch {
            print("Error updating event status: \(error)")
            return event
        }
    }
    
    // MARK: - Profile Image Operations
    private func uploadProfileImage(_ image: UIImage, for userId: UUID) async throws -> (fullUrl: String, thumbnailUrl: String) {
        // Process and validate image
        try ImageProcessor.validateImage(image)
        let (fullData, thumbnailData) = try ImageProcessor.processProfileImage(image)
        
        let imageId = UUID().uuidString
        let fullImageRef = storage.child("profile_images/\(userId.uuidString)/\(imageId)")
        let thumbnailRef = storage.child("profile_images/\(userId.uuidString)/\(imageId)_thumbnail")
        
        // Create metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // Upload both images concurrently
        async let fullUpload = fullImageRef.putDataAsync(fullData, metadata: metadata)
        async let thumbnailUpload = thumbnailRef.putDataAsync(thumbnailData, metadata: metadata)
        _ = try await (fullUpload, thumbnailUpload)
        
        // Get download URLs
        async let fullUrl = fullImageRef.downloadURL()
        async let thumbnailUrl = thumbnailRef.downloadURL()
        let urls = try await (fullUrl, thumbnailUrl)
        
        return (fullUrl: urls.0.absoluteString, thumbnailUrl: urls.1.absoluteString)
    }
    
    private func deleteOldProfileImage(for userId: UUID) async {
        do {
            let profileImagesRef = storage.child("profile_images/\(userId.uuidString)")
            let items = try await profileImagesRef.listAll()
            
            // Delete all existing profile images for this user
            for item in items.items {
                try await item.delete()
            }
        } catch {
            print("Error deleting old profile images: \(error)")
        }
    }
    
    private func downloadProfileImage(from url: String, isThumbnail: Bool = false) async throws -> UIImage {
        guard let imageUrl = URL(string: url) else {
            throw ValidationError.invalidUrl("Invalid URL")
        }
        
        let (data, response) = try await URLSession.shared.data(from: imageUrl)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let image = UIImage(data: data) else {
            throw ValidationError.failedToDownloadImage("Failed to download image")
        }
        
        return image
    }
    
    // MARK: - Utility Operations
    func isUsernameTaken(_ username: String, excludingUserId: UUID?) async -> Bool {
        do {
            var query = db.collection("users").whereField("username", isEqualTo: username)
            
            if let excludeId = excludingUserId {
                query = query.whereField("id", isNotEqualTo: excludeId.uuidString)
            }
            
            let snapshot = try await query.getDocuments()
            return !snapshot.isEmpty
        } catch {
            print("Error checking username: \(error)")
            return false
        }
    }
    
    func fetchUsersByFacebookIds(_ facebookIds: [String]) async -> [User] {
        do {
            let snapshot = try await db.collection("users")
                .whereField("facebookId", in: facebookIds)
                .getDocuments()
            
            return snapshot.documents.compactMap { try? $0.data(as: User.self) }
        } catch {
            print("Error fetching users by Facebook IDs: \(error)")
            return []
        }
    }
    
    // MARK: - Friend Request Operations
    func acceptFriendRequest(requestId: String, userId: UUID, friendId: UUID) async throws {
        // Convert requestId to UUID
        guard let requestUUID = UUID(uuidString: requestId) else {
            throw ValidationError.invalidData("Invalid request ID format")
        }
        
        // Add friend to both users
        try await addFriend(friendId, to: userId)
        try await addFriend(userId, to: friendId)
        
        // Delete the friend request notification
        try await deleteNotification(userId: userId, notificationId: requestUUID)
    }
    
    func rejectFriendRequest(requestId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              let uuid = UUID(uuidString: currentUserId) else {
            throw ValidationError.userNotAuthenticated("User not authenticated")
        }
        
        // Update friend request status in Firestore
        try await updateFriendRequestStatus(requestId: requestId, targetUserId: uuid, status: .rejected)
        
        // Remove friend request and its notification atomically
        // We store the requestId in the notification when creating friend request notifications
        let updates: [String: Any?] = [
            "friend_requests/\(currentUserId)/\(requestId)": nil,
            "notifications/\(currentUserId)/\(requestId)": nil  // Using same ID for notification and request
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
    
    func addFriend(_ friendId: UUID, to userId: UUID) async throws {
        let userRef = db.collection("users").document(userId.uuidString)
        try await userRef.updateData([
            "friends": FieldValue.arrayUnion([friendId.uuidString])
        ])
    }
    
    func removeFriend(_ friendId: UUID, from userId: UUID) async throws {
        let userRef = db.collection("users").document(userId.uuidString)
        try await userRef.updateData([
            "friends": FieldValue.arrayRemove([friendId.uuidString])
        ])
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
    
    func markLandmarkVisited(userId: UUID, landmarkId: UUID) async {
        do {
            let userRef = db.collection("users").document(userId.uuidString)
            try await userRef.updateData([
                "visitedLandmarkIds": FieldValue.arrayUnion([landmarkId.uuidString])
            ])
        } catch {
            print("Error marking landmark as visited: \(error)")
        }
    }
    
    func unmarkLandmarkVisited(userId: UUID, landmarkId: UUID) async {
        do {
            let userRef = db.collection("users").document(userId.uuidString)
            try await userRef.updateData([
                "visitedLandmarkIds": FieldValue.arrayRemove([landmarkId.uuidString])
            ])
        } catch {
            print("Error unmarking landmark as visited: \(error)")
        }
    }
    
    // MARK: - Real-time Database Operations
    
    // MARK: - Location Operations
    func updateUserLocation(userId: UUID, location: CLLocationCoordinate2D) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let locationRef = rtdb.child("locations").child(userId.uuidString)
            let locationData: [String: Any] = [
                "latitude": location.latitude,
                "longitude": location.longitude,
                "timestamp": ServerValue.timestamp()
            ]
            
            locationRef.setValue(locationData) { error, _ in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
            
            // Set up onDisconnect to clean up location data
            locationRef.onDisconnectRemoveValue { error, _ in
                if let error = error {
                    print("Error setting up disconnect cleanup: \(error)")
                }
            }
        }
    }
    
    func observeUserLocation(userId: UUID, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        let path = "locations/\(userId.uuidString)"
        
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
    }
    
    // MARK: - Friend Requests
    func sendFriendRequest(from userId: UUID, to targetUserId: UUID) async throws {
        let requestRef = rtdb.child("friend_requests")
            .child(targetUserId.uuidString)
            .child(UUID().uuidString)
        
        let requestData: [String: Any] = [
            "fromUserId": userId.uuidString,
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
    
    func observeFriendRequests(for userId: UUID, completion: @escaping ([FriendRequest]) -> Void) {
        let requestsRef = rtdb.child("friend_requests").child(userId.uuidString)
        
        requestsRef.observe(.value) { snapshot in
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
                    id: UUID(uuidString: snapshot.key) ?? UUID(),
                    fromUserId: UUID(uuidString: fromUserId) ?? UUID(),
                    timestamp: Date(timeIntervalSince1970: timestamp / 1000),
                    status: FriendRequestStatus(rawValue: status) ?? .pending
                )
                requests.append(request)
            }
            
            completion(requests)
        }
    }
    
    func updateFriendRequestStatus(requestId: String, targetUserId: UUID, status: FriendRequestStatus) async throws {
        let requestRef = rtdb.child("friend_requests")
            .child(targetUserId.uuidString)
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
    func sendNotification(to userId: UUID, type: NotificationType, fromUserId: UUID, content: String, relatedEventId: UUID? = nil) async throws {
        let notificationRef = rtdb.child("notifications")
            .child(userId.uuidString)
            .child(UUID().uuidString)
        
        let notificationData: [String: Any] = [
            "type": type.rawValue,
            "fromUserId": fromUserId.uuidString,
            "content": content,
            "timestamp": ServerValue.timestamp(),
            "read": false,
            "relatedEventId": relatedEventId?.uuidString
        ].compactMapValues { $0 }  // Remove nil values
        
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
    
    func observeNotifications(for userId: UUID, completion: @escaping ([TrailNotification]) -> Void) {
        let notificationsRef = rtdb.child("notifications").child(userId.uuidString)
        
        notificationsRef.observe(.value) { [self] snapshot in
            var notifications: [TrailNotification] = []
            
            for child in snapshot.children {
                guard let snapshot = child as? DataSnapshot,
                      let data = snapshot.value as? [String: Any],
                      let typeString = data["type"] as? String,
                      let type = NotificationType(rawValue: typeString),
                      let fromUserId = data["fromUserId"] as? String,
                      let content = data["content"] as? String,
                      let timestamp = data["timestamp"] as? TimeInterval else {
                    continue
                }
                
                let relatedEventId = (data["relatedEventId"] as? String).flatMap { UUID(uuidString: $0) }
                let read = data["read"] as? Bool ?? false
                
                let notification = TrailNotification(
                    id: UUID(uuidString: snapshot.key) ?? UUID(),
                    type: type,
                    title: getTitleForNotificationType(type),
                    message: content,
                    timestamp: Date(timeIntervalSince1970: timestamp / 1000),
                    isRead: read,
                    userId: userId,
                    fromUserId: UUID(uuidString: fromUserId),
                    relatedEventId: relatedEventId
                )
                notifications.append(notification)
            }
            
            completion(notifications)
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
    
    func markNotificationAsRead(userId: UUID, notificationId: UUID) async throws {
        let notificationRef = rtdb.child("notifications")
            .child(userId.uuidString)
            .child(notificationId.uuidString)
        
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
    
    func fetchNotifications(for userId: UUID) async throws -> [TrailNotification] {
        return try await withCheckedThrowingContinuation { [self] continuation in
            let notificationsRef = rtdb.child("notifications").child(userId.uuidString)
            
            notificationsRef.getData { [self] error, snapshot in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let snapshot = snapshot else {
                    continuation.resume(returning: [])
                    return
                }
                
                var notifications: [TrailNotification] = []
                
                for child in snapshot.children {
                    guard let snapshot = child as? DataSnapshot,
                          let data = snapshot.value as? [String: Any],
                          let typeString = data["type"] as? String,
                          let type = NotificationType(rawValue: typeString),
                          let fromUserId = data["fromUserId"] as? String,
                          let content = data["content"] as? String,
                          let timestamp = data["timestamp"] as? TimeInterval else {
                        continue
                    }
                    
                    let relatedEventId = (data["relatedEventId"] as? String).flatMap { UUID(uuidString: $0) }
                    let read = data["read"] as? Bool ?? false
                    
                    let notification = TrailNotification(
                        id: UUID(uuidString: snapshot.key) ?? UUID(),
                        type: type,
                        title: self.getTitleForNotificationType(type),
                        message: content,
                        timestamp: Date(timeIntervalSince1970: timestamp / 1000),
                        isRead: read,
                        userId: userId,
                        fromUserId: UUID(uuidString: fromUserId),
                        relatedEventId: relatedEventId
                    )
                    notifications.append(notification)
                }
                
                continuation.resume(returning: notifications.sorted { $0.timestamp > $1.timestamp })
            }
        }
    }
    
    func deleteNotification(userId: UUID, notificationId: UUID) async throws {
        let notificationRef = rtdb.child("notifications")
            .child(userId.uuidString)
            .child(notificationId.uuidString)
        
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
}
