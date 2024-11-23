import SwiftUI
import CoreLocation
import UserNotifications
import Contacts
import PhotosUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showsStats = true
    @AppStorage("appearance") private var appearance: String = "System"
    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationView {
            List {
                // Personal Info
                Section(header: Text("Personal Info")) {
                    NavigationLink(destination: ChangePhoneView(focusedField: $focusedField)) {
                        SettingsRow(icon: "phone.fill",
                                  title: "Change Phone Number",
                                  subtitle: "Requires verification")
                    }
                    
                    Button(action: {
                        // Sync contacts action
                    }) {
                        SettingsRow(icon: "person.2.fill",
                                  title: "Sync Phone Contacts",
                                  subtitle: "Find friends using TrailMates")
                    }
                    
                    Button(action: {
                        // Toggle Facebook link
                        Task {
                            try await userManager.toggleFacebookLink()
                        }
                    }) {
                        SettingsRow(icon: "link",
                                    title: userManager.isFacebookLinked ? "Unlink Facebook" : "Link Facebook",
                                  subtitle: "Connect with Facebook friends")
                    }
                }
                
                // Privacy & Notifications (as submenus)
                                Section {
                                    NavigationLink(destination: PrivacySettingsView()) {
                                        SettingsRow(icon: "hand.raised.fill",
                                                  title: "Privacy",
                                                  subtitle: "Location sharing, visibility settings")
                                    }
                                    
                                    NavigationLink(destination: NotificationSettingsView()) {
                                        SettingsRow(icon: "bell.fill",
                                                  title: "Notifications",
                                                  subtitle: "Event and message alerts")
                                    }
                                }
                                
                                // App Permissions
                                Section {
                                    Button(action: { openAppSettings() }) {
                                        SettingsRow(icon: "gear",
                                                  title: "App Permissions",
                                                  subtitle: "Location, contacts, notifications")
                                    }
                                }
                                
                                // Appearance
                                Section {
                                    Picker("Appearance", selection: $appearance) {
                                        Text("System").tag("System")
                                        Text("Light").tag("Light")
                                        Text("Dark").tag("Dark")
                                    }
                                    .onChange(of: appearance) { oldValue, newValue in
                                        updateAppearance(newValue)
                                    }
                                }
                                
                                // Resources
                                Section(header: Text("Resources")) {
                                    NavigationLink(destination: Text("Help Center")) {
                                        SettingsRow(icon: "questionmark.circle.fill",
                                                  title: "Help Center",
                                                  subtitle: "FAQs and support")
                                    }
                                    
                                    NavigationLink(destination: Text("About")) {
                                        SettingsRow(icon: "info.circle.fill",
                                                  title: "About",
                                                  subtitle: "Version info")
                                    }
                                    
                                    Button(action: {
                                        // Rate app action
                                    }) {
                                        SettingsRow(icon: "star.fill",
                                                  title: "Rate TrailMates",
                                                  subtitle: "Share your feedback")
                                    }
                                }
                                
                                // Logout
                                Section {
                                    Button(action: {
                                        Task { @MainActor in
                                            authViewModel.signOut()
                                        }
                                    }) {
                                        HStack {
                                            Spacer()
                                            Text("Log Out")
                                                .foregroundColor(.red)
                                            Spacer()
                                        }
                                    }
                                }
                            }
                            .listStyle(InsetGroupedListStyle())
                            .navigationTitle("Settings")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button {
                                        dismiss()
                                    } label: {
                                        Image(systemName: "xmark")
                                            .foregroundColor(Color("pine"))
                                    }
                                }
                            }
                        }
                    }
                    
                    func openAppSettings() {
                        if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                            DispatchQueue.main.async {
                                UIApplication.shared.open(appSettings)
                            }
                        }
                    }
                    
                    func updateAppearance(_ appearance: String) {
                        DispatchQueue.main.async {
                            // Update app appearance based on selection
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                                windowScene.windows.forEach { window in
                                    window.overrideUserInterfaceStyle = {
                                        switch appearance {
                                        case "Light": return .light
                                        case "Dark": return .dark
                                        default: return .unspecified
                                        }
                                    }()
                                }
                            }
                        }
                    }
                }

// MARK: - Supporting Views
struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(Color("pine"))
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(Color("pine"))
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(Color("pine").opacity(0.7))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
        }
    }
}

struct PreferenceToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isEnabled: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(Color("pine"))
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(Color("pine").opacity(0.7))
            }
            
            Spacer()
            
            Toggle("", isOn: $isEnabled)
                .tint(Color("pine"))
        }
    }
}

struct PrivacySettingsView: View {
    @EnvironmentObject var userManager: UserManager

    var body: some View {
            List {
                Section(header: Text("Location Sharing")) {
                    Toggle("Share with Friends", isOn: Binding(
                        get: { userManager.currentUser?.shareLocationWithFriends ?? false },
                        set: { newValue in
                            Task {
                                try await userManager.updatePrivacySettings(shareWithFriends: newValue)
                            }
                        }
                    ))
                    .tint(Color("pine"))
                    
                    Toggle("Share with Event Host", isOn: Binding(
                        get: { userManager.currentUser?.shareLocationWithEventHost ?? false },
                        set: { newValue in
                            Task {
                                try await userManager.updatePrivacySettings(shareWithHost: newValue)
                            }
                        }
                    ))
                    .tint(Color("pine"))
                    
                    Toggle("Share with Entire Event Group", isOn: Binding(
                        get: { userManager.currentUser?.shareLocationWithEventGroup ?? false },
                        set: { newValue in
                            Task {
                                try await userManager.updatePrivacySettings(shareWithGroup: newValue)
                            }
                        }
                    ))
                    .tint(Color("pine"))
                }
                
                Section(header: Text("Event Settings")) {
                    Toggle("Allow Friends to Invite Others to My Events", isOn: Binding(
                        get: { userManager.currentUser?.allowFriendsToInviteOthers ?? false },
                        set: { newValue in
                            Task {
                                try await userManager.updatePrivacySettings(allowFriendsInvite: newValue)
                            }
                        }
                    ))
                    .tint(Color("pine"))
                }
            }
            .navigationTitle("Privacy")
            .listStyle(InsetGroupedListStyle())
        }
}

struct NotificationSettingsView: View {
    @EnvironmentObject var userManager: UserManager

    var body: some View {
            List {
                Section(header: Text("Social")) {
                    Toggle("Friend Requests", isOn: Binding(
                        get: { userManager.currentUser?.receiveFriendRequests ?? true },
                        set: { newValue in
                            Task {
                                try await userManager.updateNotificationSettings(friendRequests: newValue)
                            }
                        }
                    ))
                    .tint(Color("pine"))
                    
                    Toggle("New Events from Friends", isOn: Binding(
                        get: { userManager.currentUser?.receiveFriendEvents ?? true },
                        set: { newValue in
                            Task {
                                try await userManager.updateNotificationSettings(friendEvents: newValue)
                            }
                        }
                    ))
                    .tint(Color("pine"))
                }
                
                Section(header: Text("Events")) {
                    Toggle("Event Updates & Changes", isOn: Binding(
                        get: { userManager.currentUser?.receiveEventUpdates ?? true },
                        set: { newValue in
                            Task {
                                try await userManager.updateNotificationSettings(eventUpdates: newValue)
                            }
                        }
                    ))
                    .tint(Color("pine"))
                }
            }
            .navigationTitle("Notifications")
            .listStyle(InsetGroupedListStyle())
        }
}
