//
//  PermissionsView.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on 11/12/24.
//


// PermissionsView.swift
import SwiftUI
import CoreLocation
import UserNotifications

struct PermissionsView: View {
    @EnvironmentObject var userManager: UserManager
    @Environment(\.dismiss) var dismiss
    @StateObject private var locationManager = LocationManager()
    @State private var showLocationSettingsAlert = false
    @State private var showNotificationSettingsAlert = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("beige").ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Text("Enable Permissions")
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
                        Button(action: requestPermissions) {
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
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationStatus = settings.authorizationStatus
            }
        }
    }
    
    private func requestPermissions() {
        // Request notifications first
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                if !granted {
                    showNotificationSettingsAlert = true
                }
                checkNotificationStatus()
            }
        }
        
        // Location permission will be handled by LocationManager
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestAppropriateAuthorization()
        } else if locationManager.authorizationStatus != .authorizedAlways {
            showLocationSettingsAlert = true
        }
    }
    
    private func skipPermissions() {
        userManager.isOnboardingComplete = true
        userManager.persistUserSession()
    }
}

enum PermissionStatus {
    case notRequested
    case granted
    case denied
    case partial
}

struct PermissionCard: View {
    let title: String
    let description: String
    let iconName: String
    let status: PermissionStatus
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(Color("pumpkin"))
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(Color("pine"))
                    
                    Spacer()
                    
                    statusIcon
                }
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 2)
    }
    
    private var statusIcon: some View {
        switch status {
        case .granted:
            return Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .denied:
            return Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
        case .partial:
            return Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.orange)
        case .notRequested:
            return Image(systemName: "circle")
                .foregroundColor(.gray)
        }
    }
}