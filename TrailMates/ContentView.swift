import SwiftUI

// ContentView.swift
struct ContentView: View {
    @EnvironmentObject var userManager: UserManager

    var body: some View {
        let content: AnyView

        if !userManager.isLoggedIn {
            content = AnyView(AuthView())
        } else if userManager.currentUser?.firstName.isEmpty ?? true || userManager.currentUser?.username.isEmpty ?? true || userManager.currentUser?.lastName.isEmpty ?? true{
                    // Profile setup is required after login but before welcome screen
            content = AnyView(OnboardingAddFriendsView(onFinish: {
                userManager.hasAddedFriends = true
                userManager.isOnboardingComplete = true
                userManager.persistUserSession()
            }))
        } else if !userManager.isWelcomeComplete {
            content = AnyView(WelcomeView(onComplete: {
                userManager.isWelcomeComplete = true
                userManager.persistUserSession()
            }))
        } else if !userManager.isPermissionsGranted {
            content = AnyView(PermissionsView(onComplete: {
                userManager.isPermissionsGranted = true
                userManager.persistUserSession()
            }))
        } else if !userManager.hasAddedFriends && !userManager.isOnboardingComplete {
            content = AnyView(OnboardingAddFriendsView(onFinish: {
                userManager.hasAddedFriends = true
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
