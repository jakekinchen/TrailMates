//
//  AppSpacing.swift
//  TrailMates
//
//  Consistent spacing values for the TrailMates design system.
//
//  Usage:
//  ```swift
//  VStack(spacing: AppSpacing.medium) { ... }
//  .padding(AppSpacing.screenHorizontal)
//  .cornerRadius(AppSpacing.cornerRadiusLarge)
//  ```

import SwiftUI

/// Spacing constants for consistent layout across the app
enum AppSpacing {
    // MARK: - Base Spacing Scale
    /// Extra extra small: 2pt
    static let xxs: CGFloat = 2
    /// Extra small: 4pt
    static let xs: CGFloat = 4
    /// Small: 8pt
    static let sm: CGFloat = 8
    /// Medium: 12pt
    static let md: CGFloat = 12
    /// Large: 16pt
    static let lg: CGFloat = 16
    /// Extra large: 20pt
    static let xl: CGFloat = 20
    /// Extra extra large: 24pt
    static let xxl: CGFloat = 24
    /// Extra extra extra large: 32pt
    static let xxxl: CGFloat = 32

    // MARK: - Semantic Spacing
    /// Spacing between related items
    static var itemSpacing: CGFloat { sm }
    /// Spacing between sections
    static var sectionSpacing: CGFloat { xxl }
    /// Spacing between groups of content
    static var groupSpacing: CGFloat { lg }
    /// Spacing for stack children
    static var stackSpacing: CGFloat { md }

    // MARK: - Screen Padding
    /// Horizontal screen padding
    static var screenHorizontal: CGFloat { lg }
    /// Vertical screen padding
    static var screenVertical: CGFloat { lg }
    /// Screen edge insets
    static var screenInsets: EdgeInsets {
        EdgeInsets(top: screenVertical, leading: screenHorizontal, bottom: screenVertical, trailing: screenHorizontal)
    }

    // MARK: - Component Padding
    /// Button horizontal padding
    static var buttonHorizontal: CGFloat { xxl }
    /// Button vertical padding
    static var buttonVertical: CGFloat { lg }
    /// Card padding
    static var cardPadding: CGFloat { lg }
    /// Input field padding
    static var inputPadding: CGFloat { lg }
    /// List row vertical padding
    static var listRowVertical: CGFloat { md }
    /// List row horizontal padding
    static var listRowHorizontal: CGFloat { md }

    // MARK: - Corner Radius
    /// Small corner radius: 8pt
    static let cornerRadiusSmall: CGFloat = 8
    /// Medium corner radius: 12pt
    static let cornerRadiusMedium: CGFloat = 12
    /// Large corner radius: 16pt
    static let cornerRadiusLarge: CGFloat = 16
    /// Extra large corner radius: 20pt
    static let cornerRadiusXL: CGFloat = 20
    /// Full/pill corner radius: 25pt
    static let cornerRadiusFull: CGFloat = 25

    // MARK: - Icon Sizes
    /// Small icon size: 16pt
    static let iconSmall: CGFloat = 16
    /// Medium icon size: 24pt
    static let iconMedium: CGFloat = 24
    /// Large icon size: 32pt
    static let iconLarge: CGFloat = 32
    /// Extra large icon size: 48pt
    static let iconXL: CGFloat = 48

    // MARK: - Avatar Sizes
    /// Small avatar: 32pt
    static let avatarSmall: CGFloat = 32
    /// Medium avatar: 48pt
    static let avatarMedium: CGFloat = 48
    /// Large avatar: 64pt
    static let avatarLarge: CGFloat = 64
    /// Extra large avatar: 96pt
    static let avatarXL: CGFloat = 96
    /// Profile avatar: 120pt
    static let avatarProfile: CGFloat = 120

    // MARK: - Component Heights
    /// Standard button height
    static let buttonHeight: CGFloat = 52
    /// Small button height
    static let buttonHeightSmall: CGFloat = 40
    /// Input field height
    static let inputHeight: CGFloat = 56
    /// Navigation bar height
    static let navigationBarHeight: CGFloat = 60
    /// Tab bar height
    static let tabBarHeight: CGFloat = 83
    /// List row minimum height
    static let listRowMinHeight: CGFloat = 56
}

// MARK: - Spacing View Extension
extension View {
    /// Applies standard screen padding
    func screenPadding() -> some View {
        self.padding(AppSpacing.screenInsets)
    }

    /// Applies horizontal screen padding only
    func screenPaddingHorizontal() -> some View {
        self.padding(.horizontal, AppSpacing.screenHorizontal)
    }

    /// Applies card-style padding and corner radius
    func cardStyle() -> some View {
        self
            .padding(AppSpacing.cardPadding)
            .background(AppColors.backgroundSecondary)
            .cornerRadius(AppSpacing.cornerRadiusMedium)
    }
}

// MARK: - Previews
#Preview("Spacing Scale") {
    VStack(alignment: .leading, spacing: 16) {
        spacingRow("xxs", AppSpacing.xxs)
        spacingRow("xs", AppSpacing.xs)
        spacingRow("sm", AppSpacing.sm)
        spacingRow("md", AppSpacing.md)
        spacingRow("lg", AppSpacing.lg)
        spacingRow("xl", AppSpacing.xl)
        spacingRow("xxl", AppSpacing.xxl)
        spacingRow("xxxl", AppSpacing.xxxl)
    }
    .padding()
    .background(AppColors.backgroundPrimary)
}

#Preview("Corner Radius Scale") {
    VStack(spacing: 16) {
        radiusRow("Small (8)", AppSpacing.cornerRadiusSmall)
        radiusRow("Medium (12)", AppSpacing.cornerRadiusMedium)
        radiusRow("Large (16)", AppSpacing.cornerRadiusLarge)
        radiusRow("XL (20)", AppSpacing.cornerRadiusXL)
        radiusRow("Full (25)", AppSpacing.cornerRadiusFull)
    }
    .padding()
    .background(AppColors.backgroundPrimary)
}

#Preview("Icon Sizes") {
    HStack(spacing: 24) {
        iconSizePreview("S", AppSpacing.iconSmall)
        iconSizePreview("M", AppSpacing.iconMedium)
        iconSizePreview("L", AppSpacing.iconLarge)
        iconSizePreview("XL", AppSpacing.iconXL)
    }
    .padding()
    .background(AppColors.backgroundPrimary)
}

#Preview("Avatar Sizes") {
    HStack(spacing: 16) {
        avatarPreview(AppSpacing.avatarSmall)
        avatarPreview(AppSpacing.avatarMedium)
        avatarPreview(AppSpacing.avatarLarge)
    }
    .padding()
    .background(AppColors.backgroundPrimary)
}

#Preview("Card Style Example") {
    VStack(spacing: AppSpacing.sectionSpacing) {
        VStack(alignment: .leading, spacing: AppSpacing.itemSpacing) {
            Text("Card Title")
                .font(AppTypography.headingPrimary)
            Text("This card uses standard spacing and styling.")
                .font(AppTypography.bodySecondary)
        }
        .cardStyle()

        VStack(alignment: .leading, spacing: AppSpacing.itemSpacing) {
            Text("Another Card")
                .font(AppTypography.headingPrimary)
            Text("Consistent spacing makes the UI feel cohesive.")
                .font(AppTypography.bodySecondary)
        }
        .cardStyle()
    }
    .screenPadding()
    .background(AppColors.backgroundPrimary)
}

private func spacingRow(_ name: String, _ value: CGFloat) -> some View {
    HStack {
        Text(name)
            .font(.caption)
            .frame(width: 40, alignment: .leading)
        Rectangle()
            .fill(AppColors.pumpkin)
            .frame(width: value, height: 20)
        Text("\(Int(value))pt")
            .font(.caption)
            .foregroundColor(AppColors.textSecondary)
    }
}

private func radiusRow(_ name: String, _ radius: CGFloat) -> some View {
    HStack {
        RoundedRectangle(cornerRadius: radius)
            .fill(AppColors.pumpkin)
            .frame(width: 80, height: 40)
        Text(name)
            .font(.caption)
            .foregroundColor(AppColors.textSecondary)
        Spacer()
    }
}

private func iconSizePreview(_ label: String, _ size: CGFloat) -> some View {
    VStack(spacing: 4) {
        Image(systemName: "star.fill")
            .font(.system(size: size))
            .foregroundColor(AppColors.pumpkin)
        Text(label)
            .font(.caption2)
            .foregroundColor(AppColors.textSecondary)
    }
}

private func avatarPreview(_ size: CGFloat) -> some View {
    Circle()
        .fill(AppColors.sage)
        .frame(width: size, height: size)
        .overlay(
            Image(systemName: "person.fill")
                .foregroundColor(AppColors.pine)
                .font(.system(size: size * 0.4))
        )
}
