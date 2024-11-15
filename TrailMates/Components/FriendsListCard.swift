struct FriendsListCard: View {
    let friends: [User]
    @State private var showAddFriends = false
    var onAddFriends: () -> Void // Closure to trigger data reload

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Friends on the Trail")
                    .font(.system(size: 18))
                    .foregroundColor(Color("pine"))
                Spacer()
                Button(action: {
                    showAddFriends = true
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(Color("pine"))
                        .font(.system(size: 20))
                }
            }
            
            Divider()
            
            FriendsSection(title: "Active", friends: friends.filter { $0.isActive })
            
            Spacer() // Pushes content to the top
        }
        .padding()
        //.background(Color("beige").opacity(0.9))
        .cornerRadius(15)
        .padding(.horizontal)
        .sheet(isPresented: $showAddFriends) {
            AddFriendsView(isOnboarding: false, onSkip: nil) {
                showAddFriends = false
                onAddFriends() // Trigger the closure to reload data
            }
        }
    }
}