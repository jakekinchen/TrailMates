import SwiftUI
import MapKit

extension Color {
    static let bottomSheetBackground = AppColors.beige.opacity(0.95)
}

// MARK: - Main Map View
struct MapView: View {
    @EnvironmentObject var userManager: UserManager
    @ObservedObject private var eventViewModel = EventViewModel.shared
    @State private var friends: [User] = []
    @State private var isBottomSheetOpen = false
    @State private var activeSegment = "friends"
    @State private var mapView: MKMapView?
    @State private var showNotifications = false
    @State private var selectedEvent: Event?
    @State private var locationUpdateTask: Task<Void, Never>?
    
    var currentUser: User? {
        return userManager.currentUser
    }
    
    var activeFriends: [User] {
        friends.filter { $0.isActive }
    }
    
    var body: some View {
        ZStack {
            UnifiedMapView(
                mapView: $mapView,
                configuration: MapConfiguration(
                    showUserLocation: true,
                    showFriendLocations: true,
                    showEventLocations: true,
                    friends: activeFriends,  // Only pass active friends to map
                    events: eventViewModel.events,
                    onLocationSelected: { location in
                        // Handle location selection if needed
                    }
                )
            )
            .ignoresSafeArea(edges: [.top, .horizontal])
            
            // Navigation overlay
            VStack(spacing: 0) {
                Color.clear
                    .withDefaultNavigation(
                        title: "TrailMates",
                        rightButtonIcon: "bell",
                        rightButtonAction: { showNotifications = true }
                    )
                Spacer()
            }
            
            // Bottom Sheet
            BottomSheet(
                isOpen: $isBottomSheetOpen,
                maxHeight: 500
            ) {
                bottomSheetContent
            }
        }
        .background(AppColors.beige)
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
        }
        .sheet(item: $selectedEvent) { event in
            // Get the fresh event from EventViewModel to ensure up-to-date attendee data
            let freshEvent = eventViewModel.events.first(where: { $0.id == event.id }) ?? event
            NavigationStack {
                EventDetailView(
                    event: freshEvent,
                    eventViewModel: eventViewModel
                )
            }
        }
        .task {
            await loadData()
            startLocationUpdates()
        }
        .onDisappear {
            stopLocationUpdates()
        }
    }
    
    // MARK: - Location Update Methods
    private func startLocationUpdates() {
        // Cancel any existing task first
        locationUpdateTask?.cancel()

        // Create a new task for periodic location updates using structured concurrency
        locationUpdateTask = Task { [weak userManager] in
            // Initial update
            await updateFriendLocations()

            // Use AsyncTimerSequence pattern for periodic updates
            // This properly handles cancellation and doesn't retain self strongly
            while !Task.isCancelled {
                do {
                    // Wait for 30 seconds between updates
                    try await Task.sleep(for: .seconds(30))

                    // Check if task is cancelled before proceeding
                    guard !Task.isCancelled, userManager != nil else { break }

                    await updateFriendLocations()
                } catch {
                    // Task was cancelled (likely view disappeared)
                    break
                }
            }
        }
    }

    private func stopLocationUpdates() {
        locationUpdateTask?.cancel()
        locationUpdateTask = nil
    }
    
    private func updateFriendLocations() async {
        await loadData()

        // Force map to refresh annotations (already on MainActor via View context)
        if let mapView = mapView {
            // Trigger the map coordinator to update annotations
            let coordinator = mapView.delegate as? UnifiedMapView.MapCoordinator
            coordinator?.updateAnnotations(mapView)
        }
    }
    
    // MARK: - Bottom Sheet Content
    private var bottomSheetContent: some View {
        VStack(spacing: 0) {
            // Segment Control
            Picker("View", selection: $activeSegment) {
                Text("Friends").tag("friends")
                Text("Events").tag("events")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            Divider()
            
            ScrollView {
                if activeSegment == "friends" {
                    FriendsListCard(friends: friends, onAddFriends: {
                        Task {
                            await loadData()
                        }
                    })
                } else {
                    ZStack {
                        // Background layer that extends under section headers
                        //Color.bottomSheetBackground
                        //    .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        // Content layer with negative padding to account for section headers
                        eventsList
                            .padding(.top, -8) // Adjust this value based on your section header height
                            //
                    }
                    
                }
                    
            }
        }
    }
    
    // Custom mask to clip scroll content underneath the header
    private struct ScrollMask: View {
        var body: some View {
            GeometryReader { proxy in
                VStack {
                    Rectangle()
                        .frame(height: proxy.size.height * 0.2) // Header height (adjust as needed)
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Events List View
    // MARK: - Events List View
    private var eventsList: some View {
        let userEvents = currentUser.map { eventViewModel.getUserEvents(for: $0.id) } ?? []
        let eventGroups = eventViewModel.getEventGroups(from: userEvents)
        
        return LazyVStack(spacing: 16, pinnedViews: .sectionHeaders) {
            ForEach(eventGroups) { group in
                Section(header: SectionHeader(title: group.title)) {
                    ForEach(group.events) { event in
                        EventRowView(
                            event: event,
                            currentUser: currentUser,
                            onJoinTap: {
                                //handleJoinEvent(event)
                            },
                            onLeaveTap: {
                                //handleLeaveEvent(event)
                            },
                            showLeaveJoinButton: false
                        )
                        .onTapGesture {
                            selectedEvent = event
                        }
                    }
                }
                
            }
            
        }
        .padding(.horizontal)
    }
    
    // MARK: - Helper Methods
    private func loadData() async {
        if let _ = userManager.currentUser {
            friends = await userManager.fetchFriends()
            await eventViewModel.loadEvents()
        }
    }
    }
struct FriendsSection: View {
    //let title: String
    let friends: [User]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            ForEach(friends) { friend in
                HStack {
                    UserAvatarView(user: friend, size: 40)
                    VStack(alignment: .leading) {
                        Text("\(friend.firstName) \(friend.lastName)")
                            .foregroundColor(AppColors.pine)
                        if friend.isActive {
                            Text("Now")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    Spacer()
                }
            }
        }
    }
}
