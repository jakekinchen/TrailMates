//
//  ListRowView.swift
//  TrailMates
//
//  A reusable list row component with consistent styling.
//
//  Usage:
//  ```swift
//  ListRowView(
//      title: "John Doe",
//      subtitle: "@johndoe"
//  )
//  ListRowView(
//      title: "Morning Hike",
//      subtitle: "Tomorrow at 8:00 AM",
//      leadingIcon: "figure.hiking"
//  )
//  ListRowView(
//      title: "Settings",
//      leadingIcon: "gear",
//      showChevron: true
//  ) {
//      openSettings()
//  }
//  ```

import SwiftUI

/// A styled list row component with flexible content options
struct ListRowView<LeadingContent: View, TrailingContent: View>: View {
    /// Primary title text
    let title: String
    /// Optional subtitle text
    var subtitle: String?
    /// Optional leading SF Symbol icon
    var leadingIcon: String?
    /// Whether to show a trailing chevron
    var showChevron: Bool = false
    /// Background style
    var style: Style = .default
    /// Custom leading content
    var leadingContent: (() -> LeadingContent)?
    /// Custom trailing content
    var trailingContent: (() -> TrailingContent)?
    /// Optional tap action
    var action: (() -> Void)?

    enum Style {
        case `default`
        case card
        case plain

        var backgroundColor: Color {
            switch self {
            case .default: return Color("sage").opacity(0.1)
            case .card: return Color.white.opacity(0.8)
            case .plain: return Color.clear
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .default, .card: return 12
            case .plain: return 0
            }
        }

        var padding: CGFloat {
            switch self {
            case .default, .card: return 12
            case .plain: return 8
            }
        }
    }

    init(
        title: String,
        subtitle: String? = nil,
        leadingIcon: String? = nil,
        showChevron: Bool = false,
        style: Style = .default,
        action: (() -> Void)? = nil
    ) where LeadingContent == EmptyView, TrailingContent == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.leadingIcon = leadingIcon
        self.showChevron = showChevron
        self.style = style
        self.leadingContent = nil
        self.trailingContent = nil
        self.action = action
    }

    init(
        title: String,
        subtitle: String? = nil,
        showChevron: Bool = false,
        style: Style = .default,
        action: (() -> Void)? = nil,
        @ViewBuilder leading: @escaping () -> LeadingContent
    ) where TrailingContent == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.leadingIcon = nil
        self.showChevron = showChevron
        self.style = style
        self.leadingContent = leading
        self.trailingContent = nil
        self.action = action
    }

    init(
        title: String,
        subtitle: String? = nil,
        leadingIcon: String? = nil,
        style: Style = .default,
        action: (() -> Void)? = nil,
        @ViewBuilder trailing: @escaping () -> TrailingContent
    ) where LeadingContent == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.leadingIcon = leadingIcon
        self.showChevron = false
        self.style = style
        self.leadingContent = nil
        self.trailingContent = trailing
        self.action = action
    }

    init(
        title: String,
        subtitle: String? = nil,
        showChevron: Bool = false,
        style: Style = .default,
        action: (() -> Void)? = nil,
        @ViewBuilder leading: @escaping () -> LeadingContent,
        @ViewBuilder trailing: @escaping () -> TrailingContent
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leadingIcon = nil
        self.showChevron = showChevron
        self.style = style
        self.leadingContent = leading
        self.trailingContent = trailing
        self.action = action
    }

    var body: some View {
        Group {
            if let action = action {
                Button(action: action) {
                    rowContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            // Leading content
            if let leadingContent = leadingContent {
                leadingContent()
            } else if let icon = leadingIcon {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(Color("pine"))
                    .frame(width: 32)
            }

            // Text content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(Color("pine"))

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Color("pine").opacity(0.7))
                }
            }

            Spacer()

            // Trailing content
            if let trailingContent = trailingContent {
                trailingContent()
            }

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color("pine").opacity(0.4))
            }
        }
        .padding(.horizontal, style.padding)
        .padding(.vertical, style.padding)
        .background(style.backgroundColor)
        .cornerRadius(style.cornerRadius)
    }
}

// MARK: - Swipe Action Modifier
struct SwipeActionsModifier: ViewModifier {
    let leadingActions: [SwipeAction]
    let trailingActions: [SwipeAction]

    struct SwipeAction: Identifiable {
        let id = UUID()
        let title: String
        let icon: String?
        let tint: Color
        let action: () -> Void

        init(
            _ title: String,
            icon: String? = nil,
            tint: Color = .blue,
            action: @escaping () -> Void
        ) {
            self.title = title
            self.icon = icon
            self.tint = tint
            self.action = action
        }
    }

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                ForEach(leadingActions) { action in
                    Button(action: action.action) {
                        if let icon = action.icon {
                            Label(action.title, systemImage: icon)
                        } else {
                            Text(action.title)
                        }
                    }
                    .tint(action.tint)
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                ForEach(trailingActions) { action in
                    Button(action: action.action) {
                        if let icon = action.icon {
                            Label(action.title, systemImage: icon)
                        } else {
                            Text(action.title)
                        }
                    }
                    .tint(action.tint)
                }
            }
    }
}

extension View {
    /// Adds standardized swipe actions to a list row
    func listSwipeActions(
        leading: [SwipeActionsModifier.SwipeAction] = [],
        trailing: [SwipeActionsModifier.SwipeAction] = []
    ) -> some View {
        modifier(SwipeActionsModifier(leadingActions: leading, trailingActions: trailing))
    }
}

// MARK: - Previews
#Preview("Basic Row") {
    VStack(spacing: 8) {
        ListRowView(title: "John Doe", subtitle: "@johndoe")
        ListRowView(title: "Jane Smith", subtitle: "@janesmith")
    }
    .padding()
    .background(Color("beige"))
}

#Preview("With Icons") {
    VStack(spacing: 8) {
        ListRowView(title: "Settings", leadingIcon: "gear", showChevron: true)
        ListRowView(title: "Notifications", leadingIcon: "bell", showChevron: true)
        ListRowView(title: "Privacy", leadingIcon: "lock", showChevron: true)
    }
    .padding()
    .background(Color("beige"))
}

#Preview("Card Style") {
    VStack(spacing: 8) {
        ListRowView(
            title: "Morning Hike",
            subtitle: "Tomorrow at 8:00 AM",
            leadingIcon: "figure.hiking",
            style: .card
        )
        ListRowView(
            title: "Trail Run",
            subtitle: "Saturday at 6:30 AM",
            leadingIcon: "figure.run",
            style: .card
        )
    }
    .padding()
    .background(Color("beige"))
}

#Preview("With Custom Leading") {
    VStack(spacing: 8) {
        ListRowView(
            title: "John Doe",
            subtitle: "Active now",
            showChevron: true
        ) {
            Circle()
                .fill(Color.green)
                .frame(width: 40, height: 40)
                .overlay(
                    Text("JD")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
        }
    }
    .padding()
    .background(Color("beige"))
}

#Preview("With Custom Trailing") {
    VStack(spacing: 8) {
        ListRowView(
            title: "Notifications",
            leadingIcon: "bell",
            trailing: {
                Toggle("", isOn: .constant(true))
                    .labelsHidden()
            }
        )

        ListRowView(
            title: "Friend Request",
            subtitle: "John wants to be friends",
            trailing: {
                HStack(spacing: 8) {
                    Button("Accept") {}
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color("pumpkin"))
                        .cornerRadius(8)

                    Button("Decline") {}
                        .font(.caption)
                        .foregroundColor(Color("pine"))
                }
            }
        )
    }
    .padding()
    .background(Color("beige"))
}

#Preview("Plain Style") {
    VStack(spacing: 0) {
        ListRowView(title: "Account", leadingIcon: "person", showChevron: true, style: .plain)
        Divider()
        ListRowView(title: "Security", leadingIcon: "lock", showChevron: true, style: .plain)
        Divider()
        ListRowView(title: "Help", leadingIcon: "questionmark.circle", showChevron: true, style: .plain)
    }
    .padding()
    .background(Color("beige"))
}
