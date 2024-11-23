import Foundation

enum FriendRequestStatus: String {
    case pending
    case accepted
    case rejected
}

struct FriendRequest: Identifiable {
    let id: UUID
    let fromUserId: UUID
    let timestamp: Date
    let status: FriendRequestStatus
}
