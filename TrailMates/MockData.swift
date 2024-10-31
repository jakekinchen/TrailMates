import Foundation
import CoreLocation

struct MockData {
    static var users: [UUID: User] = {
        var users = [UUID: User]()
        
        // User 1
        let user1 = User(
            id: UUID(),
            username: "johndoe",
            fullName: "John Doe",
            email: "john@example.com",
            profileImageName: "johnProfilePic",
            bio: "Love hiking and outdoor adventures.",
            location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            isActive: true,
            friends: []
        )
        
        // User 2
        let user2 = User(
            id: UUID(),
            username: "janedoe",
            fullName: "Jane Doe",
            email: "jane@example.com",
            profileImageName: "janeProfilePic",
            bio: "Nature enthusiast.",
            location: CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437),
            isActive: false,
            friends: []
        )
        
        // Add users to dictionary
        users[user1.id] = user1
        users[user2.id] = user2
        
        // Set up friends
        users[user1.id]?.friends.append(user2.id)
        users[user2.id]?.friends.append(user1.id)
        
        return users
    }()
}