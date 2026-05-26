import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
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
    private lazy var functions: Functions = {
        let functions = Functions.functions(region: "us-central1")
        #if DEBUG
        functions.useEmulator(withHost: "127.0.0.1", port: 5001)
        #endif
        return functions
    }()

    // MARK: - Observer State
    private var friendRequestsHandle: DatabaseHandle?
    private var friendRequestsRef: DatabaseReference?

    private init() {
        print("FriendDataProvider initialized")
    }

    // MARK: - Friend Request Operations

    func sendFriendRequest(fromUserId: String, to targetUserId: String) async throws {
        guard fromUserId != targetUserId else {
            throw AppError.invalidInput("You cannot add yourself as a friend.")
        }

        // Get Firebase UIDs for both users
        let userDoc = try await db.collection(FirestoreConstants.Collections.users).document(fromUserId).getDocument()
        let targetDoc = try await db.collection(FirestoreConstants.Collections.users).document(targetUserId).getDocument()

        guard let userId = userDoc.get("id") as? String,
              let targetId = targetDoc.get("id") as? String else {
            throw AppError.invalidData("Could not find Firebase UIDs for users")
        }

        let existingFriends = userDoc.get("friends") as? [String] ?? []
        guard !existingFriends.contains(targetUserId) else {
            throw AppError.alreadyExists("Friend relationship")
        }

        // Verify the current user is sending the request
        guard let currentUser = auth.currentUser,
              currentUser.uid == userId else {
            throw AppError.notAuthenticated("Cannot send request on behalf of another user")
        }

        let requestId = UUID().uuidString
        let requestRef = rtdb.child(FirestoreConstants.RTDBPaths.friendRequests)
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
                    continuation.resume(throwing: AppError.classify(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func acceptFriendRequest(requestId: String, userId: String, friendId: String) async throws {
        guard let currentUser = auth.currentUser,
              currentUser.uid == userId else {
            throw AppError.notAuthenticated("Cannot accept a request on behalf of another user")
        }

        let callable = functions.httpsCallable(FirestoreConstants.Functions.acceptFriendRequest)
        do {
            _ = try await withRetry(maxAttempts: 3) {
                try await callable.call(["requestId": requestId])
            }
        } catch {
            throw try AppError.from(error)
        }
    }

    func rejectFriendRequest(requestId: String) async throws {
        guard let currentUser = auth.currentUser else {
            throw AppError.notAuthenticated()
        }

        // Remove friend request and its notification from RTDB
        let updates: [String: Any?] = [
            "\(FirestoreConstants.RTDBPaths.friendRequests)/\(currentUser.uid)/\(requestId)": nil,
            "\(FirestoreConstants.RTDBPaths.notifications)/\(currentUser.uid)/\(requestId)": nil
        ]

        return try await withCheckedThrowingContinuation { continuation in
            rtdb.updateChildValues(updates as [AnyHashable : Any]) { error, _ in
                if let error = error {
                    continuation.resume(throwing: AppError.classify(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func updateFriendRequestStatus(requestId: String, targetUserId: String, status: FriendRequestStatus) async throws {
        guard let currentUser = auth.currentUser else {
            throw AppError.notAuthenticated()
        }

        let requestRef = rtdb.child(FirestoreConstants.RTDBPaths.friendRequests)
            .child(currentUser.uid)
            .child(requestId)

        return try await withCheckedThrowingContinuation { continuation in
            requestRef.updateChildValues(["status": status.rawValue]) { error, _ in
                if let error = error {
                    continuation.resume(throwing: AppError.classify(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Friend Relationship Operations

    func addFriend(_ friendId: String, to userId: String) async throws {
        guard friendId != userId else {
            throw AppError.invalidInput("You cannot add yourself as a friend.")
        }
        throw AppError.unauthorized("Use friend requests to add friends.")
    }

    func removeFriend(_ friendId: String, from userId: String) async throws {
        guard let currentUser = auth.currentUser,
              currentUser.uid == userId else {
            throw AppError.notAuthenticated("Cannot remove a friend on behalf of another user")
        }

        let callable = functions.httpsCallable(FirestoreConstants.Functions.removeFriend)
        do {
            _ = try await withRetry(maxAttempts: 3) {
                try await callable.call(["friendId": friendId])
            }
        } catch {
            throw try AppError.from(error)
        }
    }

    // MARK: - Friend Request Observation

    func observeFriendRequests(for userId: String, completion: @escaping @Sendable ([FriendRequest]) -> Void) {
        guard let currentUser = auth.currentUser else {
            #if DEBUG
            print("FriendDataProvider: No authenticated user for friend requests")
            #endif
            completion([])
            return
        }

        // Clean up any existing observer before setting up a new one
        stopObservingFriendRequests()

        let requestsRef = rtdb.child(FirestoreConstants.RTDBPaths.friendRequests).child(currentUser.uid)
        friendRequestsRef = requestsRef

        friendRequestsHandle = requestsRef.observe(.value, with: { snapshot in
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

            Task { @MainActor in
                completion(requests)
            }
        })
    }

    func stopObservingFriendRequests() {
        if let handle = friendRequestsHandle {
            friendRequestsRef?.removeObserver(withHandle: handle)
        }
        friendRequestsHandle = nil
        friendRequestsRef = nil
    }

    // MARK: - Account Deletion Operations

    /// Deletes all friend requests for a user (used during account deletion)
    func deleteAllFriendRequests(for userId: String) async throws {
        let requestsRef = rtdb.child(FirestoreConstants.RTDBPaths.friendRequests).child(userId)

        return try await withCheckedThrowingContinuation { continuation in
            requestsRef.removeValue { error, _ in
                if let error = error {
                    continuation.resume(throwing: AppError.classify(error))
                } else {
                    #if DEBUG
                    print("FriendDataProvider: Deleted all friend requests for user \(userId)")
                    #endif
                    continuation.resume()
                }
            }
        }
    }

    /// Removes a user from all their friends' friend lists (used during account deletion)
    func removeUserFromAllFriendLists(userId: String, friendIds: [String]) async throws {
        for friendId in friendIds {
            let friendRef = db.collection(FirestoreConstants.Collections.users).document(friendId)

            do {
                let friendDoc = try await friendRef.getDocument()
                guard friendDoc.exists else { continue }

                var friendFriends = friendDoc.get("friends") as? [String] ?? []
                friendFriends.removeAll { $0 == userId }

                try await friendRef.updateData(["friends": friendFriends])
                #if DEBUG
                print("FriendDataProvider: Removed user \(userId) from friend \(friendId)'s list")
                #endif
            } catch {
                #if DEBUG
                print("FriendDataProvider: Error removing user from friend \(friendId): \(error.localizedDescription)")
                #endif
                // Continue with other friends even if one fails
            }
        }
    }
}
