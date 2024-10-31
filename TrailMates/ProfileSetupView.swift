import SwiftUI

struct ProfileSetupView: View {
    @Binding var isProfileSetupComplete: Bool
    @State private var fullName = ""
    @State private var bio = ""
    @State private var profileImageName = "defaultProfilePic" // Placeholder image
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        VStack {
            Text("Set Up Your Profile")
                .font(.largeTitle)
                .padding()

            // Profile Image Picker (Simulated)
            Image(profileImageName)
                .resizable()
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .onTapGesture {
                    // Simulate image selection
                    profileImageName = "userSelectedProfilePic"
                }
                .padding()

            // Full Name Field
            TextField("Full Name", text: $fullName)
                .padding()
                .background(RoundedRectangle(cornerRadius: 8).fill(Color("beige")))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("pine"), lineWidth: 2))
                .font(Font.custom("SF Pro", size: 16))
                .foregroundColor(Color("pine"))
                .autocapitalization(.words)
                .padding(.horizontal)

            // Bio Field
            TextField("Bio", text: $bio)
                .padding()
                .background(RoundedRectangle(cornerRadius: 8).fill(Color("beige")))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("pine"), lineWidth: 2))
                .font(Font.custom("SF Pro", size: 16))
                .foregroundColor(Color("pine"))
                .padding(.horizontal)

            // Save Button
            Button(action: {
                saveProfile()
            }) {
                Text("Save")
                    .font(Font.custom("SF Pro", size: 16))
                    .fontWeight(.bold)
                    .foregroundColor(Color("beige"))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("pumpkin"))
                    .cornerRadius(25)
            }
            .padding()

            Spacer()
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Profile Setup"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    private func saveProfile() {
        guard !fullName.isEmpty else {
            alertMessage = "Please enter your full name."
            showAlert = true
            return
        }

        // Create a new User instance
        let newUser = User(
            id: UUID(),
            fullName: fullName,
            profileImageName: profileImageName,
            bio: bio,
            location: nil,
            isActive: true,
            friends: [],
            doNotDisturb: false
        )

        // Save the user using MockDataProvider
        let dataProvider = MockDataProvider()
        dataProvider.saveUser(newUser)

        // Mark profile setup as complete
        isProfileSetupComplete = true
    }
}