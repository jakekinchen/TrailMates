import Foundation
import Firebase
import FirebaseFirestore

/// Handles all event-related Firebase operations
/// Extracted from FirebaseDataProvider as part of the provider refactoring
class EventDataProvider {
    // MARK: - Singleton
    static let shared = EventDataProvider()

    // MARK: - Dependencies
    private lazy var db = Firestore.firestore()

    private init() {
        // Configure Firestore settings if not already configured
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings()
        db.settings = settings

        print("EventDataProvider initialized")
    }

    // MARK: - Event CRUD Operations

    func fetchAllEvents() async -> [Event] {
        do {
            let snapshot = try await db.collection("events").getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: Event.self) }
        } catch {
            print("EventDataProvider: Error fetching all events: \(error)")
            return []
        }
    }

    func fetchEvent(by id: String) async -> Event? {
        do {
            let document = try await db.collection("events").document(id).getDocument()
            return try document.data(as: Event.self)
        } catch {
            print("EventDataProvider: Error fetching event: \(error)")
            return nil
        }
    }

    func saveEvent(_ event: Event) async throws {
        let eventRef = db.collection("events").document(event.id)
        let data = try Firestore.Encoder().encode(event)
        try await eventRef.setData(data)
    }

    func deleteEvent(_ eventId: String) async throws {
        try await db.collection("events").document(eventId).delete()
    }

    func updateEventStatus(_ event: Event) async -> Event {
        do {
            let updatedEvent = event
            try await saveEvent(updatedEvent)
            return updatedEvent
        } catch {
            print("EventDataProvider: Error updating event status: \(error)")
            return event
        }
    }

    /// Generate a new event reference with DocumentReference type (for internal use)
    func generateNewEventReference() -> (reference: DocumentReference, id: String) {
        let eventRef = db.collection("events").document()
        return (eventRef, eventRef.documentID)
    }

    /// Generate a new event reference with Any type (for protocol conformance)
    /// This allows the protocol to be Firebase-agnostic for testing
    func generateNewEventReferenceAny() -> (reference: Any, id: String) {
        let result = generateNewEventReference()
        return (reference: result.reference as Any, id: result.id)
    }

    // MARK: - Event Query Methods

    func fetchUserEvents(for userId: String) async -> [Event] {
        do {
            let snapshot = try await db.collection("events")
                .whereField("creatorId", isEqualTo: userId)
                .getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: Event.self) }
        } catch {
            print("EventDataProvider: Error fetching user events: \(error)")
            return []
        }
    }

    func fetchCircleEvents(for userId: String, friendIds: [String]) async -> [Event] {
        do {
            let friendIdsStrings = friendIds.map { $0 }
            let snapshot = try await db.collection("events")
                .whereField("creatorId", in: [userId] + friendIdsStrings)
                .getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: Event.self) }
        } catch {
            print("EventDataProvider: Error fetching circle events: \(error)")
            return []
        }
    }

    func fetchPublicEvents() async -> [Event] {
        do {
            let snapshot = try await db.collection("events")
                .whereField("isPublic", isEqualTo: true)
                .getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: Event.self) }
        } catch {
            print("EventDataProvider: Error fetching public events: \(error)")
            return []
        }
    }

    /// Fetch events that the user is attending
    func fetchAttendingEvents(for userId: String) async -> [Event] {
        do {
            let snapshot = try await db.collection("events")
                .whereField("attendeeIds", arrayContains: userId)
                .getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: Event.self) }
        } catch {
            print("EventDataProvider: Error fetching attending events: \(error)")
            return []
        }
    }

    /// Fetch events within a date range
    func fetchEvents(from startDate: Date, to endDate: Date) async -> [Event] {
        do {
            let snapshot = try await db.collection("events")
                .whereField("startTime", isGreaterThanOrEqualTo: startDate)
                .whereField("startTime", isLessThanOrEqualTo: endDate)
                .getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: Event.self) }
        } catch {
            print("EventDataProvider: Error fetching events in date range: \(error)")
            return []
        }
    }
}
