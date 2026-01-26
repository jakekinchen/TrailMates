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
            print("UserDataProvider: Fetching user with ID: \(id)")
            let document = try await db.collection("users").document(id).getDocument()

            guard document.exists else {
                print("UserDataProvider: No user document found with ID: \(id)")
                return nil
            }

            let user = try document.data(as: User.self)

            // Validate and fix ID if needed
            if user.id != document.documentID {
                print("Warning: Stored ID mismatch with document ID")
                user.id = document.documentID
                try? await db.collection("users").document(id).updateData([
                    "id": document.documentID
                ])
            }

            // Handle profile image according to hierarchy rules
            if let imageUrl = user.profileImageUrl {
                do {
                    user.profileImage = try await ImageStorageProvider.shared.downloadProfileImage(from: imageUrl)
                    print("UserDataProvider: Loaded profile image from remote URL")
                } catch {
                    print("Warning: Failed to load remote image: \(error.localizedDescription)")
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
            print("UserDataProvider: Error fetching user: \(error)")
            return nil
        }
    }

    func fetchAllUsers() async -> [User] {
        do {
            let snapshot = try await db.collection("users").getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: User.self) }
        } catch {
            print("UserDataProvider: Error fetching all users: \(error)")
            return []
        }
    }

    func saveInitialUser(_ user: User) async throws {
        print("UserDataProvider: Starting initial user save")
        guard !user.phoneNumber.isEmpty else {
            throw FirebaseDataProvider.ValidationError.emptyField("Phone number cannot be empty")
        }

        // Ensure user.id matches Auth UID
        guard let currentUser = auth.currentUser,
              user.id == currentUser.uid else {
            throw FirebaseDataProvider.ValidationError.invalidData("User ID must match Firebase Auth UID")
        }

        let userRef = db.collection("users").document(user.id)

        // First check if document already exists
        let docSnapshot = try await userRef.getDocument()
        guard !docSnapshot.exists else {
            throw FirebaseDataProvider.ValidationError.invalidData("User document already exists")
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
            throw FirebaseDataProvider.ValidationError.invalidData("Failed to verify user creation or ID mismatch")
        }
    }

    func saveUser(_ user: User) async throws {
        print("UserDataProvider: Starting full user save")

        // Only validate required fields if this is not initial setup
        if !user.firstName.isEmpty || !user.lastName.isEmpty || !user.username.isEmpty {
            guard !user.firstName.isEmpty,
                  !user.lastName.isEmpty,
                  !user.username.isEmpty else {
                print("UserDataProvider: Error - Missing required fields")
                print("User: \(user)")
                throw FirebaseDataProvider.ValidationError.missingRequiredFields("All required fields must be non-empty")
            }
        }

        let userData = user
        print("UserDataProvider: Using document ID: \(user.id)")

        // If there's a profile image, upload it to Storage first
        if let image = user.profileImage {
            print("UserDataProvider: Profile image found, uploading...")
            // Delete old profile images
            await ImageStorageProvider.shared.deleteOldProfileImage(for: user.id)

            // Upload new image and get URLs
            let urls = try await ImageStorageProvider.shared.uploadProfileImage(image, for: user.id)
            print("UserDataProvider: Profile image uploaded successfully")

            // Store the URLs and clear the image data
            userData.profileImage = nil
            userData.profileImageUrl = urls.fullUrl
            userData.profileThumbnailUrl = urls.thumbnailUrl
        }

        // Save user data to Firestore
        let userRef = db.collection("users").document(user.id)
        let data = try Firestore.Encoder().encode(userData)

        print("UserDataProvider: Attempting to save full user data")
        do {
            try await userRef.setData(data)
            print("UserDataProvider: Full user data saved successfully")
        } catch {
            print("UserDataProvider: Error saving full user: \(error.localizedDescription)")
            print("Error details: \(String(describing: error))")
            throw error
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
        print("UserDataProvider: Fetching user by phone number")
        let hashedNumber = PhoneNumberHasher.shared.hashPhoneNumber(phoneNumber)
        print("   Hashed number: '\(hashedNumber)'")

        do {
            print("Querying Firestore for hashed phone: '\(hashedNumber)'")
            let snapshot = try await db.collection("users")
                                    .whereField("hashedPhoneNumber", isEqualTo: hashedNumber)
                                    .limit(to: 1)
                                    .getDocuments()

            if let doc = snapshot.documents.first {
                print("UserDataProvider: Found user document: \(doc.documentID)")
                let user = try doc.data(as: User.self)
                print("   User details: \(user.firstName) \(user.lastName)")
                return user
            } else {
                print("UserDataProvider: No user document found for hashed phone: '\(hashedNumber)'")
                return nil
            }
        } catch {
            print("UserDataProvider: Error fetching user by phone: \(error)")
            return nil
        }
    }

    func checkUserExists(phoneNumber: String) async -> Bool {
        let hashedNumber = PhoneNumberHasher.shared.hashPhoneNumber(phoneNumber)

        let function = functions.httpsCallable("checkUserExists")
        do {
            let result = try await function.call(["hashedPhoneNumber": hashedNumber])
            if let data = result.data as? [String: Any],
               let userExists = data["userExists"] as? Bool {
                return userExists
            }
        } catch {
            print("UserDataProvider: Error calling checkUserExists function: \(error)")
        }
        return false
    }

    func findUsersByPhoneNumbers(_ phoneNumbers: [String]) async throws -> [User] {
        let hashedNumbers = phoneNumbers.map { PhoneNumberHasher.shared.hashPhoneNumber($0) }

        do {
            let callable = functions.httpsCallable("findUsersByPhoneNumbers")
            let result = try await callable.call(["hashedPhoneNumbers": hashedNumbers])

            guard let response = result.data as? [String: Any],
                  let usersData = response["users"] as? [[String: Any]] else {
                throw FirebaseDataProvider.ValidationError.invalidData("Invalid response format")
            }

            let matchedUsers = try usersData.map { userData in
                let jsonData = try JSONSerialization.data(withJSONObject: userData)
                return try JSONDecoder().decode(User.self, from: jsonData)
            }

            print("UserDataProvider: Successfully matched \(matchedUsers.count) users")
            return matchedUsers

        } catch {
            print("UserDataProvider: Error finding users by phone numbers: \(error)")
            throw error
        }
    }

    // MARK: - Username Operations

    func isUsernameTaken(_ username: String, excludingUserId: String?) async -> Bool {
        return await isUsernameTakenCloudFunction(username, excludingUserId: excludingUserId)
    }

    func isUsernameTakenCloudFunction(_ username: String, excludingUserId: String?) async -> Bool {
        do {
            let result = try await functions.httpsCallable("checkUsernameTaken")
                .call([
                    "username": username,
                    "excludeUserId": excludingUserId ?? ""
                ])

            if let data = result.data as? [String: Any],
               let usernameTaken = data["usernameTaken"] as? Bool {
                return usernameTaken
            }
        } catch {
            print("UserDataProvider: Error calling checkUsernameTaken:", error)
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
                    print("UserDataProvider: Error fetching document: \(error?.localizedDescription ?? "Unknown error")")
                    onChange(nil)
                    return
                }

                guard document.exists else {
                    print("UserDataProvider: Document does not exist")
                    onChange(nil)
                    return
                }

                do {
                    let user = try document.data(as: User.self)
                    onChange(user)
                } catch {
                    print("UserDataProvider: Error decoding user: \(error)")
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
