//
//  FloatingLabelTextField.swift
//  TrailMatesATX
//
//  A unified floating-label text field used throughout the app.
//

import SwiftUI
import UIKit

// MARK: - Color Style

/// Controls the background / foreground / border color scheme.
enum FloatingLabelColorStyle {
    /// Pine text on beige background with pine border (profile setup, settings)
    case standard
    /// Pine text on clear background with pine border stroke only (change phone)
    case outline
    /// Beige text on pine background with beige border (auth dark variant)
    case dark
    /// Pine text on beige background with pine border (auth inverted variant)
    case inverted
}

// MARK: - FloatingLabelTextField

/// A configurable floating-label text field component.
///
/// The label sits inside the field and floats up when the field has content.
/// Supports multiple color schemes, keyboard types, content types, clear
/// buttons, character limits, and focus management via any `Hashable` enum.
///
/// For simple `Bool` focus bindings, omit the `field`/`focusedField` parameters
/// and apply `.focused($isFocused)` on the outside.
struct FloatingLabelTextField<Field: Hashable>: View {
    // MARK: - Required
    let placeholder: String
    @Binding var text: String

    // MARK: - Configuration
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var isSecure: Bool = false
    var isEnabled: Bool = true
    var characterLimit: Int? = nil
    var autocapitalization: UITextAutocapitalizationType = .sentences
    var colorStyle: FloatingLabelColorStyle = .standard
    var showClearButton: Bool = false
    var autocorrectionDisabled: Bool = false
    var submitLabel: SubmitLabel = .done
    var accessibilityId: String? = nil

    // MARK: - Focus (optional — works with any Hashable enum)
    var field: Field? = nil
    var focusedField: FocusState<Field?>.Binding? = nil

    // MARK: - Callbacks
    var onSubmit: (() -> Void)? = nil
    var onChange: ((_ oldValue: String, _ newValue: String) -> Void)? = nil

    // MARK: - Private State
    @State private var isAnimated = false

    // MARK: - Computed Colors
    private var foregroundColor: Color {
        switch colorStyle {
        case .standard, .outline, .inverted: AppColors.pine
        case .dark: AppColors.alwaysBeige
        }
    }

    private var backgroundColor: Color {
        switch colorStyle {
        case .standard: AppColors.beige
        case .outline: Color.clear
        case .dark: AppColors.alwaysPine
        case .inverted: AppColors.alwaysBeige
        }
    }

    private var borderColor: Color {
        switch colorStyle {
        case .standard, .outline: AppColors.pine
        case .dark: AppColors.alwaysBeige
        case .inverted: AppColors.alwaysPine
        }
    }

    private var labelColor: Color {
        switch colorStyle {
        case .standard, .outline, .inverted: AppColors.pine
        case .dark: AppColors.alwaysBeige
        }
    }

    // MARK: - Body
    var body: some View {
        ZStack(alignment: .leading) {
            backgroundShape
            floatingLabel
            inputField
        }
        .frame(height: 56)
        .onChange(of: text) { oldValue, newValue in
            var processed = newValue
            if let limit = characterLimit {
                processed = String(processed.prefix(limit))
            }
            if processed != newValue {
                text = processed
            }
            withAnimation {
                isAnimated = !processed.isEmpty
            }
            onChange?(oldValue, processed)
        }
        .onAppear {
            isAnimated = !text.isEmpty
        }
    }
}

// MARK: - Subviews

private extension FloatingLabelTextField {
    @ViewBuilder
    var backgroundShape: some View {
        switch colorStyle {
        case .outline:
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 2)
        default:
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: 2)
                )
        }
    }

    var floatingLabel: some View {
        Text(placeholder)
            .font(isAnimated ? AppTypography.inputLabel : AppTypography.inputText)
            .foregroundColor(labelColor.opacity(0.8))
            .offset(x: 10, y: isAnimated ? -14 : 0)
            .animation(.spring(response: 0.2), value: isAnimated)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    var inputField: some View {
        HStack {
            textFieldContent
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .autocapitalization(autocapitalization)
                .autocorrectionDisabled(autocorrectionDisabled)
                .disabled(!isEnabled)
                .font(AppTypography.inputText)
                .foregroundColor(foregroundColor)
                .tint(foregroundColor)
                .padding(.leading, 12)
                .padding(.trailing, showClearButton ? 35 : 12)
                .padding(.top, isAnimated ? 8 : 0)
                .applyFocus(focusedField: focusedField, field: field)
                .applyAccessibilityId(accessibilityId)

            if showClearButton && !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(foregroundColor)
                }
                .padding(.trailing, 8)
            }
        }
    }

    @ViewBuilder
    var textFieldContent: some View {
        if isSecure {
            SecureField("", text: $text)
        } else {
            TextField("", text: $text)
                .submitLabel(submitLabel)
                .onSubmit { onSubmit?() }
        }
    }
}

// MARK: - Focus Helper

private extension View {
    @ViewBuilder
    func applyFocus<F: Hashable>(
        focusedField: FocusState<F?>.Binding?,
        field: F?
    ) -> some View {
        if let binding = focusedField, let fieldValue = field {
            self.focused(binding, equals: fieldValue)
        } else {
            self
        }
    }

    @ViewBuilder
    func applyAccessibilityId(_ id: String?) -> some View {
        if let id = id {
            self.accessibilityIdentifier(id)
        } else {
            self
        }
    }
}
