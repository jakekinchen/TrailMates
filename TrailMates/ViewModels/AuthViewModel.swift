//
//  AuthViewModel.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on 11/19/24.
//


// ViewModels/AuthViewModel.swift

import SwiftUI
import FirebaseAuth

class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var verificationID: String?
    @Published var errorMessage: String?
    
    private let userManager: UserManager
        
        init(userManager: UserManager) {
            self.userManager = userManager
        }
    

    func sendVerificationCode(to phoneNumber: String) {
        // Validate the phone number
        guard let formattedPhoneNumber = validatePhoneNumber(phoneNumber) else {
            DispatchQueue.main.async {
                self.errorMessage = "Invalid phone number. Please enter a valid US phone number."
            }
            print("Phone number validation failed: \(phoneNumber)") // Debugging invalid number
            return
        }

        print("Sending verification code to: \(formattedPhoneNumber)") // Debugging formatted number
        
        PhoneAuthProvider.provider().verifyPhoneNumber(formattedPhoneNumber, uiDelegate: nil) { [weak self] verificationID, error in
            if let error = error {
                        print("Error during phone verification: \(error.localizedDescription)") // Log Firebase error description
                        if let nsError = error as NSError? {
                            print("Firebase Auth error details: \(nsError.userInfo)") // Log detailed Firebase error info
                            print("Error code: \(nsError.code)") // Log specific error code
                        }
                        DispatchQueue.main.async {
                            self?.errorMessage = error.localizedDescription
                        }
                        return
                    }
            
            print("Verification ID received: \(verificationID ?? "None")") // Debugging verification ID
            DispatchQueue.main.async {
                self?.verificationID = verificationID
            }
        }
    }
    
    private func validatePhoneNumber(_ phoneNumber: String) -> String? {
        // Remove all non-numeric characters
        let digitsOnly = phoneNumber.filter { $0.isNumber }

        // Case 1: Valid 10-digit number (no country code)
        if digitsOnly.count == 10 {
            return "+1\(digitsOnly)"
        }

        // Case 2: Valid 11-digit number starting with '1' (country code without '+')
        if digitsOnly.count == 11, digitsOnly.first == "1" {
            let remainingDigits = digitsOnly.dropFirst()
            return "+1\(remainingDigits)"
        }

        // Invalid if not 10 or 11 digits
        print("Invalid phone number: \(digitsOnly)") // Debugging
        return nil
    }

    func verifyCode(_ code: String) {
        print("Starting code verification...")
        guard let verificationID = verificationID else {
            print("Error: No verification ID found")
            return
        }
        print("Creating credential with verification ID: \(verificationID)")
        
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: code
        )
        
        print("Attempting to sign in with credential...")
        Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            guard let self = self else {
                print("Self is nil in completion handler")
                return
            }
            
            if let error = error {
                print("Firebase Auth Error: \(error.localizedDescription)")
                print("Error details: \(String(describing: error))")
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                }
                return
            }
            
            print("Successfully signed in with Firebase Auth")
            
            // Get the phone number from the authenticated user
            if let phoneNumber = Auth.auth().currentUser?.phoneNumber {
                print("Got phone number from Auth: \(phoneNumber)")
                Task {
                    print("Starting user login process...")
                    // Let UserManager handle the login/signup logic
                    await self.userManager.login(phoneNumber: phoneNumber)
                    
                    print("Login complete, updating UI...")
                    DispatchQueue.main.async {
                        self.isAuthenticated = true
                        print("Authentication state updated: \(self.isAuthenticated)")
                    }
                }
            } else {
                print("Error: No phone number found in Auth.auth().currentUser")
            }
        }
    }

    @MainActor
    func signOut() {
        do {
            try Auth.auth().signOut()
            isAuthenticated = false
            verificationID = nil
            userManager.logout()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
