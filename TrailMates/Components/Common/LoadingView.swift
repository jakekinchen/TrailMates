//
//  LoadingView.swift
//  TrailMates
//
//  Standard loading indicator component for consistent loading states across the app.
//
//  Usage:
//  ```swift
//  LoadingView()
//  LoadingView(message: "Loading events...")
//  LoadingView(message: "Please wait", style: .large)
//  ```

import SwiftUI

/// A reusable loading indicator with optional message
struct LoadingView: View {
    /// Optional message to display below the spinner
    let message: String?
    /// Size style of the loading indicator
    var style: Style = .default

    enum Style {
        case `default`
        case large
        case small

        var scale: CGFloat {
            switch self {
            case .small: return 1.0
            case .default: return 1.5
            case .large: return 2.0
            }
        }

        var font: Font {
            switch self {
            case .small: return .caption
            case .default: return .subheadline
            case .large: return .headline
            }
        }
    }

    init(message: String? = nil, style: Style = .default) {
        self.message = message
        self.style = style
    }

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(style.scale)
                .tint(Color("pine"))

            if let message = message {
                Text(message)
                    .font(style.font)
                    .foregroundColor(Color("pine").opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Full Screen Loading Overlay
/// A full-screen loading overlay with dimmed background
struct LoadingOverlay: View {
    let message: String?

    init(message: String? = nil) {
        self.message = message
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                if let message = message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color("pine").opacity(0.9))
            )
        }
    }
}

// MARK: - Previews
#Preview("Default Loading") {
    LoadingView()
}

#Preview("With Message") {
    LoadingView(message: "Loading events...")
}

#Preview("Large Style") {
    LoadingView(message: "Please wait", style: .large)
}

#Preview("Small Style") {
    LoadingView(message: "Updating", style: .small)
}

#Preview("Loading Overlay") {
    ZStack {
        Color("beige").ignoresSafeArea()
        Text("Background Content")
        LoadingOverlay(message: "Saving changes...")
    }
}
