//
//  AppColors.swift
//  TrailMates
//
//  Semantic color definitions for consistent theming across the app.
//
//  Usage:
//  ```swift
//  Text("Hello")
//      .foregroundColor(AppColors.textPrimary)
//  view.background(AppColors.backgroundPrimary)
//  ```

import SwiftUI

/// Semantic color definitions for the TrailMates design system
enum AppColors {
    // MARK: - Brand Colors
    /// Primary brand color - pine green
    static let pine = Color("pine")
    /// Accent brand color - pumpkin orange
    static let pumpkin = Color("pumpkin")
    /// Light background color - beige
    static let beige = Color("beige")
    /// Muted accent color - sage green
    static let sage = Color("sage")

    // MARK: - Always Colors (Don't change with dark mode)
    /// Pine that stays consistent regardless of color scheme
    static let alwaysPine = Color("alwaysPine")
    /// Beige that stays consistent regardless of color scheme
    static let alwaysBeige = Color("alwaysBeige")
    /// Sage that stays consistent regardless of color scheme
    static let alwaysSage = Color("alwaysSage")

    // MARK: - Semantic Text Colors
    /// Primary text color
    static var textPrimary: Color { pine }
    /// Secondary text color (muted)
    static var textSecondary: Color { pine.opacity(0.7) }
    /// Tertiary text color (subtle)
    static var textTertiary: Color { pine.opacity(0.5) }
    /// Text on colored backgrounds
    static var textOnAccent: Color { alwaysBeige }
    /// Link/interactive text color
    static var textLink: Color { pumpkin }

    // MARK: - Semantic Background Colors
    /// Primary background color
    static var backgroundPrimary: Color { beige }
    /// Secondary background color (cards, elevated surfaces)
    static var backgroundSecondary: Color { beige.opacity(0.5) }
    /// Tertiary background color (input fields)
    static var backgroundTertiary: Color { Color.white.opacity(0.8) }
    /// Accent background color
    static var backgroundAccent: Color { pumpkin }
    /// Subtle/muted background
    static var backgroundMuted: Color { sage.opacity(0.1) }

    // MARK: - Semantic UI Colors
    /// Primary button background
    static var buttonPrimary: Color { pumpkin }
    /// Secondary button background
    static var buttonSecondary: Color { alwaysBeige }
    /// Border color for inputs and cards
    static var border: Color { pine.opacity(0.3) }
    /// Border color when focused
    static var borderFocused: Color { pumpkin }
    /// Divider color
    static var divider: Color { pine.opacity(0.15) }

    // MARK: - Status Colors
    /// Success state color
    static let success = Color.green
    /// Warning state color
    static let warning = Color.orange
    /// Error state color
    static let error = Color.red
    /// Info state color
    static let info = Color.blue

    // MARK: - Activity Status
    /// Active/online status
    static let statusActive = Color.green
    /// Away status
    static let statusAway = Color.orange
    /// Inactive/offline status
    static let statusInactive = Color.gray

    // MARK: - Navigation
    /// Tab bar selected item
    static var tabSelected: Color { pine }
    /// Tab bar unselected item
    static var tabUnselected: Color { pine.opacity(0.4) }
    /// Navigation bar background
    static var navigationBackground: Color { beige.opacity(0.65) }
}

// MARK: - Color Extensions
extension Color {
    /// Creates a color with the given opacity applied
    func opacity(_ opacity: Double) -> Color {
        self.opacity(opacity)
    }
}

// MARK: - Previews
#Preview("Brand Colors") {
    VStack(spacing: 16) {
        colorSwatch("Pine", AppColors.pine)
        colorSwatch("Pumpkin", AppColors.pumpkin)
        colorSwatch("Beige", AppColors.beige)
        colorSwatch("Sage", AppColors.sage)
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}

#Preview("Text Colors") {
    VStack(alignment: .leading, spacing: 12) {
        Text("Primary Text")
            .foregroundColor(AppColors.textPrimary)
        Text("Secondary Text")
            .foregroundColor(AppColors.textSecondary)
        Text("Tertiary Text")
            .foregroundColor(AppColors.textTertiary)
        Text("Link Text")
            .foregroundColor(AppColors.textLink)
    }
    .padding()
    .background(AppColors.backgroundPrimary)
}

#Preview("Background Colors") {
    VStack(spacing: 16) {
        RoundedRectangle(cornerRadius: 8)
            .fill(AppColors.backgroundPrimary)
            .frame(height: 60)
            .overlay(Text("Primary").foregroundColor(AppColors.textPrimary))

        RoundedRectangle(cornerRadius: 8)
            .fill(AppColors.backgroundSecondary)
            .frame(height: 60)
            .overlay(Text("Secondary").foregroundColor(AppColors.textPrimary))

        RoundedRectangle(cornerRadius: 8)
            .fill(AppColors.backgroundMuted)
            .frame(height: 60)
            .overlay(Text("Muted").foregroundColor(AppColors.textPrimary))

        RoundedRectangle(cornerRadius: 8)
            .fill(AppColors.backgroundAccent)
            .frame(height: 60)
            .overlay(Text("Accent").foregroundColor(AppColors.textOnAccent))
    }
    .padding()
    .background(Color.gray.opacity(0.3))
}

#Preview("Status Colors") {
    HStack(spacing: 24) {
        statusDot("Active", AppColors.statusActive)
        statusDot("Away", AppColors.statusAway)
        statusDot("Inactive", AppColors.statusInactive)
    }
    .padding()
    .background(AppColors.backgroundPrimary)
}

private func colorSwatch(_ name: String, _ color: Color) -> some View {
    HStack {
        RoundedRectangle(cornerRadius: 8)
            .fill(color)
            .frame(width: 60, height: 40)
        Text(name)
            .font(.subheadline)
        Spacer()
    }
}

private func statusDot(_ name: String, _ color: Color) -> some View {
    VStack(spacing: 4) {
        Circle()
            .fill(color)
            .frame(width: 16, height: 16)
        Text(name)
            .font(.caption)
            .foregroundColor(AppColors.textSecondary)
    }
}
