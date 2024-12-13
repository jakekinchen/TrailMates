import SwiftUI
import CoreLocation
import UserNotifications
import Contacts
import PhotosUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var showsStats = true
    @AppStorage("appearance") private var appearance: String = "System"
    @State private var showUnlinkFacebookAlert = false
    
    private var overlayColor: Color {
        switch colorScheme {
        case .dark:
            // Now use a slightly darker overlay for dark mode
            return Color.black.opacity(0.4)
        default:
            // Use a slightly lighter overlay for light mode
            return Color.white.opacity(0.4)
        }
    }
    
    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color.white)
                    .ignoresSafeArea()
                Color("beige")
                    .opacity(0.5) // Overlay with partial opacity
                    .ignoresSafeArea()
            
            NavigationStack {
                List {
                    // Personal Info
                    Section(header: Text("Personal Info")) {
                        NavigationLink(destination: ChangePhoneView()) {
                            SettingsRow(icon: "phone.fill",
                                        title: "Change Phone Number",
                                        subtitle: "Requires verification",
                                        showChevron: false)
                        }
                        
                        Button(action: {
                            if userManager.isFacebookLinked {
                                showUnlinkFacebookAlert = true
                            } else {
                                Task {
                                    try await userManager.toggleFacebookLink()
                                }
                            }
                        }) {
                            SettingsRow(icon: "link",
                                        title: userManager.isFacebookLinked ? "Unlink Facebook" : "Link Facebook",
                                        subtitle: "Connect with Facebook friends",
                                        showChevron: false)
                        }
                    }
                    .listRowBackground(Color("altBeige").opacity(0.9))
                    .foregroundColor(Color("pine"))
                    
                    // Privacy & Notifications (as submenus)
                    Section(header: Text("Privacy & Notifications")) {
                        NavigationLink(destination: PrivacySettingsView()) {
                            SettingsRow(icon: "hand.raised.fill",
                                        title: "Privacy",
                                        subtitle: "Trail Location sharing, visibility settings",
                                        showChevron: false)
                        }
                        
                        NavigationLink(destination: NotificationSettingsView()) {
                            SettingsRow(icon: "bell.fill",
                                        title: "Notifications",
                                        subtitle: "Event and message alerts",
                                        showChevron: false)
                        }
                    }
                    .listRowBackground(Color("altBeige").opacity(0.9))
                    .foregroundColor(Color("pine"))
                    
                    // App Permissions
                    Section {
                        Button(action: { openAppSettings() }) {
                            SettingsRow(icon: "gear",
                                        title: "App Permissions",
                                        subtitle: "Location, contacts, notifications",
                                        showChevron: false)
                        }
                    }
                    .listRowBackground(Color("altBeige").opacity(0.9))
                    .foregroundColor(Color("pine"))
                    
                    // Appearance
                    Section {
                        Picker("Appearance", selection: $appearance) {
                            Text("System").tag("System")
                            Text("Light").tag("Light")
                            Text("Dark").tag("Dark")
                        }
                        .onChange(of: appearance) { oldValue, newValue in
                            updateAppearance(newValue)
                            print("Appearance setting: \(appearance)")
                        }
                    }
                    .listRowBackground(Color("altBeige").opacity(0.9))
                    .foregroundColor(Color("pine"))
                    
                    // Resources
                    Section(header: Text("Resources")) {
                        NavigationLink(destination: HelpCenterView()) {
                            SettingsRow(icon: "questionmark.circle.fill",
                                        title: "Help Center",
                                        subtitle: "FAQs and support",
                                        showChevron: false)
                        }
                        
                        NavigationLink(destination: AboutView()) {
                            SettingsRow(icon: "info.circle.fill",
                                        title: "About",
                                        subtitle: "Version info",
                                        showChevron: false)
                        }
                        
                        Button(action: {
                            if let url = URL(string: "itms-apps://itunes.apple.com/app/id123456789") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            SettingsRow(icon: "star.fill",
                                        title: "Rate TrailMates",
                                        subtitle: "Share your feedback",
                                        showChevron: false)
                        }
                    }
                    .listRowBackground(Color("altBeige").opacity(0.9))
                    .foregroundColor(Color("pine"))
                    
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
                                    .foregroundColor(Color("pine"))
                                Spacer()
                            }
                        }
                    }
                    .listRowBackground(Color("altBeige").opacity(0.9))
                    .foregroundColor(Color("pine"))
                }

                .listStyle(InsetGroupedListStyle())
                .background(Color("beige"))
                .scrollContentBackground(.hidden)
                .toolbar {
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
                .navigationBarTitleDisplayMode(.inline)
            }
            .tint(Color("pine"))
            .toolbarBackground(Color("altBeige"), for: .navigationBar)
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
    var showChevron: Bool = false
    
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
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
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
                .tint(Color("sage"))
        }
    }
}

struct PrivacySettingsView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var pendingUpdates: Set<String> = []
    @State private var localShareWithFriends = false
    @State private var localShareWithHost = false
    @State private var localShareWithGroup = false
    @State private var localAllowFriendsInvite = false
    @Environment(\.colorScheme) var colorScheme

    private var baseBackground: Color {
            Color("beige")
        }
        
    private var overlayColor: Color {
        switch colorScheme {
        case .dark:
            // Now use a slightly darker overlay for dark mode
            return Color.black.opacity(0.4)
        default:
            // Use a slightly lighter overlay for light mode
            return Color.white.opacity(0.4)
        }
    }
        

    var body: some View {
        ZStack {
            baseBackground.ignoresSafeArea()
            
            List {
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
            .scrollContentBackground(.hidden)
            .background(overlayColor)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Privacy")
                        .foregroundColor(Color("pine"))
                        .font(.headline)
                    }
                }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let user = userManager.currentUser {
                    localShareWithFriends = user.shareLocationWithFriends
                    localShareWithHost = user.shareLocationWithEventHost
                    localShareWithGroup = user.shareLocationWithEventGroup
                    localAllowFriendsInvite = user.allowFriendsToInviteOthers
                }
            }
        }
    }

    private func updateSetting<T>(key: String, oldValue: T, newValue: T, action: @escaping () async throws -> Void) {
        guard !pendingUpdates.contains(key) else { return }
        pendingUpdates.insert(key)
        Task {
            do {
                try await action()
            } catch {
                if pendingUpdates.contains(key) {
                    if let boolVal = oldValue as? Bool, var binding = self.binding(forKey: key) {
                        binding.wrappedValue = boolVal
                    }
                }
            }
            pendingUpdates.remove(key)
        }
    }

    private func binding(forKey key: String) -> Binding<Bool>? {
        switch key {
        case "shareWithFriends": return $localShareWithFriends
        case "shareWithHost": return $localShareWithHost
        case "shareWithGroup": return $localShareWithGroup
        case "allowFriendsInvite": return $localAllowFriendsInvite
        default: return nil
        }
    }
}

struct NotificationSettingsView: View {
    @EnvironmentObject var userManager: UserManager
    @Environment(\.colorScheme) var colorScheme
    
    private var overlayColor: Color {
        switch colorScheme {
        case .dark:
            return Color.black.opacity(0.4)
        default:
            return Color.white.opacity(0.4)
            }
        }

    var body: some View {
        ZStack {
            Color("beige").ignoresSafeArea()

            List {
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
            .scrollContentBackground(.hidden)
            .background(overlayColor)
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
        }
    }
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
                .environmentObject(UserManager.shared)
                .environmentObject(AuthViewModel())
        }
    }
}

// Add these new views after the existing view definitions
struct HelpCenterView: View {
    @Environment(\.colorScheme) var colorScheme
    
    private var overlayColor: Color {
        switch colorScheme {
        case .dark:
            return Color.black.opacity(0.4)
        default:
            return Color.white.opacity(0.4)
            }
        }
    
    struct FAQItem {
        let question: String
        let answer: String
    }

    let faqItems: [FAQItem] = [
        FAQItem(
            question: "How do I create an event?",
            answer: """
            To create an event:
            1. Go to the Events tab
            2. Tap the + button in the top right
            3. Fill in the event details
            4. Choose a location on the map
            5. Tap Create to publish your event
            """
        ),
        FAQItem(
            question: "How does location sharing work?",
            answer: """
            Location sharing is privacy-focused and customizable:
            • You control who sees your location
            • Share with friends only
            • Share with event hosts
            • Share with event groups
            
            Adjust these settings in Privacy Settings.
            """
        ),
        FAQItem(
            question: "How do I add friends?",
            answer: """
            Add friends in several ways:
            1. Search by username or phone number
            2. Connect through Facebook
            3. Send friend requests
            4. Accept incoming requests
            
            Manage your friends in the Friends tab.
            """
        )
    ]
    
    var body: some View {
        ZStack {
            Color("beige").ignoresSafeArea()

            List {
                Section(header: Text("Frequently Asked Questions").foregroundColor(Color("pine"))) {
                    ForEach(faqItems, id: \.question) { item in
                        NavigationLink(item.question) {
                            FAQDetailView(question: item.question, answer: item.answer)
                        }
                    }
                }
                .listRowBackground(Color("beige").opacity(0.9))
                .foregroundColor(Color("pine"))
                
                Section(header: Text("Contact Support")
                    .foregroundColor(Color("pine"))
                )
                {
                    Link(destination: URL(string: "mailto:support@trailmates.app")!) {
                        HStack {
                            Text("Email Support")
                            Spacer()
                            Image(systemName: "envelope.fill")
                        }
                        
                    }
                    
                    Link(destination: URL(string: "https://trailmates.app/support")!) {
                        HStack {
                            Text("Visit Support Center")
                            Spacer()
                            Image(systemName: "safari.fill")
                        }
                    }
                }
                .listRowBackground(Color("beige").opacity(0.9))
                .foregroundColor(Color("pine"))
                
                Section(header: Text("Feedback").foregroundColor(Color("pine"))) {
                    Button(action: {
                        // Implement feedback form
                    }) {
                        HStack {
                            Text("Submit Feedback")
                            Spacer()
                            Image(systemName: "square.and.pencil")
                        }
                    }
                }
                .listRowBackground(Color("beige").opacity(0.9))
                .foregroundColor(Color("pine"))
            }
            .scrollContentBackground(.hidden)
            .background(overlayColor)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Help Center")
                        .foregroundColor(Color("pine"))
                        .font(.headline)
                    }
                }
            .navigationBarTitleDisplayMode(.inline)
            .foregroundColor(Color("pine"))
        }
    }
}

struct FAQDetailView: View {
    let question: String
    let answer: String

    var body: some View {
        ZStack {
            Color("beige").ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(question)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color("pine"))
                        .padding(.bottom, 8)
                    
                    Text(answer)
                        .foregroundColor(Color("pine").opacity(0.8))
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(question)
                        .foregroundColor(Color("beige"))
                        .font(.headline)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct AboutView: View {
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    @Environment(\.colorScheme) var colorScheme
    
    private var overlayColor: Color {
        switch colorScheme {
        case .dark:
            return Color.black.opacity(0.4)
        default:
            return Color.white.opacity(0.4)
            }
        }

    var appIcon: some View {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first,
           let icon = window.windowScene?.activationState == .foregroundActive ? UIImage(named: "AppIcon60x60") : nil {
            return AnyView(
                Image(uiImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .cornerRadius(22)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color("pine").opacity(0.1), lineWidth: 1)
                    )
            )
        } else {
            return AnyView(
                Image(systemName: "app.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .foregroundColor(Color("pine"))
            )
        }
    }

    var body: some View {
        ZStack {
            Color("beige").ignoresSafeArea()
            List {
                Section {
                    VStack(spacing: 8) {
                        appIcon

                        Text("TrailMates")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(Color("pine"))

                        Text("Version \(appVersion) (\(buildNumber))")
                            .foregroundColor(Color("pine").opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section(header: Text("App Info")
                    .foregroundColor(Color("pine"))
                )
                {
                    infoRow("Version", value: appVersion)
                    infoRow("Build", value: buildNumber)
                }
                .listRowBackground(Color("beige").opacity(0.9))
                .foregroundColor(Color("pine"))

                Section(header: Text("Legal").foregroundColor(Color("pine"))) {
                    NavigationLink("Terms of Service") {
                        WebViewContainer(url: URL(string: "https://trailmates.app/terms")!)
                    }

                    NavigationLink("Privacy Policy") {
                        WebViewContainer(url: URL(string: "https://trailmates.app/privacy")!)
                    }

                    NavigationLink("Acknowledgments") {
                        AcknowledgmentsView()
                    }
                }
                .listRowBackground(Color("beige").opacity(0.9))
                .foregroundColor(Color("pine"))

                Section(header: Text("Follow Us").foregroundColor(Color("pine"))) {
                    Link(destination: URL(string: "https://twitter.com/trailmates")!) {
                        HStack {
                            Text("Twitter")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                    }

                    Link(destination: URL(string: "https://instagram.com/trailmates")!) {
                        HStack {
                            Text("Instagram")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                }
                .listRowBackground(Color("beige").opacity(0.9))
                .foregroundColor(Color("pine"))
            }
            .scrollContentBackground(.hidden)
            .background(overlayColor)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("About")
                        .foregroundColor(Color("pine"))
                        .font(.headline)
                    }
                }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func infoRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title).foregroundColor(Color("pine"))
            Spacer()
            Text(value).foregroundColor(.gray)
        }
    }
}

struct WebViewContainer: View {
    let url: URL

    var body: some View {
        ZStack {
            Color("beige").ignoresSafeArea()
            WebView(url: url)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AcknowledgmentsView: View {
    @Environment(\.colorScheme) var colorScheme
    
    private var overlayColor: Color {
        switch colorScheme {
        case .dark:
            return Color.black.opacity(0.4)
        default:
            return Color.white.opacity(0.4)
            }
        }
    
    var body: some View {
        ZStack {
            Color("beige").ignoresSafeArea()

            List {
                Section(header: Text("Open Source Libraries").foregroundColor(Color("pine"))) {
                    acknowledgmentRow(title: "Firebase", description: "Mobile and web application development platform")
                    acknowledgmentRow(title: "SwiftUI", description: "User interface framework by Apple")
                }
                .listRowBackground(Color("beige").opacity(0.9))
                .foregroundColor(Color("pine"))

                Section(header: Text("Assets").foregroundColor(Color("pine"))) {
                    acknowledgmentRow(title: "SF Symbols", description: "Icons by Apple Inc.")
                }
                .listRowBackground(Color("beige").opacity(0.9))
                .foregroundColor(Color("pine"))
            }
            .scrollContentBackground(.hidden)
            .background(overlayColor)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Acknowledgements")
                        .foregroundColor(Color("pine"))
                        .font(.headline)
                    }
                }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func acknowledgmentRow(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(Color("pine"))
            Text(description)
                .font(.caption)
                .foregroundColor(Color("pine").opacity(0.7))
        }
    }
}

// Add extension to get app icon name
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
