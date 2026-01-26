import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseDatabase
import CoreLocation

/// Handles all location-related Firebase operations
/// Extracted from FirebaseDataProvider as part of the provider refactoring
@MainActor
class LocationDataProvider {
    // MARK: - Singleton
    static let shared = LocationDataProvider()

    // MARK: - Dependencies
    private lazy var db = Firestore.firestore()
    private lazy var rtdb = Database.database().reference()
    private lazy var auth = Auth.auth()

    // Store active listeners
    private var activeListeners: [String: DatabaseHandle] = [:]

    private init() {
        print("LocationDataProvider initialized")
    }

    deinit {
        // Clean up all active listeners
        // Use Task to call MainActor-isolated method from nonisolated deinit context
        Task { @MainActor [weak self] in
            self?.removeAllListeners()
        }
    }

    private func removeAllListeners() {
        activeListeners.forEach { path, handle in
            rtdb.child(path).removeObserver(withHandle: handle)
        }
        activeListeners.removeAll()
    }

    // MARK: - Location Update Operations

    func updateUserLocation(userId: String, location: CLLocationCoordinate2D) async throws {
        // 1. Verify the current user is updating their own location
        guard let currentUser = Auth.auth().currentUser else {
            throw AppError.notAuthenticated()
        }

        // 2. Ensure the userId matches the currentUser's UID
        guard userId == currentUser.uid else {
            throw AppError.unauthorized("Cannot update location for another user")
        }

        // 3. Get fresh ID token to ensure auth is valid
        let token = try await currentUser.getIDToken()

        print("\nFirebase Location Debug:")
        print("1. Auth Check:")
        print("   - UID: \(currentUser.uid)")
        print("   - Token valid: \(token.prefix(10))...")
        print("   - Provider: \(currentUser.providerID)")
        print("   - Anonymous: \(currentUser.isAnonymous)")

        // 4. Reference the user's location node in RTDB
        let locationRef = rtdb.child("locations").child(currentUser.uid)
        print("   - Path: \(locationRef.url)")

        // 5. Verify database connection
        let connectedRef = rtdb.child(".info/connected")
        let isConnected = try await withCheckedThrowingContinuation { continuation in
            connectedRef.observeSingleEvent(of: .value) { snapshot in
                continuation.resume(returning: snapshot.value as? Bool ?? false)
            }
        }
        print("2. Connection Check:")
        print("   - Connected: \(isConnected)")

        // 6. Write location data to RTDB
        return try await withCheckedThrowingContinuation { continuation in
            let locationData: [String: Any] = [
                "latitude": location.latitude,
                "longitude": location.longitude,
                "timestamp": ServerValue.timestamp(),
                "lastUpdated": ServerValue.timestamp()
            ]

            print("3. Data Validation:")
            print("   - Fields: \(locationData.keys.sorted().joined(separator: ", "))")
            print("   - Location: (\(location.latitude), \(location.longitude))")

            locationRef.setValue(locationData) { error, _ in
                if let error = error {
                    print("4. Write Result: Failed")
                    print("   - Error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    print("4. Write Result: Success")
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Location Observation

    func observeUserLocation(userId: String, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        // First get the Firebase UID for the target user
        Task {
            // Fetch the user document to get their Firebase UID
            if let userDoc = try? await db.collection("users").document(userId).getDocument(),
               let id = userDoc.get("id") as? String {
                let path = "locations/\(id)"

                // Remove existing listener if any
                if let existingHandle = activeListeners[path] {
                    rtdb.child(path).removeObserver(withHandle: existingHandle)
                    activeListeners.removeValue(forKey: path)
                }

                // Add new listener
                let handle = rtdb.child(path).observe(.value) { snapshot in
                    guard let locationData = snapshot.value as? [String: Any],
                          let latitude = locationData["latitude"] as? Double,
                          let longitude = locationData["longitude"] as? Double else {
                        completion(nil)
                        return
                    }

                    let location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    completion(location)
                }

                activeListeners[path] = handle
            } else {
                #if DEBUG
                print("LocationDataProvider: Could not find Firebase UID for user \(userId)")
                #endif
                completion(nil)
            }
        }
    }

    func stopObservingUserLocation(userId: String) {
        let path = "locations/\(userId)"
        if let handle = activeListeners[path] {
            rtdb.child(path).removeObserver(withHandle: handle)
            activeListeners.removeValue(forKey: path)
        }
    }

    func stopObservingAllLocations() {
        removeAllListeners()
    }
}
