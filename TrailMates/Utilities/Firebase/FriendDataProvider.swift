import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseDatabase

/// Handles all friend-related Firebase operations
/// Extracted from FirebaseDataProvider as part of the provider refactoring
@MainActor
class FriendDataProvider {
    // MARK: - Singleton
    static let shared = FriendDataProvider()

    // MARK: - Dependencies
    private lazy var db = Firestore.firestore()
    private lazy var rtdb = Database.database().reference()
    private lazy var auth = Auth.auth()

    private init() {
        print("FriendDataProvider initialized")
    }

    // MARK: - Friend Request Operations

    func sendFriendRequest(fromUserId: String, to targetUserId: String) async throws {
        // Get Firebase UIDs for both users
        let userDoc = try await db.collection("users").document(fromUserId).getDocument()
        let targetDoc = try await db.collection("users").document(targetUserId).getDocument()

        guard let userId = userDoc.get("id") as? String,
              let targetId = targetDoc.get("id") as? String else {
            throw FirebaseDataProvider.ValidationError.invalidData("Could not find Firebase UIDs for users")
        }

        // Verify the current user is sending the request
        guard let currentUser = Auth.auth().currentUser,
              currentUser.uid == userId else {
            throw FirebaseDataProvider.ValidationError.userNotAuthenticated("Cannot send request on behalf of another user")
        }

        let requestId = UUID().uuidString
        let requestRef = rtdb.child("friend_requests")
            .child(targetId)
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
        // Get Firebase UID for the accepting user (for RTDB operations)
        let userDoc = try await db.collection("users").document(userId).getDocument()
        guard let firebaseUid = userDoc.get("id") as? String else {
            throw FirebaseDataProvider.ValidationError.invalidData("Could not find Firebase UID for user")
        }

        // Add friend relationship in Firestore using SwiftData UUIDs
        try await addFriend(friendId, to: userId)
        try await addFriend(userId, to: friendId)

        // Clean up friend request and notification in RTDB using Firebase UID
        let updates: [String: Any?] = [
            "friend_requests/\(firebaseUid)/\(requestId)": nil,
            "notifications/\(firebaseUid)/\(requestId)": nil
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
            throw FirebaseDataProvider.ValidationError.userNotAuthenticated("No authenticated user")
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

    func updateFriendRequestStatus(requestId: String, targetUserId: String, status: FriendRequestStatus) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw FirebaseDataProvider.ValidationError.userNotAuthenticated("No authenticated user")
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

    // MARK: - Friend Relationship Operations

    func addFriend(_ friendId: String, to userId: String) async throws {
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

    // MARK: - Friend Request Observation

    func observeFriendRequests(for userId: String, completion: @escaping ([FriendRequest]) -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            print("FriendDataProvider: No authenticated user for friend requests")
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
}
