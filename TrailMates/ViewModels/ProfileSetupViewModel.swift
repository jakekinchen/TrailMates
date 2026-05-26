//
//  ProfileSetupViewModel.swift
//  TrailMatesATX
//

import SwiftUI

@MainActor
class ProfileSetupViewModel: ObservableObject {
    // MARK: - Published State
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var username: String = ""
    @Published var profileImage: UIImage?
    @Published var hasSelectedNewProfileImage = false
    @Published var isLoading = false
    @Published var showAlert = false
    @Published var alertMessage = ""

    // MARK: - Dependencies
    private let userManager: UserManager

    init(userManager: UserManager) {
        self.userManager = userManager
    }

    // MARK: - Setup
    func setupFromCurrentUser() async {
        #if DEBUG
        print("\n ProfileSetupViewModel - Setting up from current user")
        #endif
        if let user = userManager.currentUser {
            #if DEBUG
            print("Current User State:")
            print("   First Name: '\(user.firstName)'")
            print("   Last Name: '\(user.lastName)'")
            print("   Username: '\(user.username)'")
            #endif

            firstName = user.firstName
            lastName = user.lastName
            username = user.username
            if let imageData = user.profileImageData,
               let image = UIImage(data: imageData) {
                profileImage = image
                #if DEBUG
                print("   Profile Image: Loaded from local data")
                #endif
            } else if let image = try? await userManager.fetchProfileImage(for: user, forceRefresh: true) {
                profileImage = image
                #if DEBUG
                print("   Profile Image: Loaded from provider")
                #endif
            } else {
                #if DEBUG
                print("   Profile Image: Not available")
                #endif
            }
        } else {
            #if DEBUG
            print("No current user available during setup")
            #endif
        }
    }

    // MARK: - Save Profile
    /// Saves the profile and returns whether the caller should dismiss (edit mode) or persist session (new setup).
    /// Returns `true` if the save completed successfully.
    func saveProfile(isEditMode: Bool) async throws -> Bool {
        #if DEBUG
        print("\n ProfileSetupViewModel - Starting Save Profile")
        print("Current State Variables:")
        print("   First Name: '\(firstName)'")
        print("   Last Name: '\(lastName)'")
        print("   Username: '\(username)'")
        print("   Has Profile Image: \(profileImage != nil)")
        #endif

        isLoading = true
        defer { isLoading = false }

        #if DEBUG
        print("\n Validating Inputs...")
        #endif
        guard await validateInputs() else {
            #if DEBUG
            print("Input validation failed")
            #endif
            return false
        }
        #if DEBUG
        print("Input validation passed")
        #endif

        #if DEBUG
        print("\n Updating User Profile...")
        #endif
        try await updateUserProfile()
        #if DEBUG
        print("User profile updated")
        #endif

        if !isEditMode {
            userManager.persistUserSession()
        }
        return true
    }

    // MARK: - Validation
    func validateInputs() async -> Bool {
        #if DEBUG
        print("\n Validating Profile Inputs")
        print("Current Values:")
        print("   First Name: '\(firstName)'")
        print("   Last Name: '\(lastName)'")
        print("   Username: '\(username)'")
        #endif

        guard !firstName.isEmpty else {
            #if DEBUG
            print("First name is empty")
            #endif
            alertMessage = "Please enter a first name."
            showAlert = true
            return false
        }

        guard !lastName.isEmpty else {
            #if DEBUG
            print("Last name is empty")
            #endif
            alertMessage = "Please enter a last name."
            showAlert = true
            return false
        }

        guard !username.isEmpty else {
            #if DEBUG
            print("Username is empty")
            #endif
            alertMessage = "Please enter a username."
            showAlert = true
            return false
        }

        let usernameRegex = "^[a-zA-Z0-9_]{1,20}$"
        guard username.range(of: usernameRegex, options: .regularExpression) != nil else {
            #if DEBUG
            print("Username format invalid")
            #endif
            alertMessage = "Username can only contain letters, numbers, and underscores, and must be between 1-20 characters."
            showAlert = true
            return false
        }

        if await userManager.isUsernameTaken(username) {
            #if DEBUG
            print("Username is already taken")
            #endif
            alertMessage = "This username is already taken. Please choose another."
            showAlert = true
            return false
        }

        #if DEBUG
        print("All validations passed")
        #endif
        return true
    }

    func presentError(_ error: Error, fallbackMessage: String) {
        let appError = AppError.classify(error)
        alertMessage = appError.errorDescription ?? fallbackMessage
        showAlert = true
    }

    // MARK: - Update User Profile
    func updateUserProfile() async throws {
        #if DEBUG
        print("\n Updating User Profile")
        #endif
        guard let oldUser = userManager.currentUser else {
            #if DEBUG
            print("Error: No current user available")
            #endif
            alertMessage = "Error: No user found. Please try logging in again."
            showAlert = true
            throw AppError.notAuthenticated()
        }

        #if DEBUG
        print("Current User Before Update:")
        print("   ID: \(oldUser.id)")
        print("   First Name: '\(oldUser.firstName)'")
        print("   Last Name: '\(oldUser.lastName)'")
        print("   Username: '\(oldUser.username)'")
        #endif

        let wasProfileIncomplete = oldUser.firstName.isEmpty ||
                                  oldUser.lastName.isEmpty ||
                                  oldUser.username.isEmpty

        let user = oldUser
        user.firstName = firstName
        user.lastName = lastName
        user.username = username

        #if DEBUG
        if wasProfileIncomplete {
            print("Initial profile setup detected - will force save")
        }
        #endif

        if hasSelectedNewProfileImage, let image = profileImage {
            #if DEBUG
            print("Uploading profile image...")
            #endif
            try await userManager.setProfileImage(image)
            #if DEBUG
            print("Profile image uploaded")
            #endif
        }

        #if DEBUG
        print("Updated User State:")
        print("   First Name: '\(user.firstName)'")
        print("   Last Name: '\(user.lastName)'")
        print("   Username: '\(user.username)'")
        print("\n Saving updated user...")
        #endif
        if wasProfileIncomplete {
            try await userManager.saveInitialProfile(updatedUser: user)
        } else {
            try await userManager.saveProfile(updatedUser: user)
        }
        #if DEBUG
        print("User saved successfully")
        #endif

        if let updatedUser = userManager.currentUser {
            #if DEBUG
            print("\nUpdating local state with saved user:")
            print("   First Name: '\(updatedUser.firstName)'")
            print("   Last Name: '\(updatedUser.lastName)'")
            print("   Username: '\(updatedUser.username)'")
            #endif

            firstName = updatedUser.firstName
            lastName = updatedUser.lastName
            username = updatedUser.username

            if let image = try? await userManager.fetchProfileImage(for: updatedUser, forceRefresh: true) {
                profileImage = image
                #if DEBUG
                print("Profile image refreshed")
                #endif
            }
        }
    }
}
