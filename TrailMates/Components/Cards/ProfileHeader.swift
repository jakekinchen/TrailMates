//
//  ProfileHeader.swift
//  TrailMates
//
//  A header component displaying user profile information with customizable action button.
//
//  Usage:
//  ```swift
//  ProfileHeader(
//      user: user,
//      actionButton: AnyView(Button("Edit Profile") { /* action */ })
//  )
//  .environmentObject(userManager)
//  ```

import SwiftUI

/// A profile header with image, name, username, and action button
struct ProfileHeader: View {
    let user: User
    let actionButton: AnyView
    @EnvironmentObject var userManager: UserManager
    @State private var profileImage: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Profile Image
            Group {
                if let image = profileImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if isLoading {
                    ProgressView()
                        .frame(width: 120, height: 120)
                } else {
                    defaultProfileImage
                }
            }
            .frame(width: 120, height: 120)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color("pine"), lineWidth: 3))
            .shadow(radius: 5)
            
            VStack(spacing: 8) {
                Text("\(user.firstName) \(user.lastName)")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color("pine"))
                
                Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundColor(Color("pine").opacity(0.8))
            }
            
            actionButton
        }
        .padding(.top, -20)
        .padding(.bottom, 8)
        .task {
            await loadProfileImage()
        }
        .onChange(of: user.profileImageUrl) { oldValue, newValue in
            if oldValue != newValue {
                Task {
                    await loadProfileImage(forceRefresh: true)
                }
            }
        }
    }
    
    private func loadProfileImage(forceRefresh: Bool = false) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            if let image = try await userManager.fetchProfileImage(for: user, forceRefresh: forceRefresh) {
                await MainActor.run {
                    profileImage = image
                }
            }
        } catch {
            print("❌ Error loading profile image: \(error.localizedDescription)")
        }
    }
    
    private var defaultProfileImage: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundColor(Color("pine").opacity(0.8))
            .background(Circle().fill(Color("beige")))
    }
}
