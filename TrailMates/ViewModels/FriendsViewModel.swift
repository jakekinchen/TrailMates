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
            
            // Fetch friends
            let fetchedFriends = await userManager.fetchFriends()
            
            // Update UI state on main thread
            self.friends = fetchedFriends
            self.isLoading = false
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
