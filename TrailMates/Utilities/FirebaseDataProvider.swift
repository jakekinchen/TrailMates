import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import FirebaseDatabase
import CoreLocation
import SwiftUI
import FirebaseStorage

class FirebaseDataProvider {
    // MARK: - Singleton
    static let shared = FirebaseDataProvider()
    
    // Lazy initialize Firebase services
    private lazy var db = Firestore.firestore()
    private lazy var functions = Functions.functions(region: "us-central1")
    let functionURL = URL(string: "https://us-central1-trailmates-atx.cloudfunctions.net/getUserByPhoneNumber")!
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
        
        print("🔥 FirebaseDataProvider init started - Services will be initialized on first use")
    }
    
    deinit {
        // Remove auth listener when provider is deallocated
        if let listener = authStateListener {
            auth.removeStateDidChangeListener(listener)
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
    }
    
    // MARK: - User Operations
    func fetchCurrentUser() async -> User? {
        // Safely access auth
        guard let currentUser = auth.currentUser else {
            print("🔥 No authenticated user found")
            return nil
        }
        
        // Find user by Firebase UID in Firestore
        let snapshot = try? await db.collection("users")
            .whereField("id", isEqualTo: currentUser.uid)
            .getDocuments()
        
        guard let document = snapshot?.documents.first else {
            print("🔥 No user document found for Firebase UID")
            return nil
        }
        
        return try? document.data(as: User.self)
    }
    
    // Add a method to check auth state without initializing Firebase
    func isUserAuthenticated() -> Bool {
        auth.currentUser != nil
    }
    
    private func normalizePhoneNumber(_ phoneNumber: String) -> String {
        print("📞 Normalizing phone number:")
        print("   Input: '\(phoneNumber)'")
        print("   Length: \(phoneNumber.count)")
        print("   Characters: \(phoneNumber.map { String($0) })")
        
        let normalized = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        print("   Normalized: '\(normalized)'")
        print("   Normalized Length: \(normalized.count)")
        print("   Normalized Characters: \(normalized.map { String($0) })")
        
        return normalized
    }
    
    func fetchUser(byPhoneNumber phoneNumber: String) async -> User? {
        guard !phoneNumber.isEmpty else {
            print("❌ Empty phone number provided")
            return nil
        }
        
        // Normalize the phone number
        let normalizedPhone = normalizePhoneNumber(phoneNumber)
        guard !normalizedPhone.isEmpty else {
            print("❌ Normalization resulted in empty phone number")
            return nil
        }
        
        let function = functions.httpsCallable("getUserByPhoneNumber")
        
        do {
            let result = try await function.call(["phoneNumber": normalizedPhone, "region": "US"])
            
            if let data = result.data as? [String: Any],
               let userExists = data["userExists"] as? Bool,
               let userId = data["userId"] as? String {
                
                if userExists {
                    return await fetchUser(by: userId)
                }
            }
            return nil
        } catch let error as NSError {
            if error.domain == FunctionsErrorDomain {
                let code = FunctionsErrorCode(rawValue: error.code)
                let message = error.localizedDescription
                let details = error.userInfo[FunctionsErrorDetailsKey]
                print("❌ Cloud Function error:")
                print("   Code: \(String(describing: code))")
                print("   Message: \(message)")
                print("   Details: \(String(describing: details))")
            }
            return nil
        }
    }
    
    func fetchUser(by id: String) async -> User? {
        do {
            print("🔍 Fetching user with ID: \(id)")
            let document = try await db.collection("users").document(id).getDocument()
            
            guard document.exists else {
                print("❌ No user document found with ID: \(id)")
                return nil
            }
            
            let user = try document.data(as: User.self)
            
            // Validate required IDs according to rules
            guard !user.id.isEmpty else {
                print("❌ User document missing Firebase UID")
                return nil
            }
            
            // Handle profile image according to hierarchy rules
            if let imageUrl = user.profileImageUrl {
                do {
                    // Try remote URL first
                    user.profileImage = try await downloadProfileImage(from: imageUrl)
                    print(" Loaded profile image from remote URL")
                } catch {
                    print("⚠️ Failed to load remote image: \(error.localizedDescription)")
                    
                    // Clear invalid URLs
                    user.profileImageUrl = nil
                    user.profileThumbnailUrl = nil
                    
                    // Update document to clear invalid URLs
                    try? await db.collection("users").document(id).updateData([
                        "profileImageUrl": FieldValue.delete(),
                        "profileThumbnailUrl": FieldValue.delete()
                    ])
                }
            }
            
            print("✅ Successfully fetched user: \(user.firstName) \(user.lastName)")
            return user
            
        } catch let decodingError as DecodingError {
            print("❌ Error decoding user data: \(decodingError)")
            return nil
        } catch {
            print("❌ Error fetching user: \(error)")
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
        
        // Normalize the phone number before saving
        let normalizedPhone = normalizePhoneNumber(user.phoneNumber)
        print("Using normalized phone number: \(normalizedPhone)")
        
        print("Using document ID: \(user.id)")
        let userRef = db.collection("users").document(user.id)
        
        // First check if document already exists
        let docSnapshot = try await userRef.getDocument()
        guard !docSnapshot.exists else {
            throw ValidationError.invalidData("User document already exists")
        }
        
        let initialData: [String: Any] = [
            "id": user.id,
            "phoneNumber": normalizedPhone,  // Save normalized phone number
            "joinDate": user.joinDate,
            "isActive": true,
            "firstName": "",
            "lastName": "",
            "username": "",
            "friends": [],
            "doNotDisturb": false,
            "createdEventIds": [],
            "attendingEventIds": [],
            "visitedLandmarkIds": [],
            "receiveFriendRequests": true,
            "receiveFriendEvents": true,
            "receiveEventUpdates": true,
            "shareLocationWithFriends": true,
            "shareLocationWithEventHost": true,
            "shareLocationWithEventGroup": true,
            "allowFriendsToInviteOthers": true
        ]
        
        do {
            try await userRef.setData(initialData)
            
            // Verify the document was created
            let verifySnapshot = try await userRef.getDocument()
            guard verifySnapshot.exists else {
                throw ValidationError.invalidData("Failed to verify user creation")
            }
            
            print("Initial user data saved and verified successfully")
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
              !user.username.isEmpty else {
            print("Error: Missing required fields")
            print("User: \(user)")
            throw ValidationError.missingRequiredFields("All required fields must be non-empty")
        }
        
        let userData = user
        print("Using document ID: \(user.id)")
        
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
        let userRef = db.collection("users").document(user.id)
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
    
    func observeUser(id: String, onChange: @escaping (User?) -> Void) {
        // Remove existing listener if any
        stopObservingUser(id: id)
        
        // Create new listener
        let listener = db.collection("users").document(id)
            .addSnapshotListener { documentSnapshot, error in
                guard let document = documentSnapshot else {
                    print("Error fetching document: \(error?.localizedDescription ?? "Unknown error")")
                    onChange(nil)
                    return
                }
                
                guard document.exists else {
                    print("Document does not exist")
                    onChange(nil)
                    return
                }
                
                do {
                    let user = try document.data(as: User.self)
                    onChange(user)
                } catch {
                    print("Error decoding user: \(error)")
                    onChange(nil)
                }
            }
        
        // Store listener for cleanup
        userListeners[id] = listener
    }
    
    func stopObservingUser(id: String) {
        userListeners[id]?.remove()
        userListeners.removeValue(forKey: id)
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
    
    func fetchEvent(by id: String) async -> Event? {
        do {
            let document = try await db.collection("events").document(id).getDocument()
            return try document.data(as: Event.self)
        } catch {
            print("Error fetching event: \(error)")
            return nil
        }
    }
    
    func fetchUserEvents(for userId: String) async -> [Event] {
        do {
            let snapshot = try await db.collection("events")
                .whereField("creatorId", isEqualTo: userId)
                .getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: Event.self) }
        } catch {
            print("Error fetching user events: \(error)")
            return []
        }
    }
    
    func fetchCircleEvents(for userId: String, friendIds: [String]) async -> [Event] {
        do {
            let friendIdsStrings = friendIds.map { $0 }
            let snapshot = try await db.collection("events")
                .whereField("creatorId", in: [userId] + friendIdsStrings)
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
        let eventRef = db.collection("events").document(event.id)
        let data = try Firestore.Encoder().encode(event)
        try await eventRef.setData(data)
    }
    
    func deleteEvent(_ eventId: String) async throws {
        try await db.collection("events").document(eventId).delete()
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
    
    func generateNewEventReference() -> (reference: DocumentReference, id: String) {
        let eventRef = db.collection("events").document()
        return (eventRef, eventRef.documentID)
    }
    
    // MARK: - Profile Image Operations
    func uploadProfileImage(_ image: UIImage, for userId: String) async throws -> (fullUrl: String, thumbnailUrl: String) {
        // Delete old images first
        await deleteOldProfileImage(for: userId)
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "com.trailmates", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        let storage = Storage.storage()
        let fullSizeRef = storage.reference(withPath: "profile_images/\(userId)/full.jpg")
        let thumbnailRef = storage.reference(withPath: "profile_images/\(userId)/thumbnail.jpg")
        
        // Create metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // Upload full size image
        _ = try await fullSizeRef.putDataAsync(imageData, metadata: metadata)
        let fullUrl = try await fullSizeRef.downloadURL().absoluteString
        
        // Create and upload thumbnail
        let thumbnailSize = CGSize(width: 150, height: 150)
        guard let thumbnailImage = image.preparingThumbnail(of: thumbnailSize),
              let thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "com.trailmates", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create thumbnail"])
        }
        
        _ = try await thumbnailRef.putDataAsync(thumbnailData, metadata: metadata)
        let thumbnailUrl = try await thumbnailRef.downloadURL().absoluteString
        
        return (fullUrl: fullUrl, thumbnailUrl: thumbnailUrl)
    }
    
    private func deleteOldProfileImage(for userId: String) async {
        let storage = Storage.storage()
        let profileImagesRef = storage.reference(withPath: "profile_images/\(userId)")
        
        do {
            let result = try await profileImagesRef.listAll()
            
            // Delete all existing profile images for this user
            for item in result.items {
                try? await item.delete()
            }
        } catch {
            print("Error deleting old profile images: \(error.localizedDescription)")
            // We don't throw here as this is a cleanup operation
            // and shouldn't prevent the new upload from proceeding
        }
    }
    
    private let imageCache = NSCache<NSString, UIImage>()
    
    func downloadProfileImage(from url: String) async throws -> UIImage {
        // Check cache first
        if let cachedImage = imageCache.object(forKey: url as NSString) {
            return cachedImage
        }
        
        // Download if not in cache
        guard let imageUrl = URL(string: url) else {
            throw NSError(domain: "com.trailmates", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image URL"])
        }
        
        let (data, _) = try await URLSession.shared.data(from: imageUrl)
        guard let image = UIImage(data: data) else {
            throw NSError(domain: "com.trailmates", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
        }
        
        // Cache the downloaded image
        imageCache.setObject(image, forKey: url as NSString)
        return image
    }
    
    func prefetchProfileImages(urls: [String]) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask {
                    _ = try? await self.downloadProfileImage(from: url)
                }
            }
        }
    }
    
    // MARK: - Utility Operations
    func isUsernameTaken(_ username: String, excludingUserId: String?) async -> Bool {
        do {
            var query = db.collection("users").whereField("username", isEqualTo: username)
            
            if let excludeId = excludingUserId {
                query = query.whereField("id", isNotEqualTo: excludeId)
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
    func sendFriendRequest(from userId: String, to targetUserId: String) async throws {
        // Get Firebase UIDs for both users
        let userDoc = try await db.collection("users").document(userId).getDocument()
        let targetDoc = try await db.collection("users").document(targetUserId).getDocument()
        
        guard let userId = userDoc.get("id") as? String,
              let targetId = targetDoc.get("id") as? String else {
            throw ValidationError.invalidData("Could not find Firebase UIDs for users")
        }
        
        // Verify the current user is sending the request
        guard let currentUser = Auth.auth().currentUser,
              currentUser.uid == userId else {
            throw ValidationError.userNotAuthenticated("Cannot send request on behalf of another user")
        }
        
        let requestId = UUID().uuidString
        let requestRef = rtdb.child("friend_requests")
            .child(targetId)
            .child(requestId)
        
        let requestData: [String: Any] = [
            "fromid": userId,  // Use Firebase UID for RTDB
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
        // Get Firebase UID for the accepting user (for RTDB operations)
        let userDoc = try await db.collection("users").document(userId).getDocument()
        guard let userid = userDoc.get("id") as? String else {
            throw ValidationError.invalidData("Could not find Firebase UID for user")
        }
        
        // Add friend relationship in Firestore using SwiftData UUIDs
        try await addFriend(friendId, to: userId)
        try await addFriend(userId, to: friendId)
        
        // Clean up friend request and notification in RTDB using Firebase UID
        let updates: [String: Any?] = [
            "friend_requests/\(userid)/\(requestId)": nil,
            "notifications/\(userid)/\(requestId)": nil
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
            
            // Remove friend IDs
            userFriends.removeAll { $0 == friendId }
            friendFriends.removeAll { $0 == userId }
            
            // Update both documents
            transaction.updateData(["friends": userFriends], forDocument: userRef)
            transaction.updateData(["friends": friendFriends], forDocument: friendRef)
            
            return nil
        }
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
    func updateUserLocation(userId: String, location: CLLocationCoordinate2D) async throws {
        // First get the user's Firebase UID
        guard let userDoc = try? await db.collection("users").document(userId).getDocument(),
              let id = userDoc.get("id") as? String else {
            throw ValidationError.invalidData("Could not find user's Firebase UID")
        }
        
        guard let currentUser = Auth.auth().currentUser else {
            print("Firebase: No authenticated user")
            throw NSError(domain: "com.firebase", code: 1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        // Verify the current user is updating their own location
        guard currentUser.uid == id else {
            throw ValidationError.invalidData("Cannot update location for another user")
        }
        
        // Get fresh ID token to ensure auth is valid
        let token = try await currentUser.getIDToken()
        
        print("\nFirebase Location Debug:")
        print("1. Auth Check:")
        print("   - UID: \(currentUser.uid)")
        print("   - Token valid: \(token.prefix(10))...")
        print("   - Provider: \(currentUser.providerID)")
        print("   - Anonymous: \(currentUser.isAnonymous)")
        
        let locationRef = rtdb.child("locations").child(id)
        print("   - Path: \(locationRef.url)")
        
        // Verify database connection
        let connectedRef = rtdb.child(".info/connected")
        let isConnected = try await withCheckedThrowingContinuation { continuation in
            connectedRef.observeSingleEvent(of: .value) { snapshot in
                continuation.resume(returning: snapshot.value as? Bool ?? false)
            }
        }
        print("2. Connection Check:")
        print("   - Connected: \(isConnected)")
        
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
            
            locationRef.setValue(locationData) { error, ref in
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
}

