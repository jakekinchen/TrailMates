import SwiftUI
import Combine

class UserManager: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoggedIn = false
    @Published var isProfileComplete = false
    
    private var dataProvider: MockDataProvider
    private var cancellables = Set<AnyCancellable>()
    
    init(dataProvider: MockDataProvider = MockDataProvider()) {
        self.dataProvider = dataProvider
        checkPersistedUser()
    }
    
    func login(phoneNumber: String) {
        // Simulating an asynchronous login process
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self = self else { return }
            
            if let user = self.dataProvider.fetchUser(byPhoneNumber: phoneNumber) {
                self.currentUser = user
                self.isLoggedIn = true
                self.isProfileComplete = true
                self.persistUserSession()
            } else {
                // User not found, create a new user
                let newUser = User(id: UUID(), firstName: "", lastName: "", profileImageName: "defaultProfilePic", bio: "", location: nil, isActive: true, friends: [], doNotDisturb: false, phoneNumber: phoneNumber)
                self.currentUser = newUser
                self.isLoggedIn = true
                self.isProfileComplete = false
                self.persistUserSession()
            }
        }
    }
    
    func signup(phoneNumber: String) {
        // For this implementation, signup is the same as login
        login(phoneNumber: phoneNumber)
    }
    
    func saveProfile(user: User) {
        dataProvider.saveUser(user)
        self.currentUser = user
        self.isProfileComplete = true
        self.persistUserSession()
    }
    
    func logout() {
        currentUser = nil
        isLoggedIn = false
        isProfileComplete = false
        clearPersistedUserSession()
    }
    
    private func persistUserSession() {
        // Persist user session data to UserDefaults
        if let userData = try? JSONEncoder().encode(currentUser) {
            UserDefaults.standard.set(userData, forKey: "currentUser")
            UserDefaults.standard.set(isLoggedIn, forKey: "isLoggedIn")
            UserDefaults.standard.set(isProfileComplete, forKey: "isProfileComplete")
        }
    }
    
    private func clearPersistedUserSession() {
        UserDefaults.standard.removeObject(forKey: "currentUser")
        UserDefaults.standard.removeObject(forKey: "isLoggedIn")
        UserDefaults.standard.removeObject(forKey: "isProfileComplete")
    }
    
    private func checkPersistedUser() {
        if let userData = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            currentUser = user
            isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
            isProfileComplete = UserDefaults.standard.bool(forKey: "isProfileComplete")
        }
    }
    
    func refreshUserData() {
        guard let phoneNumber = currentUser?.phoneNumber else { return }
        if let updatedUser = dataProvider.fetchUser(byPhoneNumber: phoneNumber) {
            currentUser = updatedUser
            isProfileComplete = true
        }
    }
    
    func updateUserLocation(_ location: CLLocationCoordinate2D) {
        guard var updatedUser = currentUser else { return }
        updatedUser.location = location
        saveProfile(user: updatedUser)
    }
    
    func toggleDoNotDisturb() {
        guard var updatedUser = currentUser else { return }
        updatedUser.doNotDisturb.toggle()
        saveProfile(user: updatedUser)
    }
}