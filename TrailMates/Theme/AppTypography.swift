//
//  AppTypography.swift
//  TrailMates
//
//  Typography definitions for consistent text styling across the app.
//
//  Usage:
//  ```swift
//  Text("Welcome")
//      .font(AppTypography.title)
//  Text("Description")
//      .appTextStyle(.bodySecondary)
//  ```

import SwiftUI

/// Typography definitions for the TrailMates design system
enum AppTypography {
    // MARK: - Display Styles
    /// Large display title - Magic Retro font
    static let displayLarge = Font.custom("Magic Retro", size: 48)
    /// Medium display - Magic Retro font
    static let displayMedium = Font.custom("Magic Retro", size: 36)
    /// Small display - Magic Retro font
    static let displaySmall = Font.custom("Magic Retro", size: 24)

    // MARK: - Title Styles
    /// Large title
    static let titleLarge = Font.title.weight(.bold)
    /// Medium title
    static let titleMedium = Font.title2.weight(.semibold)
    /// Small title
    static let titleSmall = Font.title3.weight(.semibold)

    // MARK: - Heading Styles
    /// Primary heading
    static let headingPrimary = Font.headline.weight(.semibold)
    /// Secondary heading
    static let headingSecondary = Font.subheadline.weight(.semibold)

    // MARK: - Body Styles
    /// Primary body text
    static let bodyPrimary = Font.body
    /// Secondary body text
    static let bodySecondary = Font.subheadline
    /// Small body text
    static let bodySmall = Font.footnote

    // MARK: - Label Styles
    /// Primary label
    static let labelPrimary = Font.subheadline.weight(.medium)
    /// Secondary label
    static let labelSecondary = Font.caption.weight(.medium)
    /// Tertiary label
    static let labelTertiary = Font.caption2

    // MARK: - Button Styles
    /// Large button text
    static let buttonLarge = Font.headline.weight(.bold)
    /// Default button text
    static let buttonDefault = Font.body.weight(.semibold)
    /// Small button text
    static let buttonSmall = Font.subheadline.weight(.semibold)

    // MARK: - Input Styles
    /// Input field text
    static let inputText = Font.body
    /// Input placeholder text
    static let inputPlaceholder = Font.body
    /// Input label text
    static let inputLabel = Font.caption
}

// MARK: - Text Style Enum
enum TextStyle {
    case displayLarge
    case displayMedium
    case displaySmall
    case titleLarge
    case titleMedium
    case titleSmall
    case headingPrimary
    case headingSecondary
    case bodyPrimary
    case bodySecondary
    case bodySmall
    case labelPrimary
    case labelSecondary
    case labelTertiary

    var font: Font {
        switch self {
        case .displayLarge: return AppTypography.displayLarge
        case .displayMedium: return AppTypography.displayMedium
        case .displaySmall: return AppTypography.displaySmall
        case .titleLarge: return AppTypography.titleLarge
        case .titleMedium: return AppTypography.titleMedium
        case .titleSmall: return AppTypography.titleSmall
        case .headingPrimary: return AppTypography.headingPrimary
        case .headingSecondary: return AppTypography.headingSecondary
        case .bodyPrimary: return AppTypography.bodyPrimary
        case .bodySecondary: return AppTypography.bodySecondary
        case .bodySmall: return AppTypography.bodySmall
        case .labelPrimary: return AppTypography.labelPrimary
        case .labelSecondary: return AppTypography.labelSecondary
        case .labelTertiary: return AppTypography.labelTertiary
        }
    }

    var color: Color {
        switch self {
        case .displayLarge, .displayMedium, .displaySmall,
             .titleLarge, .titleMedium, .titleSmall,
             .headingPrimary, .headingSecondary,
             .bodyPrimary:
            return AppColors.textPrimary
        case .bodySecondary, .bodySmall,
             .labelPrimary:
            return AppColors.textSecondary
        case .labelSecondary, .labelTertiary:
            return AppColors.textTertiary
        }
    }
}

// MARK: - View Extension
extension View {
    /// Applies a predefined text style to the view
    func appTextStyle(_ style: TextStyle) -> some View {
        self
            .font(style.font)
            .foregroundColor(style.color)
    }
}

// MARK: - Previews
#Preview("Display Styles") {
    VStack(alignment: .leading, spacing: 16) {
        Text("TrailMates")
            .font(AppTypography.displayLarge)
        Text("TrailMates")
            .font(AppTypography.displayMedium)
        Text("TrailMates")
            .font(AppTypography.displaySmall)
    }
    .foregroundColor(AppColors.textPrimary)
    .padding()
    .background(AppColors.backgroundPrimary)
}

#Preview("Title Styles") {
    VStack(alignment: .leading, spacing: 12) {
        Text("Title Large")
            .font(AppTypography.titleLarge)
        Text("Title Medium")
            .font(AppTypography.titleMedium)
        Text("Title Small")
            .font(AppTypography.titleSmall)
    }
    .foregroundColor(AppColors.textPrimary)
    .padding()
    .background(AppColors.backgroundPrimary)
}

#Preview("Body Styles") {
    VStack(alignment: .leading, spacing: 12) {
        Text("Body Primary - This is the main body text style used for content throughout the app.")
            .appTextStyle(.bodyPrimary)
        Text("Body Secondary - This is used for less prominent text.")
            .appTextStyle(.bodySecondary)
        Text("Body Small - Used for fine print and supplementary info.")
            .appTextStyle(.bodySmall)
    }
    .padding()
    .background(AppColors.backgroundPrimary)
}

#Preview("Label Styles") {
    VStack(alignment: .leading, spacing: 12) {
        Text("Label Primary")
            .appTextStyle(.labelPrimary)
        Text("Label Secondary")
            .appTextStyle(.labelSecondary)
        Text("Label Tertiary")
            .appTextStyle(.labelTertiary)
    }
    .padding()
    .background(AppColors.backgroundPrimary)
}

#Preview("Full Typography Scale") {
    ScrollView {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                Text("Display Large").font(AppTypography.displayLarge)
                Text("Display Medium").font(AppTypography.displayMedium)
                Text("Display Small").font(AppTypography.displaySmall)
            }

            Divider().padding(.vertical, 8)

            Group {
                Text("Title Large").font(AppTypography.titleLarge)
                Text("Title Medium").font(AppTypography.titleMedium)
                Text("Title Small").font(AppTypography.titleSmall)
            }

            Divider().padding(.vertical, 8)

            Group {
                Text("Heading Primary").font(AppTypography.headingPrimary)
                Text("Heading Secondary").font(AppTypography.headingSecondary)
            }

            Divider().padding(.vertical, 8)

            Group {
                Text("Body Primary").font(AppTypography.bodyPrimary)
                Text("Body Secondary").font(AppTypography.bodySecondary)
                Text("Body Small").font(AppTypography.bodySmall)
            }

            Divider().padding(.vertical, 8)

            Group {
                Text("Label Primary").font(AppTypography.labelPrimary)
                Text("Label Secondary").font(AppTypography.labelSecondary)
                Text("Label Tertiary").font(AppTypography.labelTertiary)
            }
        }
        .foregroundColor(AppColors.textPrimary)
        .padding()
    }
    .background(AppColors.backgroundPrimary)
}
