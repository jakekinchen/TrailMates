import SwiftUI

// MARK: - Notification Model
struct TrailNotification: Identifiable {
    let id = UUID()
    let type: NotificationType
    let title: String
    let message: String
    let timestamp: Date
    let isRead: Bool
    let relatedUserId: UUID?
    let relatedEventId: UUID?
    
    enum NotificationType {
        case friendRequest
        case eventInvite
        case eventUpdate
        case friendJoined
        case general
    }
}

// MARK: - Notifications View
struct NotificationsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var notifications: [TrailNotification] = []  // Replace with real data source
    @State private var showUnreadOnly = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Toggle
                Toggle("Show Unread Only", isOn: $showUnreadOnly)
                    .padding()
                    .foregroundColor(Color("pine"))
                    .tint(Color("pine"))
                
                Divider()
                
                if notifications.isEmpty {
                    EmptyNotificationsView()
                } else {
                    NotificationsList(notifications: filterNotifications())
                }
            }
            .background(Color("beige"))
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color("pine"))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear All") {
                        // Add clear functionality
                    }
                    .foregroundColor(Color("pine"))
                }
            }
        }
    }
    
    private func filterNotifications() -> [TrailNotification] {
        showUnreadOnly ? notifications.filter { !$0.isRead } : notifications
    }
}

// MARK: - Empty State View
private struct EmptyNotificationsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 50))
                .foregroundColor(Color("pine"))
            
            Text("No Notifications")
                .font(.headline)
                .foregroundColor(Color("pine"))
            
            Text("You're all caught up!")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("beige"))
    }
}

// MARK: - Notifications List
private struct NotificationsList: View {
    let notifications: [TrailNotification]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
                ForEach(groupNotificationsByDate()) { section in
                    Section {
                        ForEach(section.notifications) { notification in
                            NotificationCell(notification: notification)
                        }
                    } header: {
                        NotificationDateHeader(date: section.date)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private struct NotificationSection: Identifiable {
        let id = UUID()
        let date: Date
        let notifications: [TrailNotification]
    }
    
    private func groupNotificationsByDate() -> [NotificationSection] {
        let grouped = Dictionary(grouping: notifications) { notification in
            Calendar.current.startOfDay(for: notification.timestamp)
        }
        
        return grouped.map { date, notifications in
            NotificationSection(date: date, notifications: notifications)
        }.sorted { $0.date > $1.date }
    }
}

// MARK: - Notification Cell
private struct NotificationCell: View {
    let notification: TrailNotification
    
    var body: some View {
        HStack(spacing: 12) {
            NotificationIcon(type: notification.type)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.headline)
                    .foregroundColor(Color("pine"))
                
                Text(notification.message)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Text(timeAgo(from: notification.timestamp))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if !notification.isRead {
                Circle()
                    .fill(Color("pumpkin"))
                    .frame(width: 8, height: 8)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4)
    }
    
    private func timeAgo(from date: Date) -> String {
        // Implement time ago logic (e.g., "2h ago", "1d ago")
        "2h ago" // Placeholder
    }
}

// MARK: - Supporting Views
private struct NotificationIcon: View {
    let type: TrailNotification.NotificationType
    
    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 24))
            .foregroundColor(Color("pine"))
            .frame(width: 40, height: 40)
            .background(Color("pine").opacity(0.1))
            .cornerRadius(12)
    }
    
    private var iconName: String {
        switch type {
        case .friendRequest: return "person.badge.plus"
        case .eventInvite: return "calendar.badge.plus"
        case .eventUpdate: return "bell.badge"
        case .friendJoined: return "person.2"
        case .general: return "bell"
        }
    }
}

private struct NotificationDateHeader: View {
    let date: Date
    
    var body: some View {
        HStack {
            Text(formattedDate)
                .font(.headline)
                .foregroundColor(Color("pine"))
                .padding(.horizontal)
                .padding(.vertical, 8)
            Spacer()
        }
        .background(Color("beige").opacity(0.95))
    }
    
    private var formattedDate: String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, yyyy"
            return formatter.string(from: date)
        }
    }
}