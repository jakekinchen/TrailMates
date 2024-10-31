import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var friendNotifications: Bool = true
    @State private var friendRequests: Bool = true

    var body: some View {
        Form {
            Section(header: Text("Notifications").foregroundColor(Color("pine"))) {
                Toggle(isOn: $friendNotifications) {
                    Text("Friends on Trail")
                        .foregroundColor(Color("pine"))
                }
                Toggle(isOn: $friendRequests) {
                    Text("Friend Requests")
                        .foregroundColor(Color("pine"))
                }
            }
        }
        .navigationBarTitle("Notifications", displayMode: .inline)
        .onAppear {
            // Load user's notification settings
            // For now, we use default values
            // You can extend UserManager to store and retrieve these settings
        }
        .onDisappear {
            // Save user's notification settings
            // You can extend UserManager to save these settings
        }
    }
}

struct NotificationsView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationsView()
            .environmentObject(UserManager())
    }
}