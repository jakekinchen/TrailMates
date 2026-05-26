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

    func fetchAllEvents(limit: Int = 50) async throws -> [Event] {
        // Use retry logic for network fetch
        let snapshot = try await withRetry(maxAttempts: 3) {
            try await self.db.collection(FirestoreConstants.Collections.events)
                .limit(to: limit)
                .getDocuments()
        }
        return snapshot.documents.compactMap { try? $0.data(as: Event.self) }
    }

    func fetchEvent(by id: String) async -> Event? {
        do {
            // Use retry logic for network fetch
            let document = try await withRetry(maxAttempts: 3) {
                try await self.db.collection(FirestoreConstants.Collections.events).document(id).getDocument()
            }
            return try document.data(as: Event.self)
        } catch {
            let appError = AppError.classify(error)
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
            try await db.collection(FirestoreConstants.Collections.events)
                .document(event.id)
                .updateData(["status": event.status.rawValue])
            return event
        } catch {
            let appError = AppError.classify(error)
            #if DEBUG
            print("EventDataProvider: Error updating event status: \(appError.errorDescription ?? "Unknown")")
            #endif
            return event
        }
    }

    func updateAttendance(eventId: String, userId: String, isAttending: Bool) async throws -> Event {
        let eventRef = db.collection(FirestoreConstants.Collections.events).document(eventId)
        let attendeeUpdate = isAttending
            ? FieldValue.arrayUnion([userId])
            : FieldValue.arrayRemove([userId])

        try await withRetry(maxAttempts: 3) {
            try await eventRef.updateData(["attendeeIds": attendeeUpdate])
        }

        guard let updatedEvent = await fetchEvent(by: eventId) else {
            throw AppError.notFound("Event")
        }

        return updatedEvent
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
            let appError = AppError.classify(error)
            #if DEBUG
            print("EventDataProvider: Error fetching user events: \(appError.errorDescription ?? "Unknown")")
            #endif
            return []
        }
    }

    func fetchCircleEvents(for userId: String, friendIds: [String]) async -> [Event] {
        let allIds = [userId] + friendIds

        // Firestore 'in' queries are limited to 30 items; chunk when necessary
        let chunkSize = 30
        var allEvents: [Event] = []

        for chunkStart in stride(from: 0, to: allIds.count, by: chunkSize) {
            let chunkEnd = min(chunkStart + chunkSize, allIds.count)
            let chunk = Array(allIds[chunkStart..<chunkEnd])

            do {
                let snapshot = try await withRetry(maxAttempts: 3) {
                    try await self.db.collection(FirestoreConstants.Collections.events)
                        .whereField("hostId", in: chunk)
                        .getDocuments()
                }
                let chunkEvents = snapshot.documents.compactMap { try? $0.data(as: Event.self) }
                allEvents.append(contentsOf: chunkEvents)
            } catch {
                let appError = AppError.classify(error)
                #if DEBUG
                print("EventDataProvider: Error fetching circle events chunk: \(appError.errorDescription ?? "Unknown")")
                #endif
            }
        }

        return allEvents
    }

    func fetchPublicEvents() async throws -> [Event] {
        // Use retry logic for network fetch
        let snapshot = try await withRetry(maxAttempts: 3) {
            try await self.db.collection(FirestoreConstants.Collections.events)
                .whereField("isPublic", isEqualTo: true)
                .getDocuments()
        }
        return snapshot.documents.compactMap { try? $0.data(as: Event.self) }
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
            let appError = AppError.classify(error)
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
            let appError = AppError.classify(error)
            #if DEBUG
            print("EventDataProvider: Error fetching events in date range: \(appError.errorDescription ?? "Unknown")")
            #endif
            return []
        }
    }
}
