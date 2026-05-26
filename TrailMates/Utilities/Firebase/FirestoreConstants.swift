import Foundation

/// Centralized constants for all Firebase path strings used across providers.
///
/// Using these constants instead of hardcoded strings prevents typos,
/// enables compiler-checked references, and makes future path changes
/// a single-line edit.
///
/// ## Usage
/// ```swift
/// // Firestore collection reference
/// db.collection(FirestoreConstants.Collections.users).document(id)
///
/// // Cloud Function call
/// functions.httpsCallable(FirestoreConstants.Functions.searchUsers)
///
/// // Realtime Database path
/// rtdb.child(FirestoreConstants.RTDBPaths.locations).child(userId)
/// ```
enum FirestoreConstants {

    // MARK: - Firestore Collections

    enum Collections {
        static let users = "users"
        static let events = "events"
        static let landmarks = "landmarks"
    }

    // MARK: - Cloud Functions

    enum Functions {
        static let checkUserExists = "checkUserExists"
        static let searchUsers = "searchUsers"
        static let checkUsernameTaken = "checkUsernameTaken"
        static let findUsersByPhoneNumbers = "findUsersByPhoneNumbers"
        static let ensureUserDocument = "ensureUserDocument"
        static let acceptFriendRequest = "acceptFriendRequest"
        static let removeFriend = "removeFriend"
    }

    // MARK: - Realtime Database Paths

    enum RTDBPaths {
        static let locations = "locations"
        static let friendRequests = "friend_requests"
        static let notifications = "notifications"
    }

    // MARK: - Storage Paths

    enum StoragePaths {
        static let profileImages = "profile_images"
    }
}
