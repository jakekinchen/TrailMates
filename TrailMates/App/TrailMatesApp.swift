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
import UserNotifications

@main
struct TrailMatesApp: App {
    // Static property to configure Firebase
    static let firebaseConfigured: Void = {
        if FirebaseApp.app() == nil {
            print("🔥 Configuring Firebase in TrailMatesApp")
            FirebaseApp.configure()
            // Set Firebase logger level
            #if DEBUG
            FirebaseConfiguration.shared.setLoggerLevel(.debug)
            #endif
            print("🔥 Firebase configured successfully in TrailMatesApp.")
        } else {
            print("🔥 Firebase already configured")
        }
        return ()
    }()
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    // View Models with guaranteed Firebase configuration
    @StateObject private var userManager: UserManager = {
        _ = TrailMatesApp.firebaseConfigured
        return UserManager.shared
    }()
    
    @StateObject private var authViewModel: AuthViewModel = {
        _ = TrailMatesApp.firebaseConfigured
        return AuthViewModel()
    }()

    @StateObject private var deepLinkRouter = DeepLinkRouter.shared
    
    var body: some Scene {
        WindowGroup {
            RootAppView()
                .environmentObject(userManager)
                .environmentObject(authViewModel)
                .environmentObject(deepLinkRouter)
                .task {
                    await userManager.initializeIfNeeded()
                    // Initialize LocationManager
                    await MainActor.run {
                        LocationManager.setupShared()
                    }
                    await deepLinkRouter.resolvePendingProfileIfPossible(userManager: userManager)
                }
                .onOpenURL { url in
                    guard !Auth.auth().canHandle(url) else { return }
                    guard deepLinkRouter.handle(url) else { return }

                    Task {
                        await deepLinkRouter.resolvePendingProfileIfPossible(userManager: userManager)
                    }
                }
        }
    }
}

private struct RootAppView: View {
    @EnvironmentObject private var userManager: UserManager
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter

    var body: some View {
        ContentView()
            .sheet(item: $deepLinkRouter.presentedProfileUser) { user in
                NavigationStack {
                    FriendProfileView(user: user)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    deepLinkRouter.presentedProfileUser = nil
                                }
                            }
                        }
                }
                .environmentObject(userManager)
            }
            .task(id: userManager.isLoggedIn) {
                await deepLinkRouter.resolvePendingProfileIfPossible(userManager: userManager)
            }
            .alert("Unable to Open Profile", isPresented: Binding(
                get: { deepLinkRouter.errorMessage != nil },
                set: { if !$0 { deepLinkRouter.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deepLinkRouter.errorMessage ?? "")
            }
    }
}

@MainActor
class AppDelegate: NSObject, UIApplicationDelegate {
    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        print("AppDelegate: didFinishLaunchingWithOptions started")

        _ = TrailMatesApp.firebaseConfigured
        
        // Firebase is already configured
        if FirebaseApp.app() != nil {
            print("🔥 Firebase is already configured in AppDelegate")
        } else {
            print("❌ Firebase is not configured in AppDelegate")
        }

        if isRunningTests {
            print("⏭️ Skipping push notification setup (tests)")
            print("AppDelegate: didFinishLaunchingWithOptions completed.")
            return true
        }

        // Configure notifications
        configureNotifications(application)
        
        print("AppDelegate: didFinishLaunchingWithOptions completed.")
        return true
    }
    
    private func configureNotifications(_ application: UIApplication) {
        print("Configuring push notifications...")
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        
        Task { @MainActor [weak self] in
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                if granted {
                    print("✅ Push notification permissions granted")

                    // Check for pending APNS token
                    self?.registerPendingAPNSTokenIfNeeded()
                } else {
                    print("❌ Push notification permissions denied")
                    self?.registerPendingAPNSTokenIfNeeded()
                }
            } catch {
                print("❌ Error requesting notification permissions: \(error)")
                self?.registerPendingAPNSTokenIfNeeded()
            }
        }
    }
    
    private func registerPendingAPNSTokenIfNeeded() {
        guard let pendingToken = UserDefaults.standard.data(forKey: "pendingAPNSToken") else {
            return
        }
        
        print("📱 Registering pending APNS token with Firebase")
        let tokenType: AuthAPNSTokenType = {
            #if DEBUG
            return .sandbox
            #else
            return .prod
            #endif
        }()
        Auth.auth().setAPNSToken(pendingToken, type: tokenType)
        UserDefaults.standard.removeObject(forKey: "pendingAPNSToken")
        print("✅ Successfully registered pending APNS token")
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        guard !isRunningTests else { return }
        print("📱 Received APNS token from Apple")
        let tokenType: AuthAPNSTokenType = {
            #if DEBUG
            return .sandbox
            #else
            return .prod
            #endif
        }()
        Auth.auth().setAPNSToken(deviceToken, type: tokenType)
        print("✅ Successfully registered APNS token with Firebase")
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
        if Auth.auth().canHandle(url) {
            return true
        }

        return DeepLinkRouter.shared.handle(url)
    }

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return false
        }

        return DeepLinkRouter.shared.handle(url)
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate: @preconcurrency UNUserNotificationCenterDelegate {
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
}
