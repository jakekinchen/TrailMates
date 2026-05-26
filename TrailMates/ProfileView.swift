import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var userStats: UserStats?
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let user = userManager.currentUser {
                    ProfileHeader(user: user, actionButton: AnyView(
                        Button(action: { showEditProfile = true }) {
                            Text("Edit Profile")
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.beige)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(AppColors.pine)
                                .cornerRadius(25)
                        }
                    ))
                } else {
                    LoadingView()
                        .frame(height: 120)
                }

                // Stats Section - uses .equatable() to prevent unnecessary re-renders
                if let stats = userStats {
                    StatsSection(stats: stats)
                        .equatable()
                } else {
                    // Show placeholder stats while loading
                    StatsSection(stats: UserStats(
                        joinDate: "Loading...",
                        landmarkCompletion: 0,
                        friendCount: 0,
                        hostedEventCount: 0,
                        attendedEventCount: 0
                    ))
                    .equatable()
                    .redacted(reason: .placeholder)
                    .shimmering()
                }
            }
            .padding()
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .themedBackground()
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
                .presentationDetents([.large])
        }
        .task {
            // Load cached stats immediately if available
            if let cachedStats = userManager.loadCachedStats() {
                userStats = cachedStats
            }
            
            // Then refresh in background if needed
            if userManager.shouldRefreshUser() {
                await refreshProfileData()
            }
        }
        .onChange(of: showEditProfile) { oldValue, newValue in
            if !newValue {
                Task {
                    await refreshProfileData()
                }
            }
        }
        .refreshable {
            await refreshProfileData()
        }
    }
    
    private func refreshProfileData() async {
        isLoading = true
        defer { isLoading = false }

        // Refresh user data in background
        await userManager.refreshUserInBackground()

        // Refresh stats
        if let newStats = await userManager.getUserStats() {
            userStats = newStats
            // Cache the new stats
            userManager.cacheStats(newStats)
        }
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
                .foregroundColor(AppColors.pine)

            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(AppColors.pine.opacity(0.8))

                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.pine)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(
            colorScheme == .dark ? Color.white.opacity(0.2) : AppColors.sage.opacity(0.2)
        )
        .cornerRadius(16)
        .accessibilityElement(children: .combine)
    }
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

// MARK: - Equatable Conformances
extension StatCard: Equatable {
    static func == (lhs: StatCard, rhs: StatCard) -> Bool {
        lhs.icon == rhs.icon && lhs.title == rhs.title && lhs.value == rhs.value
    }
}

extension StatsSection: Equatable {
    static func == (lhs: StatsSection, rhs: StatsSection) -> Bool {
        lhs.stats == rhs.stats
    }
}

// MARK: - Shimmering Effect
extension View {
    func shimmering() -> some View {
        self.modifier(ShimmeringEffect())
    }
}

struct ShimmeringEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .clear,
                            .white.opacity(0.5),
                            .clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 3)
                    .offset(x: -geometry.size.width)
                    .offset(x: phase)
                    .animation(
                        Animation.linear(duration: 1.5)
                            .repeatForever(autoreverses: false),
                        value: phase
                    )
                }
            )
            .onAppear {
                phase = 0
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = UIScreen.main.bounds.width
                }
            }
            .mask(content)
    }
}
