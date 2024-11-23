import Foundation

enum NotificationType: String, Codable {
    case friendRequest
    case friendAccepted
    case eventInvite
    case eventUpdate
    case general
}

struct TrailNotification: Identifiable, Codable {
    let id: UUID
    let type: NotificationType
    let title: String
    let message: String
    let timestamp: Date
    let isRead: Bool
    let userId: UUID
    let fromUserId: UUID?
    let relatedEventId: UUID?
    
    init(id: UUID = UUID(),
         type: NotificationType,
         title: String,
         message: String,
         timestamp: Date = Date(),
         isRead: Bool = false,
         userId: UUID,
         fromUserId: UUID? = nil,
         relatedEventId: UUID? = nil) {
        self.id = id
        self.type = type
        self.title = title
        self.message = message
        self.timestamp = timestamp
        self.isRead = isRead
        self.userId = userId
        self.fromUserId = fromUserId
        self.relatedEventId = relatedEventId
    }
}

// MARK: - Notification Message Generation
extension TrailNotification {
    static func friendRequestMessage(from user: User) -> String {
        return "\(user.firstName) \(user.lastName) wants to be your friend!"
    }
    
    static func friendAcceptedMessage(from user: User) -> String {
        return "\(user.firstName) \(user.lastName) accepted your friend request!"
    }
    
    static func eventInviteMessage(from user: User, event: Event) -> String {
        return "\(user.firstName) \(user.lastName) invited you to \(event.title)!"
    }
    
    static func eventUpdateMessage(event: Event) -> String {
        return "Event '\(event.title)' has been updated!"
    }
}
