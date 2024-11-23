import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var userStats: UserStats?
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            Color("beige").ignoresSafeArea()
            
            VStack(spacing: 16) {
                if let user = userManager.currentUser {
                    ProfileHeader(user: user, actionButton: AnyView(
                        Button(action: { showEditProfile = true }) {
                            Text("Edit Profile")
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.medium)
                                .foregroundColor(Color("beige"))
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color("pine"))
                                .cornerRadius(25)
                        }
                    ))
                } else {
                    ProgressView()
                        .frame(width: 120, height: 120)
                }
                
                // Stats Section
                if let stats = userStats {
                    StatsSection(stats: stats)
                } else if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .padding()
        }
        .withDefaultNavigation(
            title: "Profile",
            rightButtonIcon: "gear",
            rightButtonAction: { showSettings = true }
        )
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showEditProfile) {
            ProfileSetupView(isEditMode: true)
        }
        .task {
            await refreshStats()
        }
        .onChange(of: showEditProfile) { oldValue, newValue in
            if !newValue {
                Task {
                    await refreshStats()
                }
            }
        }
    }
    
    private func refreshStats() async {
        isLoading = true
        userStats = await userManager.getUserStats()
        isLoading = false
    }
}
// Keeping the existing supporting views and models
struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(Color("pine"))
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(Color("pine").opacity(0.8))
                
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(Color("pine"))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(
            colorScheme == .dark ? Color.white.opacity(0.2) : Color("sage").opacity(0.2)
        )
        .cornerRadius(16)
    }
}

struct UserStats {
    let joinDate: String
    let landmarkCompletion: Int
    let friendCount: Int
    let hostedEventCount: Int
    let attendedEventCount: Int
}

struct StatsSection: View {
    let stats: UserStats
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                StatCard(
                    icon: "calendar",
                    title: "Joined",
                    value: stats.joinDate
                )
                
                StatCard(
                    icon: "flag.fill",
                    title: "Landmarks Visited",
                    value: "\(stats.landmarkCompletion)%"
                )
            }
            
            HStack(spacing: 16) {
                StatCard(
                    icon: "person.2.fill",
                    title: "Friends",
                    value: "\(stats.friendCount)"
                )
                
                StatCard(
                    icon: "star.fill",
                    title: "Events Hosted",
                    value: "\(stats.hostedEventCount)"
                )
            }
            
            StatCard(
                icon: "figure.hiking",
                title: "Events Attended",
                value: "\(stats.attendedEventCount)"
            )
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ProfileView()
                .environmentObject(UserManager())
        }
    }
}
