import SwiftUI

struct FriendsView: View {
    @State private var friends = [
        Friend(name: "Collin Nelson", isActive: true),
        Friend(name: "Nancy Melancon", isActive: false),
        // Add more friends as needed
    ]
    
    var body: some View {
        VStack {
            // Top bar with title
            HStack {
                Text("TrailMates")
                    .font(.custom("MagicRetro", size: 24))
                    .foregroundColor(Color("pine"))
                Spacer()
                Button(action: {
                    // Action to add friend
                }) {
                    Image(systemName: "person.badge.plus")
                        .foregroundColor(Color("pine"))
                }
            }
            .padding()
            .background(Color("beige").opacity(0.9))
            
            // Friends List
            List {
                Section(header: Text("Active").foregroundColor(Color("pine"))) {
                    ForEach(friends.filter { $0.isActive }) { friend in
                        HStack {
                            Image("friendProfilePic") // Replace with friend's profile image
                                .resizable()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                            Text(friend.name)
                                .foregroundColor(Color("pine"))
                            Spacer()
                            Text("Now")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Section(header: Text("Inactive").foregroundColor(Color("pine"))) {
                    ForEach(friends.filter { !$0.isActive }) { friend in
                        HStack {
                            Image("friendProfilePic") // Replace with friend's profile image
                                .resizable()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                            Text(friend.name)
                                .foregroundColor(Color("pine"))
                            Spacer()
                        }
                    }
                }
            }
            .listStyle(GroupedListStyle())
        }
        .edgesIgnoringSafeArea(.top)
    }
}

struct Friend: Identifiable {
    let id = UUID()
    let name: String
    let isActive: Bool
}

struct FriendsView_Previews: PreviewProvider {
    static var previews: some View {
        FriendsView()
    }
}