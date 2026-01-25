// PermissionsView.swift
import SwiftUI
import CoreLocation
import UserNotifications

struct PermissionsView: View {
    @EnvironmentObject var userManager: UserManager
    @Environment(\.dismiss) var dismiss
    @StateObject private var locationManager: LocationManager
    @State private var showLocationSettingsAlert = false
    @State private var showNotificationSettingsAlert = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
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
                    Button(action: {
                        Task {
                            await requestPermissions()
                        }
                    }) {
                        Text("Enable Permissions")
                            .font(.title)
                            .foregroundColor(Color("pine"))
                            .padding(.top, 40)
                    }
                    
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
                            Text("Enable Permissions")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color("pumpkin"))
                                .cornerRadius(10)
                        }
                        
                        Button(action: skipPermissions) {
                            Text("Set Up Later")
                                .foregroundColor(Color("pine"))
                        }
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                checkNotificationStatus()
            }
            .alert("Location Access Required", isPresented: $showLocationSettingsAlert) {
                Button("Open Settings", role: .none) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Background location access is required for core app functionality. Please enable it in Settings.")
            }
            .alert("Notifications Required", isPresented: $showNotificationSettingsAlert) {
                Button("Open Settings", role: .none) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Notifications are required to receive alerts about your friends. Please enable them in Settings.")
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
        // Check and request notification permission
        let notificationGranted = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        if let granted = notificationGranted, !granted {
            await MainActor.run {
                showNotificationSettingsAlert = true
            }
        }
        await MainActor.run {
            checkNotificationStatus()
        }
        
        // Check location permission status
        let status = await locationManager.requestLocationPermission()
        if status == .denied || status == .restricted {
            await MainActor.run {
                showLocationSettingsAlert = true
            }
            return // Stop if location access is denied
        }
        
        // Request background location if needed
        if status == .authorizedWhenInUse {
            let alwaysStatus = await locationManager.requestAlwaysAuthorization()
            if alwaysStatus != .authorizedAlways {
                await MainActor.run {
                    showLocationSettingsAlert = true
                }
                return
            }
        }
        
        // Trigger onComplete if all permissions are granted or not needed
        await MainActor.run {
            onComplete()
        }
    }
    
    private func skipPermissions() {
        userManager.isOnboardingComplete = true
        userManager.persistUserSession()
    }
}
