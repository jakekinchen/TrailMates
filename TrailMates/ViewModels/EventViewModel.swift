import SwiftUI
import Combine
import CoreLocation

@MainActor
class EventViewModel: ObservableObject {
    // MARK: - Singleton
    static let shared = EventViewModel()
    
    // MARK: - Published Properties
    @Published private(set) var events: [Event] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    // MARK: - Private Properties
    // MARK: Sub-provider (preferred for new code)
    private let eventProvider = EventDataProvider.shared

    // Legacy provider (deprecated - use eventProvider instead)
    @available(*, deprecated, message: "Use eventProvider instead")
    let dataProvider: FirebaseDataProvider

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    private init(dataProvider: FirebaseDataProvider = FirebaseDataProvider.shared) {
        self.dataProvider = dataProvider
        setupSubscriptions()
        Task { await loadEvents() }
    }
    
    // MARK: - Private Methods
    private func setupSubscriptions() {
        // Add any Combine subscriptions here
    }
    // MARK: - Public Methods
    
    /// Asynchronously loads all events from the data provider
    func loadEvents() async {
        isLoading = true
        defer { isLoading = false }

        self.events = await eventProvider.fetchAllEvents()
    }
    
    /// Groups events by their date sections
    func groupEvents(_ events: [Event]) -> [EventsView.EventGroup] {
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
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE, MMMM d"
                title = formatter.string(from: sectionDate)
            }
            
            groupedEvents.append((sectionDate: sectionDate, title: title, events: events))
        }
        
        return groupedEvents
            .sorted { $0.sectionDate < $1.sectionDate }
            .map { EventsView.EventGroup(title: $0.title, events: $0.events) }
    }
    
    /// Creates a new event
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
        // 1. Generate a Firestore reference with a new ID
        let (_, eventId) = eventProvider.generateNewEventReference()

        // 2. Create the event using this new ID
        let newEvent = Event(
            id: eventId,
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

        // 3. Save the event to Firestore using eventProvider
        try await eventProvider.saveEvent(newEvent)

        // 4. Reload events if needed
        await loadEvents()
    }

    
    /// Allows a user to attend an event
    func attendEvent(userId: String, eventId: String) async throws {
        guard var event = await eventProvider.fetchEvent(by: eventId) else {
            throw EventError.eventNotFound
        }

        event.attendeeIds.insert(userId)
        try await eventProvider.saveEvent(event)
        await loadEvents()
    }

    /// Allows a user to leave an event
    func leaveEvent(userId: String, eventId: String) async throws {
        guard var event = await eventProvider.fetchEvent(by: eventId) else {
            throw EventError.eventNotFound
        }

        event.attendeeIds.remove(userId)
        try await eventProvider.saveEvent(event)
        await loadEvents()
    }

    /// Cancels an event if the requester is the host
    func cancelEvent(eventId: String, hostId: String) async throws -> Bool {
        guard let event = await eventProvider.fetchEvent(by: eventId) else {
            throw EventError.eventNotFound
        }

        guard event.hostId == hostId else {
            throw EventError.unauthorized
        }

        try await eventProvider.deleteEvent(eventId)
        await loadEvents()
        return true
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

// MARK: - Error Types
extension EventViewModel {
    /// Event-specific errors that map to AppError for consistent handling
    enum EventError: LocalizedError {
        case eventNotFound
        case unauthorized

        var errorDescription: String? {
            switch self {
            case .eventNotFound:
                return "Event not found"
            case .unauthorized:
                return "You are not authorized to perform this action"
            }
        }

        /// Convert to AppError for consistent error handling
        var asAppError: AppError {
            switch self {
            case .eventNotFound:
                return .notFound("Event")
            case .unauthorized:
                return .unauthorized()
            }
        }
    }
}
