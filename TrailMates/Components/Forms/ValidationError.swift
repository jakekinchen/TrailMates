//
//  ValidationError.swift
//  TrailMates
//
//  A standardized validation error display component.
//
//  Usage:
//  ```swift
//  ValidationError("Please enter a valid email address")
//  ValidationError("Password must be at least 8 characters", style: .banner)
//  if let error = validationError {
//      ValidationError(error)
//  }
//  ```

import SwiftUI

/// A styled validation error message component
struct ValidationError: View {
    /// Error message to display
    let message: String
    /// Display style
    var style: Style = .inline

    enum Style {
        case inline
        case banner
        case toast
    }

    init(_ message: String, style: Style = .inline) {
        self.message = message
        self.style = style
    }

    var body: some View {
        switch style {
        case .inline:
            inlineView
        case .banner:
            bannerView
        case .toast:
            toastView
        }
    }

    private var inlineView: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption)
            Text(message)
                .font(.caption)
        }
        .foregroundColor(.red)
    }

    private var bannerView: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.body)

            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .foregroundColor(.white)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.9))
        )
    }

    private var toastView: some View {
        HStack(spacing: 10) {
            Image(systemName: "xmark.circle.fill")
                .font(.title3)

            Text(message)
                .font(.subheadline)

            Spacer()
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.red.opacity(0.95))
                .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
        )
    }
}

// MARK: - View Modifier for Form Validation
struct FormValidationModifier: ViewModifier {
    let errors: [String]
    var style: ValidationError.Style = .banner

    func body(content: Content) -> some View {
        VStack(spacing: 12) {
            if !errors.isEmpty && style == .banner {
                VStack(spacing: 8) {
                    ForEach(errors, id: \.self) { error in
                        ValidationError(error, style: style)
                    }
                }
            }

            content

            if !errors.isEmpty && style == .toast {
                VStack(spacing: 8) {
                    ForEach(errors, id: \.self) { error in
                        ValidationError(error, style: style)
                    }
                }
            }
        }
    }
}

extension View {
    /// Adds validation error display to a form or container
    func validationErrors(_ errors: [String], style: ValidationError.Style = .banner) -> some View {
        modifier(FormValidationModifier(errors: errors, style: style))
    }
}

// MARK: - Previews
#Preview("Inline Style") {
    VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 4) {
            Text("Username")
                .font(.caption)
                .foregroundColor(Color("pine"))
            Text("ab")
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .cornerRadius(8)
            ValidationError("Username must be at least 3 characters")
        }
    }
    .padding()
    .background(Color("beige"))
}

#Preview("Banner Style") {
    VStack(spacing: 16) {
        ValidationError("Please fill in all required fields", style: .banner)
        ValidationError("Your session has expired. Please log in again.", style: .banner)
    }
    .padding()
    .background(Color("beige"))
}

#Preview("Toast Style") {
    VStack {
        Spacer()
        ValidationError("Failed to save changes", style: .toast)
            .padding(.horizontal)
            .padding(.bottom, 32)
    }
    .background(Color("beige"))
}

#Preview("Form with Validation") {
    VStack(spacing: 16) {
        Text("Create Account")
            .font(.title2)
            .fontWeight(.bold)

        Text("Field 1")
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .cornerRadius(8)

        Text("Field 2")
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .cornerRadius(8)
    }
    .validationErrors(["Email is required", "Password must be at least 8 characters"])
    .padding()
    .background(Color("beige"))
}
