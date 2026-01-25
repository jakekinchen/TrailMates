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
        ZStack {
            Color("beige").ignoresSafeArea()

            if viewModel.contacts.isEmpty {
                EmptyContactsView()
            } else {
                VStack(spacing: 0) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color("pine"))
                        TextField("Search contacts", text: $viewModel.searchText)
                            .foregroundColor(Color("pine"))
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
                            .foregroundColor(Color("pine"))
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
                    .foregroundColor(Color("pine"))
                }
            }

            ToolbarItem(placement: .principal) {
                Text("Contacts")
                    .font(.headline)
                    .foregroundColor(Color("pine"))
            }
        }
        .onAppear {
            Task {
                await viewModel.loadAndMatchContacts(userManager: userManager)
            }
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
                            .background(Color("pine").opacity(0.2))
                            .padding(.horizontal)
                    }
                }
            }
        } header: {
            SectionHeader(title: "Add your friends on TrailMates")
        }
    }
}

private struct SectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(Color("pine"))
                .padding(.horizontal)
                .padding(.vertical, 8)
            Spacer()
        }
        .background(Color("beige").opacity(0.95))
    }
}

// MARK: - Matched User Row
private struct MatchedUserRow: View {
    let matchedContact: ContactsListViewModel.MatchedContact
    @Binding var matchedUsers: [ContactsListViewModel.MatchedContact]
    @EnvironmentObject var userManager: UserManager

    @State private var profileImage: UIImage?
    @State private var isLoadingImage = false
    @State private var isProcessing = false
    @State private var error: Error?

    var body: some View {
        // If we have a matched user, show a NavigationLink to their profile
        NavigationLink(destination: FriendProfileView(user: matchedContact.user)) {
            HStack(spacing: 12) {
                // Profile Image
                profileImageView

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(matchedContact.contact.givenName) \(matchedContact.contact.familyName)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color("pine"))
                    
                    Text("@\(matchedContact.user.username)")
                        .font(.system(size: 14))
                        .foregroundColor(Color("pine").opacity(0.7))
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
                        .foregroundColor(Color("beige"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color("pine"))
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal)
            .background(Color("beige").opacity(0.1))
        }
        .task {
            await loadProfileImageIfNeeded()
        }
        .alert("Error", isPresented: .constant(error != nil), presenting: error) { _ in
            Button("OK") { error = nil }
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    @ViewBuilder
    private var profileImageView: some View {
        
        Group{
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
        .overlay(Circle().stroke(userManager.isFriend(matchedContact.user.id) ? Color.green : Color.gray, lineWidth: 2))
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

    private func loadProfileImageIfNeeded() async {
        isLoadingImage = true
        defer { isLoadingImage = false }

        do {
            profileImage = try await userManager.fetchProfileImage(for: matchedContact.user, preferredSize: .thumbnail)
        } catch {
            print("Error loading profile image: \(error)")
        }
    }
}

// MARK: - Unmatched Contact Row
private struct UnmatchedContactRow: View {
    let contact: CNContact
    @State private var showingMessageComposer = false
    @State private var messageDelegate = MessageComposeDelegate()
    @State private var showingAlert = false
    
    private let appStoreLink = "https://apps.apple.com/app/id123456789" // Replace with your actual App Store link
    private let inviteMessage: String

    init(contact: CNContact) {
        self.contact = contact
        self.inviteMessage = "Hey! Join me on TrailMates, the best app for finding walking, running, and biking buddies in Austin! Download it here: \(appStoreLink)"
    }

    var body: some View {
        HStack {
            Text("\(contact.givenName) \(contact.familyName)")
                .foregroundColor(Color("pine"))
            Spacer()
            Button("Add") {
                if MessageComposerView.canSendText() {
                    showingMessageComposer = true
                } else {
                    showingAlert = true
                }
            }
            .foregroundColor(Color("beige"))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color("pine"))
            .cornerRadius(8)
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
        .sheet(isPresented: $showingMessageComposer) {
            if let phoneNumber = contact.phoneNumbers.first?.value.stringValue {
                MessageComposerView(
                    recipients: [phoneNumber],
                    messageBody: inviteMessage,
                    delegate: messageDelegate
                )
            }
        }
        .alert("Cannot Send Messages", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your device is not configured to send messages.")
        }
        .contextMenu {
            if let phoneNumber = contact.phoneNumbers.first?.value.stringValue {
                Button {
                    UIPasteboard.general.string = inviteMessage
                    if let url = URL(string: "sms:\(phoneNumber)") {
                        DispatchQueue.main.async {
                            UIApplication.shared.open(url)
                        }
                    }
                } label: {
                    Label("Send SMS", systemImage: "message.fill")
                }
            }
            Button {
                UIPasteboard.general.string = inviteMessage
            } label: {
                Label("Copy Invite Message", systemImage: "doc.on.doc")
            }
        }
    }
}
