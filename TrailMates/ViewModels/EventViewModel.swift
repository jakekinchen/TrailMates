import SwiftUI
import Combine
import CoreLocation

@MainActor
class EventViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var events: [Event] = []
    @Published var errorMessage: String? = nil  // Optional property to handle errors if needed in the future
    
    // MARK: - Private Properties
    private let dataProvider: DataProvider
    
    // MARK: - Initialization
    /// Synchronous initializer compatible with SwiftUI's @StateObject
    /// - Parameter dataProvider: An object conforming to DataProvider protocol. Defaults to MockDataProvider.
    init(dataProvider: DataProvider = MockDataProvider()) {
        self.dataProvider = dataProvider
        // Initiate asynchronous task to load events without blocking the initializer
        Task { await loadEvents() }
    }
    
    /// Groups events by their date sections
    func groupEvents(_ events: [Event]) -> [EventsView.EventGroup] {
        let calendar = Calendar.current
        let now = Date()
        
        // Sort events by date
        let sortedEvents = events.sorted { $0.dateTime < $1.dateTime }
        
        // Create array to group events with their section date
        var groupedEvents: [(sectionDate: Date, title: String, events: [Event])] = []
        
        // Create a dictionary to collect events for each section
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
        
        // Now create the groupedEvents array
        for (sectionDate, events) in sectionDict {
            // Determine the section title
            let title: String
            if calendar.isDateInToday(sectionDate) {
                title = "Today"
            } else if calendar.isDateInTomorrow(sectionDate) {
                title = "Tomorrow"
            } else if sectionDate < now {
                title = "Past"
            } else {
                // Add day of the week for future dates
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE, MMMM d" // "Monday, January 1"
                title = formatter.string(from: sectionDate)
            }
            
            groupedEvents.append((sectionDate: sectionDate, title: title, events: events))
        }
        
        // Sort the groupedEvents by sectionDate
        let sortedGroupedEvents = groupedEvents.sorted { $0.sectionDate < $1.sectionDate }
        
        // Map to EventGroup and apply custom sorting for special titles
        return sortedGroupedEvents.map { EventsView.EventGroup(title: $0.title, events: $0.events) }
            .sorted { group1, group2 in
                let order = ["Today", "Tomorrow", "Past"]
                let index1 = order.firstIndex(of: group1.title) ?? Int.max
                let index2 = order.firstIndex(of: group2.title) ?? Int.max
                
                if index1 != index2 {
                    return index1 < index2
                } else {
                    // If both titles are not special, compare their dates
                    let date1 = groupedEvents.first { $0.title == group1.title }?.sectionDate ?? Date.distantFuture
                    let date2 = groupedEvents.first { $0.title == group2.title }?.sectionDate ?? Date.distantFuture
                    return date1 < date2
                }
            }
    }
    
    /// Filters events based on user preferences and active segment
    func getFilteredEvents(for user: User, activeSegment: String, showOnlyMyEvents: Bool) -> [Event] {
        let allEvents = events
        
        // First apply the showOnlyMyEvents filter if enabled
        let eventsAfterMyEventsFilter = showOnlyMyEvents ?
        allEvents.filter { event in
            event.hostId == user.id || event.attendeeIds.contains(user.id)
        } : allEvents
        
        // Then filter based on segment
        switch activeSegment {
        case "myEvents":
            // Show only events where the user is the host
            return eventsAfterMyEventsFilter.filter { event in
                event.hostId == user.id
            }
            
        case "circle":
            // Show events from friends, including events user is attending
            return eventsAfterMyEventsFilter.filter { event in
                user.friends.contains(event.hostId)
            }
            
        case "explore":
            // Show all public events except those from friends
            // But don't exclude events user is attending
            return eventsAfterMyEventsFilter.filter { event in
                event.isPublic &&
                event.hostId != user.id &&
                !user.friends.contains(event.hostId)
            }
            
        default:
            return []
        }
    }
    
    // MARK: - Private Methods
    
    /// Asynchronously loads all events from the data provider
    func loadEvents() async {
        // Since fetchAllEvents() does not throw, directly assign the result
        self.events = await dataProvider.fetchAllEvents()
    }
    
    // MARK: - Public Methods
    
    /// Creates a new event and refreshes the events list
    /// - Parameters:
    ///   - user: The user creating the event
    ///   - title: Title of the event
    ///   - description: Optional description of the event
    ///   - location: Geographical location of the event
    ///   - date: Date and time of the event
    ///   - isPublic: Privacy setting of the event
    ///   - eventType: Type/category of the event
    ///   - tags: Optional tags associated with the event
    func createEvent(
        for user: User,
        title: String,
        description: String?,
        location: CLLocationCoordinate2D,
        date: Date,
        isPublic: Bool,
        eventType: Event.EventType = .walk,
        tags: [String]? = nil
    ) async throws {
        let newEvent = Event(
            id: UUID(),
            title: title,
            description: description,
            location: location,
            dateTime: date,
            hostId: user.id,
            eventType: eventType,
            isPublic: isPublic,
            tags: tags ?? [],
            attendeeIds: [],
            status: .upcoming
        )
        try await dataProvider.saveEvent(newEvent)
        await loadEvents()
    }
    
    /// Allows a user to attend an event
    /// - Parameters:
    ///   - userId: UUID of the user attending
    ///   - eventId: UUID of the event to attend
    func attendEvent(userId: UUID, eventId: UUID) async throws {
        guard var event = await dataProvider.fetchEvent(by: eventId) else {
            // Optionally, set an error message if the event is not found
            self.errorMessage = "Event not found."
            return
        }
        event.attendeeIds.insert(userId)
        try await dataProvider.saveEvent(event)
        await loadEvents()
    }
    
    /// Cancels an event if the requester is the host
    /// - Parameters:
    ///   - eventId: UUID of the event to cancel
    ///   - hostId: UUID of the host requesting cancellation
    /// - Returns: Boolean indicating success or failure
    func cancelEvent(eventId: UUID, hostId: UUID) async throws -> Bool {
        guard let event = await dataProvider.fetchEvent(by: eventId),
              event.hostId == hostId else {
            // Optionally, set an error message if unauthorized or event not found
            self.errorMessage = "Unauthorized to cancel this event or event not found."
            return false
        }
        try await dataProvider.deleteEvent(eventId)
        await loadEvents()
        return true
    }
    
    /// Allows a user to leave an event they are attending
    /// - Parameters:
    ///   - userId: UUID of the user leaving
    ///   - eventId: UUID of the event to leave
    func leaveEvent(userId: UUID, eventId: UUID) async throws {
        guard var event = await dataProvider.fetchEvent(by: eventId) else {
            // Optionally, set an error message if the event is not found
            self.errorMessage = "Event not found."
            return
        }
        event.attendeeIds.remove(userId)
        try await dataProvider.saveEvent(event)
        await loadEvents()
    }
    
    /// Fetches events specific to a user
    /// - Parameter user: The user whose events are to be fetched
    /// - Returns: Array of events associated with the user
    func fetchEventsForUser(_ user: User) async -> [Event] {
        return await dataProvider.fetchUserEvents(for: user.id)
    }
    
    /// Fetches all public events
    /// - Returns: Array of public events
    func fetchPublicEvents() async -> [Event] {
        return await dataProvider.fetchPublicEvents()
    }
    
    
    /// Fetches events filtered by their type
    /// - Parameter type: The event type to filter by
    /// - Returns: Array of events matching the specified type
    func fetchEventsByType(_ type: Event.EventType) async -> [Event] {
        let allEvents = await dataProvider.fetchAllEvents()
        return allEvents.filter { $0.eventType == type }
    }
    
}
