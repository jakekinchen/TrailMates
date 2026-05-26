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

    /// Image storage provider for profile image operations.
    /// Accessed via a stored property to avoid scattering direct singleton
    /// references throughout method bodies.
    private let imageProvider: ImageStorageProvider = .shared

    /// Active Firestore listeners keyed by user ID for cleanup
    private var userListeners = [String: ListenerRegistration]()

    private init() {
        // Firestore settings (persistence, cache) are configured centrally
        // in FirebaseProviderContainer.init() to avoid duplicate configuration.
        print("UserDataProvider initialized")
    }

    // No deinit needed: UserDataProvider is a singleton (static let shared)
    // and will never be deallocated. Listener cleanup is handled by
    // stopObservingUser(id:) and stopObservingAllUsers().

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
            let document = try await db.collection(FirestoreConstants.Collections.users).document(currentUser.uid).getDocument()
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
                try await db.collection(FirestoreConstants.Collections.users).document(document.documentID).updateData([
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
                try await self.db.collection(FirestoreConstants.Collections.users).document(id).getDocument()
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
                try? await db.collection(FirestoreConstants.Collections.users).document(id).updateData([
                    "id": document.documentID
                ])
            }

            // Profile image loading is handled lazily by UserAvatarView.
            // We intentionally do NOT download images here to keep fetches fast
            // and avoid side effects (like deleting Firestore URLs on transient failures).

            return user
        } catch {
            let appError = AppError.classify(error)
            #if DEBUG
            print("UserDataProvider: Error fetching user: \(appError.errorDescription ?? "Unknown")")
            #endif
            return nil
        }
    }

    func fetchAllUsers(limit: Int = 50) async -> [User] {
        #if DEBUG
        print("UserDataProvider: fetchAllUsers is disabled; use targeted searchUsers/fetchPublicUserProfile callables instead.")
        #endif
        return []
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

        try Self.normalizePhoneNumberForPersistence(user)

        let userRef = db.collection(FirestoreConstants.Collections.users).document(user.id)

        // First check if document already exists
        let docSnapshot = try await userRef.getDocument()
        guard !docSnapshot.exists else {
            throw AppError.alreadyExists("User document")
        }

        // Use Firestore.Encoder for consistency with saveUser
        var initialData = try Firestore.Encoder().encode(user)
        initialData["usernameSearchKey"] = Self.normalizedUsername(user.username)

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

        try Self.normalizePhoneNumberForPersistence(user)

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
            await imageProvider.deleteOldProfileImage(for: user.id)

            // Upload new image and get URLs
            let urls = try await imageProvider.uploadProfileImage(image, for: user.id)
            #if DEBUG
            print("UserDataProvider: Profile image uploaded successfully")
            #endif

            // Store the URLs and clear the image data
            userData.profileImage = nil
            userData.profileImageUrl = urls.fullUrl
            userData.profileThumbnailUrl = urls.thumbnailUrl
        }

        // Save user data to Firestore
        let userRef = db.collection(FirestoreConstants.Collections.users).document(user.id)
        var data = try Firestore.Encoder().encode(userData)
        data["usernameSearchKey"] = Self.normalizedUsername(userData.username)

        #if DEBUG
        print("UserDataProvider: Attempting to save full user data")
        #endif
        do {
            try await userRef.setData(data, merge: true)
            #if DEBUG
            print("UserDataProvider: Full user data saved successfully")
            #endif
        } catch {
            let appError = try AppError.from(error)
            #if DEBUG
            print("UserDataProvider: Error saving full user: \(appError.errorDescription ?? "Unknown")")
            #endif
            throw appError
        }
    }

    func updateUserFields(userId: String, fields: [String: Any]) async throws {
        guard !fields.isEmpty else { return }

        let userRef = db.collection(FirestoreConstants.Collections.users).document(userId)
        do {
            try await withRetry(maxAttempts: 3) {
                try await userRef.updateData(fields)
            }
        } catch {
            throw try AppError.from(error)
        }
    }

    func updateAttendingEvent(userId: String, eventId: String, isAttending: Bool) async throws {
        let eventUpdate = isAttending
            ? FieldValue.arrayUnion([eventId])
            : FieldValue.arrayRemove([eventId])

        try await updateUserFields(
            userId: userId,
            fields: ["attendingEventIds": eventUpdate]
        )
    }

    // MARK: - User Query Methods

    func fetchFriends(for user: User) async -> [User] {
        let friendIds = user.friends
        guard !friendIds.isEmpty else { return [] }

        // Firestore 'in' queries are limited to 30 items per query; chunk accordingly
        let chunkSize = 30
        var friends: [User] = []

        for chunkStart in stride(from: 0, to: friendIds.count, by: chunkSize) {
            let chunkEnd = min(chunkStart + chunkSize, friendIds.count)
            let chunk = Array(friendIds[chunkStart..<chunkEnd])

            do {
                let snapshot = try await withRetry(maxAttempts: 3) {
                    try await self.db.collection(FirestoreConstants.Collections.users)
                        .whereField(FieldPath.documentID(), in: chunk)
                        .getDocuments()
                }
                let chunkUsers = snapshot.documents.compactMap { try? $0.data(as: User.self) }
                friends.append(contentsOf: chunkUsers)
            } catch {
                #if DEBUG
                print("UserDataProvider: Error batch-fetching friends chunk: \(error.localizedDescription)")
                #endif
            }
        }

        return friends
    }

    func fetchUser(byUsername username: String) async -> User? {
        do {
            return try await searchUsers(username: username, phoneNumber: nil).first
        } catch {
            let appError = AppError.classify(error)
            #if DEBUG
            print("UserDataProvider: Error fetching user by username: \(appError.errorDescription ?? "Unknown")")
            #endif
            return nil
        }
    }

    // MARK: - Phone Number Operations

    func fetchUser(byPhoneNumber phoneNumber: String) async -> User? {
        #if DEBUG
        print("UserDataProvider: Fetching user by phone number")
        #endif
        do {
            return try await searchUsers(username: nil, phoneNumber: phoneNumber).first
        } catch {
            let appError = AppError.classify(error)
            #if DEBUG
            print("UserDataProvider: Error fetching user by phone callable: \(appError.errorDescription ?? "Unknown")")
            #endif
            return nil
        }
    }

    func checkUserExists(phoneNumber: String) async -> Bool {
        let hashedNumber = PhoneNumberHasher.shared.hashPhoneNumber(phoneNumber)
        // Also send E.164 format for legacy user lookup
        let e164Number = PhoneNumberService.shared.format(phoneNumber, for: .storage)

        let function = functions.httpsCallable(FirestoreConstants.Functions.checkUserExists)
        do {
            // Use retry logic for cloud function call
            let result = try await withRetry(maxAttempts: 3) {
                try await function.call([
                    "hashedPhoneNumber": hashedNumber,
                    "phoneNumberE164": e164Number ?? phoneNumber
                ])
            }
            if let data = result.data as? [String: Any],
               let userExists = data["userExists"] as? Bool {
                return userExists
            }
        } catch {
            let appError = AppError.classify(error)
            #if DEBUG
            print("UserDataProvider: Error calling checkUserExists function: \(appError.errorDescription ?? "Unknown")")
            #endif
        }
        return false
    }

    func ensureUserDocument() async throws {
        let callable = functions.httpsCallable(FirestoreConstants.Functions.ensureUserDocument)

        do {
            _ = try await withRetry(maxAttempts: 3) {
                try await callable.call()
            }
        } catch {
            throw try AppError.from(error)
        }
    }

    func findUsersByPhoneNumbers(_ phoneNumbers: [String]) async throws -> [User] {
        let hashedNumbers = phoneNumbers.map { PhoneNumberHasher.shared.hashPhoneNumber($0) }

        do {
            let callable = functions.httpsCallable(FirestoreConstants.Functions.findUsersByPhoneNumbers)

            // Use retry logic for cloud function call
            let result = try await withRetry(maxAttempts: 3) {
                try await callable.call(["hashedPhoneNumbers": hashedNumbers])
            }

            guard let response = result.data as? [String: Any],
                  let usersData = response["users"] as? [[String: Any]] else {
                throw AppError.invalidData("Invalid response format from server")
            }

            let matchedUsers = usersData.compactMap { callableUser(from: $0) }

            #if DEBUG
            print("UserDataProvider: Successfully matched \(matchedUsers.count) users")
            #endif
            return matchedUsers

        } catch {
            let appError = try AppError.from(error)
            #if DEBUG
            print("UserDataProvider: Error finding users by phone numbers: \(appError.errorDescription ?? "Unknown")")
            #endif
            throw appError
        }
    }

    func searchUsers(username: String?, phoneNumber: String?) async throws -> [User] {
        let trimmedUsername = username?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedUsername: String?
        if let trimmedUsername, trimmedUsername.hasPrefix("@") {
            normalizedUsername = String(trimmedUsername.dropFirst())
        } else {
            normalizedUsername = trimmedUsername
        }

        let normalizedPhone = phoneNumber.flatMap {
            PhoneNumberService.shared.format($0, for: .storage)
        }

        let hashedPhoneNumber = normalizedPhone.map {
            PhoneNumberHasher.shared.hashPhoneNumber($0)
        }

        guard !(normalizedUsername?.isEmpty ?? true) || hashedPhoneNumber != nil else {
            throw AppError.invalidInput("Enter a username or phone number.")
        }

        do {
            let callable = functions.httpsCallable(FirestoreConstants.Functions.searchUsers)
            let result = try await withRetry(maxAttempts: 3) {
                try await callable.call([
                    "username": normalizedUsername ?? "",
                    "hashedPhoneNumber": hashedPhoneNumber ?? ""
                ])
            }

            guard let response = result.data as? [String: Any],
                  let usersData = response["users"] as? [[String: Any]] else {
                throw AppError.invalidData("Invalid response format from server")
            }

            return usersData.compactMap { callableUser(from: $0) }
        } catch {
            throw try AppError.from(error)
        }
    }

    func fetchPublicUserProfile(userId: String) async throws -> User {
        do {
            let callable = functions.httpsCallable(FirestoreConstants.Functions.searchUsers)
            let result = try await withRetry(maxAttempts: 3) {
                try await callable.call(["userId": userId])
            }

            guard let response = result.data as? [String: Any],
                  let usersData = response["users"] as? [[String: Any]],
                  let user = usersData.compactMap({ callableUser(from: $0) }).first else {
                throw AppError.notFound("Profile")
            }

            return user
        } catch {
            throw try AppError.from(error)
        }
    }

    private func callableUser(from userData: [String: Any]) -> User? {
        guard let id = userData["id"] as? String else { return nil }

        // Intentionally do NOT populate phoneNumber or hashedPhoneNumber from
        // callable responses — these are private fields that should not be
        // exposed through search/public profile endpoints.
        let user = User(
            id: id,
            firstName: userData["firstName"] as? String ?? "",
            lastName: userData["lastName"] as? String ?? "",
            username: userData["username"] as? String ?? "",
            phoneNumber: "",
            joinDate: callableDate(from: userData["joinDate"])
        )

        user.profileImageUrl = userData["profileImageUrl"] as? String
        user.profileThumbnailUrl = userData["profileThumbnailUrl"] as? String
        user.isActive = userData["isActive"] as? Bool ?? user.isActive
        user.friends = userData["friends"] as? [String] ?? user.friends
        user.doNotDisturb = userData["doNotDisturb"] as? Bool ?? false
        user.createdEventIds = userData["createdEventIds"] as? [String] ?? []
        user.attendingEventIds = userData["attendingEventIds"] as? [String] ?? []
        user.visitedLandmarkIds = userData["visitedLandmarkIds"] as? [String] ?? []
        user.facebookId = userData["facebookId"] as? String

        // Notification settings
        user.receiveFriendRequests = userData["receiveFriendRequests"] as? Bool ?? true
        user.receiveFriendEvents = userData["receiveFriendEvents"] as? Bool ?? true
        user.receiveEventUpdates = userData["receiveEventUpdates"] as? Bool ?? true

        // Privacy settings
        user.shareLocationWithFriends = userData["shareLocationWithFriends"] as? Bool ?? true
        user.shareLocationWithEventHost = userData["shareLocationWithEventHost"] as? Bool ?? true
        user.shareLocationWithEventGroup = userData["shareLocationWithEventGroup"] as? Bool ?? true
        user.allowFriendsToInviteOthers = userData["allowFriendsToInviteOthers"] as? Bool ?? true

        return user
    }

    private func callableDate(from value: Any?) -> Date {
        if let timestamp = value as? Timestamp {
            return timestamp.dateValue()
        }

        if let date = value as? Date {
            return date
        }

        if let isoString = value as? String,
           let date = ISO8601DateFormatter().date(from: isoString) {
            return date
        }

        if let seconds = value as? TimeInterval {
            return Date(timeIntervalSince1970: seconds)
        }

        if let timestampData = value as? [String: Any],
           let seconds = timestampData["_seconds"] as? TimeInterval {
            let nanos = timestampData["_nanoseconds"] as? TimeInterval ?? 0
            return Date(timeIntervalSince1970: seconds + nanos / 1_000_000_000)
        }

        #if DEBUG
        print("UserDataProvider: callableDate failed to parse value: \(String(describing: value)) — falling back to Date()")
        #endif
        return Date()
    }

    // MARK: - Username Operations

    func isUsernameTaken(_ username: String, excludingUserId: String?) async -> Bool {
        return await isUsernameTakenCloudFunction(username, excludingUserId: excludingUserId)
    }

    func isUsernameTakenCloudFunction(_ username: String, excludingUserId: String?) async -> Bool {
        do {
            // Use retry logic for cloud function call
            let result = try await withRetry(maxAttempts: 3) {
                try await self.functions.httpsCallable(FirestoreConstants.Functions.checkUsernameTaken)
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
            let appError = AppError.classify(error)
            #if DEBUG
            print("UserDataProvider: Error calling checkUsernameTaken: \(appError.errorDescription ?? "Unknown")")
            #endif
        }
        return false
    }

    // MARK: - User Observation

    func observeUser(id: String, onChange: @escaping @Sendable (User?) -> Void) {
        // Remove existing listener if any
        stopObservingUser(id: id)

        // Create new listener
        let listener = db.collection(FirestoreConstants.Collections.users).document(id)
            .addSnapshotListener { documentSnapshot, error in
                guard let document = documentSnapshot else {
                    let appError = error.map { AppError.classify($0) } ?? AppError.unknown()
                    #if DEBUG
                    print("UserDataProvider: Error fetching document: \(appError.errorDescription ?? "Unknown")")
                    #endif
                    Task { @MainActor in onChange(nil) }
                    return
                }

                guard document.exists else {
                    #if DEBUG
                    print("UserDataProvider: Document does not exist")
                    #endif
                    Task { @MainActor in onChange(nil) }
                    return
                }

                do {
                    let user = try document.data(as: User.self)
                    Task { @MainActor in onChange(user) }
                } catch {
                    let appError = AppError.classify(error)
                    #if DEBUG
                    print("UserDataProvider: Error decoding user: \(appError.errorDescription ?? "Unknown")")
                    #endif
                    Task { @MainActor in onChange(nil) }
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

    // MARK: - Account Deletion

    /// Deletes a user document from Firestore (used during account deletion)
    func deleteUserDocument(userId: String) async throws {
        let userRef = db.collection(FirestoreConstants.Collections.users).document(userId)

        do {
            try await userRef.delete()
            #if DEBUG
            print("UserDataProvider: Deleted user document for \(userId)")
            #endif
        } catch {
            throw try AppError.from(error)
        }
    }

    private static func normalizedUsername(_ username: String) -> String {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutPrefix = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
        return withoutPrefix.lowercased()
    }

    private static func normalizePhoneNumberForPersistence(_ user: User) throws {
        guard let storagePhone = PhoneNumberService.shared.format(user.phoneNumber, for: .storage) else {
            throw AppError.invalidData("Phone number must be valid before saving.")
        }

        if user.phoneNumber != storagePhone {
            user.updatePhoneNumber(storagePhone)
        }
    }
}
