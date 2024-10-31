import SwiftUI

struct ProfileView: View {
    var body: some View {
        VStack {
            // Top bar with title
            HStack {
                Text("TrailMates")
                    .font(.custom("MagicRetro", size: 24))
                    .foregroundColor(Color("pine"))
                Spacer()
                Image(systemName: "bell")
                    .foregroundColor(Color("pine"))
            }
            .padding()
            .background(Color("beige").opacity(0.9))
            
            Spacer()
            
            // Profile Content
            VStack(spacing: 20) {
                // Profile Picture
                Image("userProfilePic") // Replace with actual image name
                    .resizable()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color("pine"), lineWidth: 4))
                    .shadow(radius: 10)
                
                // Username
                Text("Your Name")
                    .font(.title)
                    .foregroundColor(Color("pine"))
                
                // Edit Profile Button
                Button(action: {
                    // Action to edit profile
                }) {
                    Text("Edit Profile")
                        .font(.headline)
                        .foregroundColor(Color("beige"))
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color("pine"))
                        .cornerRadius(15)
                }
                
                // Settings List
                List {
                    NavigationLink(destination: Text("Account Settings")) {
                        HStack {
                            Image(systemName: "person.crop.circle")
                            Text("Account Settings")
                        }
                        .foregroundColor(Color("pine"))
                    }
                    NavigationLink(destination: Text("Privacy")) {
                        HStack {
                            Image(systemName: "lock.shield")
                            Text("Privacy")
                        }
                        .foregroundColor(Color("pine"))
                    }
                    NavigationLink(destination: Text("Notifications")) {
                        HStack {
                            Image(systemName: "bell")
                            Text("Notifications")
                        }
                        .foregroundColor(Color("pine"))
                    }
                    NavigationLink(destination: Text("Help")) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                            Text("Help")
                        }
                        .foregroundColor(Color("pine"))
                    }
                }
                .listStyle(GroupedListStyle())
            }
            .padding()
            
            Spacer()
        }
        .edgesIgnoringSafeArea(.top)
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}