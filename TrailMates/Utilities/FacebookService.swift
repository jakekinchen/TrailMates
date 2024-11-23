//
//  FacebookService.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on 11/21/24.
//


// FacebookService.swift
import Foundation
import FBSDKLoginKit
import FBSDKCoreKit

class FacebookService: ObservableObject {
    @Published var isLinked = false
    
    static let shared = FacebookService()
    private let loginManager = LoginManager()
    
    func linkAccount() async throws -> FacebookUser {
        return try await withCheckedThrowingContinuation { continuation in
            loginManager.logIn(permissions: ["public_profile", "user_friends"], from: nil) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let result = result, !result.isCancelled else {
                    continuation.resume(throwing: NSError(domain: "com.bridges.trailmatesatx", code: -1, userInfo: [NSLocalizedDescriptionKey: "Facebook login was cancelled"]))
                    return
                }
                
                self.fetchProfile { user, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let user = user {
                        self.isLinked = true
                        continuation.resume(returning: user)
                    }
                }
            }
        }
    }
    
    func fetchFriends() async throws -> [FacebookFriend] {
            return try await withCheckedThrowingContinuation { continuation in
                let request = GraphRequest(graphPath: "me/friends", parameters: ["fields": "id,name,picture"])
                request.start { _, result, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let result = result as? [String: Any],
                          let data = result["data"] as? [[String: Any]] else {
                        continuation.resume(returning: [])
                        return
                    }
                    
                    let friends = data.compactMap { friendData -> FacebookFriend? in
                        guard let id = friendData["id"] as? String,
                              let name = friendData["name"] as? String else { return nil }
                        return FacebookFriend(id: id, name: name)
                    }
                    
                    continuation.resume(returning: friends)
                }
            }
        }
    
    private func fetchProfile(completion: @escaping (FacebookUser?, Error?) -> Void) {
            let request = GraphRequest(graphPath: "me", parameters: ["fields": "id,name"])
            request.start { _, result, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                guard let result = result as? [String: Any],
                      let id = result["id"] as? String,
                      let name = result["name"] as? String else {
                    completion(nil, NSError(domain: "com.trailmates", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse Facebook profile"]))
                    return
                }
                
                let user = FacebookUser(id: id, name: name)
                completion(user, nil)
            }
        }
    
    func unlinkAccount() {
        loginManager.logOut()
        isLinked = false
    }
}

// Models
struct FacebookUser {
    let id: String
    let name: String
}

struct FacebookFriend: Identifiable {
    let id: String
    let name: String
}

