//
//  MockInstagramService.swift
//  TrailMates
//
//  Created by Jake Kinchen on 10/5/24.
//

import Foundation

// Define the InstagramUser struct
struct InstagramUser {
    let id: String
    let username: String
}

class MockInstagramService {
    
    // Mark function as @MainActor to ensure safe main-thread execution
    @MainActor
    func linkAccount(completion: @escaping (Bool) -> Void) {
        // Simulate successful linking
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(true)
        }
    }
    
    @MainActor
    func fetchFriends(completion: @escaping ([InstagramUser]) -> Void) {
        // Return mock Instagram users
        let mockFriends = [
            InstagramUser(id: "123", username: "instaFriend1"),
            InstagramUser(id: "456", username: "instaFriend2")
        ]
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(mockFriends)
        }
    }
}
