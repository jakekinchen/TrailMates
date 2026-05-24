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
    @EnvironmentObject private var userManager: UserManager

    // MARK: - State
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var newPhoneNumber = ""
    @State private var verificationCode = ""
    @State private var isVerificationSent = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @FocusState private var focusedField: Field?

    // MARK: - Body
    var body: some View {
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
        .themedBackground()
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

            FloatingLabelTextField(
                placeholder: "Phone Number",
                text: $newPhoneNumber,
                keyboardType: .numberPad,
                textContentType: .telephoneNumber,
                isEnabled: !authViewModel.isLoading && !isVerificationSent,
                colorStyle: .outline,
                showClearButton: true,
                field: ChangePhoneView.Field.phone,
                focusedField: $focusedField,
                onChange: { _, newValue in handlePhoneNumberChange(newValue) }
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

            FloatingLabelTextField(
                placeholder: "Phone Number",
                text: $newPhoneNumber,
                keyboardType: .numberPad,
                textContentType: .telephoneNumber,
                isEnabled: !authViewModel.isLoading && !isVerificationSent,
                colorStyle: .outline,
                showClearButton: true,
                field: ChangePhoneView.Field.phone,
                focusedField: $focusedField,
                onChange: { _, newValue in handlePhoneNumberChange(newValue) }
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

            FloatingLabelTextField(
                placeholder: "Verification Code",
                text: $verificationCode,
                keyboardType: .numberPad,
                textContentType: .oneTimeCode,
                isEnabled: !authViewModel.isLoading,
                characterLimit: 6,
                colorStyle: .outline,
                showClearButton: true,
                field: ChangePhoneView.Field.verification,
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
                if await authViewModel.sendCode() {
                    withAnimation {
                        isVerificationSent = true
                    }
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
                if await authViewModel.sendCode() {
                    withAnimation {
                        isVerificationSent = true
                    }
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
        // For complete numbers, delegate to PhoneNumberService for accurate formatting
        if let formatted = PhoneNumberService.shared.format(number, for: .display) {
            return formatted
        }
        // Fall back to simple digit grouping for partial input (as-you-type)
        let digits = number.filter { $0.isNumber }
        if digits.isEmpty { return "" }

        let hasCountryCode = digits.count > 10 || number.hasPrefix("+")
        let last10 = String(digits.suffix(10))

        var formatted: String
        if last10.count > 6 {
            let areaCode = last10.prefix(3)
            let prefix = last10.dropFirst(3).prefix(3)
            let lineNumber = last10.dropFirst(6)
            formatted = "(\(areaCode)) \(prefix)-\(lineNumber)"
        } else if last10.count > 3 {
            let areaCode = last10.prefix(3)
            let prefix = last10.dropFirst(3)
            formatted = "(\(areaCode)) \(prefix)"
        } else {
            formatted = "(\(last10)"
        }

        if hasCountryCode {
            formatted = "+1 " + formatted
        }

        return formatted
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
