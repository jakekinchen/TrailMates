import SwiftUI

// ContentView.swift
struct ContentView: View {
    @EnvironmentObject var userManager: UserManager

    var body: some View {
        let content: AnyView

        if !userManager.isLoggedIn {
            content = AnyView(AuthView())
        } else if userManager.currentUser?.firstName.isEmpty ?? true || userManager.currentUser?.username.isEmpty ?? true || userManager.currentUser?.lastName.isEmpty ?? true {
            // Profile setup is required first
            content = AnyView(ProfileSetupView())
        } else if !userManager.isWelcomeComplete {
            // Then welcome screen
            content = AnyView(WelcomeView(onComplete: {
                userManager.isWelcomeComplete = true
                userManager.persistUserSession()
            }))
        } else if !userManager.isPermissionsGranted {
            // Then permissions
            content = AnyView(PermissionsView(onComplete: {
                userManager.isPermissionsGranted = true
                userManager.persistUserSession()
            }))
        } else if !userManager.isOnboardingComplete {
            // Finally, optional friend adding (but don't block on it)
            content = AnyView(OnboardingAddFriendsView(onFinish: {
                userManager.isOnboardingComplete = true
                userManager.persistUserSession()
            }))
        } else {
            content = AnyView(HomeView())
        }

        return content
            .onAppear {
                Task { await userManager.initializeUserIfNeeded() }
            }
    }
}
