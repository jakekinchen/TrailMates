import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var userManager: UserManager
    @StateObject private var viewModel = FriendsViewModel()
    @State private var showAddFriends = false
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                FriendsLoadingView()
            } else if viewModel.friends.isEmpty {
                EmptyFriendsView(showAddFriends: $showAddFriends)
            } else {
                friendsListContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    @ViewBuilder
    private var friendsListContent: some View {
        ScrollView {
            VStack(spacing: 18) {
                SearchBar(text: $viewModel.searchText, isFocused: $isSearchFocused)

                if hasVisibleFriends {
                    FriendsListView(
                        activeFriends: viewModel.filteredActiveFriends,
                        inactiveFriends: viewModel.filteredInactiveFriends
                    )
                } else {
                    EmptyStateView(
                        title: "No Matches",
                        message: "Try searching by a friend's name or username.",
                        systemImage: "magnifyingglass",
                        style: .compact
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 36)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
            .contentShape(Rectangle())
            .onTapGesture {
                isSearchFocused = false
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var hasVisibleFriends: Bool {
        !viewModel.filteredActiveFriends.isEmpty || !viewModel.filteredInactiveFriends.isEmpty
    }
}


struct FriendsListView: View {
    let activeFriends: [User]
    let inactiveFriends: [User]
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            if !activeFriends.isEmpty {
                FriendSection(title: "Active", friends: activeFriends)
            }
            
            if !inactiveFriends.isEmpty {
                FriendSection(title: "Inactive", friends: inactiveFriends)
            }
        }
    }
}

struct FriendSection: View {
    let title: String
    let friends: [User]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(AppTypography.headingPrimary)
                    .foregroundColor(AppColors.pine)

                Text("\(friends.count)")
                    .font(AppTypography.labelSecondary)
                    .foregroundColor(AppColors.pine.opacity(0.62))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(AppColors.sage.opacity(0.18))
                    .clipShape(Capsule())

                Spacer()
            }
            .padding(.horizontal, 2)

            ForEach(friends) { friend in
                NavigationLink(destination: FriendProfileView(user: friend)) {
                    FriendRow(friend: friend)
                }
                .buttonStyle(.plain)
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
            UserAvatarView(user: friend, size: 50)
                .overlay(Circle().stroke(statusColor, lineWidth: 2))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(friend.firstName) \(friend.lastName)")
                    .font(AppTypography.headingSecondary)
                    .foregroundColor(AppColors.pine)
                    .lineLimit(1)

                Text("@\(friend.username)")
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.pine.opacity(0.7))
                    .lineLimit(1)
            }
            
            Spacer(minLength: 12)
            
            if friend.isActive {
                HStack(spacing: 5) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text("Active")
                        .font(AppTypography.labelSecondary)
                        .foregroundColor(statusColor)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(statusColor.opacity(0.12))
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.alwaysBeige.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.sage.opacity(0.22), lineWidth: 1)
        )
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
            action: { showAddFriends = true },
            style: .card
        )
        .padding(.horizontal, 20)
    }
}

struct FriendsLoadingView: View {
    var body: some View {
        LoadingView(message: "Loading friends...")
            .padding(.horizontal, 20)
    }
}

struct SearchBar: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.pine.opacity(0.7))
            
            TextField("Search friends...", text: $text)
                .focused($isFocused)
                .foregroundColor(AppColors.pine)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.pine.opacity(0.7))
                }
            }
        }
        .frame(minHeight: 48)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.alwaysBeige.opacity(0.76))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused ? AppColors.pumpkin : AppColors.sage.opacity(0.28), lineWidth: 1)
        )
    }
}
