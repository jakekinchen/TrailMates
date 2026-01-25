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
    enum NavigationDestination: Hashable {
        case contacts
    }

    // MARK: - Properties
    let isOnboarding: Bool
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userManager: UserManager

    @State private var navigationPath = NavigationPath()
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
                            
                            contactsButton
                            inviteButton
                            
                            Text("Invite your friends to the community")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(Color("pine"))
                                .frame(maxWidth: .infinity, alignment: .leading)
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
    
    // MARK: - Actions
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
