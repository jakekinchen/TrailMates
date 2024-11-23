import SwiftUI
import CoreLocation

struct FriendsView: View {
    @EnvironmentObject var userManager: UserManager
    @StateObject private var viewModel = FriendsViewModel()
    @State private var showAddFriends = false
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        ZStack(alignment: .top) {
            Color("beige").ignoresSafeArea()
            
            VStack(spacing: 0) {
                SearchBar(text: $viewModel.searchText, isFocused: _isSearchFocused)
                    .padding(.horizontal)
                
                if viewModel.isLoading {
                    LoadingView()
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

struct SearchBar: View {
    @Binding var text: String
    @FocusState var isFocused: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color("pine").opacity(0.6))
                .padding(.leading, 8)
            
            TextField("Search friends", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .focused($isFocused)
                .padding(.vertical, 12)
        }
        .background(Color("sage").opacity(0.2))
        .cornerRadius(10)
    }
}

struct LoadingView: View {
    var body: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyFriendsView: View {
    @Binding var showAddFriends: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2")
                .font(.system(size: 50))
                .foregroundColor(Color("pine").opacity(0.6))
            Text("No Friends Yet")
                .font(.title2)
                .foregroundColor(Color("pine"))
            Text("Add friends to see them here")
                .foregroundColor(Color("pine").opacity(0.8))
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
                if let thumbnailUrl = friend.profileThumbnailUrl {
                    AsyncImage(url: URL(string: thumbnailUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                } else if let imageData = friend.profileImageData,
                          let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
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
        .background(Color("beige").opacity(0.98))
    }
}

struct EnhancedFriendRow: View {
    let friend: User
    
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
            // Profile Image or Initials
            if let imageData = friend.profileImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(statusColor, lineWidth: 2))
            } else {
                Circle()
                    .fill(Color("pine").opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(initials)
                            .foregroundColor(Color("pine"))
                            .font(.system(size: 18, weight: .medium))
                    )
                    .overlay(Circle().stroke(statusColor, lineWidth: 2))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(friend.firstName) \(friend.lastName)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color("pine"))
                
                Text("@\(friend.username)")
                    .font(.system(size: 14))
                    .foregroundColor(Color("pine").opacity(0.7))
            }
            
            Spacer()
            
            // Active Status Indicator
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
    }
}
