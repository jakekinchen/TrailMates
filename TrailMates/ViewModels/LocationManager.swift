import Foundation
import CoreLocation

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
    nonisolated init(userManager: UserManager) {
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
    nonisolated func setAuthorizationCallback(_ callback: @escaping (CLAuthorizationStatus) -> Void) {
        self.authorizationCallback = callback
        // Immediately call the callback with current status
        callback(authorizationStatus)
    }
    
    nonisolated func requestLocationPermission() async -> CLAuthorizationStatus {
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
    
    nonisolated func requestAlwaysAuthorization() async -> CLAuthorizationStatus {
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
        print("LocationManager received update - lat: \(location.coordinate.latitude), lon: \(location.coordinate.longitude)")
        
        Task { @MainActor in
            self.location = location
            print("LocationManager attempting to update user location...")
            await userManager.updateLocation(location.coordinate)
            print("LocationManager finished update attempt")
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
}
