//
//  FriendsListCard.swift
//  TrailMates
//
//  A card component showing active friends with add friends action.
//
//  Usage:
//  ```swift
//  FriendsListCard(
//      friends: userManager.friends,
//      onAddFriends: { /* refresh friends list */ }
//  )
//  ```

import SwiftUI

/// A card displaying active friends with option to add more
struct FriendsListCard: View {
    let friends: [User]
    let onAddFriends: () -> Void
    
    @State private var showAddFriends = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Friends on the Trail")
                    .font(.system(size: 18))
                    .foregroundColor(Color("pine"))
                Spacer()
                Button(action: {
                    showAddFriends = true
                }) {
                    Image(systemName: "person.badge.plus")
                        .foregroundColor(Color("pine"))
                        .font(.system(size: 20))
                }
            }
            
            Divider()
            
            FriendsSection(friends: friends.filter { $0.isActive })
            
            Spacer()
        }
        .padding()
        .cornerRadius(15)
        .padding(.horizontal)
        .sheet(isPresented: $showAddFriends) {
            AddFriendsView(
                isOnboarding: false
            ) {
                showAddFriends = false
                onAddFriends()
            }
        }
    }
}
