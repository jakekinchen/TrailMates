//
//  UserAvatarView.swift
//  TrailMatesATX
//
//  A reusable circular profile image component that handles loading,
//  fallback initials, and placeholder states.
//
//  Usage:
//  ```swift
//  UserAvatarView(user: someUser, size: 50)
//  ```

import SwiftUI

struct UserAvatarView: View {
    let user: User
    let size: CGFloat

    @State private var profileImage: UIImage?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let image = profileImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                ProgressView()
            } else {
                initialsFallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task {
            await loadProfileImage()
        }
    }

    private var initialsFallback: some View {
        ZStack {
            Circle()
                .fill(AppColors.sage.opacity(0.4))
            Text(user.initials.isEmpty ? "?" : user.initials)
                .font(.system(size: size * 0.35, weight: .bold))
                .foregroundColor(AppColors.pine)
        }
    }

    private func loadProfileImage() async {
        isLoading = true
        defer { isLoading = false }

        if let image = try? await UserManager.shared.fetchProfileImage(
            for: user,
            preferredSize: size > 80 ? .full : .thumbnail
        ) {
            await MainActor.run {
                profileImage = image
            }
        }
    }
}
