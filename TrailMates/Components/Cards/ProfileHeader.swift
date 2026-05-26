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
//  ```

import SwiftUI

/// A profile header with image, name, username, and action button
struct ProfileHeader: View {
    let user: User
    let actionButton: AnyView

    var body: some View {
        VStack(spacing: 16) {
            // Profile Image
            UserAvatarView(user: user, size: 120)
                .overlay(Circle().strokeBorder(AppColors.pine, lineWidth: 3))
                .shadow(radius: 5)
            
            VStack(spacing: 8) {
                Text("\(user.firstName) \(user.lastName)")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.pine)
                
                Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundColor(AppColors.pine.opacity(0.8))
            }
            
            actionButton
        }
        .padding(.top, -20)
        .padding(.bottom, 8)
    }
}
