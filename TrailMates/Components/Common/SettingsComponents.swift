import SwiftUI

// MARK: - SettingsRow
struct SettingsRow: View {
    // MARK: - Dependencies
    let icon: String
    let title: String
    let subtitle: String
    var showChevron: Bool = false

    // MARK: - Body
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

// MARK: - PreferenceToggleRow
struct PreferenceToggleRow: View {
    // MARK: - Dependencies
    let title: String
    let subtitle: String
    @Binding var isEnabled: Bool

    // MARK: - Body
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
