//
//  EmptyStateView.swift
//  TrailMates
//
//  Standard empty state component for displaying when content is unavailable.
//
//  Usage:
//  ```swift
//  EmptyStateView(
//      title: "No Events",
//      message: "You haven't joined any events yet",
//      systemImage: "calendar.badge.plus"
//  )
//  EmptyStateView(
//      title: "No Friends",
//      message: "Add friends to see them on the trail",
//      systemImage: "person.2",
//      actionTitle: "Add Friends",
//      action: { showAddFriends = true }
//  )
//  ```

import SwiftUI

/// A reusable empty state component with icon, message, and optional action
struct EmptyStateView: View {
    /// Title text
    let title: String
    /// Descriptive message
    let message: String
    /// SF Symbol name for the icon
    var systemImage: String = "tray"
    /// Optional action button title
    var actionTitle: String?
    /// Optional action to perform
    var action: (() -> Void)?
    /// Style of the empty state
    var style: Style = .default

    enum Style {
        case `default`
        case compact
        case card
    }

    init(
        title: String,
        message: String,
        systemImage: String = "tray",
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        style: Style = .default
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.action = action
        self.style = style
    }

    var body: some View {
        switch style {
        case .default:
            defaultView
        case .compact:
            compactView
        case .card:
            cardView
        }
    }

    // MARK: - Default View
    private var defaultView: some View {
        VStack(spacing: 20) {
            Image(systemName: systemImage)
                .font(.system(size: 56))
                .foregroundColor(Color("pine").opacity(0.4))

            VStack(spacing: 8) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(Color("pine"))

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(Color("pine").opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color("alwaysBeige"))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color("pumpkin"))
                        .cornerRadius(12)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Compact View
    private var compactView: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 36))
                .foregroundColor(Color("pine").opacity(0.4))

            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color("pine"))

                Text(message)
                    .font(.caption)
                    .foregroundColor(Color("pine").opacity(0.6))
                    .multilineTextAlignment(.center)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Color("pumpkin"))
                }
            }
        }
        .padding()
    }

    // MARK: - Card View
    private var cardView: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundColor(Color("pine").opacity(0.5))

            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(Color("pine"))

                Text(message)
                    .font(.caption)
                    .foregroundColor(Color("pine").opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Color("alwaysBeige"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color("pumpkin"))
                        .cornerRadius(8)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("beige").opacity(0.5))
                .shadow(color: Color.black.opacity(0.05), radius: 8)
        )
    }
}

// MARK: - Previews
#Preview("Default Empty State") {
    EmptyStateView(
        title: "No Events",
        message: "You haven't joined any events yet. Browse events to get started!"
    )
}

#Preview("With Action") {
    EmptyStateView(
        title: "No Friends Yet",
        message: "Add friends to see them on the trail and plan activities together.",
        systemImage: "person.2.fill",
        actionTitle: "Add Friends",
        action: {}
    )
}

#Preview("Compact Style") {
    EmptyStateView(
        title: "No Results",
        message: "Try adjusting your search",
        systemImage: "magnifyingglass",
        style: .compact
    )
    .frame(height: 200)
    .background(Color("beige"))
}

#Preview("Card Style") {
    ScrollView {
        VStack(spacing: 16) {
            Text("Your Events")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            EmptyStateView(
                title: "No Upcoming Events",
                message: "Create or join an event to see it here",
                systemImage: "calendar.badge.plus",
                actionTitle: "Create Event",
                action: {},
                style: .card
            )
        }
        .padding()
    }
    .background(Color("beige"))
}

#Preview("Search Empty State") {
    EmptyStateView(
        title: "No Trails Found",
        message: "We couldn't find any trails matching your search. Try different keywords.",
        systemImage: "map",
        actionTitle: "Clear Search",
        action: {}
    )
}
