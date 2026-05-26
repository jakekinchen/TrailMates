import SwiftUI
@preconcurrency import Contacts
import Combine
import MessageUI

struct ContactsListView: View {
    @StateObject private var viewModel = ContactsListViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userManager: UserManager
    @FocusState private var focusedField: Field?
    @State private var showContactsPermissionAlert = false

    private enum Field {
        case search
    }

    var body: some View {
        Group {
            if viewModel.contacts.isEmpty {
                EmptyContactsView()
            } else {
                VStack(spacing: 0) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppColors.pine)
                        TextField("Search contacts", text: $viewModel.searchText)
                            .foregroundColor(AppColors.pine)
                            .focused($focusedField, equals: .search)
                            .onSubmit {
                                focusedField = nil
                            }
                    }
                    .padding()
                    .background(Color("altBeige"))

                    // Request Contacts Access Button (only shown if not full access)
                    if !viewModel.hasFullContactsAccess {
                        Button(action: {
                            Task {
                                let granted = await viewModel.requestContactsAccess()
                                if !granted {
                                    showContactsPermissionAlert = true
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.plus")
                                Text("Add More Contacts")
                            }
                            .foregroundColor(AppColors.pine)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color("altBeige"))
                            .cornerRadius(10)
                            .padding()
                        }
                    }

                    // Matched Users List
                    if viewModel.filteredMatchedUsers.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "person.crop.circle")
                                .resizable()
                                .frame(width: 60, height: 60)
                                .foregroundColor(.gray)

                            Text("No matches found")
                                .font(.title2)
                                .fontWeight(.medium)

                            Text("None of your contacts are on TrailMates yet")
                                .foregroundColor(.gray)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16, pinnedViews: .sectionHeaders) {
                                MatchedUsersSection(
                                    matchedUsers: $viewModel.matchedUsers,
                                    filteredMatchedUsers: viewModel.filteredMatchedUsers
                                )
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
        }
        .themedBackground()
        .onTapGesture {
            focusedField = nil
        }
        .navigationTitle("Contacts")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Add Friends")
                    }
                    .foregroundColor(AppColors.pine)
                }
            }

            ToolbarItem(placement: .principal) {
                Text("Contacts")
                    .font(.headline)
                    .foregroundColor(AppColors.pine)
            }
        }
        .task {
            await viewModel.loadAndMatchContacts(userManager: userManager)
        }
        .alert("Contacts Access Required", isPresented: $showContactsPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable contacts access in Settings to find more friends on TrailMates.")
        }
    }
}

// Empty state view
private struct EmptyContactsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle")
                .resizable()
                .frame(width: 60, height: 60)
                .foregroundColor(.gray)

            Text("List is empty")
                .font(.title2)
                .fontWeight(.medium)

            Text("Your friends have not joined TrailMates")
                .foregroundColor(.gray)
        }
    }
}

// Main content view
private struct MatchedUsersSection: View {
    @Binding var matchedUsers: [ContactsListViewModel.MatchedContact]
    @EnvironmentObject var userManager: UserManager
    let filteredMatchedUsers: [ContactsListViewModel.MatchedContact]

    var body: some View {
        Section {
            ForEach(filteredMatchedUsers) { matchedContact in
                VStack(spacing: 0) {
                    MatchedUserRow(
                        matchedContact: matchedContact,
                        matchedUsers: $matchedUsers
                    )
                    if matchedContact.id != filteredMatchedUsers.last?.id {
                        Divider()
                            .background(AppColors.pine.opacity(0.2))
                            .padding(.horizontal)
                    }
                }
            }
        } header: {
            SectionHeader(title: "Add your friends on TrailMates")
        }
    }
}


// MARK: - Matched User Row
private struct MatchedUserRow: View {
    let matchedContact: ContactsListViewModel.MatchedContact
    @Binding var matchedUsers: [ContactsListViewModel.MatchedContact]
    @EnvironmentObject var userManager: UserManager

    @State private var isProcessing = false
    @State private var error: Error?

    var body: some View {
        // If we have a matched user, show a NavigationLink to their profile
        NavigationLink(destination: FriendProfileView(user: matchedContact.user)) {
            HStack(spacing: 12) {
                // Profile Image
                UserAvatarView(user: matchedContact.user, size: 50)
                    .overlay(Circle().stroke(userManager.isFriend(matchedContact.user.id) ? Color.green : Color.gray, lineWidth: 2))

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(matchedContact.contact.givenName) \(matchedContact.contact.familyName)")
                        .font(AppTypography.headingSecondary)
                        .foregroundColor(AppColors.pine)

                    Text("@\(matchedContact.user.username)")
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.pine.opacity(0.7))
                }

                Spacer()

                // Check if already a friend
                if userManager.isFriend(matchedContact.user.id) {
                    Label("Added", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.gray)
                } else {
                    if isProcessing {
                        ProgressView()
                    } else {
                        Button("Add") {
                            Task {
                                await sendFriendRequest()
                            }
                        }
                        .foregroundColor(AppColors.beige)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(AppColors.pine)
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal)
            .background(AppColors.beige.opacity(0.1))
        }
        .alert("Error", isPresented: .constant(error != nil), presenting: error) { _ in
            Button("OK") { error = nil }
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    private func sendFriendRequest() async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            try await userManager.sendFriendRequest(to: matchedContact.user.id)
            // Once added, remove from matchedUsers if needed
            if let index = matchedUsers.firstIndex(where: { $0.id == matchedContact.id }) {
                matchedUsers[index] = matchedContact // Update state if necessary
            }
        } catch {
            self.error = error
        }
    }

}
