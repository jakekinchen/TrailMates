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
    
    @discardableResult
    func sendCode() async -> Bool {
        isLoading = true
        showError = false
        
        do {
            let formattedNumber = try formatPhoneNumber(phoneNumber)
            return await withCheckedContinuation { continuation in
                PhoneAuthProvider.provider()
                    .verifyPhoneNumber(formattedNumber, uiDelegate: nil) { [weak self] verificationId, error in
                        guard let self = self else {
                            continuation.resume(returning: false)
                            return
                        }

                        Task { @MainActor in
                            self.isLoading = false

                            if let error = error {
                                self.showError = true
                                self.errorMessage = error.localizedDescription
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
        } catch {
            self.isLoading = false
            self.showError = true
            self.errorMessage = error.localizedDescription
            return false
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
                self.isAuthenticated = true
                userManager.isLoggedIn = true
                self.isLoading = false
                self.isVerifying = false
                print("✅ Auth state updated: isAuthenticated=true, isLoggedIn=true")
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
            self.showError = true
            self.errorMessage = appError.errorDescription ?? "An error occurred"
            self.isLoading = false
            self.isVerifying = false
            self.isAuthenticated = false
            userManager.isLoggedIn = false
        }
    }

    private func formatPhoneNumber(_ number: String) throws -> String {
        guard let formatted = PhoneNumberService.shared.format(number, for: .storage) else {
            throw AppError.invalidInput("Invalid phone number format")
        }
        return formatted
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
            throw AppError.from(error)
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
