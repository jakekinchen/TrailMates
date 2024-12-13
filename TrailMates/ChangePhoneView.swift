//
//  ChangePhoneView.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on 11/21/24.
//
import SwiftUI
import UIKit

// MARK: - CurrentPhoneSection
struct CurrentPhoneSection: View {
    @Binding var newPhoneNumber: String
    @Binding var isVerificationSent: Bool
    let authViewModel: AuthViewModel
    @FocusState.Binding var focusedField: ChangePhoneView.Field?
    let handlePhoneNumberChange: (String) -> Void
    let currentPhone: String
    
    var body: some View {
        VStack(spacing: 20) {
            Text("You can update your number and we'll send a verification to this number.")
                .font(.system(size: 14))
                .foregroundColor(Color("pine"))
                .multilineTextAlignment(.center)
                .padding(.top)
            
            FloatingTextField(
                placeholder: "Phone Number",
                text: $newPhoneNumber,
                keyboardType: .numberPad,
                contentType: .telephoneNumber,
                isEnabled: !authViewModel.isLoading && !isVerificationSent,
                field: .phone,
                focusedField: $focusedField,
                showClearButton: true,
                onClear: {
                    newPhoneNumber = ""
                }
            )
            .onChange(of: newPhoneNumber) { _, newValue in
                handlePhoneNumberChange(newValue)
            }
            .onAppear {
                if newPhoneNumber.isEmpty {
                    newPhoneNumber = ChangePhoneView.formatPhoneNumber(currentPhone)
                }
            }
            
            PhoneVerificationStatusView(currentPhone: currentPhone)
            
            if !isVerificationSent {
                NextButtonWithVerification(
                    newPhoneNumber: newPhoneNumber,
                    currentPhone: currentPhone,
                    authViewModel: authViewModel,
                    isVerificationSent: $isVerificationSent
                )
            }
        }
    }
}

// MARK: - FloatingTextField
struct FloatingTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var contentType: UITextContentType?
    var isEnabled: Bool = true
    var field: ChangePhoneView.Field
    @FocusState.Binding var focusedField: ChangePhoneView.Field?
    var showClearButton: Bool
    var onClear: () -> Void
    
    @State private var isAnimated = false
    
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color("pine"), lineWidth: 2)
            
            Text(placeholder)
                .font(.custom("SF Pro", size: isAnimated ? 12 : 16))
                .foregroundColor(Color("pine").opacity(0.8))
                .offset(y: isAnimated ? -14 : 0)
                .offset(x: 10)
                .animation(.spring(response: 0.2), value: isAnimated)
            
            HStack {
                TextField("", text: $text)
                    .keyboardType(keyboardType)
                    .textContentType(contentType)
                    .disabled(!isEnabled)
                    .focused($focusedField, equals: field)
                    .font(.custom("SF Pro", size: 16))
                    .foregroundColor(Color("pine"))
                    .padding(.leading, 12)
                    .padding(.trailing, showClearButton ? 35 : 12)
                    .padding(.top, isAnimated ? 8 : 0)
                
                if showClearButton && !text.isEmpty {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color("pine"))
                    }
                    .padding(.trailing, 8)
                }
            }
        }
        .frame(height: 56)
        .onChange(of: text) { _, newValue in
            withAnimation {
                isAnimated = !newValue.isEmpty
            }
        }
        .onAppear {
            isAnimated = !text.isEmpty
        }
    }
}


// MARK: - NewPhoneSection
struct NewPhoneSection: View {
    @Binding var newPhoneNumber: String
    @Binding var isVerificationSent: Bool
    let authViewModel: AuthViewModel
    @FocusState.Binding var focusedField: ChangePhoneView.Field?
    let handlePhoneNumberChange: (String) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Enter your new phone number and we'll send a verification.")
                .font(.system(size: 14))
                .foregroundColor(Color("pine"))
                .multilineTextAlignment(.center)
                .padding(.top)
            
            FloatingTextField(
                placeholder: "Phone number",
                text: $newPhoneNumber,
                keyboardType: .numberPad,
                contentType: .telephoneNumber,
                isEnabled: !authViewModel.isLoading && !isVerificationSent,
                field: .phone,
                focusedField: $focusedField,
                showClearButton: true,
                onClear: {
                    newPhoneNumber = ""
                }
            )
            .onChange(of: newPhoneNumber) { _, newValue in
                handlePhoneNumberChange(newValue)
            }
            
            InstructionsView()
            
            if !isVerificationSent {
                SimpleNextButton(
                    newPhoneNumber: newPhoneNumber,
                    authViewModel: authViewModel,
                    isVerificationSent: $isVerificationSent
                )
            }
        }
    }
}

// MARK: - VerificationCodeSection
struct VerificationCodeSection: View {
    @Binding var verificationCode: String
    let authViewModel: AuthViewModel
    @FocusState.Binding var focusedField: ChangePhoneView.Field?
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Verification Code")
                    .foregroundColor(Color("pine"))
                    .font(.system(size: 16))
                    .padding(.bottom, 2)
                Spacer()
            }
            
            FloatingTextField(
                placeholder: "Phone Number",
                text: $verificationCode,
                keyboardType: .numberPad,
                contentType: .oneTimeCode,
                isEnabled: !authViewModel.isLoading,
                field: .verification,
                focusedField: $focusedField,
                showClearButton: true,
                onClear: {
                    verificationCode = ""
                }
            )
            .onChange(of: verificationCode) { _, newValue in
                authViewModel.verificationCode = newValue
            }
            
            VerifyButton(
                verificationCode: verificationCode,
                authViewModel: authViewModel
            )
        }
    }
}

// MARK: - Supporting Views
struct PhoneVerificationStatusView: View {
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

struct InstructionsView: View {
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

struct ErrorView: View {
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

// MARK: - Button Views
struct NextButtonWithVerification: View {
    let newPhoneNumber: String
    let currentPhone: String
    let authViewModel: AuthViewModel
    @Binding var isVerificationSent: Bool
    
    var body: some View {
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
}

struct SimpleNextButton: View {
    let newPhoneNumber: String
    let authViewModel: AuthViewModel
    @Binding var isVerificationSent: Bool
    
    var body: some View {
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
}

struct VerifyButton: View {
    let verificationCode: String
    let authViewModel: AuthViewModel
    
    var body: some View {
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

 var baseBackground: Color {
        Color("beige")
    }

// MARK: - Main View
struct ChangePhoneView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var userManager: UserManager
    @StateObject private var authViewModel = AuthViewModel()
    
    enum Field {
        case phone, verification
    }
    
    @State private var newPhoneNumber = ""
    @State private var verificationCode = ""
    @State private var isVerificationSent = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @FocusState private var focusedField: Field?
            
    private var overlayColor: Color {
        switch colorScheme {
        case .dark:
            return Color.black.opacity(0.3)
        default:
            return Color.white.opacity(0.3)
            }
        }
    
    static func formatPhoneNumber(_ number: String) -> String {
        let digits = number.filter { "0123456789".contains($0) }
        let hasCountryCode = digits.count > 10
        let last10 = String(digits.suffix(10))
        var formatted = last10
        
        // Format the main phone number
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
        
        // Add country code if it exists in the original number
        if hasCountryCode {
            formatted = "+1 " + formatted
        } else if number.hasPrefix("+") {
            // If the original had a plus but no country code, still add the +1
            formatted = "+1 " + formatted
        }
        
        return formatted
    }
    
    private func handlePhoneNumberChange(_ value: String) {
        let formatted = Self.formatPhoneNumber(value)
        newPhoneNumber = formatted
    }
    
    var body: some View {
        ZStack {
            Color("beige").ignoresSafeArea()
            
            VStack(spacing: 20) {
                if let currentPhone = userManager.currentUser?.phoneNumber,
                   !currentPhone.isEmpty {
                    CurrentPhoneSection(
                        newPhoneNumber: $newPhoneNumber,
                        isVerificationSent: $isVerificationSent,
                        authViewModel: authViewModel,
                        focusedField: $focusedField,
                        handlePhoneNumberChange: handlePhoneNumberChange,
                        currentPhone: currentPhone
                    )
                } else {
                    NewPhoneSection(
                        newPhoneNumber: $newPhoneNumber,
                        isVerificationSent: $isVerificationSent,
                        authViewModel: authViewModel,
                        focusedField: $focusedField,
                        handlePhoneNumberChange: handlePhoneNumberChange
                    )
                }
                
                if !authViewModel.errorMessage.isEmpty {
                    ErrorView(message: authViewModel.errorMessage)
                }
                
                if isVerificationSent {
                    VerificationCodeSection(
                        verificationCode: $verificationCode,
                        authViewModel: authViewModel,
                        focusedField: $focusedField
                    )
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
    private func updateUserPhoneNumber() async throws {
            let rawNumber = newPhoneNumber.filter(\.isNumber)
            try await userManager.updatePhoneNumber(rawNumber)
            showAlert = true
            alertMessage = "Phone number successfully updated"
        }
    }

    extension Character {
        var isNumber: Bool { "0"..."9" ~= self }
    }
