import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import SwiftUI

/// Handles all user-related Firebase operations including CRUD, authentication, and queries.
///
/// This is the primary provider for user data operations. It manages:
/// - User document CRUD operations
/// - Phone number and username lookups
/// - Real-time user observation
/// - Profile validation
///
/// ## Usage
/// ```swift
/// // Fetch current user
/// if let user = await UserDataProvider.shared.fetchCurrentUser() {
///     print("Welcome, \(user.firstName)")
/// }
///
/// // Save user changes
/// try await UserDataProvider.shared.saveUser(user)
///
/// // Observe real-time updates
/// UserDataProvider.shared.observeUser(id: userId) { user in
///     // Handle updates
/// }
/// ```
///
/// ## Thread Safety
/// All methods are safe to call from any thread. Firestore handles
/// thread synchronization internally.
@MainActor
class UserDataProvider {
    // MARK: - Singleton
    static let shared = UserDataProvider()

    // MARK: - Dependencies
    private lazy var db = Firestore.firestore()
    private lazy var functions: Functions = {
        let functions = Functions.functions(region: "us-central1")
        #if DEBUG
        print("UserDataProvider: Initializing Firebase Functions in DEBUG mode")
        functions.useEmulator(withHost: "127.0.0.1", port: 5001)
        #endif
        return functions
    }()
    private lazy var auth = Auth.auth()

    /// Active Firestore listeners keyed by user ID for cleanup
    private var userListeners = [String: ListenerRegistration]()

    private init() {
        // Configure Firestore settings with offline persistence
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings()
        db.settings = settings

        print("UserDataProvider initialized")
    }

    deinit {
        // Clean up all user listeners
        userListeners.forEach { _, listener in
            listener.remove()
        }
        userListeners.removeAll()
    }

    // MARK: - Current User Operations

    /// Fetches the currently authenticated user from Firestore.
    ///
    /// This method requires an active Firebase Auth session. It also validates
    /// that the stored user ID matches the document ID, correcting mismatches.
    ///
    /// - Returns: The current User, or nil if not authenticated or not found
    func fetchCurrentUser() async -> User? {
        guard let currentUser = auth.currentUser else {
            #if DEBUG
            print("UserDataProvider: No authenticated user found")
            #endif
            return nil
        }

        do {
            let document = try await db.collection("users").document(currentUser.uid).getDocument()
            guard document.exists else {
                #if DEBUG
                print("UserDataProvider: No user document found for Firebase UID")
                #endif
                return nil
            }

            let user = try document.data(as: User.self)

            // Validate and fix ID mismatch if needed (legacy data migration)
            guard user.id == document.documentID else {
                #if DEBUG
                print("Warning: Stored ID mismatch with document ID - auto-correcting")
                #endif
                try await db.collection("users").document(document.documentID).updateData([
                    "id": document.documentID
                ])
                user.id = document.documentID
                return user
            }

            return user
        } catch {
            #if DEBUG
            print("UserDataProvider: Error fetching user: \(error)")
            #endif
            return nil
        }
    }

    /// Checks if there is an active Firebase Auth session.
    ///
    /// - Returns: true if a user is currently authenticated
    func isUserAuthenticated() -> Bool {
        auth.currentUser != nil
    }

    // MARK: - User CRUD Operations

    func fetchUser(by id: String) async -> User? {
        do {
            #if DEBUG
            print("UserDataProvider: Fetching user with ID: \(id)")
            #endif

            // Use retry logic for network fetch
            let document = try await withRetry(maxAttempts: 3) {
                try await self.db.collection("users").document(id).getDocument()
            }

            guard document.exists else {
                #if DEBUG
                print("UserDataProvider: No user document found with ID: \(id)")
                #endif
                return nil
            }

            let user = try document.data(as: User.self)

            // Validate and fix ID if needed
            if user.id != document.documentID {
                #if DEBUG
                print("Warning: Stored ID mismatch with document ID")
                #endif
                user.id = document.documentID
                try? await db.collection("users").document(id).updateData([
                    "id": document.documentID
                ])
            }

            // Handle profile image according to hierarchy rules
            if let imageUrl = user.profileImageUrl {
                do {
                    user.profileImage = try await ImageStorageProvider.shared.downloadProfileImage(from: imageUrl)
                    #if DEBUG
                    print("UserDataProvider: Loaded profile image from remote URL")
                    #endif
                } catch let error as AppError {
                    #if DEBUG
                    print("Warning: Failed to load remote image: \(error.errorDescription ?? "Unknown")")
                    #endif
                    user.profileImageUrl = nil
                    user.profileThumbnailUrl = nil

                    try? await db.collection("users").document(id).updateData([
                        "profileImageUrl": FieldValue.delete(),
                        "profileThumbnailUrl": FieldValue.delete()
                    ])
                } catch {
                    #if DEBUG
                    print("Warning: Failed to load remote image: \(error.localizedDescription)")
                    #endif
                    user.profileImageUrl = nil
                    user.profileThumbnailUrl = nil

                    try? await db.collection("users").document(id).updateData([
                        "profileImageUrl": FieldValue.delete(),
                        "profileThumbnailUrl": FieldValue.delete()
                    ])
                }
            }

            return user
        } catch {
            let appError = AppError.from(error)
            #if DEBUG
            print("UserDataProvider: Error fetching user: \(appError.errorDescription ?? "Unknown")")
            #endif
            return nil
        }
    }

    func fetchAllUsers() async -> [User] {
        do {
            // Use retry logic for network fetch
            let snapshot = try await withRetry(maxAttempts: 3) {
                try await self.db.collection("users").getDocuments()
            }
            return snapshot.documents.compactMap { try? $0.data(as: User.self) }
        } catch {
            let appError = AppError.from(error)
            #if DEBUG
            print("UserDataProvider: Error fetching all users: \(appError.errorDescription ?? "Unknown")")
            #endif
            return []
        }
    }

    func saveInitialUser(_ user: User) async throws {
        #if DEBUG
        print("UserDataProvider: Starting initial user save")
        #endif
        guard !user.phoneNumber.isEmpty else {
            throw AppError.emptyField("Phone number")
        }

        // Ensure user.id matches Auth UID
        guard let currentUser = auth.currentUser,
              user.id == currentUser.uid else {
            throw AppError.invalidData("User ID must match Firebase Auth UID")
        }

        let userRef = db.collection("users").document(user.id)

        // First check if document already exists
        let docSnapshot = try await userRef.getDocument()
        guard !docSnapshot.exists else {
            throw AppError.alreadyExists("User document")
        }

        let initialData: [String: Any] = [
            "id": user.id,
            "phoneNumber": user.phoneNumber,
            "hashedPhoneNumber": user.hashedPhoneNumber,
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

        try await userRef.setData(initialData)

        // Verify the document was created with matching IDs
        let verifySnapshot = try await userRef.getDocument()
        guard verifySnapshot.exists,
              let storedId = verifySnapshot.get("id") as? String,
              storedId == user.id else {
            throw AppError.invalidData("Failed to verify user creation or ID mismatch")
        }
    }

    func saveUser(_ user: User) async throws {
        #if DEBUG
        print("UserDataProvider: Starting full user save")
        #endif

        // Only validate required fields if this is not initial setup
        if !user.firstName.isEmpty || !user.lastName.isEmpty || !user.username.isEmpty {
            guard !user.firstName.isEmpty,
                  !user.lastName.isEmpty,
                  !user.username.isEmpty else {
                #if DEBUG
                print("UserDataProvider: Error - Missing required fields")
                print("User: \(user)")
                #endif
                throw AppError.missingRequiredFields("First name, last name, and username are required")
            }
        }

        let userData = user
        #if DEBUG
        print("UserDataProvider: Using document ID: \(user.id)")
        #endif

        // If there's a profile image, upload it to Storage first
        if let image = user.profileImage {
            #if DEBUG
            print("UserDataProvider: Profile image found, uploading...")
            #endif
            // Delete old profile images
            await ImageStorageProvider.shared.deleteOldProfileImage(for: user.id)

            // Upload new image and get URLs
            let urls = try await ImageStorageProvider.shared.uploadProfileImage(image, for: user.id)
            #if DEBUG
            print("UserDataProvider: Profile image uploaded successfully")
            #endif

            // Store the URLs and clear the image data
            userData.profileImage = nil
            userData.profileImageUrl = urls.fullUrl
            userData.profileThumbnailUrl = urls.thumbnailUrl
        }

        // Save user data to Firestore
        let userRef = db.collection("users").document(user.id)
        let data = try Firestore.Encoder().encode(userData)

        #if DEBUG
        print("UserDataProvider: Attempting to save full user data")
        #endif
        do {
            try await userRef.setData(data)
            #if DEBUG
            print("UserDataProvider: Full user data saved successfully")
            #endif
        } catch {
            let appError = AppError.from(error)
            #if DEBUG
            print("UserDataProvider: Error saving full user: \(appError.errorDescription ?? "Unknown")")
            #endif
            throw appError
        }
    }

    // MARK: - User Query Methods

    func fetchFriends(for user: User) async -> [User] {
        var friends: [User] = []
        for friendId in user.friends {
            if let friend = await fetchUser(by: friendId) {
                friends.append(friend)
            }
        }
        return friends
    }

    // MARK: - Phone Number Operations

    func fetchUser(byPhoneNumber phoneNumber: String) async -> User? {
        #if DEBUG
        print("UserDataProvider: Fetching user by phone number")
        #endif
        let hashedNumber = PhoneNumberHasher.shared.hashPhoneNumber(phoneNumber)
        #if DEBUG
        print("   Hashed number: '\(hashedNumber)'")
        #endif

        do {
            #if DEBUG
            print("Querying Firestore for hashed phone: '\(hashedNumber)'")
            #endif

            // Use retry logic for network fetch
            let snapshot = try await withRetry(maxAttempts: 3) {
                try await self.db.collection("users")
                    .whereField("hashedPhoneNumber", isEqualTo: hashedNumber)
                    .limit(to: 1)
                    .getDocuments()
            }

            if let doc = snapshot.documents.first {
                #if DEBUG
                print("UserDataProvider: Found user document: \(doc.documentID)")
                #endif
                let user = try doc.data(as: User.self)
                #if DEBUG
                print("   User details: \(user.firstName) \(user.lastName)")
                #endif
                return user
            } else {
                #if DEBUG
                print("UserDataProvider: No user document found for hashed phone: '\(hashedNumber)'")
                #endif
                return nil
            }
        } catch {
            let appError = AppError.from(error)
            #if DEBUG
            print("UserDataProvider: Error fetching user by phone: \(appError.errorDescription ?? "Unknown")")
            #endif
            return nil
        }
    }

    func checkUserExists(phoneNumber: String) async -> Bool {
        let hashedNumber = PhoneNumberHasher.shared.hashPhoneNumber(phoneNumber)

        let function = functions.httpsCallable("checkUserExists")
        do {
            // Use retry logic for cloud function call
            let result = try await withRetry(maxAttempts: 3) {
                try await function.call(["hashedPhoneNumber": hashedNumber])
            }
            if let data = result.data as? [String: Any],
               let userExists = data["userExists"] as? Bool {
                return userExists
            }
        } catch {
            let appError = AppError.from(error)
            #if DEBUG
            print("UserDataProvider: Error calling checkUserExists function: \(appError.errorDescription ?? "Unknown")")
            #endif
        }
        return false
    }

    func ensureUserDocument() async throws {
        let callable = functions.httpsCallable("ensureUserDocument")

        do {
            _ = try await withRetry(maxAttempts: 3) {
                try await callable.call()
            }
        } catch {
            throw AppError.from(error)
        }
    }

    func findUsersByPhoneNumbers(_ phoneNumbers: [String]) async throws -> [User] {
        let hashedNumbers = phoneNumbers.map { PhoneNumberHasher.shared.hashPhoneNumber($0) }

        do {
            let callable = functions.httpsCallable("findUsersByPhoneNumbers")

            // Use retry logic for cloud function call
            let result = try await withRetry(maxAttempts: 3) {
                try await callable.call(["hashedPhoneNumbers": hashedNumbers])
            }

            guard let response = result.data as? [String: Any],
                  let usersData = response["users"] as? [[String: Any]] else {
                throw AppError.invalidData("Invalid response format from server")
            }

            let matchedUsers = try usersData.map { userData in
                let jsonData = try JSONSerialization.data(withJSONObject: userData)
                return try JSONDecoder().decode(User.self, from: jsonData)
            }

            #if DEBUG
            print("UserDataProvider: Successfully matched \(matchedUsers.count) users")
            #endif
            return matchedUsers

        } catch {
            let appError = AppError.from(error)
            #if DEBUG
            print("UserDataProvider: Error finding users by phone numbers: \(appError.errorDescription ?? "Unknown")")
            #endif
            throw appError
        }
    }

    // MARK: - Username Operations

    func isUsernameTaken(_ username: String, excludingUserId: String?) async -> Bool {
        return await isUsernameTakenCloudFunction(username, excludingUserId: excludingUserId)
    }

    func isUsernameTakenCloudFunction(_ username: String, excludingUserId: String?) async -> Bool {
        do {
            // Use retry logic for cloud function call
            let result = try await withRetry(maxAttempts: 3) {
                try await self.functions.httpsCallable("checkUsernameTaken")
                    .call([
                        "username": username,
                        "excludeUserId": excludingUserId ?? ""
                    ])
            }

            if let data = result.data as? [String: Any],
               let usernameTaken = data["usernameTaken"] as? Bool {
                return usernameTaken
            }
        } catch {
            let appError = AppError.from(error)
            #if DEBUG
            print("UserDataProvider: Error calling checkUsernameTaken: \(appError.errorDescription ?? "Unknown")")
            #endif
        }
        return false
    }

    // MARK: - User Observation

    func observeUser(id: String, onChange: @escaping (User?) -> Void) {
        // Remove existing listener if any
        stopObservingUser(id: id)

        // Create new listener
        let listener = db.collection("users").document(id)
            .addSnapshotListener { documentSnapshot, error in
                guard let document = documentSnapshot else {
                    let appError = error.map { AppError.from($0) } ?? AppError.unknown()
                    #if DEBUG
                    print("UserDataProvider: Error fetching document: \(appError.errorDescription ?? "Unknown")")
                    #endif
                    onChange(nil)
                    return
                }

                guard document.exists else {
                    #if DEBUG
                    print("UserDataProvider: Document does not exist")
                    #endif
                    onChange(nil)
                    return
                }

                do {
                    let user = try document.data(as: User.self)
                    onChange(user)
                } catch {
                    let appError = AppError.from(error)
                    #if DEBUG
                    print("UserDataProvider: Error decoding user: \(appError.errorDescription ?? "Unknown")")
                    #endif
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

    func stopObservingAllUsers() {
        userListeners.forEach { _, listener in
            listener.remove()
        }
        userListeners.removeAll()
    }
}
