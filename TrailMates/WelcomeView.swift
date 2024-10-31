import SwiftUI
import MapKit

struct WelcomeView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var showSignInOptions = false

    var body: some View {
        VStack {
            Spacer()
            Text("Welcome to the TrailMates ATX Community")
                .font(.largeTitle)
                .multilineTextAlignment(.center)
                .padding()

            Text("""
                TrailMates connects you with friends in the Town Lake Community, including the Ann and Roy Butler Trail, Zilker Park, Barton Springs, and adjacent parks. Receive alerts when your friends are on the trail!
                """)
                .multilineTextAlignment(.center)
                .padding()

            // Map highlighting the trail area
            MapView()
                .frame(height: 200)
                .cornerRadius(15)
                .padding()

            Spacer()

            Button(action: {
                showSignInOptions = true
            }) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color("pumpkin"))
                    .cornerRadius(10)
            }
            .padding()

            Button(action: {
                userManager.isOnboardingComplete = true
                userManager.persistUserSession()
            }) {
                Text("Skip")
                    .foregroundColor(Color("pine"))
            }
            .padding(.bottom)

        }
        .sheet(isPresented: $showSignInOptions) {
            SignInOptionsView()
                .environmentObject(userManager)
        }
    }
}

// Placeholder for the MapView
struct MapView: View {
    var body: some View {
        // Implement your map highlighting the trail here
        Rectangle()
            .fill(Color.gray)
            .overlay(Text("Map Placeholder").foregroundColor(.white))
    }
}