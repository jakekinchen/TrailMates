import Foundation
import Firebase
import FirebaseAuth
import FirebaseDatabase

/// Handles all notification-related Firebase operations
/// Extracted from FirebaseDataProvider as part of the provider refactoring
@MainActor
class NotificationDataProvider {
    // MARK: - Singleton
    static let shared = NotificationDataProvider()

    // MARK: - Dependencies
    private lazy var rtdb = Database.database().reference()
    private lazy var auth = Auth.auth()

    // MARK: - Observer State
    private var notificationsHandle: DatabaseHandle?
    private var notificationsRef: DatabaseReference?

    private init() {
        print("NotificationDataProvider initialized")
    }

    // MARK: - Notification Send Operations

    func sendNotification(to userId: String, type: NotificationType, fromUserId: String, content: String, relatedEventId: String? = nil) async throws {
        guard self.auth.currentUser != nil else { throw AppError.notAuthenticated() }

        let notificationRef = rtdb.child(FirestoreConstants.RTDBPaths.notifications)
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
                    continuation.resume(throwing: AppError.from(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Notification Observation

    func observeNotifications(for userId: String, completion: @escaping @Sendable ([TrailNotification]) -> Void) {
        guard let currentUser = self.auth.currentUser else {
            #if DEBUG
            print("NotificationDataProvider: No authenticated user for notifications")
            #endif
            completion([])
            return
        }

        let ref = rtdb.child(FirestoreConstants.RTDBPaths.notifications).child(currentUser.uid)
        self.notificationsRef = ref

        let handle = ref.observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            var notifications: [TrailNotification] = []

            for child in snapshot.children {
                guard let childSnapshot = child as? DataSnapshot else { continue }
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

            Task { @MainActor in
                completion(notifications.sorted { $0.timestamp > $1.timestamp })
            }
        }
        self.notificationsHandle = handle
    }

    func stopObservingNotifications() {
        if let handle = notificationsHandle {
            notificationsRef?.removeObserver(withHandle: handle)
        }
        notificationsHandle = nil
        notificationsRef = nil
    }

    // MARK: - Notification Fetch Operations

    func fetchNotifications(forId id: String, userID: String) async throws -> [TrailNotification] {
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume(throwing: AppError.unknown())
                return
            }

            let notificationsRef = rtdb.child(FirestoreConstants.RTDBPaths.notifications).child(id)

            notificationsRef.getData { error, snapshot in
                if let error = error {
                    continuation.resume(throwing: AppError.from(error))
                    return
                }

                var notifications: [TrailNotification] = []

                if let snapshot = snapshot {
                    for child in snapshot.children {
                        guard let childSnapshot = child as? DataSnapshot else { continue }
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

    // MARK: - Notification Update Operations

    func markNotificationAsRead(id: String, notificationId: String) async throws {
        let notificationRef = rtdb.child(FirestoreConstants.RTDBPaths.notifications)
            .child(id)
            .child(notificationId)

        return try await withCheckedThrowingContinuation { continuation in
            notificationRef.updateChildValues(["read": true]) { error, _ in
                if let error = error {
                    continuation.resume(throwing: AppError.from(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func deleteNotification(id: String, notificationId: String) async throws {
        let notificationRef = rtdb.child(FirestoreConstants.RTDBPaths.notifications)
            .child(id)
            .child(notificationId)

        return try await withCheckedThrowingContinuation { continuation in
            notificationRef.removeValue { error, _ in
                if let error = error {
                    continuation.resume(throwing: AppError.from(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Deletes all notifications for a user (used during account deletion)
    func deleteAllNotifications(for userId: String) async throws {
        let notificationsRef = rtdb.child(FirestoreConstants.RTDBPaths.notifications).child(userId)

        return try await withCheckedThrowingContinuation { continuation in
            notificationsRef.removeValue { error, _ in
                if let error = error {
                    continuation.resume(throwing: AppError.from(error))
                } else {
                    #if DEBUG
                    print("NotificationDataProvider: Deleted all notifications for user \(userId)")
                    #endif
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Helper Methods

    private nonisolated func getTitleForNotificationType(_ type: NotificationType) -> String {
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
}
