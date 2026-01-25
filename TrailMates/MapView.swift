import SwiftUI
import MapKit

extension Color {
    static let bottomSheetBackground = Color("beige").opacity(0.95)
}

// MARK: - Main Map View
struct MapView: View {
    @EnvironmentObject var userManager: UserManager
    @StateObject private var eventViewModel = EventViewModel.shared
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
        .background(Color("beige"))
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
        }
        .sheet(item: $selectedEvent) { event in
            NavigationView {
                EventDetailView(
                    event: event,
                    eventViewModel: eventViewModel
                )
            }
        }
        .onAppear {
            Task {
                await loadData()
                startLocationUpdates()
            }
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
    
    struct EventGroup: Identifiable {
        let id = UUID()
        let title: String
        let events: [Event]
    }
    
    func getEventGroups(from events: [Event]) -> [EventGroup] {
        let calendar = Calendar.current
        let sortedEvents = events.sorted { $0.dateTime < $1.dateTime }
        var groups: [EventGroup] = []
        
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: today)!
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: today)!
        
        // Helper function to check if date is in same day
        func isInSameDay(_ date1: Date, _ date2: Date) -> Bool {
            calendar.isDate(date1, inSameDayAs: date2)
        }
        
        // Today's events
        let todayEvents = sortedEvents.filter { isInSameDay($0.dateTime, Date()) }
        if !todayEvents.isEmpty {
            groups.append(EventGroup(title: "Today", events: todayEvents))
        }
        
        // Tomorrow's events
        let tomorrowEvents = sortedEvents.filter { isInSameDay($0.dateTime, tomorrow) }
        if !tomorrowEvents.isEmpty {
            groups.append(EventGroup(title: "Tomorrow", events: tomorrowEvents))
        }
        
        // This week's events (excluding tomorrow)
        let thisWeekEvents = sortedEvents.filter { event in
            let isAfterTomorrow = event.dateTime > tomorrow
            let isBeforeNextWeek = event.dateTime < nextWeek
            let isNotTomorrow = !isInSameDay(event.dateTime, tomorrow)
            return isAfterTomorrow && isBeforeNextWeek && isNotTomorrow
        }
        if !thisWeekEvents.isEmpty {
            groups.append(EventGroup(title: "This Week", events: thisWeekEvents))
        }
        
        // Next week's events
        let nextWeekEvents = sortedEvents.filter { event in
            let isAfterNextWeek = event.dateTime >= nextWeek
            let isBeforeNextMonth = event.dateTime < nextMonth
            return isAfterNextWeek && isBeforeNextMonth
        }
        if !nextWeekEvents.isEmpty {
            groups.append(EventGroup(title: "Next Week", events: nextWeekEvents))
        }
        
        // Next month's events
        let nextMonthEvents = sortedEvents.filter { $0.dateTime >= nextMonth }
        if !nextMonthEvents.isEmpty {
            groups.append(EventGroup(title: "Next Month", events: nextMonthEvents))
        }
        
        return groups
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
        let userEvents = getUserEvents()
        let eventGroups = getEventGroups(from: userEvents)
        
        return LazyVStack(spacing: 16, pinnedViews: .sectionHeaders) {
            ForEach(eventGroups) { group in
                Section(header: sectionHeader(title: group.title)) {
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
    
    
    private func getUserEvents() -> [Event] {
        guard let currentUser = currentUser else { return [] }
        
        // First filter events by user participation
        let userParticipatedEvents = eventViewModel.events.filter { event in
            event.hostId == currentUser.id || event.attendeeIds.contains(currentUser.id)
        }
        
        // Then filter by event status
        return userParticipatedEvents.filter { event in
            event.status == .upcoming || event.status == .active
        }
    }
    
    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(Color("pine"))
                .padding(.horizontal)
                .padding(.vertical, 8)
            Spacer()
        }
       // .background(
            // Use background modifier with clear color to create a hit testing area
            // but maintain visual transparency
           // Color("beige")
       // )
        .overlay(
            // Add a subtle bottom border to visually separate sections
            // without relying on background opacity
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color("pine").opacity(0.1)),
            alignment: .bottom
        )
    }
    
    
    }
struct FriendsSection: View {
    //let title: String
    let friends: [User]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            ForEach(friends) { friend in
                HStack {
                    if let imageData = friend.profileImageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    } else {
                        Image("defaultProfilePic")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    }
                    VStack(alignment: .leading) {
                        Text("\(friend.firstName) \(friend.lastName)")
                            .foregroundColor(Color("pine"))
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
