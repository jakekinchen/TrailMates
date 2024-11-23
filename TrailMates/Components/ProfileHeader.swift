//
//  ProfileHeader.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on 11/20/24.
//

import SwiftUI

struct ProfileHeader: View {
    let user: User
    let actionButton: AnyView
    
    var body: some View {
        VStack(spacing: 16) {
            // Profile Image
            Group {
                if let imageUrl = user.profileImageUrl {
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                } else if let imageData = user.profileImageData,
                          let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.gray)
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
    }
}
