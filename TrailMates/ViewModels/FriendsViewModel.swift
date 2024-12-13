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
    
    private var userManager: UserManager?
    
    init(){ }
        
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
}
