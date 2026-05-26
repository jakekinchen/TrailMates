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
                    .foregroundColor(AppColors.pine)
                    .font(.headline)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .tint(AppColors.pine)
        .alert("Phone Number Update", isPresented: $showAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(alertMessage)
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
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.pine)
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
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.pine)
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
                    .foregroundColor(AppColors.pine)
                    .font(AppTypography.bodyPrimary)
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
        PrimaryButton("Next", isDisabled: newPhoneNumber.filter(\.isNumber).isEmpty) {
            Task {
                await sendPhoneChangeCode(currentPhone: currentPhone)
            }
        }
    }

    @ViewBuilder
    var simpleNextButton: some View {
        PrimaryButton("Next", isDisabled: newPhoneNumber.filter(\.isNumber).isEmpty) {
            Task {
                await sendPhoneChangeCode(currentPhone: nil)
            }
        }
    }

    @ViewBuilder
    var verifyButton: some View {
        Button(action: {
            Task {
                await verifyAndUpdatePhoneNumber()
            }
        }) {
            Text("Verify and Update")
                .font(AppTypography.buttonDefault)
                .foregroundColor(AppColors.beige)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppColors.pine)
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

    func sendPhoneChangeCode(currentPhone: String?) async {
        do {
            let storagePhoneNumber = try storagePhoneNumber(from: newPhoneNumber)
            if let currentPhone,
               PhoneNumberService.shared.format(currentPhone, for: .storage) == storagePhoneNumber {
                throw AppError.invalidInput("Please enter a different phone number.")
            }

            if await authViewModel.sendPhoneChangeCode(to: storagePhoneNumber) {
                withAnimation {
                    isVerificationSent = true
                }
                focusedField = .verification
            }
        } catch is CancellationError {
            return
        } catch {
            present(error)
        }
    }

    func verifyAndUpdatePhoneNumber() async {
        do {
            authViewModel.verificationCode = verificationCode
            let verifiedPhoneNumber = try await authViewModel.verifyPhoneChangeCode()
            try await userManager.updatePhoneNumber(verifiedPhoneNumber)
            showAlert = true
            alertMessage = "Phone number successfully updated"
        } catch is CancellationError {
            return
        } catch {
            present(error)
        }
    }

    func storagePhoneNumber(from number: String) throws -> String {
        guard let storageNumber = PhoneNumberService.shared.format(number, for: .storage) else {
            throw AppError.invalidInput("Invalid phone number format")
        }
        return storageNumber
    }

    func present(_ error: Error) {
        let appError = AppError.classify(error)
        authViewModel.showError = true
        authViewModel.errorMessage = appError.errorDescription ?? "Unable to update phone number."
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
                    .font(AppTypography.bodySmall)
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
                .foregroundColor(AppColors.pine)
            Text("A verification code will be sent to the above number.")
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.pine)
                .multilineTextAlignment(.leading)
            Spacer()
        }
    }
}

private struct PhoneErrorView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(AppTypography.labelPrimary)
            .foregroundColor(AppColors.beige)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.pine)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.pumpkin, lineWidth: 1)
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
