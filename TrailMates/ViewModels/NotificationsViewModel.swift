import SwiftUI

@MainActor
class NotificationsViewModel: ObservableObject {
    @Published private(set) var notifications: [TrailNotification] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?

    private let notificationProvider = NotificationDataProvider.shared
    private let userManager = UserManager.shared

    init() { }

    func fetchNotifications() async {
        isLoading = true
        error = nil

        do {
            guard let currentUser = userManager.currentUser else { return }

            notifications = try await notificationProvider.fetchNotifications(forId: currentUser.id, userID: currentUser.id)
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func deleteNotification(_ notification: TrailNotification) async {
        do {
            guard let currentUserId = userManager.currentUser?.id else { return }
            try await notificationProvider.deleteNotification(
                id: currentUserId,
                notificationId: notification.id
            )
            if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                notifications.remove(at: index)
            }
        } catch {
            self.error = error
        }
    }

    func clearAllNotifications() async {
        for notification in notifications {
            await deleteNotification(notification)
        }
    }
}

@MainActor
class NotificationRowViewModel: ObservableObject {

    private let notificationProvider = NotificationDataProvider.shared
    private let userManager = UserManager.shared

    func handleNotificationTap(_ notification: TrailNotification) async {
        if !notification.isRead {
            do {
                guard let currentUserId = userManager.currentUser?.id else { return }
                try await notificationProvider.markNotificationAsRead(
                    id: currentUserId,
                    notificationId: notification.id
                )
            } catch {
                print("Error marking notification as read: \(error)")
            }
        }

        // Handle different notification types
        switch notification.type {
        case .friendRequest:
            // Navigate to friend request handling view
            break
        case .friendAccepted:
            // Navigate to friend's profile
            break
        case .eventInvite:
            // Navigate to event details
            break
        case .eventUpdate:
            // Navigate to updated event
            break
        case .general:
            // No specific action needed
            break
        }
    }
}
