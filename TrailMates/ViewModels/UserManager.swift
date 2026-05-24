//
//  UserManager.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on [Date].
//
//

import SwiftUI
import Combine
import CoreLocation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import UIKit

@MainActor  // Ensure all UI updates happen on the main thread
class UserManager: ObservableObject {
    // Singleton instance
    static let shared = UserManager()
    
    // MARK: - Published Properties
    @Published var currentUser: User?
    @Published var isLoggedIn: Bool = false
    @Published var isOnboardingComplete: Bool = false
    @Published var isWelcomeComplete: Bool = false
    @Published var isPermissionsGranted: Bool = false
    @Published var hasAddedFriends: Bool = false
    
    // MARK: - Private Properties
    // MARK: Sub-providers (preferred for new code)
    private let userProvider = UserDataProvider.shared
    private let imageProvider = ImageStorageProvider.shared
    private let landmarkProvider = LandmarkDataProvider.shared
    private let locationProvider = LocationDataProvider.shared
    private let friendProvider = FriendDataProvider.shared

    private var locationManager: LocationManager?
    private var cancellables = Set<AnyCancellable>()
    private var hasInitialized = false
    
    
    private init() {
        // Configure Firebase debug logging level
        FirebaseConfiguration.shared.setLoggerLevel(.error)
        
        setupObservers()
        Task { @MainActor in
            LocationManager.setupShared()
            self.locationManager = LocationManager.shared
        }
    }
    
    @Published private(set) var isRefreshing = false
    private var lastRefreshTime: Date?
    private let minimumRefreshInterval: TimeInterval = 300 // 5 minutes
    
    // Add a non-isolated property to track the current user ID for cleanup
    private var currentUserId: String?

    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitesting")
    }

    func initializeIfNeeded() async {
        guard !hasInitialized else { return }

        #if DEBUG
        print("👤 Starting UserManager initialization")
        #endif
        setupObservers()

        if isUITesting {
            resetSessionForUITesting()
        }

        // First try to load from persistence
        if checkPersistedUser() {
            hasInitialized = true
            #if DEBUG
            print("👤 User loaded from persistence")
            #endif
            return
        }

        // If not persisted, fetch from Firebase
        if let user = await userProvider.fetchCurrentUser() {
            self.currentUser = user
            self.isLoggedIn = true
            self.persistUserSession()
            #if DEBUG
            print("👤 User fetched from Firebase: \(user.firstName) \(user.lastName)")
            #endif
        } else {
            // Self-heal legacy accounts where an Auth session exists but the
            // Firestore user doc isn't keyed by the Auth UID.
            if Auth.auth().currentUser != nil {
                do {
                    try await userProvider.ensureUserDocument()
                } catch {
                    #if DEBUG
                    let appError = AppError.from(error)
                    print("UserManager: ensureUserDocument failed during init: \(appError.errorDescription ?? "Unknown")")
                    #endif
                }
            }

            if let user = await userProvider.fetchCurrentUser() {
                self.currentUser = user
                self.isLoggedIn = true
                self.persistUserSession()
                #if DEBUG
                print("👤 User fetched from Firebase after ensure: \(user.firstName) \(user.lastName)")
                #endif
            } else {
                #if DEBUG
                print("❌ No user found in Firebase")
                #endif
                self.isLoggedIn = false
                self.currentUser = nil
            }
        }

        hasInitialized = true
        #if DEBUG
        print("👤 UserManager initialization completed")
        #endif
    }

    private func resetSessionForUITesting() {
        // Keep UI tests deterministic by always starting from the auth screen.
        // Do not attempt any network-dependent setup.
        do {
            try Auth.auth().signOut()
        } catch {
            // Ignored: tests should still proceed in a logged-out state.
        }

        currentUser = nil
        currentUserId = nil
        isLoggedIn = false
        isOnboardingComplete = false
        isWelcomeComplete = false
        isPermissionsGranted = false
        hasAddedFriends = false
        clearPersistedUserSession()
    }
    
    private func setupObservers() {
        // Setup state observations
        Publishers.CombineLatest4($isLoggedIn, $isWelcomeComplete, $isPermissionsGranted, $hasAddedFriends)
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.persistUserSession()
            }
            .store(in: &cancellables)
    }
    @MainActor
    private func cleanup() async {
        // Stop observing user if we have a current user
        if let userId = currentUser?.id {
            userProvider.stopObservingUser(id: userId)
        }

        // Cancel all publishers
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        // Clear current user data
        currentUser = nil
        currentUserId = nil
    }
    
    deinit {
        // deinit is nonisolated and cannot safely access @MainActor-isolated
        // properties (cancellables, currentUserId). Since UserManager is a
        // singleton it should never be deallocated; any cleanup is handled by
        // the explicit cleanup() method or signOut() instead.
    }
    
    private func checkPersistedUser() -> Bool {
        if let userData = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            currentUser = user
            isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
            isWelcomeComplete = UserDefaults.standard.bool(forKey: "isWelcomeComplete")
            isPermissionsGranted = UserDefaults.standard.bool(forKey: "isPermissionsGranted")
            isOnboardingComplete = UserDefaults.standard.bool(forKey: "isOnboardingComplete")
            hasAddedFriends = UserDefaults.standard.bool(forKey: "hasAddedFriends")
            return true
        }
        return false
    }
    
    func isUsernameTaken(_ username: String) async -> Bool {
        return await userProvider.isUsernameTaken(username, excludingUserId: currentUser?.id)
    }
    
    // MARK: - Persist User Session
    func persistUserSession() {
        #if DEBUG
        print("💾 Persisting user session")
        #endif
        if let user = currentUser {
            if let userData = try? JSONEncoder().encode(user) {
                #if DEBUG
                print("   - Saving user data:")
                print("     • First Name: '\(user.firstName)'")
                print("     • Last Name: '\(user.lastName)'")
                print("     • Username: '\(user.username)'")
                #endif
                UserDefaults.standard.set(userData, forKey: "currentUser")
                UserDefaults.standard.set(Date(), forKey: "lastUserRefreshTime")
                #if DEBUG
                print("   - User data saved successfully")
                #endif
            } else {
                #if DEBUG
                print("❌ Failed to encode user data")
                #endif
            }
        } else {
            #if DEBUG
            print("⚠️ No current user to persist")
            #endif
        }

        UserDefaults.standard.set(isLoggedIn, forKey: "isLoggedIn")
        UserDefaults.standard.set(isWelcomeComplete, forKey: "isWelcomeComplete")
        UserDefaults.standard.set(isPermissionsGranted, forKey: "isPermissionsGranted")
        UserDefaults.standard.set(hasAddedFriends, forKey: "hasAddedFriends")
        UserDefaults.standard.set(isOnboardingComplete, forKey: "isOnboardingComplete")
        #if DEBUG
        print("   - Session flags saved")
        #endif
    }

    private func loadPersistedUserSession() {
        if let userData = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            currentUser = user
            lastRefreshTime = UserDefaults.standard.object(forKey: "lastUserRefreshTime") as? Date
            isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
            isWelcomeComplete = UserDefaults.standard.bool(forKey: "isWelcomeComplete")
            isPermissionsGranted = UserDefaults.standard.bool(forKey: "isPermissionsGranted")
            hasAddedFriends = UserDefaults.standard.bool(forKey: "hasAddedFriends")
            isOnboardingComplete = UserDefaults.standard.bool(forKey: "isOnboardingComplete")
        }
    }

    private func clearPersistedUserSession() {
        UserDefaults.standard.removeObject(forKey: "currentUser")
        UserDefaults.standard.removeObject(forKey: "isLoggedIn")
        UserDefaults.standard.removeObject(forKey: "isWelcomeComplete")
        UserDefaults.standard.removeObject(forKey: "isPermissionsGranted")
        UserDefaults.standard.removeObject(forKey: "hasAddedFriends")
        UserDefaults.standard.removeObject(forKey: "isOnboardingComplete")
    }

    // MARK: - Logout
    func signOut() async {
        #if DEBUG
        print("🔄 Starting comprehensive sign out process")
        #endif

        // 1. Sign out from Firebase Auth
        do {
            try Auth.auth().signOut()
            #if DEBUG
            print("✅ Firebase Auth sign out successful")
            #endif
        } catch {
            #if DEBUG
            print("⚠️ Firebase Auth sign out error: \(error)")
            #endif
            // Continue with cleanup even if Firebase sign out fails
        }

        // 2. Clean up Firebase listeners
        if let userId = currentUser?.id {
            userProvider.stopObservingUser(id: userId)
            #if DEBUG
            print("✅ Stopped Firebase user observers")
            #endif
        }

        // 3. Stop location updates
        locationManager?.manager.stopUpdatingLocation()
        #if DEBUG
        print("✅ Stopped location updates")
        #endif

        // 4. Clear all local state
        currentUser = nil
        currentUserId = nil
        isLoggedIn = false
        isOnboardingComplete = false
        isWelcomeComplete = false
        isPermissionsGranted = false
        hasAddedFriends = false
        #if DEBUG
        print("✅ Cleared local state")
        #endif

        // 5. Clear persisted data
        clearPersistedUserSession()
        #if DEBUG
        print("✅ Cleared persisted session data")

        print("✅ Sign out process completed")
        #endif
    }

    func refreshUserData() async {
        guard let userId = currentUser?.id else { return }

        userProvider.observeUser(id: userId) { [weak self] updatedUser in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let user = updatedUser {
                    // Don't overwrite valid profile data with stale/empty data from Firebase
                    // This can happen due to Firebase read/write replication delays
                    let currentHasProfile = !(self.currentUser?.firstName.isEmpty ?? true) &&
                                           !(self.currentUser?.lastName.isEmpty ?? true) &&
                                           !(self.currentUser?.username.isEmpty ?? true)
                    let fetchedHasProfile = !user.firstName.isEmpty &&
                                           !user.lastName.isEmpty &&
                                           !user.username.isEmpty

                    if currentHasProfile && !fetchedHasProfile {
                        #if DEBUG
                        print("⚠️ refreshUserData: Ignoring stale Firebase data with empty profile fields")
                        #endif
                        return
                    }

                    self.currentUser = user
                    self.persistUserSession()
                }
            }
        }
    }
    
    func updateUserLocation(_ location: CLLocationCoordinate2D) async throws {
        guard let user = currentUser else { return }
        user.location = location
        try await saveProfile(updatedUser: user)
    }
    
    func updatePhoneNumber(_ newPhone: String) async throws {
        if let updatedUser = currentUser {
            updatedUser.updatePhoneNumber(newPhone)
            try await saveProfile(updatedUser: updatedUser)
        }
    }

    
    // MARK: - Privacy Settings Methods
    func updatePrivacySettings(
        shareWithFriends: Bool? = nil,
        shareWithHost: Bool? = nil,
        shareWithGroup: Bool? = nil,
        allowFriendsInvite: Bool? = nil
    ) async throws {
        guard let updatedUser = currentUser else { return }
        
        if let shareWithFriends = shareWithFriends {
            updatedUser.shareLocationWithFriends = shareWithFriends
        }
        if let shareWithHost = shareWithHost {
            updatedUser.shareLocationWithEventHost = shareWithHost
        }
        if let shareWithGroup = shareWithGroup {
            updatedUser.shareLocationWithEventGroup = shareWithGroup
        }
        if let allowFriendsInvite = allowFriendsInvite {
            updatedUser.allowFriendsToInviteOthers = allowFriendsInvite
        }
        
        try await saveProfile(updatedUser: updatedUser)
    }
    
    // MARK: - Notification Settings Methods
    func updateNotificationSettings(
        friendRequests: Bool? = nil,
        friendEvents: Bool? = nil,
        eventUpdates: Bool? = nil
    ) async throws {
        guard let updatedUser = currentUser else { return }
        
        if let friendRequests = friendRequests {
            updatedUser.receiveFriendRequests = friendRequests
        }
        if let friendEvents = friendEvents {
            updatedUser.receiveFriendEvents = friendEvents
        }
        if let eventUpdates = eventUpdates {
            updatedUser.receiveEventUpdates = eventUpdates
        }
        
        try await saveProfile(updatedUser: updatedUser)
    }
    
    func findUserByPhoneNumber(_ phoneNumber: String) async -> User? {
        return await userProvider.fetchUser(byPhoneNumber: phoneNumber)
    }

    func searchUsers(usernameOrPhone query: String) async throws -> [User] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            throw AppError.invalidInput("Enter a username or phone number.")
        }

        let digitCount = trimmedQuery.filter { $0.isNumber }.count
        let phoneNumber = digitCount >= 7 ? trimmedQuery : nil
        let username = phoneNumber == nil ? trimmedQuery : nil

        let users = try await userProvider.searchUsers(
            username: username,
            phoneNumber: phoneNumber
        )

        return users.filter { $0.id != currentUser?.id }
    }

    func fetchPublicUserProfile(userId: String) async throws -> User {
        try await userProvider.fetchPublicUserProfile(userId: userId)
    }

    func findUsersByPhoneNumbers(_ phoneNumbers: [String]) async throws -> [User] {
        do {
            return try await userProvider.findUsersByPhoneNumbers(phoneNumbers)
        } catch {
            let appError = AppError.from(error)
            #if DEBUG
            print("Error finding users by phone numbers: \(appError.errorDescription ?? "Unknown")")
            #endif
            throw appError
        }
    }
    
    func createNewUser(phoneNumber: String, id: String) async throws {
        #if DEBUG
        print("Starting signup process for phone: \(phoneNumber)")
        #endif

        // First check if a user with this phone number already exists
        if await checkUserExists(phoneNumber: phoneNumber) {
            throw AppError.alreadyExists("Phone number already registered")
        }

        // Create new user with Firebase UID as the primary identifier
        let initialUser = User(
            id: id,  // Use Firebase UID as primary identifier
            firstName: "",
            lastName: "",
            username: "",
            phoneNumber: phoneNumber,
            joinDate: Date()
        )

        #if DEBUG
        print("Created initial user object with ID: \(initialUser.id)")
        #endif

        do {
            #if DEBUG
            print("Attempting to save initial user")
            #endif
            try await userProvider.saveInitialUser(initialUser)
            #if DEBUG
            print("Initial user saved successfully")
            #endif

            self.currentUser = initialUser
            self.currentUserId = initialUser.id
            self.isLoggedIn = true
            self.persistUserSession()
            #if DEBUG
            print("User session persisted with minimal data")
            #endif
        } catch {
            let appError = AppError.from(error)
            #if DEBUG
            print("Error saving user: \(appError.errorDescription ?? "Unknown")")
            #endif
            throw appError
        }
    }

    // MARK: - Fetch Data
    func fetchFriends() async -> [User] {
        guard let user = currentUser else { return [] }
        return await userProvider.fetchFriends(for: user)
    }

    func fetchAllUsers() async -> [User] {
        return await userProvider.fetchAllUsers()
    }

    // MARK: - Save Profile
    func saveProfile(updatedUser: User) async throws {
        #if DEBUG
        print("🔄 Starting profile save process")
        print("   Input User State:")
        print("   - ID: \(updatedUser.id)")
        print("   - First Name: '\(updatedUser.firstName)'")
        print("   - Last Name: '\(updatedUser.lastName)'")
        print("   - Username: '\(updatedUser.username)'")
        #endif

        do {
            #if DEBUG
            print("📤 Attempting to save user to Firebase")
            #endif
            try await userProvider.saveUser(updatedUser)
            #if DEBUG
            print("✅ User saved successfully to Firebase")
            #endif

            // Ensure the in-memory reference is the same user we just saved.
            // Avoid re-assigning the same instance (which can create redundant update loops).
            if currentUser !== updatedUser {
                objectWillChange.send()
                self.currentUser = updatedUser
            }

            self.currentUserId = updatedUser.id
            self.persistUserSession()

            #if DEBUG
            print("✅ Profile save process completed")
            print("   - First Name: '\(updatedUser.firstName)'")
            print("   - Last Name: '\(updatedUser.lastName)'")
            print("   - Username: '\(updatedUser.username)'")
            #endif
        } catch {
            let appError = AppError.from(error)
            #if DEBUG
            print("❌ Error saving profile: \(appError.errorDescription ?? "Unknown")")
            #endif
            throw appError
        }
    }

    func fetchUser(_ userId: String) async -> User? {
        return await userProvider.fetchUser(by: userId)
    }

    func toggleDoNotDisturb() async throws {
        guard let user = currentUser else { return }
        user.doNotDisturb.toggle()
        try await saveProfile(updatedUser: user)
    }

    // MARK: - User Actions

    func attendEvent(_ eventId: String) async throws {
        guard let user = currentUser else { return }
        guard !user.attendingEventIds.contains(eventId) else { return }

        // Update user's attending events locally
        user.attendingEventIds.append(eventId)
        
        // Sync with Firestore
        try await saveProfile(updatedUser: user)
        #if DEBUG
        print("✅ Event attendance synced with Firestore: \(eventId)")
        #endif
    }

    func leaveEvent(_ eventId: String) async throws {
        guard let user = currentUser else { return }
        guard user.attendingEventIds.contains(eventId) else { return }

        // Remove from user's attending events locally
        if let index = user.attendingEventIds.firstIndex(of: eventId) {
            user.attendingEventIds.remove(at: index)
            
            // Sync with Firestore
            try await saveProfile(updatedUser: user)
            #if DEBUG
            print("✅ Event departure synced with Firestore: \(eventId)")
            #endif
        }
    }

    // MARK: - Friend Management
    public func sendFriendRequest(to userId: String) async throws {
        guard let currentUserId = currentUser?.id else { return }
        try await friendProvider.sendFriendRequest(fromUserId: currentUserId, to: userId)
    }

    public func acceptFriendRequest(requestId: String, fromUserId: String) async throws {
        guard let currentUserId = currentUser?.id else { return }
        try await friendProvider.acceptFriendRequest(requestId: requestId, userId: currentUserId, friendId: fromUserId)
        await refreshUserData()
    }

    public func rejectFriendRequest(requestId: String) async throws {
        try await friendProvider.rejectFriendRequest(requestId: requestId)
    }

    public func addFriend(_ friendId: String) async throws {
        guard let currentUserId = currentUser?.id else { return }
        try await friendProvider.addFriend(friendId, to: currentUserId)
        await refreshUserData()
    }

    public func removeFriend(_ friendId: String) async throws {
        guard let currentUserId = currentUser?.id else { return }
        try await friendProvider.removeFriend(friendId, from: currentUserId)
        await refreshUserData()
    }
    
    public func isFriend(_ userId: String) -> Bool {
        currentUser?.friends.contains(userId) ?? false
    }
    
    // MARK: - Stats Management
    private static let joinDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    func getUserStats(for userId: String) async -> UserStats? {
        // First fetch the user
        guard let user = await userProvider.fetchUser(by: userId) else { return nil }

        let totalLandmarks = await landmarkProvider.fetchTotalLandmarks()
        let landmarkCompletion = totalLandmarks > 0
            ? Int((Double(user.visitedLandmarkIds.count) / Double(totalLandmarks)) * 100)
            : 0

        return UserStats(
            joinDate: Self.joinDateFormatter.string(from: user.joinDate),
            landmarkCompletion: landmarkCompletion,
            friendCount: user.friends.count,
            hostedEventCount: user.createdEventIds.count,
            attendedEventCount: user.attendingEventIds.count
        )
    }
    
    func getUserStats() async -> UserStats? {
        guard let currentUser = currentUser else { return nil }
        return await getUserStats(for: currentUser.id)
    }
    
    // MARK: - Landmark Management
    func visitLandmark(_ landmarkId: String) async {
        guard let userId = currentUser?.id else { return }
        await landmarkProvider.markLandmarkVisited(userId: userId, landmarkId: landmarkId)
        await refreshUserData() // Refresh to get updated visitedLandmarkIds
    }

    func unvisitLandmark(_ landmarkId: String) async {
        guard let userId = currentUser?.id else { return }
        await landmarkProvider.unmarkLandmarkVisited(userId: userId, landmarkId: landmarkId)
        await refreshUserData() // Refresh to get updated visitedLandmarkIds
    }
    
    // MARK: - Location Management
    func updateLocation(_ location: CLLocationCoordinate2D) async {
        guard isLoggedIn, let userId = currentUser?.id else {
            #if DEBUG
            print("UserManager: Location update skipped - user not logged in or no user ID")
            #endif
            return
        }

        // Skip location updates if profile setup is not complete
        guard isOnboardingComplete else {
            #if DEBUG
            print("UserManager: Location update skipped - profile setup not complete")
            #endif
            return
        }

        // Skip location updates if user hasn't completed their profile
        guard let user = currentUser, !user.firstName.isEmpty, !user.lastName.isEmpty, !user.username.isEmpty else {
            #if DEBUG
            print("UserManager: Location update skipped - profile information incomplete")
            #endif
            return
        }
        
        do {
            // Only log location updates every 5 minutes or if there's an error
            let shouldLog = lastLocationLogTime?.timeIntervalSinceNow ?? -300 <= -300
            #if DEBUG
            if shouldLog {
                print("UserManager: Updating location for user \(userId)")
                lastLocationLogTime = Date()
            }
            #endif

            try await locationProvider.updateUserLocation(userId: userId, location: location)
            if let updatedUser = currentUser {
                updatedUser.location = location
                self.currentUser = updatedUser

                #if DEBUG
                if shouldLog {
                    print("UserManager: Location updated successfully")
                }
                #endif
            }
        } catch {
            let appError = AppError.from(error)
            #if DEBUG
            print("UserManager: Error updating location: \(appError.errorDescription ?? "Unknown")")
            #endif
        }
    }

    // MARK: - User Refresh
    func refreshCurrentUser() async throws {
        guard let userId = currentUser?.id else { return }
        if let refreshedUser = await userProvider.fetchUser(by: userId) {
            currentUser = refreshedUser
            persistUserSession()
        }
    }

    // Add this new function to verify user initialization
    func verifyUserInitialized() async -> Bool {
        guard let userId = currentUser?.id else { return false }

        // Attempt to fetch the user document to verify it exists and is properly initialized
        guard let user = await userProvider.fetchUser(by: userId) else { return false }

        // Verify essential fields are present
        return !user.phoneNumber.isEmpty
    }

    // Add this function for background refresh
    @MainActor
    func refreshUserInBackground() async {
        guard !isRefreshing,
              let currentTime = lastRefreshTime?.addingTimeInterval(minimumRefreshInterval),
              currentTime > Date() else {
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        if let userId = currentUser?.id,
           let refreshedUser = await userProvider.fetchUser(by: userId) {
            // Don't overwrite valid profile data with stale/empty data from Firebase
            let currentHasProfile = !(self.currentUser?.firstName.isEmpty ?? true) &&
                                   !(self.currentUser?.lastName.isEmpty ?? true) &&
                                   !(self.currentUser?.username.isEmpty ?? true)
            let fetchedHasProfile = !refreshedUser.firstName.isEmpty &&
                                   !refreshedUser.lastName.isEmpty &&
                                   !refreshedUser.username.isEmpty

            if currentHasProfile && !fetchedHasProfile {
                #if DEBUG
                print("⚠️ refreshUserInBackground: Ignoring stale Firebase data with empty profile fields")
                #endif
                return
            }

            self.currentUser = refreshedUser
            self.persistUserSession()
            lastRefreshTime = Date()
        }
    }

    // Add this function to check if refresh is needed
    func shouldRefreshUser() -> Bool {
        guard let lastRefresh = lastRefreshTime else { return true }
        return Date().timeIntervalSince(lastRefresh) > minimumRefreshInterval
    }

    // MARK: - Profile Image Management
    func setProfileImage(_ image: UIImage) async throws {
        guard let currentUser = self.currentUser else {
            throw AppError.notAuthenticated("No current user found")
        }

        // Upload image and get URLs
        let urls = try await imageProvider.uploadProfileImage(image, for: currentUser.id)

        // Update user model
        currentUser.profileImageUrl = urls.fullUrl
        currentUser.profileThumbnailUrl = urls.thumbnailUrl
        currentUser.profileImageData = nil // Clear local data since we have URLs now

        // Save changes
        try await userProvider.saveUser(currentUser)
        self.currentUser = currentUser
    }

    func fetchProfileImage(for user: User, preferredSize: ImageSize = .full, forceRefresh: Bool = false) async throws -> UIImage? {
        let url = preferredSize == .full ? user.profileImageUrl : (user.profileThumbnailUrl ?? user.profileImageUrl)

        // If we have a URL and are online, try to fetch from remote
        if let imageUrl = url {
            do {
                let image = try await imageProvider.downloadProfileImage(from: imageUrl)
                return image
            } catch {
                let appError = AppError.from(error)
                #if DEBUG
                print("Failed to fetch remote image: \(appError.errorDescription ?? "Unknown")")
                #endif
            }
        }

        // Fall back to local data if available
        if let imageData = user.profileImageData {
            return UIImage(data: imageData)
        }

        return nil
    }

    func prefetchProfileImages(for users: [User], preferredSize: ImageSize = .thumbnail) async {
        let urls = users.compactMap { preferredSize == .full ? $0.profileImageUrl : ($0.profileThumbnailUrl ?? $0.profileImageUrl) }
        await imageProvider.prefetchProfileImages(urls: urls)
    }

    // MARK: - Image Types
    enum ImageSize {
        case full
        case thumbnail
    }

    func checkUserExists(phoneNumber: String) async -> Bool {
        #if DEBUG
        print("Checking if user exists with phone number: \(phoneNumber)")
        #endif
        return await userProvider.checkUserExists(phoneNumber: phoneNumber)
    }

    func login(phoneNumber: String, id: String) async throws {
        #if DEBUG
        print("Starting login process for phone: \(phoneNumber)")
        #endif

        let existingUser: User
        if let user = await userProvider.fetchUser(by: id) {
            existingUser = user
        } else {
            // Self-heal legacy accounts where the user doc isn't keyed by Auth UID.
            do {
                try await userProvider.ensureUserDocument()
            } catch {
                #if DEBUG
                let appError = AppError.from(error)
                print("UserManager: ensureUserDocument failed: \(appError.errorDescription ?? "Unknown")")
                #endif
            }

            guard let user = await userProvider.fetchUser(by: id) else {
                throw AppError.notFound("No account found for this user")
            }
            existingUser = user
        }

        // (Optional) If you want to double-check that this user has the same phone number:
//        let normalizedPhone = normalizePhoneNumber(phoneNumber)
//        guard existingUser.phoneNumber == normalizedPhone else {
//            throw ValidationError.invalidData("No account found with this phone number")
//        }

        #if DEBUG
        print("User found, logging in")
        #endif
        self.currentUser = existingUser
        self.currentUserId = existingUser.id
        self.isLoggedIn = true
        self.persistUserSession()
        #if DEBUG
        print("User logged in successfully")
        #endif
    }

    // MARK: - Initial Profile Setup
    func saveInitialProfile(updatedUser: User) async throws {
        #if DEBUG
        print("🔄 Starting initial profile save process")
        print("   Input User State:")
        print("   - ID: \(updatedUser.id)")
        print("   - First Name: '\(updatedUser.firstName)'")
        print("   - Last Name: '\(updatedUser.lastName)'")
        print("   - Username: '\(updatedUser.username)'")
        #endif

        do {
            #if DEBUG
            print("📤 Forcing save to Firebase for initial setup")
            #endif
            try await userProvider.saveUser(updatedUser)
            #if DEBUG
            print("✅ User saved successfully to Firebase")
            #endif

            // Force SwiftUI to detect the change by explicitly notifying
            // (User is a class, so setting the same reference doesn't trigger @Published)
            #if DEBUG
            print("✅ Setting current user to saved user")
            #endif
            objectWillChange.send()
            self.currentUser = updatedUser
            self.persistUserSession()
            #if DEBUG
            print("✅ Initial profile save completed")
            print("   - First Name: '\(updatedUser.firstName)'")
            print("   - Last Name: '\(updatedUser.lastName)'")
            print("   - Username: '\(updatedUser.username)'")
            #endif
        } catch {
            #if DEBUG
            print("❌ Error saving initial profile: \(error.localizedDescription)")
            print("   Detailed error: \(error)")
            #endif
            throw error
        }
    }

    // Add property to track last location log time
    private var lastLocationLogTime: Date?
}
