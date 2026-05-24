import SwiftUI
import CoreLocation
import UserNotifications
import Contacts
import PhotosUI

// MARK: - SettingsView
struct SettingsView: View {
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var authViewModel: AuthViewModel

    // MARK: - State
    @State private var showsStats = true
    @AppStorage("appearance") private var appearance: String = "System"
    @State private var showDeleteAccountAlert = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?

    // MARK: - Body
    var body: some View {
        ZStack {
            backgroundView

            NavigationStack {
                List {
                    personalInfoSection
                    privacyNotificationsSection
                    appPermissionsSection
                    appearanceSection
                    resourcesSection
                    accountSection
                    logoutSection
                }
                .listStyle(InsetGroupedListStyle())
                .background(Color("beige"))
                .scrollContentBackground(.hidden)
                .toolbar { toolbarContent }
                .navigationBarTitleDisplayMode(.inline)
                .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete", role: .destructive) {
                        showDeleteAccountConfirmation = true
                    }
                } message: {
                    Text("Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently removed.")
                }
                .alert("Final Confirmation", isPresented: $showDeleteAccountConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete My Account", role: .destructive) {
                        Task {
                            await deleteAccount()
                        }
                    }
                } message: {
                    Text("This is your last chance. Your account, profile, friends, and all associated data will be permanently deleted.")
                }
                .alert("Error", isPresented: .init(
                    get: { deleteAccountError != nil },
                    set: { if !$0 { deleteAccountError = nil } }
                )) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(deleteAccountError ?? "An unknown error occurred")
                }
            }
            .tint(Color("pine"))
            .toolbarBackground(Color("altBeige"), for: .navigationBar)
        }
    }
}

// MARK: - SettingsView Background
private extension SettingsView {
    var backgroundView: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()
            Color("beige")
                .opacity(0.5)
                .ignoresSafeArea()
        }
    }
}

// MARK: - SettingsView Sections
private extension SettingsView {
    var personalInfoSection: some View {
        Section(header: Text("Personal Info")) {
            NavigationLink(destination: ChangePhoneView()) {
                SettingsRow(
                    icon: "phone.fill",
                    title: "Change Phone Number",
                    subtitle: "Requires verification",
                    showChevron: false
                )
            }
        }
        .listRowBackground(Color("altBeige").opacity(0.9))
        .foregroundColor(Color("pine"))
    }

    var privacyNotificationsSection: some View {
        Section(header: Text("Privacy & Notifications")) {
            NavigationLink(destination: PrivacySettingsView()) {
                SettingsRow(
                    icon: "hand.raised.fill",
                    title: "Privacy",
                    subtitle: "Trail Location sharing, visibility settings",
                    showChevron: false
                )
            }

            NavigationLink(destination: NotificationSettingsView()) {
                SettingsRow(
                    icon: "bell.fill",
                    title: "Notifications",
                    subtitle: "Event and message alerts",
                    showChevron: false
                )
            }
        }
        .listRowBackground(Color("altBeige").opacity(0.9))
        .foregroundColor(Color("pine"))
    }

    var appPermissionsSection: some View {
        Section {
            Button(action: { openAppSettings() }) {
                SettingsRow(
                    icon: "gear",
                    title: "App Permissions",
                    subtitle: "Location, contacts, notifications",
                    showChevron: false
                )
            }
        }
        .listRowBackground(Color("altBeige").opacity(0.9))
        .foregroundColor(Color("pine"))
    }

    var appearanceSection: some View {
        Section {
            Picker("Appearance", selection: $appearance) {
                Text("System").tag("System")
                Text("Light").tag("Light")
                Text("Dark").tag("Dark")
            }
            .onChange(of: appearance) { oldValue, newValue in
                updateAppearance(newValue)
                #if DEBUG
                print("Appearance setting: \(appearance)")
                #endif
            }
        }
        .listRowBackground(Color("altBeige").opacity(0.9))
        .foregroundColor(Color("pine"))
    }

    var resourcesSection: some View {
        Section(header: Text("Resources")) {
            NavigationLink(destination: HelpCenterView()) {
                SettingsRow(
                    icon: "questionmark.circle.fill",
                    title: "Help Center",
                    subtitle: "FAQs and support",
                    showChevron: false
                )
            }

            NavigationLink(destination: AboutView()) {
                SettingsRow(
                    icon: "info.circle.fill",
                    title: "About",
                    subtitle: "Version info",
                    showChevron: false
                )
            }

            Button(action: {
                if let url = URL(string: "itms-apps://itunes.apple.com/app/id123456789") {
                    UIApplication.shared.open(url)
                }
            }) {
                SettingsRow(
                    icon: "star.fill",
                    title: "Rate TrailMates",
                    subtitle: "Share your feedback",
                    showChevron: false
                )
            }
        }
        .listRowBackground(Color("altBeige").opacity(0.9))
        .foregroundColor(Color("pine"))
    }

    var accountSection: some View {
        Section(header: Text("Account")) {
            Button(action: {
                showDeleteAccountAlert = true
            }) {
                HStack {
                    Spacer()
                    if isDeletingAccount {
                        ProgressView()
                            .tint(.red)
                    } else {
                        Text("Delete Account")
                            .foregroundColor(.red)
                    }
                    Spacer()
                }
            }
            .disabled(isDeletingAccount)
        }
        .listRowBackground(Color("altBeige").opacity(0.9))
    }

    var logoutSection: some View {
        Section {
            Button(action: {
                Task {
                    await authViewModel.signOut()
                }
            }) {
                HStack {
                    Spacer()
                    Text("Log Out")
                        .foregroundColor(Color("pine"))
                    Spacer()
                }
            }
        }
        .listRowBackground(Color("altBeige").opacity(0.9))
        .foregroundColor(Color("pine"))
    }
}

// MARK: - SettingsView Toolbar
private extension SettingsView {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(Color("pine"))
            }
        }
        ToolbarItem(placement: .principal) {
            Text("Settings")
                .foregroundColor(Color("pine"))
                .font(.headline)
        }
    }
}

// MARK: - SettingsView Helpers
private extension SettingsView {
    func openAppSettings() {
        if let appSettings = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(appSettings)
        }
    }

    func updateAppearance(_ appearance: String) {
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

    func deleteAccount() async {
        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            try await authViewModel.deleteAccount()
            dismiss()
        } catch {
            deleteAccountError = error.localizedDescription
        }
    }
}

// MARK: - UIApplication Extension
extension UIApplication {
    var icon: String? {
        guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
              let icon = iconFiles.last
        else { return nil }
        return icon
    }
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SettingsView()
                .environmentObject(UserManager.shared)
                .environmentObject(AuthViewModel())
        }
    }
}
