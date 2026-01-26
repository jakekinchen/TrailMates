import Testing
import Foundation
import CoreLocation
@testable import TrailMatesATX

/// Tests for EventViewModel event management and filtering logic.
/// Note: EventViewModel uses a singleton pattern with FirebaseDataProvider dependency.
/// These tests focus on event grouping, filtering, and model validation.
@Suite("EventViewModel Tests")
struct EventViewModelTests {

    // MARK: - Event Model Tests

    @Test("Event model stores all properties correctly")
    func testEventModelProperties() {
        let location = CLLocationCoordinate2D(latitude: 30.2672, longitude: -97.7431)
        let dateTime = Date()

        let event = Event(
            id: "test-event",
            title: "Test Event",
            description: "A test description",
            location: location,
            dateTime: dateTime,
            hostId: "host-id",
            eventType: .walk,
            isPublic: true,
            tags: ["test", "sample"],
            attendeeIds: ["user-1", "user-2"],
            status: .upcoming
        )

        #expect(event.id == "test-event")
        #expect(event.title == "Test Event")
        #expect(event.description == "A test description")
        #expect(event.location.latitude == location.latitude)
        #expect(event.location.longitude == location.longitude)
        #expect(event.hostId == "host-id")
        #expect(event.eventType == .walk)
        #expect(event.isPublic == true)
        #expect(event.tags == ["test", "sample"])
        #expect(event.attendeeIds.contains("user-1"))
        #expect(event.attendeeIds.contains("user-2"))
        #expect(event.status == .upcoming)
    }

    @Test("Event model handles optional description")
    func testEventOptionalDescription() {
        let event = TestFixtures.createEvent(description: nil)

        #expect(event.description == nil)
    }

    @Test("Event model event types are correct")
    func testEventTypes() {
        let walkEvent = TestFixtures.createEvent(eventType: .walk)
        let bikeEvent = TestFixtures.createEvent(eventType: .bike)
        let runEvent = TestFixtures.createEvent(eventType: .run)

        #expect(walkEvent.eventType == .walk)
        #expect(bikeEvent.eventType == .bike)
        #expect(runEvent.eventType == .run)
    }

    @Test("Event model status types are correct")
    func testEventStatuses() {
        let upcomingEvent = TestFixtures.createEvent(status: .upcoming)
        let activeEvent = TestFixtures.createEvent(status: .active)
        let completedEvent = TestFixtures.createEvent(status: .completed)
        let canceledEvent = TestFixtures.createEvent(status: .canceled)

        #expect(upcomingEvent.status == .upcoming)
        #expect(activeEvent.status == .active)
        #expect(completedEvent.status == .completed)
        #expect(canceledEvent.status == .canceled)
    }

    // MARK: - Event Utility Function Tests

    @Test("isUpcoming returns true for future events")
    func testIsUpcomingForFutureEvent() {
        let futureEvent = TestFixtures.createEvent(
            dateTime: Date().addingTimeInterval(86400) // Tomorrow
        )

        #expect(futureEvent.isUpcoming() == true)
    }

    @Test("isUpcoming returns false for past events")
    func testIsUpcomingForPastEvent() {
        let pastEvent = TestFixtures.createEvent(
            dateTime: Date().addingTimeInterval(-86400) // Yesterday
        )

        #expect(pastEvent.isUpcoming() == false)
    }

    @Test("formattedDate returns non-empty string")
    func testFormattedDate() {
        let event = TestFixtures.sampleWalkEvent

        let formattedDate = event.formattedDate()

        #expect(!formattedDate.isEmpty)
    }

    // MARK: - Attendee Management Tests

    @Test("Event attendeeIds can be modified")
    func testEventAttendeeManagement() {
        var event = TestFixtures.createEvent(attendeeIds: [])

        #expect(event.attendeeIds.isEmpty)

        // Add attendee
        event.attendeeIds.insert("user-1")
        #expect(event.attendeeIds.contains("user-1"))

        // Add another attendee
        event.attendeeIds.insert("user-2")
        #expect(event.attendeeIds.count == 2)

        // Remove attendee
        event.attendeeIds.remove("user-1")
        #expect(!event.attendeeIds.contains("user-1"))
        #expect(event.attendeeIds.contains("user-2"))
    }

    @Test("Event attendeeIds uses Set semantics (no duplicates)")
    func testEventAttendeesNoDuplicates() {
        var event = TestFixtures.createEvent(attendeeIds: [])

        event.attendeeIds.insert("user-1")
        event.attendeeIds.insert("user-1")
        event.attendeeIds.insert("user-1")

        #expect(event.attendeeIds.count == 1)
    }

    // MARK: - Event Tags Tests

    @Test("Event tags can be stored and retrieved")
    func testEventTags() {
        let event = TestFixtures.createEvent(tags: ["hiking", "morning", "beginner"])

        #expect(event.tags.count == 3)
        #expect(event.tags.contains("hiking"))
        #expect(event.tags.contains("morning"))
        #expect(event.tags.contains("beginner"))
    }

    @Test("Event can have empty tags")
    func testEventEmptyTags() {
        let event = TestFixtures.createEvent(tags: [])

        #expect(event.tags.isEmpty)
    }

    // MARK: - Event Encoding/Decoding Tests

    @Test("Event model encodes and decodes correctly")
    func testEventEncodingDecoding() throws {
        let originalEvent = TestFixtures.sampleWalkEvent

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalEvent)

        let decoder = JSONDecoder()
        let decodedEvent = try decoder.decode(Event.self, from: data)

        #expect(decodedEvent.id == originalEvent.id)
        #expect(decodedEvent.title == originalEvent.title)
        #expect(decodedEvent.description == originalEvent.description)
        #expect(decodedEvent.hostId == originalEvent.hostId)
        #expect(decodedEvent.eventType == originalEvent.eventType)
        #expect(decodedEvent.isPublic == originalEvent.isPublic)
        #expect(decodedEvent.status == originalEvent.status)
    }

    // MARK: - Event Location Tests

    @Test("Event stores location coordinates correctly")
    func testEventLocation() {
        let location = TestFixtures.austinDowntown
        let event = TestFixtures.createEvent(location: location)

        #expect(event.location == location)
    }

    @Test("Event location can be different coordinates")
    func testEventDifferentLocations() {
        let event1 = TestFixtures.createEvent(location: TestFixtures.austinDowntown)
        let event2 = TestFixtures.createEvent(location: TestFixtures.zilkerPark)

        #expect(event1.location != event2.location)
    }

    // MARK: - Event Visibility Tests

    @Test("Event public flag works correctly")
    func testEventPublicFlag() {
        let publicEvent = TestFixtures.createEvent(isPublic: true)
        let privateEvent = TestFixtures.createEvent(isPublic: false)

        #expect(publicEvent.isPublic == true)
        #expect(privateEvent.isPublic == false)
    }

    // MARK: - Event Error Types Tests

    @Test("EventError eventNotFound has correct description")
    func testEventNotFoundError() {
        let error = EventViewModel.EventError.eventNotFound

        #expect(error.errorDescription == "Event not found")
    }

    @Test("EventError unauthorized has correct description")
    func testUnauthorizedError() {
        let error = EventViewModel.EventError.unauthorized

        #expect(error.errorDescription == "You are not authorized to perform this action")
    }

    // MARK: - Event Filtering Logic Tests

    @Test("Filter events by host ID")
    func testFilterEventsByHost() {
        let events = [
            TestFixtures.createEvent(id: "1", hostId: "user-a"),
            TestFixtures.createEvent(id: "2", hostId: "user-b"),
            TestFixtures.createEvent(id: "3", hostId: "user-a"),
            TestFixtures.createEvent(id: "4", hostId: "user-c")
        ]

        let userAEvents = events.filter { $0.hostId == "user-a" }

        #expect(userAEvents.count == 2)
        #expect(userAEvents.allSatisfy { $0.hostId == "user-a" })
    }

    @Test("Filter events by attendee")
    func testFilterEventsByAttendee() {
        let events = [
            TestFixtures.createEvent(id: "1", attendeeIds: ["user-1", "user-2"]),
            TestFixtures.createEvent(id: "2", attendeeIds: ["user-2", "user-3"]),
            TestFixtures.createEvent(id: "3", attendeeIds: ["user-1"]),
            TestFixtures.createEvent(id: "4", attendeeIds: [])
        ]

        let user1Events = events.filter { $0.attendeeIds.contains("user-1") }

        #expect(user1Events.count == 2)
    }

    @Test("Filter public events")
    func testFilterPublicEvents() {
        let events = [
            TestFixtures.createEvent(id: "1", isPublic: true),
            TestFixtures.createEvent(id: "2", isPublic: false),
            TestFixtures.createEvent(id: "3", isPublic: true),
            TestFixtures.createEvent(id: "4", isPublic: false)
        ]

        let publicEvents = events.filter { $0.isPublic }

        #expect(publicEvents.count == 2)
    }

    @Test("Filter events by status")
    func testFilterEventsByStatus() {
        let events = TestFixtures.mixedStatusEvents

        let upcomingEvents = events.filter { $0.status == .upcoming }
        let canceledEvents = events.filter { $0.status == .canceled }
        let completedEvents = events.filter { $0.status == .completed }

        #expect(upcomingEvents.count >= 1)
        #expect(canceledEvents.count == 1)
        #expect(completedEvents.count == 1)
    }

    // MARK: - Event Sorting Tests

    @Test("Events can be sorted by date")
    func testSortEventsByDate() {
        let now = Date()
        let events = [
            TestFixtures.createEvent(id: "3", dateTime: now.addingTimeInterval(300)),
            TestFixtures.createEvent(id: "1", dateTime: now.addingTimeInterval(100)),
            TestFixtures.createEvent(id: "2", dateTime: now.addingTimeInterval(200))
        ]

        let sorted = events.sorted { $0.dateTime < $1.dateTime }

        #expect(sorted[0].id == "1")
        #expect(sorted[1].id == "2")
        #expect(sorted[2].id == "3")
    }

    // MARK: - Event Grouping Logic Tests

    @Test("Events can be grouped by event type")
    func testGroupEventsByType() {
        let events = [
            TestFixtures.createEvent(id: "1", eventType: .walk),
            TestFixtures.createEvent(id: "2", eventType: .bike),
            TestFixtures.createEvent(id: "3", eventType: .walk),
            TestFixtures.createEvent(id: "4", eventType: .run),
            TestFixtures.createEvent(id: "5", eventType: .bike)
        ]

        let grouped = Dictionary(grouping: events) { $0.eventType }

        #expect(grouped[.walk]?.count == 2)
        #expect(grouped[.bike]?.count == 2)
        #expect(grouped[.run]?.count == 1)
    }

    @Test("Events can be grouped by host")
    func testGroupEventsByHost() {
        let events = [
            TestFixtures.createEvent(id: "1", hostId: "host-a"),
            TestFixtures.createEvent(id: "2", hostId: "host-b"),
            TestFixtures.createEvent(id: "3", hostId: "host-a")
        ]

        let grouped = Dictionary(grouping: events) { $0.hostId }

        #expect(grouped["host-a"]?.count == 2)
        #expect(grouped["host-b"]?.count == 1)
    }

    // MARK: - My Events Filter Tests

    @Test("Filter my events (hosted or attending)")
    func testFilterMyEvents() {
        let currentUserId = "current-user"

        let events = [
            TestFixtures.createEvent(id: "1", hostId: currentUserId, attendeeIds: []),
            TestFixtures.createEvent(id: "2", hostId: "other-host", attendeeIds: [currentUserId]),
            TestFixtures.createEvent(id: "3", hostId: "other-host", attendeeIds: ["other-user"]),
            TestFixtures.createEvent(id: "4", hostId: currentUserId, attendeeIds: ["other-user"])
        ]

        let myEvents = events.filter {
            $0.hostId == currentUserId || $0.attendeeIds.contains(currentUserId)
        }

        #expect(myEvents.count == 3)
    }

    // MARK: - Circle Events Filter Tests

    @Test("Filter circle events (friends' events)")
    func testFilterCircleEvents() {
        let friendIds = ["friend-1", "friend-2"]

        let events = [
            TestFixtures.createEvent(id: "1", hostId: "friend-1"),
            TestFixtures.createEvent(id: "2", hostId: "friend-2"),
            TestFixtures.createEvent(id: "3", hostId: "stranger"),
            TestFixtures.createEvent(id: "4", hostId: "friend-1")
        ]

        let circleEvents = events.filter { friendIds.contains($0.hostId) }

        #expect(circleEvents.count == 3)
    }

    // MARK: - Explore Events Filter Tests

    @Test("Filter explore events (public, not mine, not friends)")
    func testFilterExploreEvents() {
        let currentUserId = "current-user"
        let friendIds = ["friend-1", "friend-2"]

        let events = [
            TestFixtures.createEvent(id: "1", hostId: currentUserId, isPublic: true),
            TestFixtures.createEvent(id: "2", hostId: "friend-1", isPublic: true),
            TestFixtures.createEvent(id: "3", hostId: "stranger", isPublic: true),
            TestFixtures.createEvent(id: "4", hostId: "stranger", isPublic: false),
            TestFixtures.createEvent(id: "5", hostId: "another-stranger", isPublic: true)
        ]

        let exploreEvents = events.filter {
            $0.isPublic &&
            $0.hostId != currentUserId &&
            !friendIds.contains($0.hostId)
        }

        #expect(exploreEvents.count == 2) // Events 3 and 5
    }

    // MARK: - Test Fixtures Validation

    @Test("Test fixtures create valid event objects")
    func testFixturesCreateValidEvents() {
        let event = TestFixtures.sampleWalkEvent

        #expect(!event.id.isEmpty)
        #expect(!event.title.isEmpty)
        #expect(!event.hostId.isEmpty)
    }

    @Test("Test fixtures create distinct events")
    func testFixturesCreateDistinctEvents() {
        let events = TestFixtures.sampleEvents

        #expect(events.count == 3)

        let ids = Set(events.map { $0.id })
        #expect(ids.count == 3)
    }

    @Test("Test fixtures create events with different types")
    func testFixturesCreateDifferentEventTypes() {
        let events = TestFixtures.sampleEvents

        let types = Set(events.map { $0.eventType })
        #expect(types.count == 3) // walk, bike, run
    }
}
