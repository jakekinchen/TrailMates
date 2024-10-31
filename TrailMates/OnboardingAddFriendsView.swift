import SwiftUI

struct OnboardingAddFriendsView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        AddFriendsView(isOnboarding: true, onSkip: {
            // Handle skip action
            presentationMode.wrappedValue.dismiss()
        }, onFinish: {
            // Handle finish action
            presentationMode.wrappedValue.dismiss()
        })
    }
}