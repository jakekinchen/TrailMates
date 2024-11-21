struct FriendProfileView: View {
    let user: User
    @EnvironmentObject var userManager: UserManager
    @State private var userStats: UserStats?
    @State private var isLoading = false
    @State private var isFriend: Bool
    @State private var isProcessingFriendAction = false
    
    init(user: User, userManager: UserManager) {
        self.user = user
        _isFriend = State(initialValue: userManager.currentUser?.friends.contains(user.id) ?? false)
    }
    
    var body: some View {
        ZStack {
            Color("beige").ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProfileHeader(user: user, actionButton: AnyView(
                    Button(action: {
                        Task {
                            await toggleFriendStatus()
                        }
                    }) {
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
    
    private func toggleFriendStatus() async {
        isProcessingFriendAction = true
        defer { isProcessingFriendAction = false }
        
        if isFriend {
            await userManager.removeFriend(user.id)
        } else {
            await userManager.addFriend(user.id)
        }
        
        isFriend.toggle()
    }
}