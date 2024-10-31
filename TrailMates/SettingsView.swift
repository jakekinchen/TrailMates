//
//  SettingsView 2.swift
//  TrailMates
//
//  Created by Jake Kinchen on 10/8/24.
//


import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    var body: some View {
        GeometryReader { geometry in
            ZStack(){
                Color("beige")
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    Spacer()
                    HStack {
                        ZStack {
                            Text("Settings")
                                .font(.custom("SF Pro", size: 28))
                                .foregroundColor(Color("pine"))
                                .fontWeight(.semibold)
    
                            HStack {
                                Button(action: {
                                    presentationMode.wrappedValue.dismiss()
                                }) {
                                    Image(systemName: "arrow.left")
                                        .foregroundColor(Color("pine"))
                                        .imageScale(.large)
                                        .font(.system(size: 24, weight: .bold))
                                }
                                Spacer()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 15)
                    }
                    .padding(.bottom, 45)
                    
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(Color("pine"))
                        .imageScale(.large)
                        .font(.system(size: 72, weight: .bold))
    
                    Spacer()
                    
                    // Device Permissions Section
                    DevicePermissionsView()
                        .padding()
                        .background(Color("beige").opacity(0.9))
                        .cornerRadius(15)
                        .padding(.horizontal)
                    
                    Spacer()
                    // Exercise Awareness Section
                    ExerciseAwarenessView()
                        .padding()
                        .background(Color("beige").opacity(0.9))
                        .cornerRadius(15)
                        .padding(.horizontal)

                    
                }
                .navigationBarHidden(true)
            }
        }
    }
}

struct ExerciseAwarenessView: View {
    @State private var isWalkingEnabled = true
    @State private var isBikingEnabled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Exercise Awareness")
                .font(.headline)
                .foregroundColor(Color("pine"))

            Toggle(isOn: $isWalkingEnabled) {
                Text("Walking")
                    .foregroundColor(Color("pine"))
            }
            .tint(Color("pine"))

            Toggle(isOn: $isBikingEnabled) {
                Text("Biking")
                    .foregroundColor(Color("pine"))
            }
            .tint(Color("pine"))
        }
    }
}

struct DevicePermissionsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Device Permissions")
                .font(.headline)
                .foregroundColor(Color("pine"))
            
            PermissionRow(permission: "Location Services", isAllowed: isLocationAllowed())
            PermissionRow(permission: "Notifications", isAllowed: isNotificationsAllowed())
            PermissionRow(permission: "Contacts", isAllowed: isContactsAllowed())
            PermissionRow(permission: "Photos", isAllowed: isPhotosAllowed())
            
            Button(action: {
                openAppSettings()
            }) {
                Text("Update Device Settings")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("pumpkin"))
                    .cornerRadius(15)
            }
            .padding(.top)
        }
    }
    
    func isLocationAllowed() -> Bool {
        let status = CLLocationManager.authorizationStatus()
        return status == .authorizedAlways || status == .authorizedWhenInUse
    }
    
    func isNotificationsAllowed() -> Bool {
        var isAllowed = false
        let semaphore = DispatchSemaphore(value: 0)
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            isAllowed = settings.authorizationStatus == .authorized
            semaphore.signal()
        }
        semaphore.wait()
        return isAllowed
    }
    
    func isContactsAllowed() -> Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        return status == .authorized
    }
    
    func isPhotosAllowed() -> Bool {
        let status = PHPhotoLibrary.authorizationStatus()
        return status == .authorized
    }
    
    func openAppSettings() {
        if let appSettings = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(appSettings)
        }
    }
}

struct PermissionRow: View {
    let permission: String
    let isAllowed: Bool
    
    var body: some View {
        HStack {
            Text(permission)
            Spacer()
            Text(isAllowed ? "Allowed" : "Not Allowed")
                .foregroundColor(isAllowed ? .green : .red)
        }
        .foregroundColor(Color("pine"))
    }
}
