import Foundation

protocol DataProvider {
    func fetchCurrentUser() -> User?
    func fetchFriends(for user: User) -> [User]
    func fetchAllUsers() -> [User]
}

class MockDataProvider: DataProvider {
    private var users = MockData.users
    
    func fetchCurrentUser() -> User? {
        // Return a mock current user
        return users.values.first
    }
    
    func fetchFriends(for user: User) -> [User] {
        var friendsList = [User]()
        for friendId in user.friends {
            if let friend = users[friendId] {
                friendsList.append(friend)
            }
        }
        return friendsList
    }
    
    func fetchAllUsers() -> [User] {
        return Array(users.values)
    }
}