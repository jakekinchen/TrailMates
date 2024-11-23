import Foundation
import CoreLocation

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    let manager: CLLocationManager
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    
    // UserManager reference for updating visit status
    private var userManager: UserManager
    
    // Distance threshold for considering a landmark "visited" (in meters)
    private let visitThreshold: Double = 25
    
    private var authorizationCallback: ((CLAuthorizationStatus) -> Void)?
    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    
    init(userManager: UserManager) {
        let manager = CLLocationManager()
        self.manager = manager
        self.authorizationStatus = manager.authorizationStatus
        self.userManager = userManager
        super.init()
        self.manager.delegate = self
        print("LocationManager initialized with status: \(authorizationStatus.rawValue)")
    }
    
    func updateUserManager(_ newUserManager: UserManager) {
            self.userManager = newUserManager
            print("LocationManager userManager updated")
        }
    
    // MARK: - Landmark Visit Detection
    private func checkForLandmarkVisits(at location: CLLocation) async {
        for (index, landmark) in Locations.items.enumerated() {
            let landmarkLocation = CLLocation(
                latitude: landmark.coordinate.latitude,
                longitude: landmark.coordinate.longitude
            )
            
            let distance = location.distance(from: landmarkLocation)
            
            if distance <= visitThreshold {
                let landmarkId = generateLandmarkId(index: index)
                
                // Check if user hasn't already visited this landmark
                if let user = userManager.currentUser,
                   !user.visitedLandmarkIds.contains(landmarkId) {
                    // Mark landmark as visited
                    await userManager.visitLandmark(landmarkId)
                    
                    // Post notification for UI update
                    NotificationCenter.default.post(
                        name: .landmarkVisited,
                        object: nil,
                        userInfo: [
                            "landmarkTitle": landmark.title,
                            "landmarkId": landmarkId
                        ]
                    )
                }
            }
        }
    }
    
    // Generate consistent UUIDs for landmarks based on their index
    private func generateLandmarkId(index: Int) -> UUID {
        let indexString = String(format: "%05d", index)
        let uniqueString = "landmark_\(indexString)"
        return UUID(uuidString: uniqueString) ?? UUID()
    }
    
    // MARK: - Existing Authorization Methods
    func requestLocationPermission() async -> CLAuthorizationStatus {
        print("Requesting when-in-use authorization")
        let currentStatus = manager.authorizationStatus
        if currentStatus != .notDetermined {
            return currentStatus
        }
        
        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }
    
    func requestAlwaysAuthorization() async -> CLAuthorizationStatus {
        print("Requesting always authorization")
        let currentStatus = manager.authorizationStatus
        if currentStatus == .authorizedAlways {
            return currentStatus
        }
        
        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestAlwaysAuthorization()
        }
    }
    
    func setAuthorizationCallback(_ callback: @escaping (CLAuthorizationStatus) -> Void) {
        Task { @MainActor in
            authorizationCallback = callback
            callback(authorizationStatus)
        }
    }
    
    // MARK: - CLLocationManagerDelegate Methods
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        print("Location authorization did change to: \(status.rawValue)")
        
        Task { @MainActor in
            updateAuthorizationStatus(status)
            handleAuthorizationChange(status)
            if let continuation = authorizationContinuation {
                authorizationContinuation = nil
                continuation.resume(returning: status)
            }
        }
    }
    
    private func updateAuthorizationStatus(_ status: CLAuthorizationStatus) {
        self.authorizationStatus = status
        self.authorizationCallback?(status)
    }
    
    private func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways:
            manager.startUpdatingLocation()
            manager.allowsBackgroundLocationUpdates = true
            manager.pausesLocationUpdatesAutomatically = false
            print("Background location updates enabled.")
            
        case .authorizedWhenInUse:
            manager.startUpdatingLocation()
            manager.allowsBackgroundLocationUpdates = false
            print("Background location updates disabled (when-in-use only).")
            
        case .denied, .restricted:
            manager.stopUpdatingLocation()
            print("Location updates stopped due to denied or restricted access.")
            
        case .notDetermined:
            print("Authorization not determined.")
            
        @unknown default:
            print("Unknown authorization status.")
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.location = location
            await checkForLandmarkVisits(at: location)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error)")
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let landmarkVisited = Notification.Name("landmarkVisited")
}
