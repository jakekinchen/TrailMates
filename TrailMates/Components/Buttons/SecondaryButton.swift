//
//  SecondaryButton.swift
//  TrailMates
//
//  A secondary action button with outline or subtle styling.
//
//  Usage:
//  ```swift
//  SecondaryButton("Cancel") {
//      dismiss()
//  }
//  SecondaryButton("Learn More", style: .outline) {
//      showDetails = true
//  }
//  SecondaryButton("Skip", style: .text) {
//      skipStep()
//  }
//  ```

import SwiftUI

/// A styled secondary action button for non-primary actions
struct SecondaryButton: View {
    /// Button title text
    let title: String
    /// Whether the button is in loading state
    var isLoading: Bool = false
    /// Whether the button is disabled
    var isDisabled: Bool = false
    /// Visual style of the button
    var style: Style = .filled
    /// Size of the button
    var size: Size = .default
    /// Action to perform on tap
    let action: () -> Void

    enum Style {
        case filled
        case outline
        case text

        func backgroundColor(isPressed: Bool) -> Color {
            switch self {
            case .filled:
                return isPressed ? Color("alwaysBeige").opacity(0.8) : Color("alwaysBeige")
            case .outline:
                return isPressed ? Color("pine").opacity(0.1) : Color.clear
            case .text:
                return Color.clear
            }
        }

        var foregroundColor: Color {
            switch self {
            case .filled: return Color("pumpkin")
            case .outline: return Color("pine")
            case .text: return Color("pumpkin")
            }
        }

        var borderColor: Color? {
            switch self {
            case .filled: return nil
            case .outline: return Color("pine")
            case .text: return nil
            }
        }
    }

    enum Size {
        case small
        case `default`
        case large

        var font: Font {
            switch self {
            case .small: return .subheadline.weight(.medium)
            case .default: return .body.weight(.semibold)
            case .large: return .headline.weight(.semibold)
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .small: return 8
            case .default: return 14
            case .large: return 18
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small: return 14
            case .default: return 20
            case .large: return 28
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .small: return 10
            case .default: return 20
            case .large: return 25
            }
        }
    }

    init(
        _ title: String,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        style: Style = .filled,
        size: Size = .default,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.style = style
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: style.foregroundColor))
                        .scaleEffect(size == .small ? 0.7 : 0.9)
                }

                Text(title)
                    .font(size.font)
                    .foregroundColor(style.foregroundColor)
            }
            .frame(maxWidth: style == .text ? nil : .infinity)
            .padding(.vertical, style == .text ? 8 : size.verticalPadding)
            .padding(.horizontal, size.horizontalPadding)
            .background(style.backgroundColor(isPressed: false))
            .cornerRadius(size.cornerRadius)
            .overlay(
                Group {
                    if let borderColor = style.borderColor {
                        RoundedRectangle(cornerRadius: size.cornerRadius)
                            .stroke(borderColor, lineWidth: 1.5)
                    }
                }
            )
        }
        .disabled(isLoading || isDisabled)
        .opacity(isLoading || isDisabled ? 0.5 : 1.0)
    }
}

// MARK: - Previews
#Preview("Filled Style (Default)") {
    VStack(spacing: 16) {
        SecondaryButton("Cancel") {}
        SecondaryButton("Go Back") {}
    }
    .padding()
    .background(Color("beige"))
}

#Preview("Outline Style") {
    VStack(spacing: 16) {
        SecondaryButton("Learn More", style: .outline) {}
        SecondaryButton("View Details", style: .outline) {}
    }
    .padding()
    .background(Color("beige"))
}

#Preview("Text Style") {
    VStack(spacing: 16) {
        SecondaryButton("Skip for now", style: .text) {}
        SecondaryButton("Maybe later", style: .text) {}
    }
    .padding()
    .background(Color("beige"))
}

#Preview("Sizes") {
    VStack(spacing: 16) {
        SecondaryButton("Small", size: .small) {}
        SecondaryButton("Default", size: .default) {}
        SecondaryButton("Large", size: .large) {}
    }
    .padding()
    .background(Color("beige"))
}

#Preview("Loading State") {
    VStack(spacing: 16) {
        SecondaryButton("Loading...", isLoading: true) {}
        SecondaryButton("Loading...", isLoading: true, style: .outline) {}
    }
    .padding()
    .background(Color("beige"))
}

#Preview("Button Pair") {
    VStack(spacing: 12) {
        PrimaryButton("Save Changes") {}
        SecondaryButton("Cancel") {}
    }
    .padding()
    .background(Color("beige"))
}
