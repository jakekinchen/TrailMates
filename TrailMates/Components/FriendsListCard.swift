//
//  FriendsListCard.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on 11/13/24.
//

import SwiftUI

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
