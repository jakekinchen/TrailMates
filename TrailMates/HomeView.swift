import SwiftUI

struct HomeView: View {
    @EnvironmentObject var userManager: UserManager
    @StateObject private var eventViewModel = EventViewModel.shared
    @State private var selectedTab = 0
    @State private var showCreateEvent = false
    @State private var showEventDetails = false
    @State private var selectedEvent: Event?
    @State private var isRefreshing = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            MapView()
                .tag(0)
                .tabItem {
                    Label("Map", systemImage: "map")
                }
            
            EventsView(eventViewModel: eventViewModel)
                .tag(1)
                .tabItem {
                    Label("Events", systemImage: "calendar")
                }
            
            FriendsView()
                .tag(2)
                .tabItem {
                    Label("Friends", systemImage: "person.2")
                }
            
            ProfileView()
                .tag(3)
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
        .accentColor(Color("pine"))
        .overlay(
            Group {
                if isRefreshing {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
        )
        .onChange(of: selectedTab) { oldValue, newValue in
            Task {
                await refreshContent(for: newValue)
            }
        }
        .task {
            await initialRefresh()
        }
    }
    
    private func initialRefresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        
        await userManager.refreshUserData()
        await eventViewModel.loadEvents()
    }
    
    private func refreshContent(for tab: Int) async {
        isRefreshing = true
        defer { isRefreshing = false }
        
        switch tab {
        case 0: // Map
            await userManager.refreshUserData()
            // Add any map-specific refresh logic
            
        case 1: // Events
            await userManager.refreshUserData()
            await eventViewModel.loadEvents()
            
        case 2: // Friends
            await userManager.refreshUserData()
            // Friends view has its own refresh logic
            
        case 3: // Profile
            await userManager.refreshUserData()
            
        default:
            break
        }
    }
    
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        
        let itemAppearance = UITabBarItemAppearance()
        let pineColor = UIColor(named: "pine") ?? .green
        let unfocusedColor = pineColor.withAlphaComponent(0.4)
        
        // Normal (unselected) state
        itemAppearance.normal.iconColor = unfocusedColor
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: unfocusedColor]
        
        // Selected state
        itemAppearance.selected.iconColor = pineColor
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: pineColor]
        
        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance
        
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

// Refresh indicator view
struct RefreshIndicator: View {
    var body: some View {
        ProgressView()
            .scaleEffect(1.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.2))
    }
}
