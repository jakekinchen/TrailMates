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
            loginManager.logIn(permissions: ["public_profile", "email", "user_friends"], from: nil) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let result = result, !result.isCancelled else {
                    continuation.resume(throwing: NSError(domain: "com.trailmates", code: -1, userInfo: [NSLocalizedDescriptionKey: "Facebook login was cancelled"]))
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
        let request = GraphRequest(graphPath: "me", parameters: ["fields": "id,name,email,picture"])
        request.start { _, result, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let result = result as? [String: Any],
                  let id = result["id"] as? String,
                  let name = result["name"] as? String,
                  let email = result["email"] as? String else {
                completion(nil, NSError(domain: "com.trailmates", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse Facebook profile"]))
                return
            }
            
            let user = FacebookUser(id: id, name: name, email: email)
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
    let email: String
}

struct FacebookFriend: Identifiable {
    let id: String
    let name: String
}

// Updated UserManager methods
extension UserManager {
    func linkFacebook() async throws {
        do {
            let fbUser = try await FacebookService.shared.linkAccount()
            isFacebookLinked = true
            if var updatedUser = currentUser {
                updatedUser.facebookId = fbUser.id
                updatedUser.email = fbUser.email // Only if you want to update the email
                await saveProfile(updatedUser: updatedUser)
            }
            persistUserSession()
        } catch {
            isFacebookLinked = false
            throw error
        }
    }
    
    func unlinkFacebook() {
        FacebookService.shared.unlinkAccount()
        isFacebookLinked = false
        if var updatedUser = currentUser {
            updatedUser.facebookId = nil
            Task {
                await saveProfile(updatedUser: updatedUser)
            }
        }
        persistUserSession()
    }
    
    func fetchFacebookFriends() async throws -> [FacebookFriend] {
        guard isFacebookLinked else { throw NSError(domain: "com.trailmates", code: -1, userInfo: [NSLocalizedDescriptionKey: "Facebook not linked"]) }
        return try await FacebookService.shared.fetchFriends()
    }
}

// Updated User model (add these properties to your existing User model)
extension User {
    var facebookId: String? { get set }
}