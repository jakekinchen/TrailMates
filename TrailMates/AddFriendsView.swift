import SwiftUI
import Contacts
import UserNotifications
import CoreLocation
import MessageUI

// MARK: - Onboarding Wrapper
struct OnboardingAddFriendsView: View {
    let onFinish: () -> Void
    @EnvironmentObject var userManager: UserManager

    var body: some View {
        AddFriendsView(isOnboarding: true) {
            userManager.hasAddedFriends = true
            userManager.isOnboardingComplete = true
            userManager.persistUserSession()
            onFinish()
        }
    }
}

struct AddFriendsView: View {
    enum ViewState: Equatable {
        case idle
        case loading
        case loaded([(friend: FacebookFriend, user: User?, isFriend: Bool)])
        case error(Error)
        
        static func == (lhs: ViewState, rhs: ViewState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle):
                return true
            case (.loading, .loading):
                return true
            case (.loaded(let lhsFriends), .loaded(let rhsFriends)):
                return lhsFriends.map { $0.friend.id } == rhsFriends.map { $0.friend.id }
            case (.error, .error):
                return true
            default:
                return false
            }
        }
    }
    
    enum NavigationDestination: Hashable {
        case contacts
    }
    
    // MARK: - Properties
    let isOnboarding: Bool
    let onComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userManager: UserManager
    
    @State private var navigationPath = NavigationPath()
    @State private var viewState: ViewState = .idle
    @State private var contactsAccessGranted = false
    @State private var showContactsPermissionAlert = false
    @State private var showMessageComposer = false
    @State private var selectedPhoneNumber: String?
    @State private var inviteMessage = "Hey! Join me on TrailMates ATX, the best app for going on social walks around Lady Bird Lake! Download here: [App Store Link]"
    
    private let messageComposeDelegate = MessageComposeDelegate()
    
    // MARK: - Body
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color("beige").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Connection Methods Section
                        VStack(spacing: 16) {
                            Text("Connect with Friends")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Color("pine"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            facebookButton
                            contactsButton
                            inviteButton
                            
                            Text("Invite your friends to the community")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(Color("pine"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal)
                        
                        // Friends List Section
                        VStack(spacing: 16) {
                            friendsSection
                                .background(Color.white)
                                .cornerRadius(15)
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Add Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        if isOnboarding {
                            onComplete()
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundColor(Color("pine"))
                }
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .contacts:
                    ContactsListView()
                }
            }
            .sheet(isPresented: $showMessageComposer) {
                if MessageComposerView.canSendText() {
                    MessageComposerView(
                        recipients: selectedPhoneNumber.map { [$0] } ?? [],
                        messageBody: inviteMessage,
                        delegate: messageComposeDelegate
                    )
                }
            }
        }
        .alert("Find contacts", isPresented: $showContactsPermissionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Allow access to your contacts in Settings to find friends on TrailMates.")
        }
    }
    
    // MARK: - Components
    private var facebookButton: some View {
        Button(action: handleFacebookAction) {
            HStack {
                Image("facebook_icon")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.white)
                    .accessibilityHidden(true)
                
                Text(userManager.isFacebookLinked ? "View Facebook Friends" : "Link Facebook")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color.blue)
            .cornerRadius(15)
            .disabled(viewState == .loading)
        }
    }
    
    private var contactsButton: some View {
        Button(action: handleContactsAction) {
            HStack {
                Image(systemName: "person.crop.circle.badge.plus")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(Color("beige"))
                    .accessibilityHidden(true)
                
                Text("Add from Contacts")
                    .fontWeight(.bold)
                    .foregroundColor(Color("beige"))
                    .frame(maxWidth: .infinity)
                
                if contactsAccessGranted {
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color("beige"))
                        .accessibilityHidden(true)
                }
            }
            .padding()
            .background(Color("pine"))
            .cornerRadius(15)
        }
    }
    
    private var inviteButton: some View {
        Button(action: {
            showMessageComposer = true
        }) {
            HStack {
                Image(systemName: "envelope")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(Color("alwaysBeige"))
                    .accessibilityHidden(true)
                
                Text("Invite Friends")
                    .fontWeight(.bold)
                    .foregroundColor(Color("alwaysBeige"))
                    .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color("pumpkin"))
            .cornerRadius(15)
        }
    }
    
    private var friendsSection: some View {
        Group {
            switch viewState {
            case .idle:
                EmptyView()
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            case .loaded(let friends):
                if friends.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("No Facebook friends found")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Invite your friends to join TrailMates!")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Button(action: {
                            showMessageComposer = true
                        }) {
                            Text("Send Invite")
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(20)
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                } else {
                    FacebookFriendsList(friends: friends)
                }
            case .error(let error):
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                    Text(error.localizedDescription)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
    }
    
    // MARK: - Actions
    private func handleFacebookAction() {
        Task {
            viewState = .loading
            do {
                if !userManager.isFacebookLinked {
                    try await userManager.linkFacebook()
                }
                let friends = try await userManager.fetchFacebookFriendsWithStatus()
                viewState = .loaded(friends)
            } catch {
                viewState = .error(error)
            }
        }
    }
    
    private func handleContactsAction() {
        let store = CNContactStore()
        if contactsAccessGranted {
            navigationPath.append(NavigationDestination.contacts)
        } else {
            store.requestAccess(for: .contacts) { granted, _ in
                DispatchQueue.main.async {
                    if granted {
                        contactsAccessGranted = true
                        navigationPath.append(NavigationDestination.contacts)
                    } else {
                        showContactsPermissionAlert = true
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views
struct FacebookFriendsList: View {
    let friends: [(friend: FacebookFriend, user: User?, isFriend: Bool)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Facebook Friends")
                .font(.headline)
                .foregroundColor(Color("pine"))
                .padding(.horizontal)
                .padding(.top)
            
            ForEach(Array(friends.enumerated()), id: \.element.friend.id) { index, friendData in
                VStack {
                    FacebookFriendRow(friendData: friendData)
                    if index < friends.count - 1 {
                        Divider()
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom)
        }
    }
}

struct FacebookFriendRow: View {
    let friendData: (friend: FacebookFriend, user: User?, isFriend: Bool)
    @EnvironmentObject private var userManager: UserManager
    @State private var isProcessing = false
    @State private var error: Error?
    @State private var showMessageComposer = false
    @State private var showPhoneNumberInput = false
    @State private var phoneNumber = ""
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile Image or Placeholder
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundColor(Color("pine").opacity(0.3))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(friendData.friend.name)
                    .fontWeight(.medium)
                    .foregroundColor(Color("pine"))
            }
            
            Spacer()
            
            Group {
                if friendData.isFriend {
                    Label("Added", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.gray)
                } else if let user = friendData.user {
                    Button(action: { sendFriendRequest(to: user.id) }) {
                        if isProcessing {
                            ProgressView()
                        } else {
                            Text("Add")
                                .fontWeight(.medium)
                                .foregroundColor(Color("pine"))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color("pine").opacity(0.1))
                                .cornerRadius(20)
                        }
                    }
                    .disabled(isProcessing)
                } else {
                    Button(action: { showPhoneNumberInput = true }) {
                        Text("Invite")
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(20)
                    }
                }
            }
        }
        .padding(.horizontal)
        .sheet(isPresented: $showMessageComposer) {
            if MessageComposerView.canSendText() {
                MessageComposerView(
                    recipients: [phoneNumber],
                    messageBody: "Hey! Join me on TrailMates, the best app for finding hiking buddies! Download here: [App Store Link]",
                    delegate: MessageComposeDelegate()
                )
            }
        }
        .alert("Enter Phone Number", isPresented: $showPhoneNumberInput) {
            TextField("Phone Number", text: $phoneNumber)
                .keyboardType(.phonePad)
            Button("Cancel", role: .cancel) {
                phoneNumber = ""
            }
            Button("Send Invite") {
                if !phoneNumber.isEmpty {
                    showMessageComposer = true
                }
            }
        } message: {
            Text("Enter the phone number to send an invitation")
        }
        .alert("Error", isPresented: .constant(error != nil), presenting: error) { _ in
            Button("OK") { error = nil }
        } message: { error in
            Text(error.localizedDescription)
        }
    }
    
    

    
    private func sendFriendRequest(to userId: String) {
        Task {
            isProcessing = true
            defer { isProcessing = false }
            
            do {
                try await userManager.sendFriendRequest(to: userId)
            } catch {
                self.error = error
            }
        }
    }
}
