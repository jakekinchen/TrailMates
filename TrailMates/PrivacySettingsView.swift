import SwiftUI

// MARK: - PrivacySettingsView
struct PrivacySettingsView: View {
    // MARK: - Environment
    @EnvironmentObject var userManager: UserManager

    // MARK: - State
    @State private var pendingUpdates: Set<String> = []
    @State private var localShareWithFriends = false
    @State private var localShareWithHost = false
    @State private var localShareWithGroup = false
    @State private var localAllowFriendsInvite = false

    // MARK: - Body
    var body: some View {
        List {
            locationSharingSection
            eventSettingsSection
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Privacy")
                    .foregroundColor(Color("pine"))
                    .font(.headline)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadUserSettings() }
        .themedBackground()
    }
}

// MARK: - PrivacySettingsView Sections
private extension PrivacySettingsView {
    var locationSharingSection: some View {
        Section(header: Text("Trail Location Sharing").foregroundColor(Color("pine"))) {
            Toggle("Share with Friends", isOn: $localShareWithFriends)
                .tint(Color("sage"))
                .listRowBackground(Color("beige").opacity(0.9))
                .foregroundColor(Color("pine"))
                .onChange(of: localShareWithFriends) { oldValue, newValue in
                    updateSetting(key: "shareWithFriends", oldValue: oldValue, newValue: newValue) {
                        try await userManager.updatePrivacySettings(shareWithFriends: newValue)
                    }
                }

            Toggle("Share with Event Host", isOn: $localShareWithHost)
                .tint(Color("sage"))
                .foregroundColor(Color("pine"))
                .listRowBackground(Color("beige").opacity(0.9))
                .onChange(of: localShareWithHost) { oldValue, newValue in
                    updateSetting(key: "shareWithHost", oldValue: oldValue, newValue: newValue) {
                        try await userManager.updatePrivacySettings(shareWithHost: newValue)
                    }
                }

            Toggle("Share with Entire Event Group", isOn: $localShareWithGroup)
                .tint(Color("sage"))
                .foregroundColor(Color("pine"))
                .listRowBackground(Color("beige").opacity(0.9))
                .onChange(of: localShareWithGroup) { oldValue, newValue in
                    updateSetting(key: "shareWithGroup", oldValue: oldValue, newValue: newValue) {
                        try await userManager.updatePrivacySettings(shareWithGroup: newValue)
                    }
                }
        }
    }

    var eventSettingsSection: some View {
        Section(header: Text("Event Settings").foregroundColor(Color("pine"))) {
            Toggle("Allow Friends to Invite Others to My Events", isOn: $localAllowFriendsInvite)
                .tint(Color("sage"))
                .foregroundColor(Color("pine"))
                .listRowBackground(Color("beige").opacity(0.9))
                .onChange(of: localAllowFriendsInvite) { oldValue, newValue in
                    updateSetting(key: "allowFriendsInvite", oldValue: oldValue, newValue: newValue) {
                        try await userManager.updatePrivacySettings(allowFriendsInvite: newValue)
                    }
                }
        }
    }
}

// MARK: - PrivacySettingsView Helpers
private extension PrivacySettingsView {
    func loadUserSettings() {
        if let user = userManager.currentUser {
            localShareWithFriends = user.shareLocationWithFriends
            localShareWithHost = user.shareLocationWithEventHost
            localShareWithGroup = user.shareLocationWithEventGroup
            localAllowFriendsInvite = user.allowFriendsToInviteOthers
        }
    }

    func updateSetting<T>(key: String, oldValue: T, newValue: T, action: @escaping () async throws -> Void) {
        guard !pendingUpdates.contains(key) else { return }
        pendingUpdates.insert(key)
        Task {
            do {
                try await action()
            } catch {
                if pendingUpdates.contains(key) {
                    if let boolVal = oldValue as? Bool, let binding = self.binding(forKey: key) {
                        binding.wrappedValue = boolVal
                    }
                }
            }
            pendingUpdates.remove(key)
        }
    }

    func binding(forKey key: String) -> Binding<Bool>? {
        switch key {
        case "shareWithFriends": return $localShareWithFriends
        case "shareWithHost": return $localShareWithHost
        case "shareWithGroup": return $localShareWithGroup
        case "allowFriendsInvite": return $localAllowFriendsInvite
        default: return nil
        }
    }
}
