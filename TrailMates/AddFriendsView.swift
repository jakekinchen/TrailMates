//
//  AddFriendsView.swift
//  TrailMatesATX
//

import SwiftUI
import Contacts
import UserNotifications
import CoreLocation
import MessageUI

// MARK: - Onboarding Wrapper
struct OnboardingAddFriendsView: View {
    // MARK: - Dependencies
    let onFinish: () -> Void

    // MARK: - Environment
    @EnvironmentObject private var userManager: UserManager

    // MARK: - Body
    var body: some View {
        AddFriendsView(isOnboarding: true) {
            userManager.hasAddedFriends = true
            userManager.isOnboardingComplete = true
            userManager.persistUserSession()
            onFinish()
        }
    }
}

// MARK: - Main View
struct AddFriendsView: View {
    // MARK: - Navigation Destination
    enum NavigationDestination: Hashable {
        case contacts
    }

    // MARK: - Dependencies
    let isOnboarding: Bool
    let onComplete: () -> Void

    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userManager: UserManager

    // MARK: - State
    @State private var navigationPath = NavigationPath()
    @State private var contactsAccessGranted = false
    @State private var showContactsPermissionAlert = false
    @State private var showMessageComposer = false
    @State private var selectedPhoneNumber: String?
    @State private var inviteMessage = "Hey! Join me on TrailMates ATX, the best app for going on social walks around Lady Bird Lake! Download here: [App Store Link]"

    // MARK: - Private
    private let messageComposeDelegate = MessageComposeDelegate()

    // MARK: - Body
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color("beige").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        connectionMethodsSection
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Add Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    doneButton
                }
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .contacts:
                    ContactsListView()
                }
            }
            .sheet(isPresented: $showMessageComposer) {
                messageComposerSheet
            }
        }
        .alert("Find contacts", isPresented: $showContactsPermissionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Open Settings") {
                openSettings()
            }
        } message: {
            Text("Allow access to your contacts in Settings to find friends on TrailMates.")
        }
    }
}

// MARK: - View Builders
private extension AddFriendsView {
    @ViewBuilder
    var connectionMethodsSection: some View {
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

    @ViewBuilder
    var contactsButton: some View {
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

    @ViewBuilder
    var inviteButton: some View {
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

    @ViewBuilder
    var doneButton: some View {
        Button("Done") {
            if isOnboarding {
                onComplete()
            } else {
                dismiss()
            }
        }
        .foregroundColor(Color("pine"))
    }

    @ViewBuilder
    var messageComposerSheet: some View {
        if MessageComposerView.canSendText() {
            MessageComposerView(
                recipients: selectedPhoneNumber.map { [$0] } ?? [],
                messageBody: inviteMessage,
                delegate: messageComposeDelegate
            )
        }
    }
}

// MARK: - Helper Methods
private extension AddFriendsView {
    func handleContactsAction() {
        let store = CNContactStore()
        if contactsAccessGranted {
            navigationPath.append(NavigationDestination.contacts)
        } else {
            Task { @MainActor in
                do {
                    let granted = try await store.requestAccess(for: .contacts)
                    if granted {
                        contactsAccessGranted = true
                        navigationPath.append(NavigationDestination.contacts)
                    } else {
                        showContactsPermissionAlert = true
                    }
                } catch {
                    showContactsPermissionAlert = true
                }
            }
        }
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
