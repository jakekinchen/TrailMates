import Foundation

class MockInstagramService {
    func linkAccount(completion: (Bool) -> Void) {
        // Simulate successful linking
        completion(true)
    }
    
    func fetchFriends(completion: ([InstagramUser]) -> Void) {
        // Return mock Instagram users
        let mockFriends = [
            InstagramUser(id: "123", username: "instaFriend1"),
            InstagramUser(id: "456", username: "instaFriend2")
        ]
        completion(mockFriends)
    }
}