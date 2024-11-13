struct ContactsListView: View {
    @State private var contacts: [CNContact] = []
    @State private var matchedUsers: [MatchedContact] = []
    @State private var unmatchedContacts: [CNContact] = []
    @State private var searchText: String = ""
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userManager: UserManager
    
    struct MatchedContact: Identifiable {
        let id: UUID
        let contact: CNContact
        let user: User
    }
    
   
    
    // Filtered contacts based on search
    private var filteredMatchedUsers: [MatchedContact] {
        if searchText.isEmpty { return matchedUsers }
        return matchedUsers.filter { contact in
            let fullName = "\(contact.contact.givenName) \(contact.contact.familyName)".lowercased()
            return fullName.contains(searchText.lowercased())
        }
    }
    
    private var filteredUnmatchedContacts: [CNContact] {
        if searchText.isEmpty { return unmatchedContacts }
        return unmatchedContacts.filter { contact in
            let fullName = "\(contact.givenName) \(contact.familyName)".lowercased()
            return fullName.contains(searchText.lowercased())
        }
    }
    
    var body: some View {
        ZStack {
            Color("beige").ignoresSafeArea()
            
            if contacts.isEmpty {
                EmptyContactsView()
            } else {
                VStack(spacing: 0) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color("pine"))
                        TextField("Search contacts", text: $searchText)
                            .foregroundColor(Color("pine"))
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
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
                        matchedUsers: $matchedUsers,
                        unmatchedContacts: filteredUnmatchedContacts,
                        userManager: userManager,
                        filteredMatchedUsers: filteredMatchedUsers
                    )
                }
            }
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
                await loadAndMatchContacts()
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
    
    private func fetchContacts() async throws -> [CNContact] {
        let store = CNContactStore()
        let keysToFetch = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey] as [CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var contacts: [CNContact] = []
                do {
                    try store.enumerateContacts(with: request) { contact, _ in
                        contacts.append(contact)
                    }
                    continuation.resume(returning: contacts)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func loadAndMatchContacts() async {
        do {
            // Fetch contacts on background thread
            let loadedContacts = try await fetchContacts()
            
            // Process contacts and match with users
            var matched: [MatchedContact] = []
            var unmatched: [CNContact] = []
            
            for contact in loadedContacts {
                var isMatched = false
                for phoneNumber in contact.phoneNumbers {
                    let number = phoneNumber.value.stringValue
                    if let user = await userManager.findUserByPhoneNumber(number) {
                        matched.append(MatchedContact(id: UUID(), contact: contact, user: user))
                        isMatched = true
                        break
                    }
                }
                if !isMatched {
                    unmatched.append(contact)
                }
            }
            
            // Update UI on main thread
            await MainActor.run {
                self.contacts = loadedContacts
                self.matchedUsers = matched
                self.unmatchedContacts = unmatched
            }
        } catch {
            print("Error fetching contacts: \(error)")
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
    @Binding var matchedUsers: [ContactsListView.MatchedContact]
    let unmatchedContacts: [CNContact]
    @ObservedObject var userManager: UserManager
    let filteredMatchedUsers: [ContactsListView.MatchedContact]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16, pinnedViews: .sectionHeaders) {
                // Matched Users Section
                if !filteredMatchedUsers.isEmpty {
                    MatchedUsersSection(
                        matchedUsers: $matchedUsers,
                        userManager: userManager,
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

@MainActor
struct MessageComposeDelegate: NSObject, MFMessageComposeViewControllerDelegate {
    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true)
    }
}

private struct MatchedUsersSection: View {
    @Binding var matchedUsers: [ContactsListView.MatchedContact]
    @ObservedObject var userManager: UserManager
    let filteredMatchedUsers: [ContactsListView.MatchedContact]
    
    var body: some View {
        Section {
            ForEach(Array(filteredMatchedUsers.enumerated()), id: \.element.id) { index, matchedContact in
                VStack(spacing: 0) {
                    MatchedUserRow(
                        matchedContact: matchedContact,
                        matchedUsers: $matchedUsers,
                        userManager: userManager
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
    let matchedContact: ContactsListView.MatchedContact
    @Binding var matchedUsers: [ContactsListView.MatchedContact]
    @ObservedObject var userManager: UserManager
    
    var body: some View {
        HStack {
            Text("\(matchedContact.contact.givenName) \(matchedContact.contact.familyName)")
                .foregroundColor(Color("pine"))
            Spacer()
            Button("Add") {
                userManager.addFriend(friendId: matchedContact.user.id)
                if let index = matchedUsers.firstIndex(where: { $0.id == matchedContact.id }) {
                    matchedUsers.remove(at: index)
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

// handle the message composition
struct MessageComposerView: UIViewControllerRepresentable {
    let recipients: [String]
    let messageBody: String
    let delegate: MessageComposeDelegate
    
    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.messageComposeDelegate = delegate
        controller.recipients = recipients
        controller.body = messageBody
        return controller
    }
    
    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}
    
    static func canSendText() -> Bool {
        return MFMessageComposeViewController.canSendText()
    }
}

private struct UnmatchedContactRow: View {
    let contact: CNContact
    @State private var showingMessageComposer = false
    @State private var messageDelegate = MessageComposeDelegate()
    @State private var showingAlert = false
    
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
                    messageBody: "Hey! Join me on TrailMates, the best app for finding walking, running, and biking buddies in Austin! Download it here: [App Store Link]",
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
                    UIPasteboard.general.string = "Hey! Join me on TrailMates, the best app for finding walking, running, and biking buddies in Austin! Download it here: [App Store Link]"
                    if let url = URL(string: "sms:\(phoneNumber)") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Send SMS", systemImage: "message.fill")
                }
            }
            
            Button {
                UIPasteboard.general.string = "Hey! Join me on TrailMates, the best app for finding walking, running, and biking buddies in Austin! Download it here: [App Store Link]"
            } label: {
                Label("Copy Invite Message", systemImage: "doc.on.doc")
            }
        }
    }
}