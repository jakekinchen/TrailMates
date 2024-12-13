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
    private let dataProvider = FirebaseDataProvider.shared
    private var cancellables = Set<AnyCancellable>()
    private var hasInitialized = false
    
    // Facebook-related properties
    private let facebookService = FacebookService.shared
    @Published var isFacebookLinked: Bool = false
    
    private init() {
        setupObservers()
    }
    
    @Published private(set) var isRefreshing = false
    private var lastRefreshTime: Date?
    private let minimumRefreshInterval: TimeInterval = 300 // 5 minutes
    
    // Add a non-isolated property to track the current user ID for cleanup
    private var currentUserId: String?
    
    func initializeIfNeeded() async {
        guard !hasInitialized else { return }
        
        print("👤 Starting UserManager initialization")
        setupObservers()
        
        // First try to load from persistence
        if checkPersistedUser() {
            hasInitialized = true
            print("👤 User loaded from persistence")
            return
        }
        
        // If not persisted, fetch from Firebase
        if let user = await dataProvider.fetchCurrentUser() {
            await MainActor.run {
                self.currentUser = user
                self.isLoggedIn = true
                self.persistUserSession()
            }
            print("👤 User fetched from Firebase: \(user.firstName) \(user.lastName)")
        } else {
            print("❌ No user found in Firebase")
            await MainActor.run {
                self.isLoggedIn = false
                self.currentUser = nil
            }
        }
        
        hasInitialized = true
        print("👤 UserManager initialization completed")
    }
    
    private func setupObservers() {
        // Setup Facebook link status observation
        facebookService.$isLinked
            .sink { [weak self] isLinked in
                self?.isFacebookLinked = isLinked
            }
            .store(in: &cancellables)
        
        // Setup automatic saving
        $currentUser
            .dropFirst()
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .compactMap { $0 }
            .sink { [weak self] user in
                Task { [weak self] in
                    try await self?.saveProfile(updatedUser: user)
                }
            }
            .store(in: &cancellables)
        
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
            dataProvider.stopObservingUser(id: userId)
        }
        
        // Cancel all publishers
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        
        // Clear current user data
        currentUser = nil
        currentUserId = nil
    }
    
    deinit {
        // Cancel publishers (this is safe as it's not actor-isolated)
        cancellables.forEach { $0.cancel() }
        
        // Use the tracked ID for cleanup
        if let userId = currentUserId {
            dataProvider.stopObservingUser(id: userId)
        }
    }
    
    // MARK: - Initialize User
    func initializeUserIfNeeded() async {
        guard !hasInitialized else { return }
        
        print("👤 Starting UserManager initialization")
        setupObservers()
        
        // First try to load from persistence
        if checkPersistedUser() {
            hasInitialized = true
            print("👤 User loaded from persistence")
            return
        }
        
        // If not persisted, fetch from Firebase
        if let user = await dataProvider.fetchCurrentUser() {
            await MainActor.run {
                self.currentUser = user
                self.currentUserId = user.id  // Track the ID
                self.isLoggedIn = true
                self.persistUserSession()
            }
            print("👤 User fetched from Firebase: \(user.firstName) \(user.lastName)")
        } else {
            print("❌ No user found in Firebase")
            await MainActor.run {
                self.isLoggedIn = false
                self.currentUser = nil
                self.currentUserId = nil  // Clear the ID
            }
        }
        
        hasInitialized = true
        print("👤 UserManager initialization completed")
    }
    
    private func checkPersistedUser() -> Bool {
        if let userData = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            currentUser = user
            isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
            isOnboardingComplete = UserDefaults.standard.bool(forKey: "isOnboardingComplete")
            hasAddedFriends = UserDefaults.standard.bool(forKey: "hasAddedFriends")
            return true
        }
        return false
    }
    
    func isUsernameTaken(_ username: String) async -> Bool {
        let excludeId = currentUser?.id // Exclude current user when checking (for edit mode)
        return await dataProvider.isUsernameTaken(username, excludingUserId: excludeId)
    }
    
    // MARK: Facebook Integration
    
    func toggleFacebookLink() async throws {
        isFacebookLinked.toggle()
        if let updatedUser = currentUser {
            // Update any Facebook-related user properties here
            try await saveProfile(updatedUser: updatedUser)
        }
    }
    
    // Facebook-related methods
    func linkFacebook() async throws {
        do {
            let fbUser = try await facebookService.linkAccount()
            isFacebookLinked = true
            if let updatedUser = currentUser {
                updatedUser.facebookId = fbUser.id
                try await saveProfile(updatedUser: updatedUser)
            }
            persistUserSession()
        } catch {
            isFacebookLinked = false
            throw error
        }
    }
    
    func unlinkFacebook() {
        facebookService.unlinkAccount()
        isFacebookLinked = false
        if let updatedUser = currentUser {
            updatedUser.facebookId = nil
            Task {
                try await saveProfile(updatedUser: updatedUser)
            }
        }
        persistUserSession()
    }
    
    func fetchFacebookFriendsWithStatus() async throws -> [(friend: FacebookFriend, user: User?, isFriend: Bool)] {
        guard isFacebookLinked else {
            throw NSError(domain: "com.bridges.trailmatesatx", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Facebook not linked"])
        }
        
        // 1. Get Facebook friends
        let facebookFriends = try await facebookService.fetchFriends()
        
        // 2. Get all Facebook IDs
        let facebookIds = facebookFriends.map { $0.id }
        
        // 3. Fetch TrailMates users with these Facebook IDs
        let matchedUsers = await dataProvider.fetchUsersByFacebookIds(facebookIds)
        
        // 4. Create result array with all necessary information
        return facebookFriends.map { friend -> (friend: FacebookFriend, user: User?, isFriend: Bool) in
            let matchedUser = matchedUsers.first { $0.facebookId == friend.id }
            let isFriend = matchedUser.map { self.isFriend($0.id) } ?? false
            return (friend: friend, user: matchedUser, isFriend: isFriend)
        }
    }
    
    // MARK: - Persist User Session
    func persistUserSession() {
        print("💾 Persisting user session")
        if let user = currentUser {
            if let userData = try? JSONEncoder().encode(user) {
                print("   - Saving user data:")
                print("     • First Name: '\(user.firstName)'")
                print("     • Last Name: '\(user.lastName)'")
                print("     • Username: '\(user.username)'")
                UserDefaults.standard.set(userData, forKey: "currentUser")
                UserDefaults.standard.set(Date(), forKey: "lastUserRefreshTime")
                print("   - User data saved successfully")
            } else {
                print("❌ Failed to encode user data")
            }
        } else {
            print("⚠️ No current user to persist")
        }
        
        UserDefaults.standard.set(isLoggedIn, forKey: "isLoggedIn")
        UserDefaults.standard.set(isWelcomeComplete, forKey: "isWelcomeComplete")
        UserDefaults.standard.set(isPermissionsGranted, forKey: "isPermissionsGranted")
        UserDefaults.standard.set(hasAddedFriends, forKey: "hasAddedFriends")
        UserDefaults.standard.set(isOnboardingComplete, forKey: "isOnboardingComplete")
        UserDefaults.standard.set(isFacebookLinked, forKey: "isFacebookLinked")
        print("   - Session flags saved")
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
            isFacebookLinked = UserDefaults.standard.bool(forKey: "isFacebookLinked")
        }
    }

    private func clearPersistedUserSession() {
        UserDefaults.standard.removeObject(forKey: "currentUser")
        UserDefaults.standard.removeObject(forKey: "isLoggedIn")
        UserDefaults.standard.removeObject(forKey: "isWelcomeComplete")
        UserDefaults.standard.removeObject(forKey: "isPermissionsGranted")
        UserDefaults.standard.removeObject(forKey: "hasAddedFriends")
        UserDefaults.standard.removeObject(forKey: "isOnboardingComplete")
        UserDefaults.standard.removeObject(forKey: "isFacebookLinked")
    }

    func signOut() {
        // Clear all state
        currentUser = nil
        currentUserId = nil  // Clear the ID
        isLoggedIn = false
        isOnboardingComplete = false
        isWelcomeComplete = false
        isPermissionsGranted = false
        hasAddedFriends = false
        isFacebookLinked = false
        
        // Clear persisted data
        clearPersistedUserSession()
    }

    func refreshUserData() async {
        guard let userId = currentUser?.id else { return }
        
        dataProvider.observeUser(id: userId) { [weak self] updatedUser in
            guard let self = self else { return }
            if let user = updatedUser {
                self.currentUser = user
                self.persistUserSession()
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
            updatedUser.phoneNumber = newPhone
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
        print("📱 UserManager - Finding user by phone: \(phoneNumber)")
        let result = await dataProvider.fetchUser(byPhoneNumber: phoneNumber)
        if let user = result {
            print("✅ UserManager - Found user: \(user.firstName) \(user.lastName)")
        } else {
            print("❌ UserManager - No user found for phone number")
        }
        return result
    }

    
    func createNewUser(phoneNumber: String, id: String) async throws {
        print("Starting signup process for phone: \(phoneNumber)")
        
        // First check if a user with this phone number already exists
        if await checkUserExists(phoneNumber: phoneNumber) {
            throw ValidationError.invalidData("Phone number already registered")
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
        
        print("Created initial user object with ID: \(initialUser.id)")
        
        do {
            print("Attempting to save initial user")
            try await dataProvider.saveInitialUser(initialUser)
            print("Initial user saved successfully")
            
            await MainActor.run {
                self.currentUser = initialUser
                self.currentUserId = initialUser.id
                self.isLoggedIn = true
                self.persistUserSession()
            }
            print("User session persisted with minimal data")
        } catch {
            print("Error saving user: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Fetch Data
    func fetchFriends() async -> [User] {
        guard let user = currentUser else { return [] }
        return await dataProvider.fetchFriends(for: user)
    }

    func fetchAllUsers() async -> [User] {
        return await dataProvider.fetchAllUsers()
    }

    // MARK: - Save Profile
    func saveProfile(updatedUser: User) async throws {
        print("🔄 Starting profile save process")
        print("   Input User State:")
        print("   - ID: \(updatedUser.id)")
        print("   - First Name: '\(updatedUser.firstName)'")
        print("   - Last Name: '\(updatedUser.lastName)'")
        print("   - Username: '\(updatedUser.username)'")
        
        // Check if this is initial profile setup
        let isInitialSetup = currentUser?.firstName.isEmpty ?? true || 
                            currentUser?.lastName.isEmpty ?? true || 
                            currentUser?.username.isEmpty ?? true
        
        // Always save during initial setup or when there are changes
        if isInitialSetup || updatedUser.profileImage != nil || currentUser != updatedUser {
            print("✅ Changes detected or initial setup, proceeding with save")
            do {
                print("📤 Attempting to save user to Firebase")
                try await dataProvider.saveUser(updatedUser)
                print("✅ User saved successfully to Firebase")
                
                // Force a fresh fetch to get updated URLs
                print("📥 Fetching updated user from Firebase")
                let refreshedUser = await dataProvider.fetchUser(by: updatedUser.id)
                print("   Fetch completed. Got refreshed user: \(refreshedUser != nil)")
                
                if let refreshedUser = refreshedUser {
                    print("✅ Setting refreshed user:")
                    print("   - First Name: '\(refreshedUser.firstName)'")
                    print("   - Last Name: '\(refreshedUser.lastName)'")
                    print("   - Username: '\(refreshedUser.username)'")
                    self.currentUser = refreshedUser
                } else {
                    print("⚠️ No refreshed user found, using updated user")
                    self.currentUser = updatedUser
                }
                self.persistUserSession()
                print("✅ Profile save process completed")
            } catch {
                print("❌ Error saving profile: \(error.localizedDescription)")
                print("   Detailed error: \(error)")
                throw error
            }
        } else {
            print("ℹ️ No changes detected, skipping save")
        }
    }

    func fetchUser(_ userId: String) async -> User? {
        return await dataProvider.fetchUser(by: userId)
    }

    // MARK: - Logout
    func logout() {
        do {
            try Auth.auth().signOut()
            currentUser = nil
            isLoggedIn = false
            clearPersistedUserSession()
        } catch {
            print("Error signing out: \(error)")
        }
    }

    

    func toggleDoNotDisturb() async throws {
        guard let user = currentUser else { return }
        user.doNotDisturb.toggle()
        try await saveProfile(updatedUser: user)
    }

    // MARK: - User Actions

    func attendEvent(eventId: String) {
        guard let user = currentUser else { return }
        guard !user.attendingEventIds.contains(eventId) else { return }

        // Update user's attending events
        user.attendingEventIds.append(eventId)
        self.currentUser = user
        self.persistUserSession()
    }

    func leaveEvent(eventId: String) {
        guard let user = currentUser else { return }
        guard user.attendingEventIds.contains(eventId) else { return }

        // Remove from user's attending events
        if let index = user.attendingEventIds.firstIndex(of: eventId) {
            user.attendingEventIds.remove(at: index)
            self.currentUser = user
            self.persistUserSession()
        }
    }

    // MARK: - Friend Management
    public func sendFriendRequest(to userId: String) async throws {
        guard let currentUserId = currentUser?.id else { return }
        try await dataProvider.sendFriendRequest(from: currentUserId, to: userId)
    }
    
    public func acceptFriendRequest(requestId: String, fromUserId: String) async throws {
        guard let currentUserId = currentUser?.id else { return }
        try await dataProvider.acceptFriendRequest(requestId: requestId, userId: currentUserId, friendId: fromUserId)
        await refreshUserData()
    }
    
    public func rejectFriendRequest(requestId: String) async throws {
        try await dataProvider.rejectFriendRequest(requestId: requestId)
    }
    
    public func addFriend(_ friendId: String) async throws {
        guard let currentUserId = currentUser?.id else { return }
        try await dataProvider.addFriend(friendId, to: currentUserId)
        await refreshUserData()
    }
    
    public func removeFriend(_ friendId: String) async throws {
        guard let currentUserId = currentUser?.id else { return }
        try await dataProvider.removeFriend(friendId, from: currentUserId)
        await refreshUserData()
    }
    
    public func isFriend(_ userId: String) -> Bool {
        currentUser?.friends.contains(userId) ?? false
    }
    
    // MARK: - Stats Management
    func getUserStats(for userId: String) async -> UserStats? {
        // First fetch the user
        guard let user = await dataProvider.fetchUser(by: userId) else { return nil }
        
        let totalLandmarks = await dataProvider.fetchTotalLandmarks()
        let landmarkCompletion = totalLandmarks > 0
            ? Int((Double(user.visitedLandmarkIds.count) / Double(totalLandmarks)) * 100)
            : 0
            
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        
        return UserStats(
            joinDate: formatter.string(from: user.joinDate),
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
        await dataProvider.markLandmarkVisited(userId: userId, landmarkId: landmarkId)
        await refreshUserData() // Refresh to get updated visitedLandmarkIds
    }
    
    func unvisitLandmark(_ landmarkId: String) async {
        guard let userId = currentUser?.id else { return }
        await dataProvider.unmarkLandmarkVisited(userId: userId, landmarkId: landmarkId)
        await refreshUserData() // Refresh to get updated visitedLandmarkIds
    }
    
    // MARK: - Location Management
    func updateLocation(_ location: CLLocationCoordinate2D) async {
        guard isLoggedIn, let userId = currentUser?.id else {
            print("UserManager: Location update skipped - user not logged in or no user ID")
            return
        }
        
        // Skip location updates if profile setup is not complete
        guard isOnboardingComplete else {
            print("UserManager: Location update skipped - profile setup not complete")
            return
        }
        
        // Skip location updates if user hasn't completed their profile
        guard let user = currentUser, !user.firstName.isEmpty, !user.lastName.isEmpty, !user.username.isEmpty else {
            print("UserManager: Location update skipped - profile information incomplete")
            return
        }
        
        do {
            print("UserManager: Attempting to update location for user \(userId)")
            try await dataProvider.updateUserLocation(userId: userId, location: location)
            if let updatedUser = currentUser {
                updatedUser.location = location
                self.currentUser = updatedUser
                print("UserManager: Successfully updated user location")
            }
        } catch {
            print("UserManager: Error updating location: \(error)")
        }
    }

    // MARK: - User Refresh
    func refreshCurrentUser() async throws {
        guard let userId = currentUser?.id else { return }
        if let refreshedUser = await dataProvider.fetchUser(by: userId) {
            currentUser = refreshedUser
            persistUserSession()
        }
    }

    // Add this new function to verify user initialization
    func verifyUserInitialized() async -> Bool {
        guard let userId = currentUser?.id else { return false }
        
        // Attempt to fetch the user document to verify it exists and is properly initialized
        guard let user = await dataProvider.fetchUser(by: userId) else { return false }
        
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
           let refreshedUser = await dataProvider.fetchUser(by: userId) {
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
            throw ValidationError.userNotAuthenticated("No current user found")
        }
        
        // Upload image and get URLs
        let urls = try await dataProvider.uploadProfileImage(image, for: currentUser.id)
        
        // Update user model
        currentUser.profileImageUrl = urls.fullUrl
        currentUser.profileThumbnailUrl = urls.thumbnailUrl
        currentUser.profileImageData = nil // Clear local data since we have URLs now
        
        // Save changes
        try await dataProvider.saveUser(currentUser)
        self.currentUser = currentUser
    }

    func fetchProfileImage(for user: User, preferredSize: ImageSize = .full, forceRefresh: Bool = false) async throws -> UIImage? {
        let url = preferredSize == .full ? user.profileImageUrl : (user.profileThumbnailUrl ?? user.profileImageUrl)
        
        // If we have a URL and are online, try to fetch from remote
        if let imageUrl = url {
            do {
                let image = try await dataProvider.downloadProfileImage(from: imageUrl)
                return image
            } catch {
                print("Failed to fetch remote image: \(error.localizedDescription)")
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
        await dataProvider.prefetchProfileImages(urls: urls)
    }

    // MARK: - Image Types
    enum ImageSize {
        case full
        case thumbnail
    }

    func checkUserExists(phoneNumber: String) async -> Bool {
        print("Checking if user exists with phone number: \(phoneNumber)")
        let existingUser = await dataProvider.fetchUser(byPhoneNumber: phoneNumber)
        return existingUser != nil
    }
    
    func login(phoneNumber: String, id: String) async throws {
        print("Starting login process for phone: \(phoneNumber)")
        
        // Fetch existing user
        guard let existingUser = await dataProvider.fetchUser(byPhoneNumber: phoneNumber) else {
            throw ValidationError.invalidData("No account found with this phone number")
        }
        
        // Verify Firebase UID matches
        if existingUser.id != id {
            throw ValidationError.invalidData("Account credentials mismatch")
        }
        
        print("User found, logging in")
        await MainActor.run {
            self.currentUser = existingUser
            self.currentUserId = existingUser.id
            self.isLoggedIn = true
            self.persistUserSession()
        }
        print("User logged in successfully")
    }

    // MARK: - Initial Profile Setup
    func saveInitialProfile(updatedUser: User) async throws {
        print("🔄 Starting initial profile save process")
        print("   Input User State:")
        print("   - ID: \(updatedUser.id)")
        print("   - First Name: '\(updatedUser.firstName)'")
        print("   - Last Name: '\(updatedUser.lastName)'")
        print("   - Username: '\(updatedUser.username)'")
        
        do {
            print("📤 Forcing save to Firebase for initial setup")
            try await dataProvider.saveUser(updatedUser)
            print("✅ User saved successfully to Firebase")
            
            // Force a fresh fetch to get updated URLs
            print("📥 Fetching updated user from Firebase")
            let refreshedUser = await dataProvider.fetchUser(by: updatedUser.id)
            print("   Fetch completed. Got refreshed user: \(refreshedUser != nil)")
            
            if let refreshedUser = refreshedUser {
                print("✅ Setting refreshed user:")
                print("   - First Name: '\(refreshedUser.firstName)'")
                print("   - Last Name: '\(refreshedUser.lastName)'")
                print("   - Username: '\(refreshedUser.username)'")
                self.currentUser = refreshedUser
            } else {
                print("⚠️ No refreshed user found, using updated user")
                self.currentUser = updatedUser
            }
            self.persistUserSession()
            print("✅ Initial profile save completed")
        } catch {
            print("❌ Error saving initial profile: \(error.localizedDescription)")
            print("   Detailed error: \(error)")
            throw error
        }
    }
}

// MARK: - Profile Image Types
extension UserManager {
    enum ProfileImageSize {
        case full
        case thumbnail
    }
    
    enum ProfileImageError: LocalizedError {
        case invalidUrl
        case downloadFailed
        case invalidData
        
        var errorDescription: String? {
            switch self {
            case .invalidUrl:
                return "Invalid profile image URL"
            case .downloadFailed:
                return "Failed to download profile image"
            case .invalidData:
                return "Invalid image data received"
            }
        }
    }
}
