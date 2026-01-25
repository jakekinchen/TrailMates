import Foundation
import CoreLocation

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    // MARK: - Properties
    let manager: CLLocationManager
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus

    // UserManager reference for updating visit status
    private let userManager: UserManager

    // Distance threshold for considering a landmark "visited" (in meters)
    private let visitThreshold: Double = 25

    private var authorizationCallback: ((CLAuthorizationStatus) -> Void)?
    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?

    // Add properties for logging throttling
    private var lastLocationLogTime: Date?
    private let logThreshold: TimeInterval = 300 // 5 minutes

    // MARK: - Location Update Throttling
    /// Minimum distance (in meters) user must move before triggering an update
    private let minimumDistanceThreshold: CLLocationDistance = 10.0
    /// Minimum time interval (in seconds) between location updates to Firebase
    private let minimumUpdateInterval: TimeInterval = 5.0
    /// Last location that was actually sent to Firebase
    private var lastSentLocation: CLLocation?
    /// Last time a location was sent to Firebase
    private var lastUpdateTime: Date?
    
    // MARK: - Singleton
    private static var _shared: LocationManager?
    
    static var shared: LocationManager {
        get {
            guard let instance = _shared else {
                fatalError("LocationManager.shared must be initialized using setupShared() before accessing")
            }
            return instance
        }
    }
    
    @MainActor
    static func setupShared() {
        if _shared == nil {
            _shared = LocationManager(userManager: UserManager.shared)
        }
    }
    
    // MARK: - Initialization
    init(userManager: UserManager) {
        let manager = CLLocationManager()
        self.manager = manager
        self.authorizationStatus = manager.authorizationStatus
        self.userManager = userManager
        super.init()
        self.manager.delegate = self
        self.manager.desiredAccuracy = kCLLocationAccuracyBest
        self.manager.allowsBackgroundLocationUpdates = true
        self.manager.pausesLocationUpdatesAutomatically = false
        print("LocationManager initialized with status: \(authorizationStatus.rawValue)")
    }
    
    // MARK: - Authorization Methods
    func setAuthorizationCallback(_ callback: @escaping (CLAuthorizationStatus) -> Void) {
        self.authorizationCallback = callback
        // Immediately call the callback with current status
        callback(authorizationStatus)
    }

    func requestLocationPermission() async -> CLAuthorizationStatus {
        // If we already have a status, return it
        if authorizationStatus != .notDetermined {
            return authorizationStatus
        }

        // Request permission and wait for the result
        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    func requestAlwaysAuthorization() async -> CLAuthorizationStatus {
        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestAlwaysAuthorization()
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            
            // Handle continuation if present
            if let continuation = authorizationContinuation {
                continuation.resume(returning: authorizationStatus)
                authorizationContinuation = nil
            }
            
            // Handle callback if present
            authorizationCallback?(authorizationStatus)
            
            // Update location updates based on authorization
            switch authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.startUpdatingLocation()
            default:
                manager.stopUpdatingLocation()
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        Task { @MainActor in
            // Always update local location for UI responsiveness
            self.location = location

            // Apply throttling before sending to Firebase
            guard shouldSendLocationUpdate(newLocation: location) else {
                return
            }

            // Check if we should log this update
            let shouldLog = lastLocationLogTime?.timeIntervalSinceNow ?? -logThreshold <= -logThreshold
            if shouldLog {
                print("LocationManager received update - lat: \(location.coordinate.latitude), lon: \(location.coordinate.longitude)")
                lastLocationLogTime = Date()
            }

            // Update user location in Firebase
            await userManager.updateLocation(location.coordinate)

            // Track this as the last sent location
            lastSentLocation = location
            lastUpdateTime = Date()
        }
    }

    // MARK: - Throttling Logic

    /// Determines if a location update should be sent to Firebase based on distance and time thresholds.
    /// This prevents excessive network calls and battery drain from minor GPS fluctuations.
    private func shouldSendLocationUpdate(newLocation: CLLocation) -> Bool {
        let now = Date()

        // Check time-based throttling
        if let lastTime = lastUpdateTime {
            let timeSinceLastUpdate = now.timeIntervalSince(lastTime)
            if timeSinceLastUpdate < minimumUpdateInterval {
                return false
            }
        }

        // Check distance-based filtering
        if let lastLocation = lastSentLocation {
            let distance = newLocation.distance(from: lastLocation)
            if distance < minimumDistanceThreshold {
                return false
            }
        }

        // First update or passed both thresholds
        return true
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
}
