import SwiftUI

struct HomeView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            MapView()
                .tabItem {
                    Image(selectedTab == 0 ? "mapActive" : "map")
                    Text("Map")
                }
                .tag(0)
            
            FriendsView()
                .tabItem {
                    Image(selectedTab == 1 ? "friendsActive" : "friends")
                    Text("Friends")
                }
                .tag(1)
            
            ARView()
                .tabItem {
                    Image(selectedTab == 2 ? "ARActive" : "AR")
                    Text("AR")
                }
                .tag(2)
            
            ProfileView()
                .tabItem {
                    Image(selectedTab == 3 ? "profileActive" : "profile")
                    Text("Profile")
                }
                .tag(3)
        }
        .accentColor(Color("pumpkin"))
    }
}

struct MapView: View {
    var body: some View {
        Text("Map View")
    }
}

struct FriendsView: View {
    var body: some View {
        Text("Friends View")
    }
}

struct ARView: View {
    var body: some View {
        Text("AR View")
    }
}

struct ProfileView: View {
    var body: some View {
        Text("Profile View")
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}