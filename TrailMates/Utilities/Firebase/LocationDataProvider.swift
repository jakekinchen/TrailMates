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
        #if DEBUG
        print("LocationDataProvider initialized")
        #endif
    }

    // Note: LocationDataProvider is a singleton and should never be deallocated.
    // Cleanup is handled by removeAllListeners() called explicitly when needed.

    private func removeAllListeners() {
        activeListeners.forEach { path, handle in
            rtdb.child(path).removeObserver(withHandle: handle)
        }
        activeListeners.removeAll()
    }

    // MARK: - Location Update Operations

    func updateUserLocation(userId: String, location: CLLocationCoordinate2D) async throws {
        // 1. Verify the current user is updating their own location
        guard let currentUser = self.auth.currentUser else {
            throw AppError.notAuthenticated()
        }

        // 2. Ensure the userId matches the currentUser's UID
        guard userId == currentUser.uid else {
            throw AppError.unauthorized("Cannot update location for another user")
        }

        // 3. Get fresh ID token to ensure auth is valid
        let token = try await currentUser.getIDToken()

        #if DEBUG
        print("\nFirebase Location Debug:")
        print("1. Auth Check:")
        print("   - UID: \(currentUser.uid)")
        print("   - Token valid: \(token.prefix(10))...")
        print("   - Provider: \(currentUser.providerID)")
        print("   - Anonymous: \(currentUser.isAnonymous)")
        #endif

        // 4. Reference the user's location node in RTDB
        let locationRef = rtdb.child(FirestoreConstants.RTDBPaths.locations).child(currentUser.uid)
        #if DEBUG
        print("   - Path: \(locationRef.url)")
        #endif

        // 5. Verify database connection
        let connectedRef = rtdb.child(".info/connected")
        let isConnected = try await withCheckedThrowingContinuation { continuation in
            connectedRef.observeSingleEvent(of: .value) { snapshot in
                continuation.resume(returning: snapshot.value as? Bool ?? false)
            }
        }
        #if DEBUG
        print("2. Connection Check:")
        print("   - Connected: \(isConnected)")
        #endif

        // 6. Write location data to RTDB
        return try await withCheckedThrowingContinuation { continuation in
            let locationData: [String: Any] = [
                "latitude": location.latitude,
                "longitude": location.longitude,
                "timestamp": ServerValue.timestamp(),
                "lastUpdated": ServerValue.timestamp()
            ]

            #if DEBUG
            print("3. Data Validation:")
            print("   - Fields: \(locationData.keys.sorted().joined(separator: ", "))")
            print("   - Location: (\(location.latitude), \(location.longitude))")
            #endif

            locationRef.setValue(locationData) { error, _ in
                if let error = error {
                    #if DEBUG
                    print("4. Write Result: Failed")
                    print("   - Error: \(error.localizedDescription)")
                    #endif
                    continuation.resume(throwing: AppError.classify(error))
                } else {
                    #if DEBUG
                    print("4. Write Result: Success")
                    #endif
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Location Observation

    func observeUserLocation(userId: String, completion: @escaping @Sendable (CLLocationCoordinate2D?) -> Void) {
        // First get the Firebase UID for the target user
        Task {
            // Fetch the user document to get their Firebase UID
            if let userDoc = try? await db.collection(FirestoreConstants.Collections.users).document(userId).getDocument(),
               let id = userDoc.get("id") as? String {
                let path = "\(FirestoreConstants.RTDBPaths.locations)/\(id)"
                // Use userId (Firestore doc ID) as the listener key so
                // stopObservingUserLocation can find it without re-resolving.
                let listenerKey = "\(FirestoreConstants.RTDBPaths.locations)/\(userId)"

                // Remove existing listener if any
                if let existingHandle = activeListeners[listenerKey] {
                    rtdb.child(path).removeObserver(withHandle: existingHandle)
                    activeListeners.removeValue(forKey: listenerKey)
                }

                // Add new listener
                let handle = rtdb.child(path).observe(.value) { snapshot in
                    guard let locationData = snapshot.value as? [String: Any],
                          let latitude = locationData["latitude"] as? Double,
                          let longitude = locationData["longitude"] as? Double else {
                        Task { @MainActor in
                            completion(nil)
                        }
                        return
                    }

                    let location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    Task { @MainActor in
                        completion(location)
                    }
                }

                activeListeners[listenerKey] = handle
            } else {
                #if DEBUG
                print("LocationDataProvider: Could not find Firebase UID for user \(userId)")
                #endif
                completion(nil)
            }
        }
    }

    func stopObservingUserLocation(userId: String) {
        let path = "\(FirestoreConstants.RTDBPaths.locations)/\(userId)"
        if let handle = activeListeners[path] {
            rtdb.child(path).removeObserver(withHandle: handle)
            activeListeners.removeValue(forKey: path)
        }
    }

    func stopObservingAllLocations() {
        removeAllListeners()
    }

    /// Deletes a user's location data (used during account deletion)
    func deleteUserLocation(userId: String) async throws {
        let locationRef = rtdb.child(FirestoreConstants.RTDBPaths.locations).child(userId)

        return try await withCheckedThrowingContinuation { continuation in
            locationRef.removeValue { error, _ in
                if let error = error {
                    continuation.resume(throwing: AppError.classify(error))
                } else {
                    #if DEBUG
                    print("LocationDataProvider: Deleted location data for user \(userId)")
                    #endif
                    continuation.resume()
                }
            }
        }
    }
}
