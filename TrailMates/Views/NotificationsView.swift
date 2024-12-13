import SwiftUI
import FirebaseAuth

struct NotificationsView: View {
    @EnvironmentObject var userManager: UserManager
    @StateObject private var viewModel = NotificationsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.notifications) { notification in
                    NotificationRow(notification: notification)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task {
                                    await viewModel.deleteNotification(notification)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .navigationTitle("Notifications")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear All") {
                        Task {
                            await viewModel.clearAllNotifications()
                        }
                    }
                    .disabled(viewModel.notifications.isEmpty)
                }
            }
            .refreshable {
                await viewModel.fetchNotifications()
            }
        }
        .task {
            await viewModel.fetchNotifications()
        }
    }
}

struct NotificationRow: View {
    let notification: TrailNotification
    @StateObject private var viewModel = NotificationRowViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                NotificationIcon(type: notification.type)
                
                Text(notification.title)
                    .font(.headline)
                
                Spacer()
                
                if !notification.isRead {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                }
            }
            
            Text(notification.message)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(notification.timestamp.formatted())
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            Task {
                await viewModel.handleNotificationTap(notification)
            }
        }
    }
}

struct NotificationIcon: View {
    let type: NotificationType
    
    var body: some View {
        Image(systemName: iconName)
            .foregroundColor(iconColor)
            .frame(width: 32, height: 32)
    }
    
    private var iconName: String {
        switch type {
        case .friendRequest:
            return "person.badge.plus"
        case .friendAccepted:
            return "person.2.fill"
        case .eventInvite:
            return "calendar.badge.plus"
        case .eventUpdate:
            return "calendar.badge.exclamationmark"
        case .general:
            return "bell.fill"
        }
    }
    
    private var iconColor: Color {
        switch type {
        case .friendRequest:
            return .blue
        case .friendAccepted:
            return .green
        case .eventInvite:
            return .purple
        case .eventUpdate:
            return .orange
        case .general:
            return .gray
        }
    }
}

@MainActor
class NotificationsViewModel: ObservableObject {
    @Published private(set) var notifications: [TrailNotification] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    private let dataProvider = FirebaseDataProvider.shared
    private let userManager = UserManager.shared
    
    init() { }
    
    func fetchNotifications() async {
        isLoading = true
        error = nil
        
        do {
            guard let firebaseUser = Auth.auth().currentUser,
                  let currentUser = userManager.currentUser else { return }
            
            notifications = try await dataProvider.fetchNotifications(forid: firebaseUser.uid, userID: currentUser.id)
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func deleteNotification(_ notification: TrailNotification) async {
        do {
            guard let firebaseUser = Auth.auth().currentUser else { return }
            try await dataProvider.deleteNotification(
                id: firebaseUser.uid,
                notificationId: notification.id
            )
            if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                notifications.remove(at: index)
            }
        } catch {
            self.error = error
        }
    }
    
    func clearAllNotifications() async {
        for notification in notifications {
            await deleteNotification(notification)
        }
    }
}

@MainActor
class NotificationRowViewModel: ObservableObject {
    
    private let dataProvider = FirebaseDataProvider.shared
    

    
    func handleNotificationTap(_ notification: TrailNotification) async {
        if !notification.isRead {
            do {
                guard let firebaseUser = Auth.auth().currentUser else { return }
                try await dataProvider.markNotificationAsRead(
                    id: firebaseUser.uid,
                    notificationId: notification.id
                )
            } catch {
                print("Error marking notification as read: \(error)")
            }
        }
        
        // Handle different notification types
        switch notification.type {
        case .friendRequest:
            // Navigate to friend request handling view
            break
        case .friendAccepted:
            // Navigate to friend's profile
            break
        case .eventInvite:
            // Navigate to event details
            break
        case .eventUpdate:
            // Navigate to updated event
            break
        case .general:
            // No specific action needed
            break
        }
    }
}
