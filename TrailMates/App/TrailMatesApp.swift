//
//  TrailMatesApp.swift
//  TrailMates
//
//  Created by Jake Kinchen on 10/3/24.
//

import SwiftUI
import UIKit
import Firebase
import FirebaseAuth
import FBSDKCoreKit
import UserNotifications
import SwiftData

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()
        FirebaseConfiguration.shared.setLoggerLevel(.debug)
        
        // Configure Facebook SDK
        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
        
        // Register for push notifications
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error requesting notification permissions: \(error)")
            }
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }
        
        return true
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Provide the APNs token to Firebase
        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Forward remote notifications to Firebase Auth
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }
        
        // Handle other remote notifications if necessary
        completionHandler(.newData)
    }
    
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        ApplicationDelegate.shared.application(
            app,
            open: url,
            sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String,
            annotation: options[UIApplication.OpenURLOptionsKey.annotation]
        )
    }
}

@main
struct TrailMatesApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // Create a UserManager instance
    @StateObject private var userManager = UserManager()
    @StateObject private var authViewModel: AuthViewModel
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
        
    init() {
        let userManager = UserManager()
        let authViewModel = AuthViewModel(userManager: userManager)
        _userManager = StateObject(wrappedValue: userManager)
        _authViewModel = StateObject(wrappedValue: authViewModel)
    }

    var body: some Scene {
            WindowGroup {
                ContentView()
                    .environmentObject(userManager)
                    .environmentObject(authViewModel)
                    .onAppear {
                        Task {
                            await userManager.initializeUserIfNeeded()
                        }
                    }
            }
            .modelContainer(sharedModelContainer)
        }
}

