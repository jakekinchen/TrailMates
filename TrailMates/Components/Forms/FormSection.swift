//
//  FormSection.swift
//  TrailMates
//
//  A styled form section component for grouping related form fields.
//
//  Usage:
//  ```swift
//  FormSection("Personal Information") {
//      FormField("First Name", text: $firstName)
//      FormField("Last Name", text: $lastName)
//  }
//  FormSection("Contact", footer: "We'll use this to verify your account") {
//      FormField("Phone", text: $phone, type: .phone)
//  }
//  ```

import SwiftUI

/// A styled container for grouping related form fields
struct FormSection<Content: View>: View {
    /// Section header title
    let title: String?
    /// Optional footer text
    var footer: String?
    /// Whether to show a card-style background
    var showBackground: Bool = true
    /// Content builder for section fields
    @ViewBuilder let content: () -> Content

    init(
        _ title: String? = nil,
        footer: String? = nil,
        showBackground: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.footer = footer
        self.showBackground = showBackground
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = title {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color("pine"))
                    .padding(.horizontal, 4)
            }

            VStack(spacing: 12) {
                content()
            }
            .padding(showBackground ? 16 : 0)
            .background(
                Group {
                    if showBackground {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color("beige").opacity(0.5))
                    }
                }
            )

            if let footer = footer {
                Text(footer)
                    .font(.caption)
                    .foregroundColor(Color("pine").opacity(0.6))
                    .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Previews
#Preview("With Title") {
    ScrollView {
        VStack(spacing: 24) {
            FormSection("Personal Information") {
                Text("Field placeholder")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(8)
                Text("Field placeholder")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(8)
            }
        }
        .padding()
    }
    .background(Color("beige"))
}

#Preview("With Footer") {
    ScrollView {
        VStack(spacing: 24) {
            FormSection("Contact Details", footer: "We'll send a verification code to this number") {
                Text("Phone field placeholder")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(8)
            }
        }
        .padding()
    }
    .background(Color("beige"))
}

#Preview("No Background") {
    ScrollView {
        VStack(spacing: 24) {
            FormSection("Settings", showBackground: false) {
                Text("Setting 1")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(8)
                Text("Setting 2")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(8)
            }
        }
        .padding()
    }
    .background(Color("beige"))
}

#Preview("Multiple Sections") {
    ScrollView {
        VStack(spacing: 24) {
            FormSection("Account") {
                Text("Username field")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(8)
            }

            FormSection("Profile") {
                Text("First name")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(8)
                Text("Last name")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(8)
            }
        }
        .padding()
    }
    .background(Color("beige"))
}
