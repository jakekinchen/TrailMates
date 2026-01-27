import Foundation
import CoreLocation
@testable import TrailMatesATX

/// Test fixtures providing sample data for unit tests.
/// Use these fixtures to create consistent test data across test files.
enum TestFixtures {

    // MARK: - User Fixtures

    /// Creates a sample user with default values that can be overridden.
    static func createUser(
        id: String = "test-user-id",
        firstName: String = "Test",
        lastName: String = "User",
        username: String = "testuser",
        phoneNumber: String = "+1 (555) 123-4567",
        // Use a deterministic default to keep equality tests stable.
        joinDate: Date = Date(timeIntervalSince1970: 0)
    ) -> User {
        let user = User(
            id: id,
            firstName: firstName,
            lastName: lastName,
            username: username,
            phoneNumber: phoneNumber,
            joinDate: joinDate
        )
        return user
    }

    /// A fully populated sample user for comprehensive tests.
    static var sampleUser: User {
        let user = createUser(
            id: "sample-user-1",
            firstName: "John",
            lastName: "Doe",
            username: "johndoe",
            phoneNumber: "+1 (555) 111-2222"
        )
        user.isActive = true
        user.doNotDisturb = false
        user.receiveFriendRequests = true
        user.receiveFriendEvents = true
        user.receiveEventUpdates = true
        user.shareLocationWithFriends = true
        user.shareLocationWithEventHost = true
        user.shareLocationWithEventGroup = true
        user.allowFriendsToInviteOthers = true
        return user
    }

    /// A second sample user for friend/interaction tests.
    static var sampleUser2: User {
        let user = createUser(
            id: "sample-user-2",
            firstName: "Jane",
            lastName: "Smith",
            username: "janesmith",
            phoneNumber: "+1 (555) 333-4444"
        )
        return user
    }

    /// A third sample user for group tests.
    static var sampleUser3: User {
        let user = createUser(
            id: "sample-user-3",
            firstName: "Bob",
            lastName: "Wilson",
            username: "bobwilson",
            phoneNumber: "+1 (555) 555-6666"
        )
        return user
    }

    /// A user with minimal data (e.g., newly created account).
    static var minimalUser: User {
        return createUser(
            id: "minimal-user",
            firstName: "",
            lastName: "",
            username: "",
            phoneNumber: "+1 (555) 777-8888"
        )
    }

    /// A user with complete profile including events and friends.
    static var completeUser: User {
        let user = sampleUser
        user.friends = ["sample-user-2", "sample-user-3"]
        user.createdEventIds = ["event-1", "event-2"]
        user.attendingEventIds = ["event-3"]
        user.visitedLandmarkIds = ["landmark-1", "landmark-2"]
        return user
    }

    // MARK: - Event Fixtures

    /// Creates a sample event with default values that can be overridden.
    static func createEvent(
        id: String = "test-event-id",
        title: String = "Test Event",
        description: String? = "A test event description",
        location: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 30.2672, longitude: -97.7431),
        dateTime: Date = Date().addingTimeInterval(86400), // Tomorrow
        hostId: String = "test-host-id",
        eventType: Event.EventType = .walk,
        isPublic: Bool = true,
        tags: [String] = ["test", "sample"],
        attendeeIds: Set<String> = [],
        status: Event.EventStatus = .upcoming
    ) -> Event {
        return Event(
            id: id,
            title: title,
            description: description,
            location: location,
            dateTime: dateTime,
            hostId: hostId,
            eventType: eventType,
            isPublic: isPublic,
            tags: tags,
            attendeeIds: attendeeIds,
            status: status
        )
    }

    /// A sample public walk event.
    static var sampleWalkEvent: Event {
        return createEvent(
            id: "walk-event-1",
            title: "Morning Walk at the Park",
            description: "Join us for a relaxing morning walk around the trail.",
            dateTime: Date().addingTimeInterval(86400),
            hostId: "sample-user-1",
            eventType: .walk,
            isPublic: true,
            tags: ["morning", "walk", "nature"]
        )
    }

    /// A sample private bike event.
    static var sampleBikeEvent: Event {
        return createEvent(
            id: "bike-event-1",
            title: "Weekend Bike Ride",
            description: "Private bike ride with friends.",
            dateTime: Date().addingTimeInterval(172800), // 2 days from now
            hostId: "sample-user-2",
            eventType: .bike,
            isPublic: false,
            tags: ["bike", "weekend", "friends"],
            attendeeIds: ["sample-user-1", "sample-user-3"]
        )
    }

    /// A sample run event happening today.
    static var sampleRunEvent: Event {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let eventTime = calendar.date(byAdding: .hour, value: 18, to: today) ?? Date()

        return createEvent(
            id: "run-event-1",
            title: "Evening Run",
            description: "Quick evening run to stay fit.",
            dateTime: eventTime,
            hostId: "sample-user-1",
            eventType: .run,
            isPublic: true,
            tags: ["run", "evening", "fitness"]
        )
    }

    /// A past event (completed).
    static var pastEvent: Event {
        return createEvent(
            id: "past-event-1",
            title: "Last Week's Walk",
            description: "A walk that already happened.",
            dateTime: Date().addingTimeInterval(-604800), // 1 week ago
            hostId: "sample-user-1",
            eventType: .walk,
            isPublic: true,
            status: .completed
        )
    }

    /// A canceled event.
    static var canceledEvent: Event {
        return createEvent(
            id: "canceled-event-1",
            title: "Canceled Meetup",
            description: "This event was canceled.",
            dateTime: Date().addingTimeInterval(86400),
            hostId: "sample-user-2",
            eventType: .walk,
            isPublic: true,
            status: .canceled
        )
    }

    // MARK: - Location Fixtures

    /// Austin, TX downtown coordinates.
    static var austinDowntown: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: 30.2672, longitude: -97.7431)
    }

    /// Zilker Park coordinates.
    static var zilkerPark: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: 30.2669, longitude: -97.7728)
    }

    /// Lady Bird Lake coordinates.
    static var ladyBirdLake: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: 30.2570, longitude: -97.7453)
    }

    // MARK: - Friend Request Fixtures

    /// Creates a sample friend request.
    static func createFriendRequest(
        id: String = UUID().uuidString,
        fromUserId: String = "sample-user-2",
        timestamp: Date = Date(),
        status: FriendRequestStatus = .pending
    ) -> FriendRequest {
        return FriendRequest(
            id: id,
            fromUserId: fromUserId,
            timestamp: timestamp,
            status: status
        )
    }

    /// A pending friend request.
    static var pendingFriendRequest: FriendRequest {
        return createFriendRequest(
            id: "request-1",
            fromUserId: "sample-user-2",
            status: .pending
        )
    }

    // MARK: - Phone Number Fixtures

    /// Valid US phone numbers in various formats.
    static var validPhoneNumbers: [String] {
        [
            "+1 (555) 123-4567",
            "5551234567",
            "+15551234567",
            "(555) 123-4567"
        ]
    }

    /// International phone numbers.
    static var internationalPhoneNumbers: [String] {
        [
            "+44 20 7123 4567",    // UK
            "+81 3-1234-5678",     // Japan
            "+61 2 3456 7890",     // Australia
            "+33 1 23 45 67 89"    // France
        ]
    }

    /// Invalid phone numbers for error testing.
    static var invalidPhoneNumbers: [String] {
        [
            "",
            "abc",
            "123",
            "+",
            "+1"
        ]
    }

    // MARK: - Date Fixtures

    /// Returns a date for today at a specific hour.
    static func today(at hour: Int) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .hour, value: hour, to: today) ?? Date()
    }

    /// Returns a date for tomorrow at a specific hour.
    static func tomorrow(at hour: Int) -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let startOfTomorrow = calendar.startOfDay(for: tomorrow)
        return calendar.date(byAdding: .hour, value: hour, to: startOfTomorrow) ?? tomorrow
    }

    /// Returns a date for a specific number of days from now.
    static func daysFromNow(_ days: Int, at hour: Int = 12) -> Date {
        let calendar = Calendar.current
        let futureDate = calendar.date(byAdding: .day, value: days, to: Date()) ?? Date()
        let startOfDay = calendar.startOfDay(for: futureDate)
        return calendar.date(byAdding: .hour, value: hour, to: startOfDay) ?? futureDate
    }

    // MARK: - Collections

    /// Returns a collection of sample users for batch testing.
    static var sampleUsers: [User] {
        [sampleUser, sampleUser2, sampleUser3]
    }

    /// Returns a collection of sample events for batch testing.
    static var sampleEvents: [Event] {
        [sampleWalkEvent, sampleBikeEvent, sampleRunEvent]
    }

    /// Returns a mixed collection of events with various statuses.
    static var mixedStatusEvents: [Event] {
        [sampleWalkEvent, sampleBikeEvent, pastEvent, canceledEvent]
    }
}

// MARK: - Equatable Helpers for Testing

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return abs(lhs.latitude - rhs.latitude) < 0.0001 &&
               abs(lhs.longitude - rhs.longitude) < 0.0001
    }
}
