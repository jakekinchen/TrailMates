import SwiftUI
import CoreLocation

// Separate view model to handle data logic
class FriendsViewModel: ObservableObject {
    @Published var friends: [User] = []
    @Published var isLoading = false
    @Published var searchText = ""
    
    private let userManager: UserManager
    
    init(userManager: UserManager) {
        self.userManager = userManager
    }
    
    func loadFriends() async {
        isLoading = true
        defer { isLoading = false }
        friends = await userManager.fetchFriends()
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