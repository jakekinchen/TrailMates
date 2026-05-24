import Foundation
import Firebase
import FirebaseFirestore

/// Handles all event-related Firebase operations
/// Extracted from FirebaseDataProvider as part of the provider refactoring
@MainActor
class EventDataProvider {
    // MARK: - Singleton
    static let shared = EventDataProvider()

    // MARK: - Dependencies
    private lazy var db = Firestore.firestore()

    private init() {
        // Firestore settings (persistence, cache) are configured centrally
        // in FirebaseProviderContainer.init() to avoid duplicate configuration.
        print("EventDataProvider initialized")
    }

    // MARK: - Event CRUD Operations

    func fetchAllEvents() async -> [Event] {
        do {
            // Use retry logic for network fetch
            let snapshot = try await withRetry(maxAttempts: 3) {
                try await self.db.collection(FirestoreConstants.Collections.events).getDocuments()
            }
            return snapshot.documents.compactMap { try? $0.data(as: Event.self) }
        } catch {
            let appError = AppError.from(error)
            #if DEBUG
            print("EventDataProvider: Error fetching all events: \(appError.errorDescription ?? "Unknown")")
            #endif
            return []
        }
    }

    func fetchEvent(by id: String) async -> Event? {
        do {
            // Use retry logic for network fetch
            let document = try await withRetry(maxAttempts: 3) {
                try await self.db.collection(FirestoreConstants.Collections.events).document(id).getDocument()
            }
            return try document.data(as: Event.self)
        } catch {
            let appError = AppError.from(error)
            #if DEBUG
            print("EventDataProvider: Error fetching event: \(appError.errorDescription ?? "Unknown")")
            #endif
            return nil
        }
    }

    func saveEvent(_ event: Event) async throws {
        let eventRef = db.collection(FirestoreConstants.Collections.events).document(event.id)
        let data = try Firestore.Encoder().encode(event)
        try await eventRef.setData(data)
    }

    func deleteEvent(_ eventId: String) async throws {
        try await db.collection(FirestoreConstants.Collections.events).document(eventId).delete()
    }

    func updateEventStatus(_ event: Event) async -> Event {
        do {
            let updatedEvent = event
            try await saveEvent(updatedEvent)
            return updatedEvent
        } catch {
            let appError = AppError.from(error)
            #if DEBUG
            print("EventDataProvider: Error updating event status: \(appError.errorDescription ?? "Unknown")")
            #endif
            return event
        }
    }

    /// Generate a new event reference with DocumentReference type (for internal use)
    func generateNewEventReference() -> (reference: DocumentReference, id: String) {
        let eventRef = db.collection(FirestoreConstants.Collections.events).document()
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
            // Use retry logic for network fetch
            let snapshot = try await withRetry(maxAttempts: 3) {
                try await self.db.collection(FirestoreConstants.Collections.events)
                    .whereField("hostId", isEqualTo: userId)
                    .getDocuments()
            }
            return snapshot.documents.compactMap { try? $0.data(as: Event.self) }
        } catch {
            let appError = AppError.from(error)
            #if DEBUG
            print("EventDataProvider: Error fetching user events: \(appError.errorDescription ?? "Unknown")")
            #endif
            return []
        }
    }

    func fetchCircleEvents(for userId: String, friendIds: [String]) async -> [Event] {
        do {
            // Use retry logic for network fetch
            let snapshot = try await withRetry(maxAttempts: 3) {
                try await self.db.collection(FirestoreConstants.Collections.events)
                    .whereField("hostId", in: [userId] + friendIds)
                    .getDocuments()
            }
            return snapshot.documents.compactMap { try? $0.data(as: Event.self) }
        } catch {
            let appError = AppError.from(error)
            #if DEBUG
            print("EventDataProvider: Error fetching circle events: \(appError.errorDescription ?? "Unknown")")
            #endif
            return []
        }
    }

    func fetchPublicEvents() async -> [Event] {
        do {
            // Use retry logic for network fetch
            let snapshot = try await withRetry(maxAttempts: 3) {
                try await self.db.collection(FirestoreConstants.Collections.events)
                    .whereField("isPublic", isEqualTo: true)
                    .getDocuments()
            }
            return snapshot.documents.compactMap { try? $0.data(as: Event.self) }
        } catch {
            let appError = AppError.from(error)
            #if DEBUG
            print("EventDataProvider: Error fetching public events: \(appError.errorDescription ?? "Unknown")")
            #endif
            return []
        }
    }

    /// Fetch events that the user is attending
    func fetchAttendingEvents(for userId: String) async -> [Event] {
        do {
            // Use retry logic for network fetch
            let snapshot = try await withRetry(maxAttempts: 3) {
                try await self.db.collection(FirestoreConstants.Collections.events)
                    .whereField("attendeeIds", arrayContains: userId)
                    .getDocuments()
            }
            return snapshot.documents.compactMap { try? $0.data(as: Event.self) }
        } catch {
            let appError = AppError.from(error)
            #if DEBUG
            print("EventDataProvider: Error fetching attending events: \(appError.errorDescription ?? "Unknown")")
            #endif
            return []
        }
    }

    /// Fetch events within a date range
    func fetchEvents(from startDate: Date, to endDate: Date) async -> [Event] {
        do {
            // Use retry logic for network fetch
            let snapshot = try await withRetry(maxAttempts: 3) {
                try await self.db.collection(FirestoreConstants.Collections.events)
                    .whereField("dateTime", isGreaterThanOrEqualTo: startDate)
                    .whereField("dateTime", isLessThanOrEqualTo: endDate)
                    .getDocuments()
            }
            return snapshot.documents.compactMap { try? $0.data(as: Event.self) }
        } catch {
            let appError = AppError.from(error)
            #if DEBUG
            print("EventDataProvider: Error fetching events in date range: \(appError.errorDescription ?? "Unknown")")
            #endif
            return []
        }
    }
}
