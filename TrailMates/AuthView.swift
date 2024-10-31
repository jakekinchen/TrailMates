import SwiftUI

struct AuthView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLogin = true // Toggle between login and signup

    var body: some View {
        ZStack {
            // Background Image
            let star = Image(systemName: "star.fill")
            star
            
            let background = Image("background")
                .resizable()
                .scaledToFill()
                .edgesIgnoringSafeArea(.all)
            background

            VStack(spacing: 20) {
                // Title
                Text("TrailMates")
                    .font(Font.custom("magic-retro", size: 48))
                    .foregroundColor(Color("beige")) // Use the color asset "beige"
                    .padding(.bottom, 50)

                // Username TextField
                TextField("Username", text: $username)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color("pine"), lineWidth: 2)) // Use the color asset "pine"
                    .font(Font.custom("SF-Pro", size: 16))
                    .autocapitalization(.none)

                // Password SecureField
                SecureField("Password", text: $password)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color("pine"), lineWidth: 2)) // Use the color asset "pine"
                    .font(Font.custom("SF-Pro", size: 16))

                // Confirm Password (for signup)
                if !isLogin {
                    SecureField("Confirm Password", text: $confirmPassword)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color("pine"), lineWidth: 2)) // Use the color asset "pine"
                        .font(Font.custom("SF-Pro", size: 16))
                }

                // Buttons
                HStack(spacing: 10) {
                    Button(action: {
                        // Handle Login
                        isLogin = true
                        handleSubmit()
                    }) {
                        Text("Log In")
                            .font(Font.custom("SF-Pro", size: 16))
                            .fontWeight(.bold)
                            .foregroundColor(Color("beige")) // Use the color asset "beige"
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color("orange")) // Use the color asset "orange"
                            .cornerRadius(25)
                    }

                    Button(action: {
                        // Handle Sign Up
                        isLogin = false
                        handleSubmit()
                    }) {
                        Text("Sign Up")
                            .font(Font.custom("SF-Pro", size: 16))
                            .fontWeight(.bold)
                            .foregroundColor(Color("orange")) // Use the color asset "orange"
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color("beige")) // Use the color asset "beige"
                            .cornerRadius(25)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    func handleSubmit() {
        // Handle login or signup logic
        // Navigate to the HomeView if credentials are valid
    }
}

struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView()
    }
}
