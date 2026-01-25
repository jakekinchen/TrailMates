//
//  PermissionCard.swift
//  TrailMates
//
//  A card component displaying permission status with icon and description.
//
//  Usage:
//  ```swift
//  PermissionCard(
//      title: "Location Access",
//      description: "Required to show your position on the map",
//      iconName: "location.fill",
//      status: .granted
//  )
//  ```

import SwiftUI

/// A card component for displaying permission request information and status
struct PermissionCard: View {
    /// Title of the permission
    let title: String
    /// Description explaining why the permission is needed
    let description: String
    /// SF Symbol name for the icon
    let iconName: String
    /// Current status of the permission
    let status: PermissionStatus

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(Color("pumpkin"))
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(Color("alwaysPine"))

                    Spacer()

                    statusIcon
                }

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(Color("alwaysSage"))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 2)
    }

    private var statusIcon: some View {
        switch status {
        case .granted:
            return Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .denied:
            return Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
        case .partial:
            return Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(Color("pumpkin"))
        case .notRequested:
            return Image(systemName: "circle")
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Previews
#Preview("Granted") {
    PermissionCard(
        title: "Location Access",
        description: "Required to show your position on the map and find nearby trails.",
        iconName: "location.fill",
        status: .granted
    )
    .padding()
}

#Preview("Not Requested") {
    PermissionCard(
        title: "Notifications",
        description: "Get notified when friends are active or events are starting.",
        iconName: "bell.fill",
        status: .notRequested
    )
    .padding()
}

#Preview("Denied") {
    PermissionCard(
        title: "Contacts",
        description: "Find friends who are already using TrailMates.",
        iconName: "person.crop.circle",
        status: .denied
    )
    .padding()
}

#Preview("Partial") {
    PermissionCard(
        title: "Location Access",
        description: "Enable 'Always' access for background location updates.",
        iconName: "location.fill",
        status: .partial
    )
    .padding()
}
