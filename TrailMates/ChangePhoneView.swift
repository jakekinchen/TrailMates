//
//  ChangePhoneView.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on 11/21/24.
//

import SwiftUI
import UIKit

// MARK: - Main View
struct ChangePhoneView: View {
    // MARK: - Field Type
    enum Field {
        case phone, verification
    }

    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var userManager: UserManager

    // MARK: - State
    @StateObject private var authViewModel = AuthViewModel()
    @State private var newPhoneNumber = ""
    @State private var verificationCode = ""
    @State private var isVerificationSent = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @FocusState private var focusedField: Field?

    // MARK: - Computed
    private var overlayColor: Color {
        switch colorScheme {
        case .dark:
            return Color.black.opacity(0.3)
        default:
            return Color.white.opacity(0.3)
        }
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            Color("beige").ignoresSafeArea()

            VStack(spacing: 20) {
                if let currentPhone = userManager.currentUser?.phoneNumber,
                   !currentPhone.isEmpty {
                    currentPhoneSection(currentPhone: currentPhone)
                } else {
                    newPhoneSection
                }

                if !authViewModel.errorMessage.isEmpty {
                    PhoneErrorView(message: authViewModel.errorMessage)
                }

                if isVerificationSent {
                    verificationCodeSection
                }

                Spacer()
            }
            .padding()
            .background(overlayColor)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Phone Number")
                        .foregroundColor(Color("pine"))
                        .font(.headline)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .tint(Color("pine"))
            .alert("Phone Number Update", isPresented: $showAlert) {
                Button("OK") {
                    if authViewModel.isAuthenticated {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
            .onChange(of: authViewModel.isAuthenticated) { _, newValue in
                if newValue {
                    Task {
                        try await updateUserPhoneNumber()
                    }
                }
            }
            .onTapGesture {
                focusedField = nil
            }
        }
    }
}

// MARK: - View Builders
private extension ChangePhoneView {
    @ViewBuilder
    func currentPhoneSection(currentPhone: String) -> some View {
        VStack(spacing: 20) {
            Text("You can update your number and we'll send a verification to this number.")
                .font(.system(size: 14))
                .foregroundColor(Color("pine"))
                .multilineTextAlignment(.center)
                .padding(.top)

            PhoneNumberInput(
                phoneNumber: $newPhoneNumber,
                isEnabled: !authViewModel.isLoading && !isVerificationSent,
                focusedField: $focusedField,
                onPhoneNumberChange: handlePhoneNumberChange
            )
            .onAppear {
                if newPhoneNumber.isEmpty {
                    newPhoneNumber = Self.formatPhoneNumber(currentPhone)
                }
            }

            PhoneVerificationStatusView(currentPhone: currentPhone)

            if !isVerificationSent {
                nextButtonWithVerification(currentPhone: currentPhone)
            }
        }
    }

    @ViewBuilder
    var newPhoneSection: some View {
        VStack(spacing: 20) {
            Text("Enter your new phone number and we'll send a verification.")
                .font(.system(size: 14))
                .foregroundColor(Color("pine"))
                .multilineTextAlignment(.center)
                .padding(.top)

            PhoneNumberInput(
                phoneNumber: $newPhoneNumber,
                isEnabled: !authViewModel.isLoading && !isVerificationSent,
                focusedField: $focusedField,
                onPhoneNumberChange: handlePhoneNumberChange
            )

            InstructionsView()

            if !isVerificationSent {
                simpleNextButton
            }
        }
    }

    @ViewBuilder
    var verificationCodeSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Verification Code")
                    .foregroundColor(Color("pine"))
                    .font(.system(size: 16))
                    .padding(.bottom, 2)
                Spacer()
            }

            VerificationCodeInput(
                verificationCode: $verificationCode,
                isEnabled: !authViewModel.isLoading,
                focusedField: $focusedField
            )
            .onChange(of: verificationCode) { _, newValue in
                authViewModel.verificationCode = newValue
            }

            verifyButton
        }
    }

    @ViewBuilder
    func nextButtonWithVerification(currentPhone: String) -> some View {
        Button(action: {
            Task {
                let rawNumber = newPhoneNumber.filter { $0.isNumber }
                if currentPhone.filter(\.isNumber) == rawNumber {
                    authViewModel.showError = true
                    authViewModel.errorMessage = "Please enter a different phone number."
                    return
                }
                authViewModel.phoneNumber = rawNumber
                await authViewModel.sendCode()
                withAnimation {
                    isVerificationSent = true
                }
            }
        }) {
            Text("Next")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color("alwaysBeige"))
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color("pumpkin"))
                .cornerRadius(25)
        }
        .disabled(newPhoneNumber.filter(\.isNumber).isEmpty)
    }

    @ViewBuilder
    var simpleNextButton: some View {
        Button(action: {
            Task {
                let rawNumber = newPhoneNumber.filter { $0.isNumber }
                authViewModel.phoneNumber = rawNumber
                await authViewModel.sendCode()
                withAnimation {
                    isVerificationSent = true
                }
            }
        }) {
            Text("Next")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color("beige"))
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color("pumpkin"))
                .cornerRadius(25)
        }
        .disabled(newPhoneNumber.filter(\.isNumber).isEmpty)
    }

    @ViewBuilder
    var verifyButton: some View {
        Button(action: {
            Task {
                await authViewModel.verifyCode()
            }
        }) {
            Text("Verify and Update")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color("beige"))
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color("pine"))
                .cornerRadius(10)
        }
        .disabled(verificationCode.isEmpty)
    }
}

// MARK: - Helper Methods
private extension ChangePhoneView {
    func handlePhoneNumberChange(_ value: String) {
        let formatted = Self.formatPhoneNumber(value)
        newPhoneNumber = formatted
    }

    func updateUserPhoneNumber() async throws {
        let rawNumber = newPhoneNumber.filter(\.isNumber)
        try await userManager.updatePhoneNumber(rawNumber)
        showAlert = true
        alertMessage = "Phone number successfully updated"
    }

    static func formatPhoneNumber(_ number: String) -> String {
        let digits = number.filter { "0123456789".contains($0) }
        let hasCountryCode = digits.count > 10
        let last10 = String(digits.suffix(10))
        var formatted = last10

        if formatted.count > 6 {
            let areaCode = formatted.prefix(3)
            let prefix = formatted.dropFirst(3).prefix(3)
            let lineNumber = formatted.dropFirst(6)
            formatted = "(\(areaCode)) \(prefix)-\(lineNumber)"
        } else if formatted.count > 3 {
            let areaCode = formatted.prefix(3)
            let prefix = formatted.dropFirst(3)
            formatted = "(\(areaCode)) \(prefix)"
        } else if formatted.count > 0 {
            formatted = "(\(formatted)"
        }

        if hasCountryCode {
            formatted = "+1 " + formatted
        } else if number.hasPrefix("+") {
            formatted = "+1 " + formatted
        }

        return formatted
    }
}

// MARK: - PhoneNumberInput Component
private struct PhoneNumberInput: View {
    @Binding var phoneNumber: String
    let isEnabled: Bool
    @FocusState.Binding var focusedField: ChangePhoneView.Field?
    let onPhoneNumberChange: (String) -> Void

    @State private var isAnimated = false

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color("pine"), lineWidth: 2)

            Text("Phone Number")
                .font(.custom("SF Pro", size: isAnimated ? 12 : 16))
                .foregroundColor(Color("pine").opacity(0.8))
                .offset(y: isAnimated ? -14 : 0)
                .offset(x: 10)
                .animation(.spring(response: 0.2), value: isAnimated)

            HStack {
                TextField("", text: $phoneNumber)
                    .keyboardType(.numberPad)
                    .textContentType(.telephoneNumber)
                    .disabled(!isEnabled)
                    .focused($focusedField, equals: .phone)
                    .font(.custom("SF Pro", size: 16))
                    .foregroundColor(Color("pine"))
                    .padding(.leading, 12)
                    .padding(.trailing, 35)
                    .padding(.top, isAnimated ? 8 : 0)

                if !phoneNumber.isEmpty {
                    Button(action: { phoneNumber = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color("pine"))
                    }
                    .padding(.trailing, 8)
                }
            }
        }
        .frame(height: 56)
        .onChange(of: phoneNumber) { _, newValue in
            withAnimation {
                isAnimated = !newValue.isEmpty
            }
            onPhoneNumberChange(newValue)
        }
        .onAppear {
            isAnimated = !phoneNumber.isEmpty
        }
    }
}

// MARK: - VerificationCodeInput Component
private struct VerificationCodeInput: View {
    @Binding var verificationCode: String
    let isEnabled: Bool
    @FocusState.Binding var focusedField: ChangePhoneView.Field?

    @State private var isAnimated = false

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color("pine"), lineWidth: 2)

            Text("Verification Code")
                .font(.custom("SF Pro", size: isAnimated ? 12 : 16))
                .foregroundColor(Color("pine").opacity(0.8))
                .offset(y: isAnimated ? -14 : 0)
                .offset(x: 10)
                .animation(.spring(response: 0.2), value: isAnimated)

            HStack {
                TextField("", text: $verificationCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .disabled(!isEnabled)
                    .focused($focusedField, equals: .verification)
                    .font(.custom("SF Pro", size: 16))
                    .foregroundColor(Color("pine"))
                    .padding(.leading, 12)
                    .padding(.trailing, 35)
                    .padding(.top, isAnimated ? 8 : 0)

                if !verificationCode.isEmpty {
                    Button(action: { verificationCode = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color("pine"))
                    }
                    .padding(.trailing, 8)
                }
            }
        }
        .frame(height: 56)
        .onChange(of: verificationCode) { _, newValue in
            withAnimation {
                isAnimated = !newValue.isEmpty
            }
        }
        .onAppear {
            isAnimated = !verificationCode.isEmpty
        }
    }
}

// MARK: - Supporting Views
private struct PhoneVerificationStatusView: View {
    let currentPhone: String

    var body: some View {
        if !currentPhone.isEmpty {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Current number")
                    .foregroundColor(.green)
                    .font(.system(size: 14))
                Spacer()
            }
        } else {
            InstructionsView()
        }
    }
}

private struct InstructionsView: View {
    var body: some View {
        HStack {
            Image(systemName: "envelope.badge.fill")
                .foregroundColor(Color("pine"))
            Text("A verification code will be sent to the above number.")
                .font(.system(size: 14))
                .foregroundColor(Color("pine"))
                .multilineTextAlignment(.leading)
            Spacer()
        }
    }
}

private struct PhoneErrorView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(Color("beige"))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("pine"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color("pumpkin"), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .transition(.opacity.combined(with: .scale))
    }
}

// MARK: - Character Extension
extension Character {
    var isNumber: Bool { "0"..."9" ~= self }
}
