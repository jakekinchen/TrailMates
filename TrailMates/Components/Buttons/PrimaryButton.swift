//
//  PrimaryButton.swift
//  TrailMates
//
//  A primary action button with consistent styling across the app.
//
//  Usage:
//  ```swift
//  PrimaryButton("Save") {
//      await saveProfile()
//  }
//  PrimaryButton("Continue", isLoading: isLoading) {
//      await submitForm()
//  }
//  PrimaryButton("Delete", style: .destructive) {
//      deleteItem()
//  }
//  ```

import SwiftUI

/// A styled primary action button with loading state support
struct PrimaryButton: View {
    /// Button title text
    let title: String
    /// Whether the button is in loading state
    var isLoading: Bool = false
    /// Whether the button is disabled
    var isDisabled: Bool = false
    /// Visual style of the button
    var style: Style = .default
    /// Size of the button
    var size: Size = .default
    /// Action to perform on tap
    let action: () -> Void

    enum Style {
        case `default`
        case destructive

        var backgroundColor: Color {
            switch self {
            case .default: return Color("pumpkin")
            case .destructive: return Color.red
            }
        }

        var foregroundColor: Color {
            Color("alwaysBeige")
        }
    }

    enum Size {
        case small
        case `default`
        case large

        var font: Font {
            switch self {
            case .small: return .subheadline.weight(.semibold)
            case .default: return .body.weight(.bold)
            case .large: return .headline.weight(.bold)
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .small: return 10
            case .default: return 16
            case .large: return 20
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small: return 16
            case .default: return 24
            case .large: return 32
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .small: return 12
            case .default: return 25
            case .large: return 30
            }
        }
    }

    init(
        _ title: String,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        style: Style = .default,
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
                        .scaleEffect(size == .small ? 0.8 : 1.0)
                }

                Text(title)
                    .font(size.font)
                    .foregroundColor(style.foregroundColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, size.verticalPadding)
            .padding(.horizontal, size.horizontalPadding)
            .background(style.backgroundColor)
            .cornerRadius(size.cornerRadius)
        }
        .disabled(isLoading || isDisabled)
        .opacity(isLoading || isDisabled ? 0.6 : 1.0)
    }
}

// MARK: - Async Variant
extension PrimaryButton {
    /// Creates a PrimaryButton with async action support
    init(
        _ title: String,
        isLoading: Binding<Bool>,
        isDisabled: Bool = false,
        style: Style = .default,
        size: Size = .default,
        action: @escaping () async -> Void
    ) {
        self.title = title
        self.isLoading = isLoading.wrappedValue
        self.isDisabled = isDisabled
        self.style = style
        self.size = size
        self.action = {
            Task {
                isLoading.wrappedValue = true
                await action()
                isLoading.wrappedValue = false
            }
        }
    }
}

// MARK: - Previews
#Preview("Default") {
    VStack(spacing: 16) {
        PrimaryButton("Save Changes") {}
        PrimaryButton("Continue") {}
    }
    .padding()
    .background(Color("beige"))
}

#Preview("Loading State") {
    VStack(spacing: 16) {
        PrimaryButton("Saving...", isLoading: true) {}
        PrimaryButton("Submit", isLoading: false) {}
    }
    .padding()
    .background(Color("beige"))
}

#Preview("Disabled State") {
    VStack(spacing: 16) {
        PrimaryButton("Save", isDisabled: true) {}
        PrimaryButton("Save", isDisabled: false) {}
    }
    .padding()
    .background(Color("beige"))
}

#Preview("Destructive Style") {
    VStack(spacing: 16) {
        PrimaryButton("Delete Account", style: .destructive) {}
        PrimaryButton("Remove Friend", style: .destructive, size: .small) {}
    }
    .padding()
    .background(Color("beige"))
}

#Preview("Sizes") {
    VStack(spacing: 16) {
        PrimaryButton("Small", size: .small) {}
        PrimaryButton("Default", size: .default) {}
        PrimaryButton("Large", size: .large) {}
    }
    .padding()
    .background(Color("beige"))
}
