import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject var userManager: UserManager
    @StateObject private var viewModel = NotificationsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(notification.isRead ? "" : "Unread, ")\(notification.title), \(notification.message)")
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

