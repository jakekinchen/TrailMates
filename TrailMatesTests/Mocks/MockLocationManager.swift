import Foundation
import CoreLocation
@testable import TrailMates

/// A mock implementation of LocationManager for testing purposes.
/// This mock allows tests to control location updates and authorization status without actual GPS.
@MainActor
class MockLocationManager: ObservableObject {
    // MARK: - Published Properties (matching LocationManager interface)
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus

    // MARK: - Mock Control Properties
    var mockLocations: [CLLocation] = []
    var mockAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    var shouldSimulateError = false
    var mockError: Error?

    // MARK: - Call Tracking
    var requestWhenInUseAuthorizationCallCount = 0
    var requestAlwaysAuthorizationCallCount = 0
    var startUpdatingLocationCallCount = 0
    var stopUpdatingLocationCallCount = 0
    var locationUpdateCallCount = 0

    // MARK: - Callbacks
    var authorizationCallback: ((CLAuthorizationStatus) -> Void)?
    var locationUpdateCallback: ((CLLocation) -> Void)?

    // MARK: - Initialization
    init(initialStatus: CLAuthorizationStatus = .notDetermined) {
        self.authorizationStatus = initialStatus
        self.mockAuthorizationStatus = initialStatus
    }

    // MARK: - Authorization Methods

    func setAuthorizationCallback(_ callback: @escaping (CLAuthorizationStatus) -> Void) {
        self.authorizationCallback = callback
        callback(authorizationStatus)
    }

    func requestLocationPermission() async -> CLAuthorizationStatus {
        requestWhenInUseAuthorizationCallCount += 1

        // If already determined, return current status
        if authorizationStatus != .notDetermined {
            return authorizationStatus
        }

        // Simulate authorization change
        authorizationStatus = mockAuthorizationStatus
        authorizationCallback?(authorizationStatus)

        return authorizationStatus
    }

    func requestAlwaysAuthorization() async -> CLAuthorizationStatus {
        requestAlwaysAuthorizationCallCount += 1

        // Simulate upgrading to always authorization
        authorizationStatus = mockAuthorizationStatus
        authorizationCallback?(authorizationStatus)

        return authorizationStatus
    }

    // MARK: - Location Update Methods

    func startUpdatingLocation() {
        startUpdatingLocationCallCount += 1

        // Automatically push mock locations if configured
        if !mockLocations.isEmpty {
            for mockLocation in mockLocations {
                simulateLocationUpdate(mockLocation)
            }
        }
    }

    func stopUpdatingLocation() {
        stopUpdatingLocationCallCount += 1
    }

    // MARK: - Simulation Methods

    /// Simulates a location update
    func simulateLocationUpdate(_ location: CLLocation) {
        locationUpdateCallCount += 1
        self.location = location
        locationUpdateCallback?(location)
    }

    /// Simulates multiple location updates
    func simulateLocationUpdates(_ locations: [CLLocation]) {
        for location in locations {
            simulateLocationUpdate(location)
        }
    }

    /// Simulates an authorization status change
    func simulateAuthorizationChange(_ status: CLAuthorizationStatus) {
        authorizationStatus = status
        authorizationCallback?(status)
    }

    /// Simulates a location error
    func simulateLocationError(_ error: Error) {
        mockError = error
        shouldSimulateError = true
    }

    // MARK: - Reset

    func reset() {
        location = nil
        authorizationStatus = .notDetermined
        mockAuthorizationStatus = .notDetermined
        mockLocations = []
        shouldSimulateError = false
        mockError = nil
        resetCallCounts()
    }

    func resetCallCounts() {
        requestWhenInUseAuthorizationCallCount = 0
        requestAlwaysAuthorizationCallCount = 0
        startUpdatingLocationCallCount = 0
        stopUpdatingLocationCallCount = 0
        locationUpdateCallCount = 0
    }
}

// MARK: - Mock Location Errors

enum MockLocationError: LocalizedError {
    case locationUnavailable
    case networkError
    case denied
    case timeout

    var errorDescription: String? {
        switch self {
        case .locationUnavailable:
            return "Location services are not available"
        case .networkError:
            return "Network error occurred while fetching location"
        case .denied:
            return "Location permission was denied"
        case .timeout:
            return "Location request timed out"
        }
    }
}

// MARK: - Test Location Fixtures

extension MockLocationManager {

    /// Creates a mock location at Austin Downtown
    static func austinDowntownLocation() -> CLLocation {
        CLLocation(
            latitude: TestFixtures.austinDowntown.latitude,
            longitude: TestFixtures.austinDowntown.longitude
        )
    }

    /// Creates a mock location at Zilker Park
    static func zilkerParkLocation() -> CLLocation {
        CLLocation(
            latitude: TestFixtures.zilkerPark.latitude,
            longitude: TestFixtures.zilkerPark.longitude
        )
    }

    /// Creates a mock location at Lady Bird Lake
    static func ladyBirdLakeLocation() -> CLLocation {
        CLLocation(
            latitude: TestFixtures.ladyBirdLake.latitude,
            longitude: TestFixtures.ladyBirdLake.longitude
        )
    }

    /// Creates a sequence of mock locations simulating movement
    static func movementSequence() -> [CLLocation] {
        [
            austinDowntownLocation(),
            CLLocation(latitude: 30.2670, longitude: -97.7500),
            CLLocation(latitude: 30.2668, longitude: -97.7600),
            zilkerParkLocation()
        ]
    }

    /// Creates a mock location with specific accuracy
    static func locationWithAccuracy(
        latitude: Double,
        longitude: Double,
        horizontalAccuracy: Double,
        verticalAccuracy: Double = 10.0
    ) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: 0,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            timestamp: Date()
        )
    }

    /// Creates a mock location with timestamp
    static func locationWithTimestamp(
        latitude: Double,
        longitude: Double,
        timestamp: Date
    ) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: 0,
            horizontalAccuracy: 10,
            verticalAccuracy: 10,
            timestamp: timestamp
        )
    }
}
