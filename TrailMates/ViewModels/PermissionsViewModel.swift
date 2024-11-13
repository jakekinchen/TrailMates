import SwiftUI
import CoreLocation
@preconcurrency import UserNotifications

@MainActor
class PermissionsViewModel: ObservableObject {
    @Published var showLocationSettingsAlert = false
    @Published var showNotificationSettingsAlert = false
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Published var isRequestingPermissions = false
    
    let locationManager: LocationManager
    let userManager: UserManager
    
    init(locationManager: LocationManager = LocationManager(), userManager: UserManager) {
        self.locationManager = locationManager
        self.userManager = userManager
    }
    
    var locationPermissionStatus: PermissionStatus {
        switch locationManager.authorizationStatus {
        case .authorizedAlways:
            return .granted
        case .authorizedWhenInUse:
            return .partial
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notRequested
        @unknown default:
            return .notRequested
        }
    }
    
    var notificationPermissionStatus: PermissionStatus {
        switch notificationStatus {
        case .authorized:
            return .granted
        case .denied:
            return .denied
        case .provisional:
            return .partial
        case .notDetermined:
            return .notRequested
        case .ephemeral:
            return .partial
        @unknown default:
            return .notRequested
        }
    }
    
    func initialSetup() async {
        print("Starting initial setup")
        await checkNotificationStatus()
        setupLocationStatusObservation()
    }
    
    func checkNotificationStatus() async {
        print("Checking notification status")
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        print("Received notification settings: \(settings.authorizationStatus.rawValue)")
        notificationStatus = settings.authorizationStatus
    }
    
    func requestPermissions() {
        print("Starting permission request flow")
        guard !isRequestingPermissions else {
            print("Already requesting permissions, skipping")
            return
        }
        
        Task {
            isRequestingPermissions = true
            print("Setting isRequestingPermissions to true")
            
            print("Requesting notification permissions")
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound, .badge])
                
                await checkNotificationStatus()
                
                print("Notification permission response: \(granted)")
                if !granted {
                    print("Notifications not granted, showing settings alert")
                    showNotificationSettingsAlert = true
                }
                
                print("Proceeding to location permissions")
                handleLocationPermissions(afterNotifications: granted)
            } catch {
                print("Error requesting notifications: \(error)")
                isRequestingPermissions = false
            }
        }
    }
    
    func skipPermissions() {
        print("Skipping permissions")
        userManager.isOnboardingComplete = true
        userManager.persistUserSession()
    }
    
    private func handleLocationPermissions(afterNotifications notificationGranted: Bool) {
        print("Handling location permissions. Notifications granted: \(notificationGranted)")
        let currentStatus = locationManager.authorizationStatus
        print("Current location authorization status: \(currentStatus.rawValue)")
        
        setupLocationStatusObservation()
        
        switch currentStatus {
        case .notDetermined:
            print("Location status not determined, requesting permission")
            locationManager.requestLocationPermission()
            
        case .authorizedWhenInUse:
            print("Have when in use, requesting always authorization")
            locationManager.requestAlwaysAuthorization()
            
        case .denied, .restricted:
            print("Location access denied or restricted")
            showLocationSettingsAlert = true
            isRequestingPermissions = false
            
        case .authorizedAlways:
            print("Already have always authorization")
            completePermissionsFlow(notificationGranted: notificationGranted)
            
        @unknown default:
            print("Unknown location authorization status")
            isRequestingPermissions = false
        }
    }
    
    private func setupLocationStatusObservation() {
        print("Setting up location status observation")
        locationManager.setAuthorizationCallback { [weak self] newStatus in
            guard let self = self else { return }
            print("Received new location status: \(newStatus.rawValue)")
            
            switch newStatus {
            case .authorizedAlways:
                print("Received authorizedAlways status")
                self.completePermissionsFlow(notificationGranted: true)
                
            case .authorizedWhenInUse:
                print("Received whenInUse status, prompting for always")
                self.showLocationSettingsAlert = true
                self.isRequestingPermissions = false
                
            case .denied, .restricted:
                print("Received denied/restricted status")
                self.showLocationSettingsAlert = true
                self.isRequestingPermissions = false
                
            case .notDetermined:
                print("Status still not determined")
                break
                
            @unknown default:
                print("Received unknown status")
                self.isRequestingPermissions = false
            }
        }
    }
    
    private func completePermissionsFlow(notificationGranted: Bool) {
        print("Completing permissions flow")
        isRequestingPermissions = false
        if notificationGranted {
            print("All permissions granted, completing onboarding")
            userManager.isOnboardingComplete = true
            userManager.persistUserSession()
        } else {
            print("Notifications not granted, showing alert")
            showNotificationSettingsAlert = true
        }
    }
}