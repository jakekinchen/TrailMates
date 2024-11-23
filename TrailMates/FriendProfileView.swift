//
//  FriendProfileView.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on 11/20/24.
//

import SwiftUI

struct FriendProfileView: View {
    let user: User
    @EnvironmentObject var userManager: UserManager
    @State private var userStats: UserStats?
    @State private var isLoading = false
    @State private var isProcessingFriendAction = false
    @State private var showUnfriendAlert = false
    
    private var isFriend: Bool {
            guard let currentUser = userManager.currentUser else { return false }
            return currentUser.friends.contains(user.id)
        }
    
    init(user: User) {
        self.user = user
    }
    
    var body: some View {
        ZStack {
            Color("beige").ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProfileHeader(user: user, actionButton: AnyView(
                    Button {
                        Task {
                            do {
                                if isFriend {
                                    try await userManager.removeFriend(user.id)
                                } else {
                                    try await userManager.sendFriendRequest(to: user.id)
                                }
                            } catch {
                                print("Error managing friend relationship: \(error)")
                                // TODO: Show error alert to user
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isFriend {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Color("pine").opacity(0.6))
                            }
                            Text(isFriend ? "Friends" : "Add Friend")
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.medium)
                        }
                        .foregroundColor(isFriend ? Color("pine").opacity(0.6) : Color("beige"))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(isFriend ? Color("sage").opacity(0.3) : Color("pine"))
                        .cornerRadius(25)
                    }
                    .disabled(isProcessingFriendAction)
                    .overlay(
                        Group {
                            if isProcessingFriendAction {
                                ProgressView()
                            }
                        }
                    )
                ))
                
                if let stats = userStats {
                    StatsSection(stats: stats)
                } else if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .padding()
        }
        .navigationTitle("Profile")
        .task {
            await refreshStats()
        }
    }
    
    private func refreshStats() async {
        isLoading = true
        // Assuming we add a method to get stats for any user
        userStats = await userManager.getUserStats(for: user.id)
        isLoading = false
    }
    
    private func handleFriendAction() async {
        isProcessingFriendAction = true
        defer { isProcessingFriendAction = false }
        
        do {
            if isFriend {
               try await userManager.removeFriend(user.id)
            } else {
              try await userManager.addFriend(user.id)
            }
            
            // Refresh the stats after friend action
            await refreshStats()
        }
        catch {
            print("Error processing friend action: \(error.localizedDescription)")
        }
    }
}
