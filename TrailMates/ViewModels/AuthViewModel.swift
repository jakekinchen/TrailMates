//
//  AuthViewModel.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on 11/19/24.
//

import SwiftUI
import FirebaseAuth

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var verificationId: String?
    @Published var isLoading = false
    @Published var isVerifying = false
    @Published var phoneNumber = ""
    @Published var verificationCode = ""
    @Published var isSigningUp = false
    
    private let auth = Auth.auth()
    private let userManager = UserManager.shared
    
    func sendCode() async {
        isLoading = true
        showError = false
        
        do {
            let formattedNumber = try formatPhoneNumber(phoneNumber)
            PhoneAuthProvider.provider()
                .verifyPhoneNumber(formattedNumber, uiDelegate: nil) { [weak self] verificationId, error in
                    guard let self = self else { return }
                    
                    Task { @MainActor in
                        self.isLoading = false
                        
                        if let error = error {
                            self.showError = true
                            self.errorMessage = error.localizedDescription
                            return
                        }
                        
                        if let verificationId = verificationId {
                            self.verificationId = verificationId
                            self.isVerifying = true
                        }
                    }
                }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.showError = true
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func verifyCode() async {
        guard let verificationId = verificationId else {
            showError = true
            errorMessage = "Missing verification ID"
            return
        }
        
        isLoading = true
        showError = false
        
        do {
            let credential = PhoneAuthProvider.provider().credential(
                withVerificationID: verificationId,
                verificationCode: verificationCode
            )
            
            // First authenticate with Firebase
            print("Firebase UID after sign-in:", Auth.auth().currentUser?.uid ?? "No user")
            let authResult = try await auth.signIn(with: credential)
            print("Firebase UID after sign-in:", Auth.auth().currentUser?.uid ?? "No user")
            print("🔐 Successfully signed in with phone auth")
            
            do { 
                // Check if user exists in our database
                let userExists = await userManager.checkUserExists(phoneNumber: phoneNumber)
                
                if isSigningUp && userExists {
                    // Prevent existing users from using signup
                    throw AppError.alreadyExists("An account with this phone number already exists. Please use the login option.")
                } else if !isSigningUp && !userExists {
                    // Prevent non-existent users from using login
                    throw AppError.notFound("No account found with this phone number. Please sign up first.")
                }
                
                if isSigningUp {
                    // For signup, create new user with Firebase UID
                    try await userManager.createNewUser(phoneNumber: phoneNumber, id: authResult.user.uid)
                    print("📱 New user created successfully")
                } else {
                    // For login, initialize existing user
                    try await userManager.login(phoneNumber: phoneNumber, id: authResult.user.uid)
                    print("📱 Existing user logged in successfully")
                }
                
                // Update UI state after successful operation
                await MainActor.run {
                    self.isAuthenticated = true
                    userManager.isLoggedIn = true
                    self.isLoading = false
                    self.isVerifying = false
                    print("✅ Auth state updated: isAuthenticated=true, isLoggedIn=true")
                }
            } catch {
                let appError = AppError.from(error)
                #if DEBUG
                print("User initialization failed: \(appError.errorDescription ?? "Unknown")")
                #endif
                // If initialization fails, sign out to maintain consistent state
                try? auth.signOut()
                #if DEBUG
                print("Auth: User signed out")
                #endif
                throw appError
            }
        } catch {
            let appError = AppError.from(error)
            #if DEBUG
            print("Verification failed: \(appError.errorDescription ?? "Unknown")")
            #endif
            await MainActor.run {
                self.showError = true
                self.errorMessage = appError.errorDescription ?? "An error occurred"
                self.isLoading = false
                self.isVerifying = false
                self.isAuthenticated = false
                userManager.isLoggedIn = false
            }
        }
    }

    private func formatPhoneNumber(_ number: String) throws -> String {
        // Remove any non-numeric characters
        let cleanNumber = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()

        // Check if the number starts with "+" already
        if number.hasPrefix("+") {
            return number
        }

        // Add "+1" prefix if not present for US numbers
        if cleanNumber.count == 10 {
            return "+1\(cleanNumber)"
        } else if cleanNumber.count == 11 && cleanNumber.hasPrefix("1") {
            return "+\(cleanNumber)"
        }

        throw AppError.invalidInput("Invalid phone number format")
    }
    
    func signOut() async {
        do {
            try Auth.auth().signOut()
            isAuthenticated = false
            await userManager.signOut()
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
    }
}
