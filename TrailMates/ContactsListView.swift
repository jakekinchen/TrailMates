import SwiftUI
@preconcurrency import Contacts
import Combine
import MessageUI

struct ContactsListView: View {
    @StateObject private var viewModel = ContactsListViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userManager: UserManager
    @FocusState private var focusedField: Field?

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

                        if !viewModel.searchText.isEmpty {
                            Button(action: {
                                viewModel.searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color("pine"))
                            }
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color("pine").opacity(0.1))
                    )
                    .padding()

                    // Contacts List
                    ContactsContentView(
                        matchedUsers: $viewModel.matchedUsers,
                        unmatchedContacts: viewModel.filteredUnmatchedContacts,
                        filteredMatchedUsers: viewModel.filteredMatchedUsers
                    )
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

            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color("beige"))
            appearance.titleTextAttributes = [.foregroundColor: UIColor(Color("pine"))]

            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            UINavigationBar.appearance().tintColor = UIColor(Color("pine"))
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
private struct ContactsContentView: View {
    @Binding var matchedUsers: [ContactsListViewModel.MatchedContact]
    let unmatchedContacts: [CNContact]
    @EnvironmentObject var userManager: UserManager
    let filteredMatchedUsers: [ContactsListViewModel.MatchedContact]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16, pinnedViews: .sectionHeaders) {
                // Matched Users Section
                if !filteredMatchedUsers.isEmpty {
                    MatchedUsersSection(
                        matchedUsers: $matchedUsers,
                        filteredMatchedUsers: filteredMatchedUsers
                    )
                }

                // Unmatched Contacts Section
                if !unmatchedContacts.isEmpty {
                    UnmatchedContactsSection(
                        contacts: unmatchedContacts
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct MatchedUsersSection: View {
    @Binding var matchedUsers: [ContactsListViewModel.MatchedContact]
    @EnvironmentObject var userManager: UserManager
    let filteredMatchedUsers: [ContactsListViewModel.MatchedContact]

    var body: some View {
        Section {
            ForEach(Array(filteredMatchedUsers.enumerated()), id: \.element.id) { index, matchedContact in
                VStack(spacing: 0) {
                    MatchedUserRow(
                        matchedContact: matchedContact,
                        matchedUsers: $matchedUsers
                    )

                    if index < filteredMatchedUsers.count - 1 {
                        Divider()
                            .background(Color("pine").opacity(0.2))
                            .padding(.horizontal)
                    }
                }
            }
        } header: {
            SectionHeader(title: "On TrailMates")
        }
    }
}

private struct UnmatchedContactsSection: View {
    let contacts: [CNContact]

    var body: some View {
        Section {
            ForEach(Array(contacts.enumerated()), id: \.element.identifier) { index, contact in
                VStack(spacing: 0) {
                    UnmatchedContactRow(contact: contact)

                    if index < contacts.count - 1 {
                        Divider()
                            .background(Color("pine").opacity(0.2))
                            .padding(.horizontal)
                    }
                }
            }
        } header: {
            SectionHeader(title: "Invite to TrailMates")
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

private struct MatchedUserRow: View {
    let matchedContact: ContactsListViewModel.MatchedContact
    @Binding var matchedUsers: [ContactsListViewModel.MatchedContact]
    @EnvironmentObject var userManager: UserManager

    var body: some View {
        HStack {
            Text("\(matchedContact.contact.givenName) \(matchedContact.contact.familyName)")
                .foregroundColor(Color("pine"))
            Spacer()
            Button("Add") {
                Task {
                    do {
                        try await userManager.sendFriendRequest(to: matchedContact.user.id)
                        if let index = matchedUsers.firstIndex(where: { $0.id == matchedContact.id }) {
                            matchedUsers.remove(at: index)
                        }
                    } catch {
                        print("Error sending friend request: \(error)")
                    }
                }
            }
            .foregroundColor(Color("beige"))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color("pine"))
            .cornerRadius(8)
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
        .background(Color("beige").opacity(0.1))
    }
}

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
            Button("Invite") {
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
