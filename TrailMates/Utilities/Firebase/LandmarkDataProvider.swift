import Foundation
import Firebase
import FirebaseFirestore

/// Handles all landmark-related Firebase operations
/// Extracted from FirebaseDataProvider as part of the provider refactoring
class LandmarkDataProvider {
    // MARK: - Singleton
    static let shared = LandmarkDataProvider()

    // MARK: - Dependencies
    private lazy var db = Firestore.firestore()

    private init() {
        // Configure Firestore settings if not already configured
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings()
        db.settings = settings

        print("LandmarkDataProvider initialized")
    }

    // MARK: - Landmark Query Operations

    func fetchTotalLandmarks() async -> Int {
        do {
            let snapshot = try await db.collection("landmarks").getDocuments()
            return snapshot.documents.count
        } catch {
            print("LandmarkDataProvider: Error fetching total landmarks: \(error)")
            return 0
        }
    }

    func fetchAllLandmarks() async -> [Landmark] {
        do {
            let snapshot = try await db.collection("landmarks").getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: Landmark.self) }
        } catch {
            print("LandmarkDataProvider: Error fetching all landmarks: \(error)")
            return []
        }
    }

    func fetchLandmark(by id: String) async -> Landmark? {
        do {
            let document = try await db.collection("landmarks").document(id).getDocument()
            return try document.data(as: Landmark.self)
        } catch {
            print("LandmarkDataProvider: Error fetching landmark: \(error)")
            return nil
        }
    }

    // MARK: - User Landmark Operations

    func markLandmarkVisited(userId: String, landmarkId: String) async {
        do {
            let userRef = db.collection("users").document(userId)
            try await userRef.updateData([
                "visitedLandmarkIds": FieldValue.arrayUnion([landmarkId])
            ])
        } catch {
            print("LandmarkDataProvider: Error marking landmark as visited: \(error)")
        }
    }

    func unmarkLandmarkVisited(userId: String, landmarkId: String) async {
        do {
            let userRef = db.collection("users").document(userId)
            try await userRef.updateData([
                "visitedLandmarkIds": FieldValue.arrayRemove([landmarkId])
            ])
        } catch {
            print("LandmarkDataProvider: Error unmarking landmark as visited: \(error)")
        }
    }

    /// Fetch landmarks visited by a specific user
    func fetchVisitedLandmarks(for userId: String) async -> [String] {
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            return document.get("visitedLandmarkIds") as? [String] ?? []
        } catch {
            print("LandmarkDataProvider: Error fetching visited landmarks: \(error)")
            return []
        }
    }
}
