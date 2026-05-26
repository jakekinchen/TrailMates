import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var userManager: UserManager
    @StateObject private var viewModel = FriendsViewModel()
    @State private var showAddFriends = false
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            SearchBar(text: $viewModel.searchText, isFocused: $isSearchFocused)
                .padding(.horizontal)

            if viewModel.isLoading {
                FriendsLoadingView()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isSearchFocused = false
                    }
            } else if viewModel.friends.isEmpty {
                EmptyFriendsView(showAddFriends: $showAddFriends)
                    .contentShape(Rectangle())
                    .padding(.top)
                    .onTapGesture {
                        isSearchFocused = false
                    }
            } else {
                ScrollView {
                    FriendsListView(
                        activeFriends: viewModel.filteredActiveFriends,
                        inactiveFriends: viewModel.filteredInactiveFriends
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isSearchFocused = false
                    }
                }
            }
        }
        .themedBackground()
        .withDefaultNavigation(
            title: "Friends",
            rightButtonIcon: "person.badge.plus",
            rightButtonAction: { showAddFriends = true }
        )
        .sheet(isPresented: $showAddFriends) {
            AddFriendsView(isOnboarding: false) {
                showAddFriends = false
                Task {
                    await viewModel.loadFriends()
                }
            }
        }
        .task {
            viewModel.setup(with: userManager)
            await viewModel.loadFriends()
        }
    }
}


struct FriendsListView: View {
    let activeFriends: [User]
    let inactiveFriends: [User]
    
    var body: some View {
        LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
            if !activeFriends.isEmpty {
                FriendSection(title: "Active", friends: activeFriends)
            }
            
            if !inactiveFriends.isEmpty {
                FriendSection(title: "Inactive", friends: inactiveFriends)
            }
        }
        .padding()
    }
}

struct FriendSection: View {
    let title: String
    let friends: [User]
    
    var body: some View {
        Section(header: SectionHeader(title: title)) {
            ForEach(friends) { friend in
                NavigationLink(destination: FriendProfileView(user: friend)) {
                    FriendRow(friend: friend)
                }
            }
        }
    }
}

struct FriendRow: View {
    let friend: User

    private var statusColor: Color {
        friend.isActive ? .green : .gray
    }

    var body: some View {
        HStack(spacing: 12) {
            // Profile Image
            UserAvatarView(user: friend, size: 50)
                .overlay(Circle().stroke(statusColor, lineWidth: 2))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(friend.firstName) \(friend.lastName)")
                    .font(AppTypography.headingSecondary)
                    .foregroundColor(AppColors.pine)

                Text("@\(friend.username)")
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.pine.opacity(0.7))
            }
            
            Spacer()
            
            if friend.isActive {
                VStack(alignment: .trailing, spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text("Active now")
                        .font(.caption2)
                        .foregroundColor(statusColor)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(AppColors.sage.opacity(0.1))
        .cornerRadius(12)
    }
}


struct EmptyFriendsView: View {
    @Binding var showAddFriends: Bool

    var body: some View {
        EmptyStateView(
            title: "No Friends Yet",
            message: "Add friends to see their activity and join them on trails!",
            systemImage: "person.2",
            actionTitle: "Add Friends",
            action: { showAddFriends = true }
        )
    }
}

struct FriendsLoadingView: View {
    var body: some View {
        LoadingView(message: "Loading Friends...")
    }
}

struct SearchBar: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.pine.opacity(0.7))
            
            TextField("Search friends...", text: $text)
                .focused($isFocused)
                .foregroundColor(AppColors.pine)
                .autocapitalization(.none)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.pine.opacity(0.7))
                }
            }
        }
        .padding(10)
        .background(AppColors.sage.opacity(0.1))
        .cornerRadius(10)
    }
}
