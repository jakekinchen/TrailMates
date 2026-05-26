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
    private let providers = FirebaseProviderContainer.shared

    /// Monotonically increasing counter to discard stale verification callbacks.
    /// Each verification request increments this; callbacks from earlier attempts are ignored.
    private var sendCodeAttempt: UInt = 0
    
    @discardableResult
    func sendCode() async -> Bool {
        do {
            let formattedNumber = try formatPhoneNumber(phoneNumber)
            phoneNumber = formattedNumber
            return await requestVerificationCode(for: formattedNumber)
        } catch {
            present(error)
            return false
        }
    }

    @discardableResult
    func sendPhoneChangeCode(to newPhoneNumber: String) async -> Bool {
        do {
            guard auth.currentUser != nil else {
                throw AppError.notAuthenticated()
            }

            let formattedNumber = try formatPhoneNumber(newPhoneNumber)
            if isCurrentPhoneNumber(formattedNumber) {
                throw AppError.invalidInput("Please enter a different phone number.")
            }

            if await userManager.checkUserExists(phoneNumber: formattedNumber) {
                throw AppError.alreadyExists("Phone number already registered")
            }

            phoneNumber = formattedNumber
            verificationCode = ""
            isSigningUp = false
            return await requestVerificationCode(for: formattedNumber)
        } catch {
            present(error)
            return false
        }
    }

    @discardableResult
    func verifyPhoneChangeCode() async throws -> String {
        guard let verificationId = verificationId else {
            let error = AppError.invalidData("Missing verification ID")
            present(error)
            throw error
        }

        guard let currentUser = auth.currentUser else {
            let error = AppError.notAuthenticated()
            present(error)
            throw error
        }

        let formattedNumber = try formatPhoneNumber(phoneNumber)
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationId,
            verificationCode: verificationCode
        )

        isLoading = true
        showError = false
        defer { isLoading = false }

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                currentUser.updatePhoneNumber(credential) { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }

            phoneNumber = formattedNumber
            self.verificationId = nil
            verificationCode = ""
            isVerifying = false
            return formattedNumber
        } catch {
            let appError = try AppError.from(error)
            showError = true
            errorMessage = appError.errorDescription ?? "Unable to update phone number."
            throw appError
        }
    }

    private func requestVerificationCode(for formattedNumber: String) async -> Bool {
        // Increment the attempt counter so any in-flight callback from a prior call is ignored.
        sendCodeAttempt &+= 1
        let currentAttempt = sendCodeAttempt

        isLoading = true
        showError = false

        return await withCheckedContinuation { continuation in
            PhoneAuthProvider.provider()
                .verifyPhoneNumber(formattedNumber, uiDelegate: nil) { [weak self] verificationId, error in
                    guard let self = self else {
                        continuation.resume(returning: false)
                        return
                    }

                    Task { @MainActor in
                        // Discard this callback if a newer attempt has been started.
                        guard self.sendCodeAttempt == currentAttempt else {
                            continuation.resume(returning: false)
                            return
                        }

                        self.isLoading = false

                        if let error = error {
                            self.present(error)
                            continuation.resume(returning: false)
                            return
                        }

                        guard let verificationId = verificationId else {
                            self.showError = true
                            self.errorMessage = "Unable to start phone verification. Please try again."
                            continuation.resume(returning: false)
                            return
                        }

                        self.verificationId = verificationId
                        self.isVerifying = true
                        continuation.resume(returning: true)
                    }
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
            let formattedPhoneNumber = try formatPhoneNumber(phoneNumber)
            phoneNumber = formattedPhoneNumber

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
                let userExists = await userManager.checkUserExists(phoneNumber: formattedPhoneNumber)
                
                if isSigningUp && userExists {
                    // Prevent existing users from using signup
                    throw AppError.alreadyExists("An account with this phone number already exists. Please use the login option.")
                } else if !isSigningUp && !userExists {
                    // Prevent non-existent users from using login
                    throw AppError.notFound("No account found with this phone number. Please sign up first.")
                }
                
                if isSigningUp {
                    // For signup, create new user with Firebase UID
                    try await userManager.createNewUser(phoneNumber: formattedPhoneNumber, id: authResult.user.uid)
                    print("📱 New user created successfully")
                } else {
                    // For login, initialize existing user
                    try await userManager.login(phoneNumber: formattedPhoneNumber, id: authResult.user.uid)
                    print("📱 Existing user logged in successfully")
                }
                
                // Update UI state after successful operation
                self.isAuthenticated = true
                userManager.isLoggedIn = true
                self.isLoading = false
                self.isVerifying = false
                print("✅ Auth state updated: isAuthenticated=true, isLoggedIn=true")
            } catch {
                let appError = AppError.classify(error)
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
            let appError = AppError.classify(error)
            #if DEBUG
            print("Verification failed: \(appError.errorDescription ?? "Unknown")")
            #endif
            self.showError = true
            self.errorMessage = appError.errorDescription ?? "An error occurred"
            self.isLoading = false
            self.isVerifying = false
            self.isAuthenticated = false
            userManager.isLoggedIn = false
        }
    }

    /// Result of a login/signup attempt indicating what the view should do next.
    enum PhoneSubmitResult {
        case showFields       // Phone was empty, just show the input fields
        case codeSent         // Verification code was sent successfully
        case failed           // Error occurred (errorMessage is already set)
    }

    /// Handles login flow: checks if user exists, then sends verification code.
    func handleLogin(phoneNumber: String) async -> PhoneSubmitResult {
        guard !phoneNumber.isEmpty else {
            return .showFields
        }

        #if DEBUG
        print("Login - Starting phone number check: \(phoneNumber)")
        print("Login - Checking if user exists")
        #endif

        let formattedPhoneNumber: String
        do {
            formattedPhoneNumber = try formatPhoneNumber(phoneNumber)
        } catch {
            present(error)
            return .failed
        }

        if await userManager.checkUserExists(phoneNumber: formattedPhoneNumber) {
            #if DEBUG
            print("Login - User found, proceeding with verification")
            #endif
            self.phoneNumber = formattedPhoneNumber
            self.isSigningUp = false
            if await sendCode() {
                return .codeSent
            } else {
                return .failed
            }
        } else {
            #if DEBUG
            print("Login - No user found with phone number")
            #endif
            showError = true
            errorMessage = "No account found with this phone number. Please sign up instead."
            return .failed
        }
    }

    /// Handles signup flow: checks user does not exist, then sends verification code.
    func handleSignup(phoneNumber: String) async -> PhoneSubmitResult {
        guard !phoneNumber.isEmpty else {
            return .showFields
        }

        let formattedPhoneNumber: String
        do {
            formattedPhoneNumber = try formatPhoneNumber(phoneNumber)
        } catch {
            present(error)
            return .failed
        }

        if await userManager.checkUserExists(phoneNumber: formattedPhoneNumber) {
            showError = true
            errorMessage = "An account already exists with this phone number. Please log in instead."
            return .failed
        }

        self.phoneNumber = formattedPhoneNumber
        self.isSigningUp = true
        if await sendCode() {
            return .codeSent
        } else {
            return .failed
        }
    }

    private func formatPhoneNumber(_ number: String) throws -> String {
        guard let formatted = PhoneNumberService.shared.format(number, for: .storage) else {
            throw AppError.invalidInput("Invalid phone number format")
        }
        return formatted
    }

    private func isCurrentPhoneNumber(_ formattedNumber: String) -> Bool {
        let candidates = [
            userManager.currentUser?.phoneNumber,
            auth.currentUser?.phoneNumber
        ]

        return candidates.contains { candidate in
            guard let candidate else { return false }
            return PhoneNumberService.shared.format(candidate, for: .storage) == formattedNumber
        }
    }

    private func present(_ error: Error) {
        let appError = AppError.classify(error)
        isLoading = false
        showError = true
        errorMessage = appError.errorDescription ?? "An error occurred"
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

    /// Permanently deletes the user's account and all associated data
    func deleteAccount() async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw AppError.notAuthenticated()
        }

        let userId = currentUser.uid
        let friendIds = userManager.currentUser?.friends ?? []

        #if DEBUG
        print("🗑️ Starting account deletion for user: \(userId)")
        #endif

        // 1. Delete profile images from Storage
        #if DEBUG
        print("   1. Deleting profile images...")
        #endif
        await providers.imageProvider.deleteOldProfileImage(for: userId)

        // 2. Delete notifications from RTDB
        #if DEBUG
        print("   2. Deleting notifications...")
        #endif
        do {
            try await providers.notificationProvider.deleteAllNotifications(for: userId)
        } catch {
            #if DEBUG
            print("   ⚠️ Error deleting notifications: \(error.localizedDescription)")
            #endif
            // Continue even if this fails
        }

        // 3. Delete friend requests from RTDB
        #if DEBUG
        print("   3. Deleting friend requests...")
        #endif
        do {
            try await providers.friendProvider.deleteAllFriendRequests(for: userId)
        } catch {
            #if DEBUG
            print("   ⚠️ Error deleting friend requests: \(error.localizedDescription)")
            #endif
        }

        // 4. Delete location data from RTDB
        #if DEBUG
        print("   4. Deleting location data...")
        #endif
        do {
            try await providers.locationProvider.deleteUserLocation(userId: userId)
        } catch {
            #if DEBUG
            print("   ⚠️ Error deleting location: \(error.localizedDescription)")
            #endif
        }

        // 5. Remove user from friends' friend lists
        #if DEBUG
        print("   5. Removing from friends' lists...")
        #endif
        do {
            try await providers.friendProvider.removeUserFromAllFriendLists(userId: userId, friendIds: friendIds)
        } catch {
            #if DEBUG
            print("   ⚠️ Error removing from friend lists: \(error.localizedDescription)")
            #endif
        }

        // 6. Delete user document from Firestore
        #if DEBUG
        print("   6. Deleting user document...")
        #endif
        do {
            try await providers.userProvider.deleteUserDocument(userId: userId)
        } catch {
            #if DEBUG
            print("   ⚠️ Error deleting user document: \(error.localizedDescription)")
            #endif
            // This is critical - rethrow if it fails
            throw error
        }

        // 7. Delete Firebase Auth account
        #if DEBUG
        print("   7. Deleting Firebase Auth account...")
        #endif
        do {
            try await currentUser.delete()
        } catch {
            #if DEBUG
            print("   ❌ Error deleting Auth account: \(error.localizedDescription)")
            #endif
            throw try AppError.from(error)
        }

        // 8. Clear local state
        #if DEBUG
        print("   8. Clearing local state...")
        #endif
        self.isAuthenticated = false
        await userManager.signOut()

        #if DEBUG
        print("✅ Account deletion completed successfully")
        #endif
    }
}
