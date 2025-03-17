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

@main
struct TrailMatesApp: App {
    // Static property to configure Firebase
    static let firebaseConfigured: Void = {
        if FirebaseApp.app() == nil {
            print("🔥 Configuring Firebase in TrailMatesApp")
            FirebaseApp.configure()
            // Set Firebase logger level
            FirebaseConfiguration.shared.setLoggerLevel(.debug)
            print("🔥 Firebase configured successfully in TrailMatesApp.")
        } else {
            print("🔥 Firebase already configured")
        }
        return ()
    }()
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // SwiftData container
    var sharedModelContainer: ModelContainer = {
        print("📱 Creating ModelContainer")
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
    
    // View Models with guaranteed Firebase configuration
    @StateObject private var userManager: UserManager = {
        _ = TrailMatesApp.firebaseConfigured
        return UserManager.shared
    }()
    
    @StateObject private var authViewModel: AuthViewModel = {
        _ = TrailMatesApp.firebaseConfigured
        return AuthViewModel()
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(userManager)
                .environmentObject(authViewModel)
                .task {
                    await userManager.initializeIfNeeded()
                    // Initialize LocationManager
                    await MainActor.run {
                        LocationManager.setupShared()
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        print("AppDelegate: didFinishLaunchingWithOptions started")
        
        // Firebase is already configured
        if FirebaseApp.app() != nil {
            print("🔥 Firebase is already configured in AppDelegate")
        } else {
            print("❌ Firebase is not configured in AppDelegate")
        }
        
        // Configure Facebook SDK (temporarily disabled)
        /*
        print("Configuring Facebook SDK...")
        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
        print("Facebook SDK configured successfully.")
        */
        
        // Configure notifications
        configureNotifications(application)
        
        print("AppDelegate: didFinishLaunchingWithOptions completed.")
        return true
    }
    
    private func configureNotifications(_ application: UIApplication) {
        print("Configuring push notifications...")
        UNUserNotificationCenter.current().delegate = self
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            if let error = error {
                print("❌ Error requesting notification permissions: \(error)")
                return
            }
            
            if granted {
                DispatchQueue.main.async {
                    print("✅ Push notification permissions granted")
                    application.registerForRemoteNotifications()
                    
                    // Check for pending APNS token
                    self?.registerPendingAPNSTokenIfNeeded()
                }
            } else {
                print("❌ Push notification permissions denied")
            }
        }
    }
    
    private func registerPendingAPNSTokenIfNeeded() {
        guard let pendingToken = UserDefaults.standard.data(forKey: "pendingAPNSToken") else {
            return
        }
        
        print("📱 Registering pending APNS token with Firebase")
        Auth.auth().setAPNSToken(pendingToken, type: .prod)
        UserDefaults.standard.removeObject(forKey: "pendingAPNSToken")
        print("✅ Successfully registered pending APNS token")
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        print("📱 Received APNS token from Apple")
        Auth.auth().setAPNSToken(deviceToken, type: .prod)
        print("✅ Successfully registered APNS token with Firebase")
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Handle foreground notifications
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification response
        completionHandler()
    }
    
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
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
        return ApplicationDelegate.shared.application(
            app,
            open: url,
            sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String,
            annotation: options[UIApplication.OpenURLOptionsKey.annotation]
        )
    }
}

