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
                    .foregroundColor(Color("pine"))
                    .font(.headline)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .foregroundColor(Color("pine"))
        .themedBackground()
    }
}

// MARK: - NotificationSettingsView Sections
private extension NotificationSettingsView {
    var socialSection: some View {
        Section(header: Text("Social").foregroundColor(Color("pine"))) {
            Toggle("Friend Requests", isOn: Binding(
                get: { userManager.currentUser?.receiveFriendRequests ?? true },
                set: { newValue in
                    Task {
                        try await userManager.updateNotificationSettings(friendRequests: newValue)
                    }
                }
            ))
            .tint(Color("sage"))
            .listRowBackground(Color("beige").opacity(0.9))
            .foregroundColor(Color("pine"))

            Toggle("New Events from Friends", isOn: Binding(
                get: { userManager.currentUser?.receiveFriendEvents ?? true },
                set: { newValue in
                    Task {
                        try await userManager.updateNotificationSettings(friendEvents: newValue)
                    }
                }
            ))
            .tint(Color("sage"))
            .listRowBackground(Color("beige").opacity(0.9))
            .foregroundColor(Color("pine"))
        }
    }

    var eventsSection: some View {
        Section(header: Text("Events").foregroundColor(Color("pine"))) {
            Toggle("Event Updates & Changes", isOn: Binding(
                get: { userManager.currentUser?.receiveEventUpdates ?? true },
                set: { newValue in
                    Task {
                        try await userManager.updateNotificationSettings(eventUpdates: newValue)
                    }
                }
            ))
            .tint(Color("sage"))
            .listRowBackground(Color("beige").opacity(0.9))
            .foregroundColor(Color("pine"))
        }
    }
}
