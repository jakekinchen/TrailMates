import SwiftUI

// ContentView.swift
struct ContentView: View {
    @EnvironmentObject var userManager: UserManager

    var body: some View {
        Group {
            if !userManager.isLoggedIn {
                AuthView()
            } else if userManager.currentUser?.firstName.isEmpty ?? true || userManager.currentUser?.username.isEmpty ?? true || userManager.currentUser?.lastName.isEmpty ?? true {
                // Profile setup is required first
                ProfileSetupView()
            } else if !userManager.isWelcomeComplete {
                // Then welcome screen
                WelcomeView(onComplete: {
                    userManager.isWelcomeComplete = true
                    userManager.persistUserSession()
                })
            } else if !userManager.isPermissionsGranted {
                // Then permissions
                PermissionsView(onComplete: {
                    userManager.isPermissionsGranted = true
                    userManager.persistUserSession()
                })
            } else if !userManager.isOnboardingComplete {
                // Finally, optional friend adding (but don't block on it)
                OnboardingAddFriendsView(onFinish: {
                    userManager.isOnboardingComplete = true
                    userManager.persistUserSession()
                })
            } else {
                HomeView()
            }
        }
        .onAppear {
            Task { await userManager.initializeIfNeeded() }
        }
    }
}
