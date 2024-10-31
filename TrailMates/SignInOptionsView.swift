import SwiftUI

struct SignInOptionsView: View {
    @EnvironmentObject var userManager: UserManager
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing: 20) {
            Text("Connect Your Account")
                .font(.title)
                .padding()

            Text("Sign in with Instagram or Facebook to autofill your profile information and find friends.")
                .multilineTextAlignment(.center)
                .padding()

            Button(action: {
                signInWithInstagram()
            }) {
                HStack {
                    Image("instagram_icon")
                        .resizable()
                        .frame(width: 24, height: 24)
                    Text("Sign in with Instagram")
                        .font(.headline)
                }
                .padding()
                .foregroundColor(.white)
                .background(Color.purple)
                .cornerRadius(10)
            }

            Button(action: {
                signInWithFacebook()
            }) {
                HStack {
                    Image("facebook_icon")
                        .resizable()
                        .frame(width: 24, height: 24)
                    Text("Sign in with Facebook")
                        .font(.headline)
                }
                .padding()
                .foregroundColor(.white)
                .background(Color.blue)
                .cornerRadius(10)
            }

            Button(action: {
                userManager.isOnboardingComplete = true
                userManager.persistUserSession()
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Skip")
                    .foregroundColor(Color("pine"))
            }
            .padding(.top)

            Spacer()
        }
        .padding()
    }

    func signInWithInstagram() {
        // Simulate sign-in process
        // In a real app, implement Instagram OAuth flow here
        userManager.currentUser?.firstName = "InstagramFirstName"
        userManager.currentUser?.lastName = "InstagramLastName"
        userManager.currentUser?.bio = "Bio from Instagram"
        // Load profile image and convert to Data
        if let image = UIImage(named: "instagram_profile_pic") {
            userManager.currentUser?.profileImageData = image.jpegData(compressionQuality: 0.8)
        }
        userManager.isOnboardingComplete = true
        userManager.persistUserSession()
        presentationMode.wrappedValue.dismiss()
    }

    func signInWithFacebook() {
        // Simulate sign-in process
        // In a real app, implement Facebook OAuth flow here
        userManager.currentUser?.firstName = "FacebookFirstName"
        userManager.currentUser?.lastName = "FacebookLastName"
        userManager.currentUser?.bio = "Bio from Facebook"
        // Load profile image and convert to Data
        if let image = UIImage(named: "facebook_profile_pic") {
            userManager.currentUser?.profileImageData = image.jpegData(compressionQuality: 0.8)
        }
        userManager.isOnboardingComplete = true
        userManager.persistUserSession()
        presentationMode.wrappedValue.dismiss()
    }
}