// PermissionsView.swift
import SwiftUI
import CoreLocation
import UserNotifications

struct PermissionsView: View {
    @StateObject private var locationManager: LocationManager
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRequestingPermissions = false
    let onComplete: () -> Void
    
    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        // Initialize LocationManager with UserManager.shared
        _locationManager = StateObject(wrappedValue: LocationManager(userManager: UserManager.shared))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("beige").ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Text("Permissions")
                        .font(.title)
                        .foregroundColor(Color("pine"))
                        .padding(.top, 40)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        PermissionCard(
                            title: "Location Access",
                            description: "TrailMates needs background location access to alert friends when you're on the trail and help coordinate meetups.",
                            iconName: "location.fill",
                            status: locationPermissionStatus
                        )
                        
                        PermissionCard(
                            title: "Push Notifications",
                            description: "Get notified when your friends are nearby on the trail or when they invite you for a walk.",
                            iconName: "bell.fill",
                            status: notificationPermissionStatus
                        )
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    VStack(spacing: 15) {
                        Button(action: {
                            Task {
                                await requestPermissions()
                            }
                        }) {
                            Text("Continue")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color("pumpkin"))
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                checkNotificationStatus()
            }
        }
    }
    
    private var locationPermissionStatus: PermissionStatus {
        switch locationManager.authorizationStatus {
        case CLAuthorizationStatus.authorizedAlways:
            return .granted
        case CLAuthorizationStatus.authorizedWhenInUse:
            return .partial
        case CLAuthorizationStatus.denied, CLAuthorizationStatus.restricted:
            return .denied
        case CLAuthorizationStatus.notDetermined:
            return .notRequested
        @unknown default:
            return .notRequested
        }
    }
    
    private var notificationPermissionStatus: PermissionStatus {
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
    
    private func checkNotificationStatus() {
        Task { @MainActor in
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            notificationStatus = settings.authorizationStatus
        }
    }
    
    private func requestPermissions() async {
        guard !isRequestingPermissions else { return }
        isRequestingPermissions = true
        defer { isRequestingPermissions = false }

        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
        await MainActor.run { checkNotificationStatus() }

        _ = await locationManager.requestLocationPermission()

        await MainActor.run { onComplete() }
    }
}
