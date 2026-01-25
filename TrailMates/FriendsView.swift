import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var userManager: UserManager
    @StateObject private var viewModel = FriendsViewModel()
    @State private var showAddFriends = false
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        ZStack(alignment: .top) {
            Color("beige").ignoresSafeArea()
            
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
        }
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
        Section(header: FriendsSectionHeader(title: title)) {
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
    @EnvironmentObject var userManager: UserManager
    @State private var profileImage: UIImage?
    @State private var isLoadingImage = false
    
    private var initials: String {
        let firstInitial = friend.firstName.prefix(1)
        let lastInitial = friend.lastName.prefix(1)
        return "\(firstInitial)\(lastInitial)"
    }
    
    private var statusColor: Color {
        friend.isActive ? .green : .gray
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile Image
            Group {
                if let image = profileImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if isLoadingImage {
                    ProgressView()
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            .overlay(Circle().stroke(statusColor, lineWidth: 2))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(friend.firstName) \(friend.lastName)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color("pine"))
                
                Text("@\(friend.username)")
                    .font(.system(size: 14))
                    .foregroundColor(Color("pine").opacity(0.7))
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
        .background(Color("sage").opacity(0.1))
        .cornerRadius(12)
        .task {
            await loadProfileImage()
        }
    }
    
    private func loadProfileImage() async {
        isLoadingImage = true
        defer { isLoadingImage = false }
        
        if let image = try? await userManager.fetchProfileImage(for: friend, preferredSize: .thumbnail) {
            await MainActor.run {
                profileImage = image
            }
        }
    }
}

struct FriendsSectionHeader: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(Color("pine"))
            Spacer()
        }
        .padding(.vertical, 8)
        .background(Color("beige"))
    }
}

struct EmptyFriendsView: View {
    @Binding var showAddFriends: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2")
                .font(.system(size: 50))
                .foregroundColor(Color("pine").opacity(0.5))
            
            Text("No Friends Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color("pine"))
            
            Text("Add friends to see their activity and join them on trails!")
                .multilineTextAlignment(.center)
                .foregroundColor(Color("pine").opacity(0.7))
            
            Button(action: { showAddFriends = true }) {
                Text("Add Friends")
                    .font(.headline)
                    .foregroundColor(Color("beige"))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color("pine"))
                    .cornerRadius(25)
            }
        }
        .padding()
    }
}

struct FriendsLoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            Text("Loading Friends...")
                .foregroundColor(Color("pine").opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SearchBar: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color("pine").opacity(0.7))
            
            TextField("Search friends...", text: $text)
                .focused($isFocused)
                .foregroundColor(Color("pine"))
                .autocapitalization(.none)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color("pine").opacity(0.7))
                }
            }
        }
        .padding(10)
        .background(Color("sage").opacity(0.1))
        .cornerRadius(10)
    }
}
