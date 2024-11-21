struct ProfileHeader: View {
    let user: User
    let actionButton: AnyView
    
    var body: some View {
        VStack(spacing: 16) {
            // Profile Image
            if let imageData = user.profileImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color("pine"), lineWidth: 3))
                    .shadow(radius: 5)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(Color("pine"))
                            .font(.system(size: 50))
                    )
                    .overlay(Circle().stroke(Color("pine"), lineWidth: 3))
                    .shadow(radius: 5)
            }
            
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