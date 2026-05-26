import SwiftUI

// MARK: - NotificationSettingsView
struct NotificationSettingsView: View {
    // MARK: - Environment
    @EnvironmentObject var userManager: UserManager

    // MARK: - Body
    var body: some View {
        List {
            socialSection
            eventsSection
        }
        .navigationTitle("Notifications")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Notifications")
                    .foregroundColor(AppColors.pine)
                    .font(.headline)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .foregroundColor(AppColors.pine)
        .themedBackground()
    }
}

// MARK: - NotificationSettingsView Sections
private extension NotificationSettingsView {
    var socialSection: some View {
        Section(header: Text("Social").foregroundColor(AppColors.pine)) {
            Toggle("Friend Requests", isOn: Binding(
                get: { userManager.currentUser?.receiveFriendRequests ?? true },
                set: { newValue in
                    Task {
                        try await userManager.updateNotificationSettings(friendRequests: newValue)
                    }
                }
            ))
            .tint(AppColors.sage)
            .listRowBackground(AppColors.beige.opacity(0.9))
            .foregroundColor(AppColors.pine)

            Toggle("New Events from Friends", isOn: Binding(
                get: { userManager.currentUser?.receiveFriendEvents ?? true },
                set: { newValue in
                    Task {
                        try await userManager.updateNotificationSettings(friendEvents: newValue)
                    }
                }
            ))
            .tint(AppColors.sage)
            .listRowBackground(AppColors.beige.opacity(0.9))
            .foregroundColor(AppColors.pine)
        }
    }

    var eventsSection: some View {
        Section(header: Text("Events").foregroundColor(AppColors.pine)) {
            Toggle("Event Updates & Changes", isOn: Binding(
                get: { userManager.currentUser?.receiveEventUpdates ?? true },
                set: { newValue in
                    Task {
                        try await userManager.updateNotificationSettings(eventUpdates: newValue)
                    }
                }
            ))
            .tint(AppColors.sage)
            .listRowBackground(AppColors.beige.opacity(0.9))
            .foregroundColor(AppColors.pine)
        }
    }
}
