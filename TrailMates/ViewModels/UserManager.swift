import SwiftUI
import Combine
import CoreLocation
import UIKit

@MainActor  // Ensure all UI updates happen on the main thread
class UserManager: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoggedIn = false
    @Published var isOnboardingComplete = false
    @Published var hasAddedFriends = false

    var isProfileComplete: Bool {
        guard let user = currentUser else { return false }
        return !user.firstName.isEmpty && !(user.bio?.isEmpty ?? true)
    }

    private let dataProvider: DataProvider
    private var cancellables = Set<AnyCancellable>()

    init(dataProvider: DataProvider = MockDataProvider()) {
        self.dataProvider = dataProvider
        Task { @MainActor in
            await checkPersistedUser()
        }
    }

    // MARK: - Async Login and Signup
    func login(phoneNumber: String) async {
        if let user = await self.dataProvider.fetchUser(byPhoneNumber: phoneNumber) {
            self.currentUser = user
            self.isLoggedIn = true
            self.persistUserSession()
        } else {
            let newUser = User(
                id: UUID(),
                firstName: "",
                lastName: "",
                bio: "",
                profileImageData: nil,
                location: nil,
                isActive: true,
                friends: [],
                doNotDisturb: false,
                phoneNumber: phoneNumber
            )
            self.currentUser = newUser
            self.isLoggedIn = true
            self.persistUserSession()
        }
    }

    func signup(phoneNumber: String) async {
        await login(phoneNumber: phoneNumber)
    }

    // MARK: - Fetch Data
    func fetchFriends(for user: User) async -> [User] {
        return await dataProvider.fetchFriends(for: user)
    }

    func fetchAllUsers() async -> [User] {
        return await dataProvider.fetchAllUsers()
    }

    // MARK: - Save Profile
    func saveProfile(user: User) async {
        await dataProvider.saveUser(user)
        self.currentUser = user
        self.persistUserSession()
    }

    // MARK: - Logout
    func logout() {
        currentUser = nil
        isLoggedIn = false
        clearPersistedUserSession()
    }

    // MARK: - Persist User Session
    func persistUserSession() {
        if let userData = try? JSONEncoder().encode(currentUser) {
            UserDefaults.standard.set(userData, forKey: "currentUser")
            UserDefaults.standard.set(isLoggedIn, forKey: "isLoggedIn")
            UserDefaults.standard.set(isOnboardingComplete, forKey: "isOnboardingComplete")
            UserDefaults.standard.set(hasAddedFriends, forKey: "hasAddedFriends")
        }
    }

    private func clearPersistedUserSession() {
        UserDefaults.standard.removeObject(forKey: "currentUser")
        UserDefaults.standard.removeObject(forKey: "isLoggedIn")
    }

    private func checkPersistedUser() async {
        if let userData = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            currentUser = user
            isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
            isOnboardingComplete = UserDefaults.standard.bool(forKey: "isOnboardingComplete")
            hasAddedFriends = UserDefaults.standard.bool(forKey: "hasAddedFriends")
        }
    }

    func refreshUserData() async {
        guard let phoneNumber = currentUser?.phoneNumber else { return }
        if let updatedUser = await dataProvider.fetchUser(byPhoneNumber: phoneNumber) {
            currentUser = updatedUser
        }
    }

    func updateUserLocation(_ location: CLLocationCoordinate2D) async {
        guard var updatedUser = currentUser else { return }
        updatedUser.location = location
        await saveProfile(user: updatedUser)
    }

    func toggleDoNotDisturb() async {
        guard var updatedUser = currentUser else { return }
        updatedUser.doNotDisturb.toggle()
        await saveProfile(user: updatedUser)
    }
}
