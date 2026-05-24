//
//  AddFriendsView.swift
//  TrailMatesATX
//

import SwiftUI
import Contacts
import UserNotifications
import CoreLocation
import MessageUI
import UIKit

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
    @StateObject private var viewModel = FriendsViewModel()

    // MARK: - State
    @State private var navigationPath = NavigationPath()
    @State private var contactsAccessGranted = false
    @State private var showContactsPermissionAlert = false
    @State private var showContactsMatchingConsentAlert = false
    @State private var showMessageComposer = false
    @State private var showInviteCopiedAlert = false
    @State private var selectedPhoneNumber: String?
    @FocusState private var isFriendLookupFocused: Bool
    @AppStorage("contactsMatchingConsentGranted") private var contactsMatchingConsentGranted = false

    // MARK: - Private
    private let messageComposeDelegate = MessageComposeDelegate()
    private let contactsMatchingDisclosure = "TrailMates will read your contacts on this device, convert phone numbers to privacy-protecting hashes, and send only those hashes to TrailMates servers to check which contacts already have accounts. We do not upload contact names, photos, emails, or your full contact list, and we use the hashes only for friend matching."

    // MARK: - Body
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 24) {
                    connectionMethodsSection
                }
                .padding(.vertical)
            }
            .themedBackground()
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
            .task {
                viewModel.setup(with: userManager)
                refreshContactsAccessStatus()
            }
        }
        .alert("Share contact hashes?", isPresented: $showContactsMatchingConsentAlert) {
            Button("Not Now", role: .cancel) { }
            Button("I Agree") {
                contactsMatchingConsentGranted = true
                requestContactsAccessAndNavigate()
            }
        } message: {
            Text(contactsMatchingDisclosure)
        }
        .alert("Find contacts", isPresented: $showContactsPermissionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Open Settings") {
                openSettings()
            }
        } message: {
            Text("Allow access to your contacts in Settings to find friends on TrailMates.")
        }
        .alert("Invite Link Copied", isPresented: $showInviteCopiedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The invite link is ready to paste into any message.")
        }
    }
}

// MARK: - View Builders
private extension AddFriendsView {
    @ViewBuilder
    var connectionMethodsSection: some View {
        VStack(spacing: 16) {
            friendLookupSection
            secondaryActionsSection
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    var friendLookupSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Find Friends")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color("pine"))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .bottom, spacing: 10) {
                FloatingLabelTextField<Bool>(
                    placeholder: "Username or Phone Number",
                    text: $viewModel.friendLookupText,
                    keyboardType: .namePhonePad,
                    autocapitalization: .none,
                    colorStyle: .dark,
                    autocorrectionDisabled: true,
                    submitLabel: .search,
                    onSubmit: handleFriendSearch
                )
                .focused($isFriendLookupFocused)

                Button(action: handleFriendSearch) {
                    ZStack {
                        if viewModel.isSearchingForFriend {
                            ProgressView()
                                .tint(AppColors.textOnAccent)
                        } else {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(AppColors.textOnAccent)
                        }
                    }
                    .frame(width: 50, height: 50)
                    .background(AppColors.buttonPrimary)
                    .cornerRadius(10)
                }
                .disabled(viewModel.isSearchingForFriend)
                .accessibilityLabel("Search friends")
            }

            if let result = viewModel.friendLookupResult {
                FriendLookupResultRow(
                    user: result,
                    isCurrentUser: viewModel.isCurrentUser(result),
                    isFriend: viewModel.isFriend(result),
                    requestSent: viewModel.hasSentFriendRequest(to: result),
                    isSending: viewModel.isSendingFriendRequest
                ) {
                    Task {
                        await viewModel.sendFriendRequest(to: result)
                    }
                }
            }

            if let message = viewModel.friendLookupMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(Color("pine").opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color("sage").opacity(0.14))
        .cornerRadius(12)
    }

    @ViewBuilder
    var secondaryActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("More Ways")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(Color("pine"))
                .frame(maxWidth: .infinity, alignment: .leading)

            contactsButton
            inviteButton
        }
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
                    .frame(maxWidth: .infinity, alignment: .leading)

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
        Button(action: handleInviteAction) {
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
                    .frame(maxWidth: .infinity, alignment: .leading)
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
    var inviteURL: URL {
        guard let senderId = userManager.currentUser?.id else {
            return TrailMatesDeepLink.appStoreFallbackURL
        }

        return TrailMatesDeepLink.inviteURL(senderId: senderId)
    }

    var inviteMessage: String {
        let senderName = userManager.currentUser.map { "\($0.firstName) \($0.lastName)" }
            ?? "I"
        return "\(senderName) invited you to TrailMates ATX. Add them here: \(inviteURL.absoluteString)"
    }

    func handleFriendSearch() {
        isFriendLookupFocused = false
        Task {
            await viewModel.searchForFriend()
        }
    }

    func handleInviteAction() {
        if MessageComposerView.canSendText() {
            showMessageComposer = true
        } else {
            UIPasteboard.general.string = inviteMessage
            showInviteCopiedAlert = true
        }
    }

    func handleContactsAction() {
        refreshContactsAccessStatus()

        guard contactsMatchingConsentGranted else {
            showContactsMatchingConsentAlert = true
            return
        }

        if contactsAccessGranted {
            navigationPath.append(NavigationDestination.contacts)
        } else {
            requestContactsAccessAndNavigate()
        }
    }

    func requestContactsAccessAndNavigate() {
        let store = CNContactStore()
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

    func refreshContactsAccessStatus() {
        contactsAccessGranted = CNContactStore.authorizationStatus(for: .contacts) == .authorized
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Friend Lookup Result Row
private struct FriendLookupResultRow: View {
    let user: User
    let isCurrentUser: Bool
    let isFriend: Bool
    let requestSent: Bool
    let isSending: Bool
    let onAdd: () -> Void

    private var buttonTitle: String {
        if isCurrentUser { return "You" }
        if isFriend { return "Friends" }
        if requestSent { return "Sent" }
        return "Add"
    }

    private var canAdd: Bool {
        !isCurrentUser && !isFriend && !requestSent
    }

    var body: some View {
        HStack(spacing: 12) {
            FriendLookupAvatar(user: user)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(user.firstName) \(user.lastName)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color("pine"))

                Text("@\(user.username)")
                    .font(.system(size: 14))
                    .foregroundColor(Color("pine").opacity(0.72))
            }

            Spacer(minLength: 8)

            Button(action: onAdd) {
                ZStack {
                    if isSending && canAdd {
                        ProgressView()
                            .tint(Color("alwaysBeige"))
                    } else {
                        Text(buttonTitle)
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .frame(minWidth: 72)
                .padding(.vertical, 9)
                .padding(.horizontal, 12)
                .foregroundColor(canAdd ? Color("alwaysBeige") : Color("pine").opacity(0.72))
                .background(canAdd ? Color("pine") : Color("sage").opacity(0.35))
                .cornerRadius(9)
            }
            .disabled(!canAdd || isSending)
        }
        .padding(12)
        .background(Color("alwaysBeige").opacity(0.72))
        .cornerRadius(12)
    }
}

private struct FriendLookupAvatar: View {
    let user: User

    var body: some View {
        UserAvatarView(user: user, size: 48)
            .overlay(Circle().stroke(Color("pine").opacity(0.18), lineWidth: 1))
    }
}
