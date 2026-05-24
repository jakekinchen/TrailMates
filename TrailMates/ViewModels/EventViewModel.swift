import SwiftUI

import CoreLocation

// MARK: - EventGroup

/// Groups events by date section for display in lists.
/// Shared across MapView and EventsView.
struct EventGroup: Identifiable {
    let id = UUID()
    let title: String
    let events: [Event]
}

@MainActor
class EventViewModel: ObservableObject {
    // MARK: - Singleton
    static let shared = EventViewModel()

    // MARK: - Cached Formatters
    private static let sectionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()
    
    // MARK: - Published Properties
    @Published private(set) var events: [Event] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    // MARK: - Private Properties
    private let eventProvider = EventDataProvider.shared

    // MARK: - Initialization
    private init() {
        Task { await loadEvents() }
    }

    // MARK: - Public Methods
    
    /// Asynchronously loads all events from the data provider
    func loadEvents() async {
        isLoading = true
        defer { isLoading = false }

        self.events = await eventProvider.fetchAllEvents()
    }
    
    /// Groups events by their date sections
    func groupEvents(_ events: [Event]) -> [EventGroup] {
        let calendar = Calendar.current
        let now = Date()
        
        // Sort events by date
        let sortedEvents = events.sorted { $0.dateTime < $1.dateTime }
        
        // Create dictionary to collect events for each section
        var sectionDict: [Date: [Event]] = [:]
        
        for event in sortedEvents {
            let eventDate = event.dateTime
            
            // Determine the section date
            let sectionDate: Date
            if calendar.isDateInToday(eventDate) {
                sectionDate = calendar.startOfDay(for: now)
            } else if calendar.isDateInTomorrow(eventDate) {
                sectionDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)
            } else {
                sectionDate = calendar.startOfDay(for: eventDate)
            }
            
            sectionDict[sectionDate, default: []].append(event)
        }
        
        // Create the groupedEvents array with proper titles
        var groupedEvents: [(sectionDate: Date, title: String, events: [Event])] = []
        
        for (sectionDate, events) in sectionDict {
            let title: String
            if calendar.isDateInToday(sectionDate) {
                title = "Today"
            } else if calendar.isDateInTomorrow(sectionDate) {
                title = "Tomorrow"
            } else if sectionDate < now {
                title = "Past"
            } else {
                title = Self.sectionDateFormatter.string(from: sectionDate)
            }
            
            groupedEvents.append((sectionDate: sectionDate, title: title, events: events))
        }
        
        return groupedEvents
            .sorted { $0.sectionDate < $1.sectionDate }
            .map { EventGroup(title: $0.title, events: $0.events) }
    }
    
    /// Creates a new event
    func createEvent(
        for user: User,
        title: String,
        description: String?,
        location: CLLocationCoordinate2D,
        locationName: String? = nil,
        date: Date,
        isPublic: Bool,
        eventType: Event.EventType = .walk,
        tags: [String]? = nil
    ) async throws {
        // 1. Generate a Firestore reference with a new ID
        let (_, eventId) = eventProvider.generateNewEventReference()

        // 2. Create the event using this new ID
        let newEvent = Event(
            id: eventId,
            title: title,
            description: description,
            location: location,
            locationName: locationName,
            dateTime: date,
            hostId: user.id,
            eventType: eventType,
            isPublic: isPublic,
            tags: tags ?? [],
            attendeeIds: [],
            status: .upcoming
        )

        // 3. Save the event to Firestore using eventProvider
        try await eventProvider.saveEvent(newEvent)

        // 4. Reload events if needed
        await loadEvents()
    }

    
    /// Allows a user to attend an event
    func attendEvent(userId: String, eventId: String) async throws {
        // Optimistically update local state first for immediate UI feedback
        if let index = events.firstIndex(where: { $0.id == eventId }) {
            events[index].attendeeIds.insert(userId)
        }

        guard var event = await eventProvider.fetchEvent(by: eventId) else {
            // Revert optimistic update on error
            if let index = events.firstIndex(where: { $0.id == eventId }) {
                events[index].attendeeIds.remove(userId)
            }
            throw AppError.notFound("Event")
        }

        event.attendeeIds.insert(userId)
        try await eventProvider.saveEvent(event)
        // No need to reload - local state is already correct
    }

    /// Allows a user to leave an event
    func leaveEvent(userId: String, eventId: String) async throws {
        // Optimistically update local state first for immediate UI feedback
        if let index = events.firstIndex(where: { $0.id == eventId }) {
            events[index].attendeeIds.remove(userId)
        }

        guard var event = await eventProvider.fetchEvent(by: eventId) else {
            // Revert optimistic update on error
            if let index = events.firstIndex(where: { $0.id == eventId }) {
                events[index].attendeeIds.insert(userId)
            }
            throw AppError.notFound("Event")
        }

        event.attendeeIds.remove(userId)
        try await eventProvider.saveEvent(event)
        // No need to reload - local state is already correct
    }

    /// Cancels an event if the requester is the host
    func cancelEvent(eventId: String, hostId: String) async throws -> Bool {
        guard let event = await eventProvider.fetchEvent(by: eventId) else {
            throw AppError.notFound("Event")
        }

        guard event.hostId == hostId else {
            throw AppError.unauthorized()
        }

        try await eventProvider.deleteEvent(eventId)
        await loadEvents()
        return true
    }
    
    /// Groups events into date-based sections (Today, Tomorrow, This Week, etc.)
    /// Used by MapView's bottom sheet to display events in chronological groups.
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

    /// Returns events the user is participating in (as host or attendee) that are upcoming or active.
    func getUserEvents(for userId: String) -> [Event] {
        // First filter events by user participation
        let userParticipatedEvents = events.filter { event in
            event.hostId == userId || event.attendeeIds.contains(userId)
        }

        // Then filter by event status
        return userParticipatedEvents.filter { event in
            event.status == .upcoming || event.status == .active
        }
    }

    /// Filters events based on user preferences and active segment
    func getFilteredEvents(for user: User, activeSegment: String, showOnlyMyEvents: Bool) -> [Event] {
        let filteredEvents = showOnlyMyEvents ?
            events.filter { $0.hostId == user.id || $0.attendeeIds.contains(user.id) } :
            events
        
        switch activeSegment {
        case "myEvents":
            return filteredEvents.filter { $0.hostId == user.id }
        case "circle":
            return filteredEvents.filter { user.friends.contains($0.hostId) }
        case "explore":
            return filteredEvents.filter {
                $0.isPublic &&
                $0.hostId != user.id &&
                !user.friends.contains($0.hostId)
            }
        default:
            return []
        }
    }
}
