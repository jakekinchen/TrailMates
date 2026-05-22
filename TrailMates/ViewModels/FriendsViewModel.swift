//
//  FriendsViewModel.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on 11/20/24.
//


import SwiftUI
import CoreLocation

// Separate view model to handle data logic
@MainActor
class FriendsViewModel: ObservableObject {
    @Published var friends: [User] = []
    @Published var isLoading = false
    @Published var searchText = ""
    @Published var friendLookupText = ""
    @Published var friendLookupResult: User?
    @Published var friendLookupMessage: String?
    @Published var isSearchingForFriend = false
    @Published var isSendingFriendRequest = false
    @Published private(set) var sentFriendRequestUserIds: Set<String> = []
    
    private var userManager: UserManager?
    
    init() { }
        
    func setup(with userManager: UserManager) {
        self.userManager = userManager
    }
    
    func loadFriends() async {
        guard let userManager = userManager else { return }

        // Update loading state on main thread
        isLoading = true
        defer { isLoading = false }

        // Fetch friends
        let fetchedFriends = await userManager.fetchFriends()

        // Update UI state on main thread
        self.friends = fetchedFriends

        // Prefetch profile images for all friends
        await prefetchFriendImages(fetchedFriends)
    }

    func searchForFriend() async {
        guard let userManager else {
            friendLookupMessage = AppError.notAuthenticated().errorDescription
            return
        }

        let query = friendLookupText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            friendLookupResult = nil
            friendLookupMessage = "Enter a username or phone number."
            return
        }

        isSearchingForFriend = true
        defer { isSearchingForFriend = false }

        let candidate = await findFriendCandidate(matching: query, using: userManager)
        guard let candidate else {
            friendLookupResult = nil
            friendLookupMessage = "No TrailMates account matched that username or phone number."
            return
        }

        friendLookupResult = candidate

        if isCurrentUser(candidate) {
            friendLookupMessage = "This is your account."
        } else if isFriend(candidate) {
            friendLookupMessage = "You are already friends with \(candidate.firstName)."
        } else {
            friendLookupMessage = nil
        }
    }

    func sendFriendRequest(to user: User) async {
        guard let userManager else {
            friendLookupMessage = AppError.notAuthenticated().errorDescription
            return
        }

        guard !isCurrentUser(user) else {
            friendLookupMessage = "This is your account."
            return
        }

        guard !isFriend(user) else {
            friendLookupMessage = "You are already friends with \(user.firstName)."
            return
        }

        guard !sentFriendRequestUserIds.contains(user.id) else {
            friendLookupMessage = "Friend request already sent to \(user.firstName)."
            return
        }

        isSendingFriendRequest = true
        defer { isSendingFriendRequest = false }

        do {
            try await userManager.sendFriendRequest(to: user.id)
            sentFriendRequestUserIds.insert(user.id)
            friendLookupMessage = "Friend request sent to \(user.firstName)."
        } catch {
            let appError = AppError.from(error)
            friendLookupMessage = appError.errorDescription
        }
    }

    func isCurrentUser(_ user: User) -> Bool {
        userManager?.currentUser?.id == user.id
    }

    func isFriend(_ user: User) -> Bool {
        userManager?.isFriend(user.id) ?? false
    }

    func hasSentFriendRequest(to user: User) -> Bool {
        sentFriendRequestUserIds.contains(user.id)
    }
    
    private func prefetchFriendImages(_ friends: [User]) async {
        guard let userManager = userManager else { return }
        
        // Prefetch thumbnails for all friends
        await userManager.prefetchProfileImages(for: friends, preferredSize: .thumbnail)
        
        // For active friends, also prefetch full-size images as they're more likely to be viewed
        let activeFriends = friends.filter { $0.isActive }
        if !activeFriends.isEmpty {
            await userManager.prefetchProfileImages(for: activeFriends, preferredSize: .full)
        }
    }
    
    var filteredActiveFriends: [User] {
        friends.filter { friend in
            friend.isActive && matchesSearch(friend)
        }
    }
    
    var filteredInactiveFriends: [User] {
        friends.filter { friend in
            !friend.isActive && matchesSearch(friend)
        }
    }
    
    private func matchesSearch(_ user: User) -> Bool {
        guard !searchText.isEmpty else { return true }
        let searchTerms = searchText.lowercased()
        return user.firstName.lowercased().contains(searchTerms) ||
               user.lastName.lowercased().contains(searchTerms) ||
               user.username.lowercased().contains(searchTerms)
    }

    private func findFriendCandidate(matching query: String, using userManager: UserManager) async -> User? {
        do {
            let users = try await userManager.searchUsers(usernameOrPhone: query)
            return users.first
        } catch {
            let appError = AppError.from(error)
            friendLookupMessage = appError.errorDescription
            return nil
        }
    }
}
