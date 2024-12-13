import Foundation

enum FriendRequestStatus: String {
    case pending
    case accepted
    case rejected
}

struct FriendRequest: Identifiable {
    let id: String           // Changed to String
    let fromUserId: String   // Changed to String
    let timestamp: Date
    let status: FriendRequestStatus
    
    init(id: String,
         fromUserId: String,
         timestamp: Date,
         status: FriendRequestStatus) {
        self.id = id
        self.fromUserId = fromUserId
        self.timestamp = timestamp
        self.status = status
    }
}
