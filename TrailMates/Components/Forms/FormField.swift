//
//  FormField.swift
//  TrailMates
//
//  A styled form field component supporting text, phone, and email input types.
//
//  Usage:
//  ```swift
//  FormField("Username", text: $username)
//  FormField("Phone Number", text: $phone, type: .phone)
//  FormField("Email", text: $email, type: .email)
//  FormField("Password", text: $password, type: .secure)
//  FormField("Name", text: $name, error: nameError)
//  ```

import SwiftUI

/// A styled text input field with floating label and validation support
struct FormField: View {
    /// Field label/placeholder text
    let label: String
    /// Bound text value
    @Binding var text: String
    /// Type of input field
    var type: FieldType = .text
    /// Optional validation error message
    var error: String?
    /// Whether the field is disabled
    var isDisabled: Bool = false
    /// Optional icon name (SF Symbol)
    var icon: String?

    enum FieldType {
        case text
        case phone
        case email
        case secure
        case numeric

        var keyboardType: UIKeyboardType {
            switch self {
            case .text, .secure: return .default
            case .phone: return .phonePad
            case .email: return .emailAddress
            case .numeric: return .numberPad
            }
        }

        var contentType: UITextContentType? {
            switch self {
            case .text: return nil
            case .phone: return .telephoneNumber
            case .email: return .emailAddress
            case .secure: return .password
            case .numeric: return nil
            }
        }

        var autocapitalization: UITextAutocapitalizationType {
            switch self {
            case .text: return .words
            case .phone, .email, .secure, .numeric: return .none
            }
        }
    }

    @State private var isSecureVisible = false
    @FocusState private var isFocused: Bool

    init(
        _ label: String,
        text: Binding<String>,
        type: FieldType = .text,
        error: String? = nil,
        isDisabled: Bool = false,
        icon: String? = nil
    ) {
        self.label = label
        self._text = text
        self.type = type
        self.error = error
        self.isDisabled = isDisabled
        self.icon = icon
    }

    private var showFloatingLabel: Bool {
        !text.isEmpty || isFocused
    }

    private var borderColor: Color {
        if error != nil {
            return .red
        }
        return isFocused ? Color("pumpkin") : Color("pine").opacity(0.3)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(isDisabled ? 0.3 : 0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(borderColor, lineWidth: isFocused ? 2 : 1)
                    )

                HStack(spacing: 12) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .foregroundColor(Color("pine").opacity(0.6))
                            .frame(width: 20)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        // Floating label
                        if showFloatingLabel {
                            Text(label)
                                .font(.caption)
                                .foregroundColor(error != nil ? .red : Color("pine").opacity(0.6))
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                                    removal: .opacity
                                ))
                        }

                        // Input field
                        inputField
                    }

                    if type == .secure {
                        Button {
                            isSecureVisible.toggle()
                        } label: {
                            Image(systemName: isSecureVisible ? "eye.slash" : "eye")
                                .foregroundColor(Color("pine").opacity(0.5))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, showFloatingLabel ? 10 : 16)
            }
            .frame(height: 56)
            .animation(.easeInOut(duration: 0.2), value: showFloatingLabel)
            .animation(.easeInOut(duration: 0.2), value: isFocused)

            // Error message
            if let error = error {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption2)
                    Text(error)
                        .font(.caption)
                }
                .foregroundColor(.red)
                .padding(.horizontal, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: error)
    }

    @ViewBuilder
    private var inputField: some View {
        Group {
            if type == .secure && !isSecureVisible {
                SecureField(showFloatingLabel ? "" : label, text: $text)
            } else {
                TextField(showFloatingLabel ? "" : label, text: $text)
                    .keyboardType(type.keyboardType)
                    .textContentType(type.contentType)
                    .autocapitalization(type.autocapitalization)
                    .autocorrectionDisabled(type != .text)
            }
        }
        .font(.body)
        .foregroundColor(Color("pine"))
        .focused($isFocused)
        .disabled(isDisabled)
    }
}

// MARK: - Previews
#Preview("Text Field") {
    VStack(spacing: 16) {
        FormField("Username", text: .constant(""))
        FormField("Username", text: .constant("jakekinchen"))
    }
    .padding()
    .background(Color("beige"))
}

#Preview("With Icons") {
    VStack(spacing: 16) {
        FormField("Username", text: .constant(""), icon: "person")
        FormField("Email", text: .constant(""), type: .email, icon: "envelope")
        FormField("Phone", text: .constant(""), type: .phone, icon: "phone")
    }
    .padding()
    .background(Color("beige"))
}

#Preview("Field Types") {
    VStack(spacing: 16) {
        FormField("Name", text: .constant("Jake"))
        FormField("Phone", text: .constant("512-555-1234"), type: .phone)
        FormField("Email", text: .constant("jake@example.com"), type: .email)
        FormField("Password", text: .constant("secret123"), type: .secure)
    }
    .padding()
    .background(Color("beige"))
}

#Preview("With Errors") {
    VStack(spacing: 16) {
        FormField("Username", text: .constant("ab"), error: "Username must be at least 3 characters")
        FormField("Email", text: .constant("invalid"), type: .email, error: "Please enter a valid email")
    }
    .padding()
    .background(Color("beige"))
}

#Preview("Disabled State") {
    VStack(spacing: 16) {
        FormField("Phone", text: .constant("512-555-1234"), type: .phone, isDisabled: true)
    }
    .padding()
    .background(Color("beige"))
}

#Preview("In Form Section") {
    ScrollView {
        VStack(spacing: 24) {
            FormSection("Personal Information") {
                FormField("First Name", text: .constant("Jake"), icon: "person")
                FormField("Last Name", text: .constant("Kinchen"))
            }

            FormSection("Contact", footer: "We'll use this to verify your account") {
                FormField("Phone", text: .constant(""), type: .phone, icon: "phone")
                FormField("Email", text: .constant(""), type: .email, icon: "envelope")
            }
        }
        .padding()
    }
    .background(Color("beige"))
}
