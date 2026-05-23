//
//  AuthView.swift
//  TrailMatesATX
//

import SwiftUI
import UIKit

// MARK: - Field Type
enum AuthField: Hashable {
    case phone
    case verification
}

// MARK: - Main View
struct AuthView: View {
    // MARK: - Environment
    @EnvironmentObject private var userManager: UserManager

    // MARK: - State
    @StateObject private var authViewModel = AuthViewModel()
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var showingLoginFields = false
    @State private var showingSignupFields = false
    @State private var isVerificationStage = false
    @State private var isVerificationSent = false
    @State private var isCheckingPhoneNumber = false
    @FocusState private var focusedField: AuthField?

    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundImage(geometry: geometry)

                VStack(spacing: 0) {
                    headerSection
                        .frame(height: 250, alignment: .top)

                    Spacer()
                    Spacer()
                    Spacer()

                    authFieldsContainer

                    Spacer()
                    Spacer()
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .simultaneousGesture(TapGesture().onEnded {
            dismissKeyboard()
        })
        .ignoresSafeArea(.keyboard, edges: .all)
    }
}

// MARK: - View Builders
private extension AuthView {
    @ViewBuilder
    func backgroundImage(geometry: GeometryProxy) -> some View {
        let safeAreaInsets = geometry.safeAreaInsets
        let fullSize = CGSize(
            width: geometry.size.width + safeAreaInsets.leading + safeAreaInsets.trailing,
            height: max(
                geometry.size.height + safeAreaInsets.top + safeAreaInsets.bottom,
                UIScreen.main.bounds.height
            )
        )
        let safeAreaOffset = CGSize(
            width: (safeAreaInsets.trailing - safeAreaInsets.leading) / 2,
            height: (safeAreaInsets.bottom - safeAreaInsets.top) / 2
        )

        ZStack {
            Color("alwaysPine")

            Image("background")
                .resizable()
                .scaledToFill()
        }
        .frame(width: fullSize.width, height: fullSize.height)
        .offset(x: safeAreaOffset.width, y: safeAreaOffset.height)
        .clipped()
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    @ViewBuilder
    var headerSection: some View {
        VStack(spacing: 0) {
            headerWithBackButton
                .frame(height: 60)
                .padding(.top, authHeaderTopPadding)

            Circle()
                .fill(Color("pumpkin"))
                .frame(width: 60, height: 60)
                .padding(.top, 20)
        }
    }

    @ViewBuilder
    var headerWithBackButton: some View {
        ZStack {
            HStack {
                if isShowingAuthFields {
                    backButton
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
                Spacer()
            }

            Text("TrailMates")
                .font(.custom("Magic Retro", size: 48))
                .foregroundColor(Color("alwaysPine"))
        }
    }

    @ViewBuilder
    var backButton: some View {
        Button(action: handleBackAction) {
            Image(systemName: "arrow.left")
                .foregroundColor(Color("alwaysPine"))
                .imageScale(.large)
                .padding(.leading, 20)
                .offset(x: 8)
        }
        .accessibilityIdentifier("auth_back_button")
    }

    var isShowingAuthFields: Bool {
        showingLoginFields || showingSignupFields
    }

    var authHeaderTopPadding: CGFloat {
        isShowingAuthFields ? 64 : 110
    }

    var isPhoneSubmissionInProgress: Bool {
        isCheckingPhoneNumber || authViewModel.isLoading
    }

    var phoneSubmissionLoadingTitle: String {
        "Sending..."
    }

    @ViewBuilder
    var authFieldsContainer: some View {
        VStack(spacing: 16) {
            if showingLoginFields || showingSignupFields {
                inputFieldsSection
                    .padding(.horizontal, 20)
                    .transition(.moveAndFade)
            }

            if !authViewModel.errorMessage.isEmpty {
                errorMessageView
            }

            buttonsSection
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
        }
    }

    @ViewBuilder
    var inputFieldsSection: some View {
        VStack(spacing: 16) {
            if isVerificationStage {
                OTPVerificationStep(
                    verificationCode: $verificationCode,
                    isEnabled: !authViewModel.isLoading,
                    focusedField: $focusedField
                )
                .onChange(of: verificationCode) { _, newValue in
                    authViewModel.verificationCode = newValue
                }
                .transition(.moveAndFade)
            } else {
                PhoneEntryStep(
                    phoneNumber: $phoneNumber,
                    isEnabled: !isPhoneSubmissionInProgress,
                    usesInvertedColors: true,
                    focusedField: $focusedField
                )
            }
        }
    }

    @ViewBuilder
    var errorMessageView: some View {
        Text(authViewModel.errorMessage)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(Color("alwaysBeige"))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("alwaysPine"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color("pumpkin"), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .transition(.opacity.combined(with: .scale))
    }

    @ViewBuilder
    var buttonsSection: some View {
        VStack(spacing: 12) {
            if isVerificationStage {
                verifyButton
            } else {
                loginButton
                signupButton
            }
        }
    }

    @ViewBuilder
    var verifyButton: some View {
        Button(action: {
            Task {
                await authViewModel.verifyCode()
            }
        }) {
            AuthSubmitButtonContent(
                title: "Verify",
                loadingTitle: "Verifying...",
                isLoading: authViewModel.isLoading,
                primary: true
            )
        }
        .accessibilityIdentifier("auth_verify_button")
        .disabled(verificationCode.isEmpty || authViewModel.isLoading)
    }

    @ViewBuilder
    var loginButton: some View {
        Button(action: handleLogin) {
            AuthSubmitButtonContent(
                title: "Log In",
                loadingTitle: phoneSubmissionLoadingTitle,
                isLoading: isCheckingPhoneNumber,
                primary: true
            )
        }
        .accessibilityIdentifier("auth_login_button")
        .disabled(isPhoneSubmissionInProgress)
        .opacity(!showingSignupFields ? 1 : 0)
        .animation(.easeOut(duration: 0.1), value: showingSignupFields)
    }

    @ViewBuilder
    var signupButton: some View {
        Button(action: handleSignup) {
            AuthSubmitButtonContent(
                title: "Sign Up",
                loadingTitle: phoneSubmissionLoadingTitle,
                isLoading: isCheckingPhoneNumber,
                primary: showingSignupFields || isCheckingPhoneNumber
            )
        }
        .accessibilityIdentifier("auth_signup_button")
        .disabled(isPhoneSubmissionInProgress)
        .opacity(!showingLoginFields ? 1 : 0)
        .animation(.easeOut(duration: 0.1), value: showingLoginFields)
    }
}

// MARK: - Helper Methods
private extension AuthView {
    func dismissKeyboard() {
        focusedField = nil
    }

    func handleBackAction() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            if isVerificationStage {
                isVerificationStage = false
            } else {
                showingLoginFields = false
                showingSignupFields = false
                phoneNumber = ""
                verificationCode = ""
                authViewModel.showError = false
                authViewModel.errorMessage = ""
            }
        }
    }

    func handleLogin() {
        withAnimation(.easeOut(duration: 0.2)) {
            if !phoneNumber.isEmpty {
                isCheckingPhoneNumber = true
                print("Login - Starting phone number check: \(phoneNumber)")
                Task {
                    print("Login - Checking if user exists")
                    if await userManager.checkUserExists(phoneNumber: phoneNumber) {
                        print("Login - User found, proceeding with verification")
                        authViewModel.phoneNumber = phoneNumber
                        if await authViewModel.sendCode() {
                            isVerificationStage = true
                            showingLoginFields = true
                            showingSignupFields = false
                            isVerificationSent = true
                        }
                    } else {
                        print("Login - No user found with phone number")
                        authViewModel.showError = true
                        authViewModel.errorMessage = "No account found with this phone number. Please sign up instead."
                    }
                    isCheckingPhoneNumber = false
                }
            } else {
                print("Login - Empty phone number field")
                showingLoginFields = true
                showingSignupFields = false
            }
        }
    }

    func handleSignup() {
        withAnimation(.easeOut(duration: 0.2)) {
            if !phoneNumber.isEmpty {
                isCheckingPhoneNumber = true
                Task {
                    if await userManager.checkUserExists(phoneNumber: phoneNumber) {
                        authViewModel.showError = true
                        authViewModel.errorMessage = "An account already exists with this phone number. Please log in instead."
                        isCheckingPhoneNumber = false
                        return
                    }
                    authViewModel.phoneNumber = phoneNumber
                    authViewModel.isSigningUp = true
                    if await authViewModel.sendCode() {
                        isVerificationStage = true
                        showingSignupFields = true
                        showingLoginFields = false
                        isVerificationSent = true
                    }
                    isCheckingPhoneNumber = false
                }
            } else {
                showingSignupFields = true
                showingLoginFields = false
            }
        }
    }
}

private enum AuthInputColorStyle {
    case standard
    case inverted
}

// MARK: - PhoneEntryStep Component
private struct PhoneEntryStep: View {
    @Binding var phoneNumber: String
    let isEnabled: Bool
    let usesInvertedColors: Bool
    @FocusState.Binding var focusedField: AuthField?

    var body: some View {
        AuthFloatingLabelTextField(
            placeholder: "Phone Number",
            text: $phoneNumber,
            keyboardType: .phonePad,
            contentType: .telephoneNumber,
            isEnabled: isEnabled,
            field: .phone,
            colorStyle: usesInvertedColors ? .inverted : .standard,
            focusedField: $focusedField
        )
    }
}

// MARK: - OTPVerificationStep Component
private struct OTPVerificationStep: View {
    @Binding var verificationCode: String
    let isEnabled: Bool
    @FocusState.Binding var focusedField: AuthField?

    var body: some View {
        AuthFloatingLabelTextField(
            placeholder: "Verification Code",
            text: $verificationCode,
            keyboardType: .numberPad,
            contentType: .oneTimeCode,
            isEnabled: isEnabled,
            field: .verification,
            focusedField: $focusedField
        )
    }
}

// MARK: - AuthFloatingLabelTextField Component
private struct AuthFloatingLabelTextField: View {
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let contentType: UITextContentType
    let isEnabled: Bool
    let field: AuthField
    var colorStyle: AuthInputColorStyle = .standard
    @FocusState.Binding var focusedField: AuthField?

    var body: some View {
        ZStack(alignment: .leading) {
            Text(placeholder)
                .font(.system(size: !text.isEmpty ? 10 : 16))
                .padding(.horizontal, 8)
                .foregroundColor(foregroundColor)
                .offset(x: 8, y: !text.isEmpty ? -16 : 0)
                .animation(.easeInOut(duration: 0.2), value: !text.isEmpty)
                .allowsHitTesting(false)
                .zIndex(1)

            TextField("", text: $text)
                .keyboardType(keyboardType)
                .textContentType(contentType)
                .disabled(!isEnabled)
                .focused($focusedField, equals: field)
                .accessibilityIdentifier(accessibilityIdentifier)
                .tint(foregroundColor)
                .offset(y: !text.isEmpty ? 2 : 0)
                .onTapGesture {
                    if focusedField == field {
                        UIPasteboard.general.string = text
                        text = ""
                    }
                    focusedField = field
                }
                .onChange(of: text) { oldValue, newValue in
                    handleTextChange(oldValue: oldValue, newValue: newValue)
                }
                .modifier(AuthInputFormattingModifier(text: $text, field: field))
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(backgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(borderColor, lineWidth: 1)
                        )
                )
                .foregroundColor(foregroundColor)
        }
        .padding(.top, 12)
    }

    private var foregroundColor: Color {
        colorStyle == .inverted ? Color("alwaysPine") : Color("alwaysBeige")
    }

    private var backgroundColor: Color {
        colorStyle == .inverted ? Color("alwaysBeige") : Color("alwaysPine")
    }

    private var borderColor: Color {
        colorStyle == .inverted ? Color("alwaysPine") : Color("alwaysBeige")
    }

    private var accessibilityIdentifier: String {
        switch field {
        case .phone:
            return "auth_phone_textfield"
        case .verification:
            return "auth_verification_textfield"
        }
    }

    private func handleTextChange(oldValue: String, newValue: String) {
        let oldDigitCount = oldValue.filter { $0.isNumber }.count
        let newDigitCount = newValue.filter { $0.isNumber }.count

        if field == .phone && newDigitCount > oldDigitCount {
            let digits = newValue.filter { $0.isNumber }
            let isUSWithCountryCode = digits.hasPrefix("1")
            let shouldDismiss =
                (!isUSWithCountryCode && newDigitCount == 10) ||
                (isUSWithCountryCode && newDigitCount == 11)

            if shouldDismiss {
                focusedField = nil
            }
        }

        if field == .verification {
            if newDigitCount > 6 {
                text = String(newValue.filter { $0.isNumber }.prefix(6))
            }
            if newDigitCount == 6 && newDigitCount > oldDigitCount {
                focusedField = nil
            }
        }
    }
}

// MARK: - AuthInputFormattingModifier
private struct AuthInputFormattingModifier: ViewModifier {
    @Binding var text: String
    let field: AuthField

    func body(content: Content) -> some View {
        if field == .phone {
            content.modifier(PhoneNumberFormatter(text: $text))
        } else {
            content
        }
    }
}

// MARK: - AuthSubmitButtonContent
private struct AuthSubmitButtonContent: View {
    let title: String
    let loadingTitle: String
    let isLoading: Bool
    let primary: Bool

    var body: some View {
        HStack(spacing: 10) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                    .tint(foregroundColor)
            }

            Text(isLoading ? loadingTitle : title)
                .font(.system(size: 16, weight: .bold))
        }
        .foregroundColor(foregroundColor)
        .frame(maxWidth: .infinity)
        .padding()
        .background(backgroundColor)
        .cornerRadius(25)
        .animation(.easeInOut(duration: 0.16), value: isLoading)
        .accessibilityLabel(isLoading ? loadingTitle : title)
    }

    private var foregroundColor: Color {
        primary ? Color("alwaysBeige") : Color("pumpkin")
    }

    private var backgroundColor: Color {
        primary ? Color("pumpkin") : Color("alwaysBeige")
    }
}

// MARK: - Text Button Style Extension
private extension Text {
    func authButtonStyle(primary: Bool) -> some View {
        self
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(primary ? Color("alwaysBeige") : Color("pumpkin"))
            .frame(maxWidth: .infinity)
            .padding()
            .background(primary ? Color("pumpkin") : Color("alwaysBeige"))
            .cornerRadius(25)
    }
}

// MARK: - Transition Extension
extension AnyTransition {
    static var moveAndFade: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        )
    }
}

// MARK: - Legacy Support (for other files using Field enum)
typealias Field = AuthField

// MARK: - Legacy FloatingLabelTextField (for backward compatibility)
struct FloatingLabelTextField: View {
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let contentType: UITextContentType
    let isEnabled: Bool
    let field: AuthField
    @FocusState.Binding var focusedField: AuthField?

    var body: some View {
        ZStack(alignment: .leading) {
            Text(placeholder)
                .font(.system(size: !text.isEmpty ? 10 : 16))
                .padding(.horizontal, 8)
                .foregroundColor(Color("alwaysBeige"))
                .offset(x: 8, y: !text.isEmpty ? -16 : 0)
                .animation(.easeInOut(duration: 0.2), value: !text.isEmpty)
                .allowsHitTesting(false)
                .zIndex(1)

            TextField("", text: $text)
                .keyboardType(keyboardType)
                .textContentType(contentType)
                .disabled(!isEnabled)
                .focused($focusedField, equals: field)
                .accessibilityIdentifier(accessibilityIdentifier)
                .offset(y: !text.isEmpty ? 2 : 0)
                .onTapGesture {
                    if focusedField == field {
                        UIPasteboard.general.string = text
                        text = ""
                    }
                    focusedField = field
                }
                .onChange(of: text) { oldValue, newValue in
                    let oldDigitCount = oldValue.filter { $0.isNumber }.count
                    let newDigitCount = newValue.filter { $0.isNumber }.count

                    if field == .phone && newDigitCount >= 11 && newDigitCount > oldDigitCount {
                        focusedField = nil
                    }

                    if field == .verification {
                        if newDigitCount > 6 {
                            text = String(newValue.filter { $0.isNumber }.prefix(6))
                        }
                        if newDigitCount == 6 && newDigitCount > oldDigitCount {
                            focusedField = nil
                        }
                    }
                }
                .modifier(InputFormattingModifier(text: $text, field: field))
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color("alwaysPine"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color("alwaysBeige"), lineWidth: 1)
                        )
                )
                .foregroundColor(Color("alwaysBeige"))
        }
        .padding(.top, 12)
    }

    private var accessibilityIdentifier: String {
        switch field {
        case .phone:
            return "auth_phone_textfield"
        case .verification:
            return "auth_verification_textfield"
        }
    }
}

// MARK: - Legacy InputFormattingModifier
struct InputFormattingModifier: ViewModifier {
    @Binding var text: String
    let field: AuthField

    func body(content: Content) -> some View {
        if field == .phone {
            content.modifier(PhoneNumberFormatter(text: $text))
        } else {
            content
        }
    }
}

// MARK: - Legacy CustomTextFieldStyle
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .foregroundColor(Color("alwaysBeige"))
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color("alwaysPine"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color("alwaysBeige"), lineWidth: 1)
                    )
            )
    }
}

// MARK: - Legacy Text Button Style Extension
extension Text {
    func buttonStyle(primary: Bool) -> some View {
        self
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(primary ? Color("alwaysBeige") : Color("pumpkin"))
            .frame(maxWidth: .infinity)
            .padding()
            .background(primary ? Color("pumpkin") : Color("alwaysBeige"))
            .cornerRadius(25)
    }
}

// MARK: - Preview
struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView()
    }
}
