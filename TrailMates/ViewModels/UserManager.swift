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
    // Published properties for UI updates
    @Published var currentUser: User?
    @Published var isLoggedIn = false
    @Published var isWelcomeComplete = false
    @Published var isPermissionsGranted = false
    @Published var hasAddedFriends = false
    @Published var isOnboardingComplete = false

    // Computed property to check if the user's profile is complete
    var isProfileComplete: Bool {
        guard let user = currentUser else { return false }
        return !user.firstName.isEmpty && !(user.username.isEmpty ? true : false)
    }

    private let dataProvider: DataProvider
    private var cancellables = Set<AnyCancellable>()
    private var currentUserId: UUID?  // Track user ID separately for deinit
    
    // Facebook-related properties
    private let facebookService = FacebookService.shared
    @Published var isFacebookLinked: Bool = false
    
    // MARK: - Initialization
    init(dataProvider: DataProvider = FirebaseDataProvider()) {
        self.dataProvider = dataProvider
        
        // Load saved user session
        loadPersistedUserSession()
        
        // Setup Facebook link status observation
        facebookService.$isLinked
            .sink { [weak self] isLinked in
                self?.isFacebookLinked = isLinked
            }
            .store(in: &cancellables)
        
        // Setup automatic saving
        $currentUser
            .dropFirst()  // Ignore the initial value
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .compactMap { $0 }  // Only proceed if user is not nil
            .sink { [weak self] user in
                Task { [weak self] in
                    try await self?.saveProfile(updatedUser: user)
                }
            }
            .store(in: &cancellables)
            
        // Setup onboarding state observation
        $isOnboardingComplete
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.persistUserSession()
            }
            .store(in: &cancellables)
            
        // Setup other state observations
        Publishers.CombineLatest4($isLoggedIn, $isWelcomeComplete, $isPermissionsGranted, $hasAddedFriends)
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.persistUserSession()
            }
            .store(in: &cancellables)
    }

    deinit {
        // Clean up listeners
        if let userId = currentUserId,
           let firebaseProvider = dataProvider as? FirebaseDataProvider {
            firebaseProvider.stopObservingUser(id: userId)
        }
        cancellables.forEach { $0.cancel() }
    }
    
    // MARK: - Initialize User
    func initializeUserIfNeeded() async  {
               checkPersistedUser()
               if currentUser == nil {
                   if let user = await dataProvider.fetchCurrentUser() {
                       self.currentUser = user
                       self.isLoggedIn = true
                       self.persistUserSession()
                       print("Current user set: \(user.firstName) \(user.lastName)")
                   } else {
                       print("No user returned from fetchCurrentUser()")
                   }
               } else {
                   print("User already persisted: \(currentUser?.firstName ?? "Unknown")")
               }
           }

        private func checkPersistedUser() {
            if let userData = UserDefaults.standard.data(forKey: "currentUser"),
               let user = try? JSONDecoder().decode(User.self, from: userData) {
                currentUser = user
                isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
                isOnboardingComplete = UserDefaults.standard.bool(forKey: "isOnboardingComplete")
                hasAddedFriends = UserDefaults.standard.bool(forKey: "hasAddedFriends")
            }
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
                if var updatedUser = currentUser {
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
            if var updatedUser = currentUser {
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
            if let user = currentUser {
                if let userData = try? JSONEncoder().encode(user) {
                    UserDefaults.standard.set(userData, forKey: "currentUser")
                }
            }
            UserDefaults.standard.set(isLoggedIn, forKey: "isLoggedIn")
            UserDefaults.standard.set(isWelcomeComplete, forKey: "isWelcomeComplete")
            UserDefaults.standard.set(isPermissionsGranted, forKey: "isPermissionsGranted")
            UserDefaults.standard.set(hasAddedFriends, forKey: "hasAddedFriends")
            UserDefaults.standard.set(isOnboardingComplete, forKey: "isOnboardingComplete")
            // Add Facebook linking state
            UserDefaults.standard.set(isFacebookLinked, forKey: "isFacebookLinked")
        }

        private func loadPersistedUserSession() {
            if let userData = UserDefaults.standard.data(forKey: "currentUser"),
               let user = try? JSONDecoder().decode(User.self, from: userData) {
                currentUser = user
                isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
                isWelcomeComplete = UserDefaults.standard.bool(forKey: "isWelcomeComplete")
                isPermissionsGranted = UserDefaults.standard.bool(forKey: "isPermissionsGranted")
                hasAddedFriends = UserDefaults.standard.bool(forKey: "hasAddedFriends")
                isOnboardingComplete = UserDefaults.standard.bool(forKey: "isOnboardingComplete")
                // Load Facebook linking state
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


    func refreshUserData() async {
        guard let userId = currentUser?.id,
              let firebaseProvider = dataProvider as? FirebaseDataProvider else { return }
        
        firebaseProvider.observeUser(id: userId) { [weak self] updatedUser in
            guard let self = self else { return }
            if let user = updatedUser {
                self.currentUser = user
            }
        }
    }
    
    func updateUserLocation(_ location: CLLocationCoordinate2D) async throws {
        guard var user = currentUser else { return }
        user.location = location
        try await saveProfile(updatedUser: user)
    }
    
    func updatePhoneNumber(_ newPhone: String) async throws {
            if var updatedUser = currentUser {
                updatedUser.phoneNumber = newPhone
                try await saveProfile(updatedUser: updatedUser)
                try await dataProvider.saveUser(updatedUser)
            }
        }
    
    
    // MARK: - Privacy Settings Methods
        func updatePrivacySettings(
            shareWithFriends: Bool? = nil,
            shareWithHost: Bool? = nil,
            shareWithGroup: Bool? = nil,
            allowFriendsInvite: Bool? = nil
        ) async throws {
            guard var updatedUser = currentUser else { return }
            
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
            guard var updatedUser = currentUser else { return }
            
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
            // Fetch all users from data provider
            let allUsers = await dataProvider.fetchAllUsers()
            // Find the user with matching phone number
            return allUsers.first { $0.phoneNumber == phoneNumber }
        }
    
    
    func login(phoneNumber: String) async {
        print("Starting login process for phone: \(phoneNumber)")
        if let user = await self.dataProvider.fetchUser(byPhoneNumber: phoneNumber) {
            print("Existing user found, logging in")
            self.currentUser = user
            self.currentUserId = user.id  // Update currentUserId
            self.isLoggedIn = true
            self.persistUserSession()
            print("User logged in successfully")
        } else {
            print("No existing user found, creating new user")
            // Create new user with ONLY phone number initially to comply with Firestore rules
            let initialUser = User(
                id: UUID(),  // Generate a new UUID instead of using Firebase UID
                firstName: "",
                lastName: "",
                username: "",
                profileImageData: nil,
                isActive: false,
                friends: [],
                doNotDisturb: false,
                phoneNumber: phoneNumber,
                createdEventIds: [],
                attendingEventIds: [],
                joinDate: Date(),
                visitedLandmarkIds: [],
                receiveFriendRequests: true,  // Set defaults for notifications
                receiveFriendEvents: true,
                receiveEventUpdates: true,
                shareLocationWithFriends: false,
                shareLocationWithEventHost: false,
                shareLocationWithEventGroup: false,
                allowFriendsToInviteOthers: true
            )
            
            print("Created initial user object with ID: \(initialUser.id)")
            
            // First save with just phone number and ID
            Task {
                do {
                    print("Attempting to save initial user")
                    // Create minimal user object for initial save
                    let minimalUser = User(
                        id: initialUser.id,
                        firstName: "",
                        lastName: "",
                        username: "",
                        phoneNumber: phoneNumber,
                        joinDate: initialUser.joinDate
                    )
                    try await dataProvider.saveInitialUser(minimalUser)
                    print("Initial user saved successfully")
                    
                    // Set the current user to the minimal version
                    self.currentUser = minimalUser
                    self.currentUserId = minimalUser.id  // Update currentUserId
                    self.isLoggedIn = true
                    self.persistUserSession()
                    print("User session persisted with minimal data")
                    
                    // Full profile update will happen during onboarding
                } catch {
                    print("Error saving user: \(error.localizedDescription)")
                    print("Error details: \(String(describing: error))")
                }
            }
        }
    }

    func signup(phoneNumber: String) async {
        await login(phoneNumber: phoneNumber)
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
            // Only save if there's actually a change
            if currentUser != updatedUser {
                try await dataProvider.saveUser(updatedUser)
                self.currentUser = updatedUser
                self.persistUserSession()
            }
        }

    // MARK: - Logout
    func logout() {
        do {
            try Auth.auth().signOut()
            currentUser = nil
            currentUserId = nil  // Clear currentUserId
            isLoggedIn = false
            clearPersistedUserSession()
        } catch {
            print("Error signing out: \(error)")
        }
    }

    

    func toggleDoNotDisturb() async throws {
        guard var user = currentUser else { return }
        user.doNotDisturb.toggle()
        try await saveProfile(updatedUser: user)
    }

    // MARK: - User Actions

    func attendEvent(eventId: UUID) {
        guard var user = currentUser else { return }
        guard !user.attendingEventIds.contains(eventId) else { return }

        // Update user's attending events
        user.attendingEventIds.append(eventId)
        self.currentUser = user
        self.persistUserSession()
    }

    func leaveEvent(eventId: UUID) {
        guard var user = currentUser else { return }
        guard user.attendingEventIds.contains(eventId) else { return }

        // Remove from user's attending events
        if let index = user.attendingEventIds.firstIndex(of: eventId) {
            user.attendingEventIds.remove(at: index)
            self.currentUser = user
            self.persistUserSession()
        }
    }

    // MARK: - Friend Management
    public func sendFriendRequest(to userId: UUID) async throws {
        guard let currentUserId = currentUser?.id else { return }
        try await dataProvider.sendFriendRequest(from: currentUserId, to: userId)
    }
    
    public func acceptFriendRequest(requestId: String, fromUserId: UUID) async throws {
        guard let currentUserId = currentUser?.id else { return }
        try await dataProvider.acceptFriendRequest(requestId: requestId, userId: currentUserId, friendId: fromUserId)
        await refreshUserData()
    }
    
    public func rejectFriendRequest(requestId: String) async throws {
        try await dataProvider.rejectFriendRequest(requestId: requestId)
    }
    
    public func addFriend(_ friendId: UUID) async throws {
        guard let currentUserId = currentUser?.id else { return }
        try await dataProvider.addFriend(friendId, to: currentUserId)
        await refreshUserData()
    }
    
    public func removeFriend(_ friendId: UUID) async throws {
        guard let currentUserId = currentUser?.id else { return }
        try await dataProvider.removeFriend(friendId, from: currentUserId)
        await refreshUserData()
    }
    
    public func isFriend(_ userId: UUID) -> Bool {
        currentUser?.friends.contains(userId) ?? false
    }

    // MARK: - Stats Management
    func getUserStats(for userId: UUID) async -> UserStats? {
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
    func visitLandmark(_ landmarkId: UUID) async {
        guard let userId = currentUser?.id else { return }
        await dataProvider.markLandmarkVisited(userId: userId, landmarkId: landmarkId)
        await refreshUserData() // Refresh to get updated visitedLandmarkIds
    }
    
    func unvisitLandmark(_ landmarkId: UUID) async {
        guard let userId = currentUser?.id else { return }
        await dataProvider.unmarkLandmarkVisited(userId: userId, landmarkId: landmarkId)
        await refreshUserData() // Refresh to get updated visitedLandmarkIds
    }
    
    // MARK: - Location Management
    func updateLocation(_ location: CLLocationCoordinate2D) async {
        guard let userId = currentUser?.id else { return }
        do {
            try await dataProvider.updateUserLocation(userId: userId, location: location)
            if var updatedUser = currentUser {
                updatedUser.location = location
                self.currentUser = updatedUser
            }
        } catch {
            print("Error updating location: \(error)")
        }
    }
}

// MARK: - Preview Helper
extension UserManager {
    static var preview: UserManager {
        let manager = UserManager(dataProvider: MockDataProvider())
        return manager
    }
}
