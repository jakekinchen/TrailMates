//
//  ErrorView.swift
//  TrailMates
//
//  Standard error display component with retry functionality.
//
//  Usage:
//  ```swift
//  ErrorView(message: "Failed to load events")
//  ErrorView(
//      message: "Network error occurred",
//      retryAction: { await loadData() }
//  )
//  ErrorView(
//      title: "Connection Lost",
//      message: "Please check your internet connection",
//      systemImage: "wifi.slash",
//      retryAction: { await reconnect() }
//  )
//  ```

import SwiftUI

/// A reusable error display component with optional retry button
struct ErrorView: View {
    /// Main error title (optional)
    let title: String?
    /// Error message to display
    let message: String
    /// SF Symbol name for the icon
    var systemImage: String = "exclamationmark.triangle.fill"
    /// Optional retry action
    var retryAction: (() async -> Void)?
    /// Style of the error view
    var style: Style = .default

    enum Style {
        case `default`
        case compact
        case inline
    }

    init(
        title: String? = nil,
        message: String,
        systemImage: String = "exclamationmark.triangle.fill",
        retryAction: (() async -> Void)? = nil,
        style: Style = .default
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.retryAction = retryAction
        self.style = style
    }

    var body: some View {
        switch style {
        case .default:
            defaultView
        case .compact:
            compactView
        case .inline:
            inlineView
        }
    }

    // MARK: - Default View
    private var defaultView: some View {
        VStack(spacing: 20) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundColor(Color("pumpkin"))

            VStack(spacing: 8) {
                if let title = title {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(Color("pine"))
                }

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(Color("pine").opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if let retryAction = retryAction {
                RetryButton(action: retryAction)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Compact View
    private var compactView: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 32))
                .foregroundColor(Color("pumpkin"))

            Text(message)
                .font(.caption)
                .foregroundColor(Color("pine").opacity(0.8))
                .multilineTextAlignment(.center)

            if let retryAction = retryAction {
                RetryButton(action: retryAction, style: .small)
            }
        }
        .padding()
    }

    // MARK: - Inline View
    private var inlineView: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundColor(Color("pumpkin"))

            Text(message)
                .font(.subheadline)
                .foregroundColor(Color("pine").opacity(0.8))

            Spacer()

            if let retryAction = retryAction {
                Button {
                    Task { await retryAction() }
                } label: {
                    Text("Retry")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color("pumpkin"))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("pumpkin").opacity(0.1))
        )
    }
}

// MARK: - Retry Button
private struct RetryButton: View {
    let action: () async -> Void
    var style: ButtonStyle = .default

    @State private var isLoading = false

    enum ButtonStyle {
        case `default`
        case small
    }

    var body: some View {
        Button {
            Task {
                isLoading = true
                await action()
                isLoading = false
            }
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(style == .small ? 0.8 : 1.0)
                        .tint(Color("alwaysBeige"))
                } else {
                    Image(systemName: "arrow.clockwise")
                }
                Text("Try Again")
            }
            .font(style == .small ? .caption : .subheadline)
            .fontWeight(.medium)
            .foregroundColor(Color("alwaysBeige"))
            .padding(.horizontal, style == .small ? 16 : 24)
            .padding(.vertical, style == .small ? 8 : 12)
            .background(Color("pumpkin"))
            .cornerRadius(style == .small ? 8 : 12)
        }
        .disabled(isLoading)
    }
}

// MARK: - Previews
#Preview("Default Error") {
    ErrorView(message: "Something went wrong")
}

#Preview("With Title and Retry") {
    ErrorView(
        title: "Failed to Load",
        message: "Unable to fetch events. Please try again.",
        retryAction: {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    )
}

#Preview("Network Error") {
    ErrorView(
        title: "No Connection",
        message: "Please check your internet connection and try again.",
        systemImage: "wifi.slash",
        retryAction: {}
    )
}

#Preview("Compact Style") {
    ErrorView(
        message: "Could not load data",
        retryAction: {},
        style: .compact
    )
    .frame(width: 200, height: 200)
    .background(Color("beige"))
}

#Preview("Inline Style") {
    VStack {
        Spacer()
        ErrorView(
            message: "Failed to sync",
            retryAction: {},
            style: .inline
        )
        .padding()
        Spacer()
    }
    .background(Color("beige"))
}
