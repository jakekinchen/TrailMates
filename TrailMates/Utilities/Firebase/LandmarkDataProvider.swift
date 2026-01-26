import Foundation
import Firebase
import FirebaseFirestore

/// Handles all landmark-related Firebase operations
/// Extracted from FirebaseDataProvider as part of the provider refactoring
@MainActor
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
            // Use retry logic for network fetch
            let snapshot = try await withRetry(maxAttempts: 3) {
                try await self.db.collection("landmarks").getDocuments()
            }
            return snapshot.documents.count
        } catch {
            let appError = AppError.from(error)
            #if DEBUG
            print("LandmarkDataProvider: Error fetching total landmarks: \(appError.errorDescription ?? "Unknown")")
            #endif
            return 0
        }
    }

    func fetchAllLandmarks() async -> [Landmark] {
        do {
            // Use retry logic for network fetch
            let snapshot = try await withRetry(maxAttempts: 3) {
                try await self.db.collection("landmarks").getDocuments()
            }
            return snapshot.documents.compactMap { try? $0.data(as: Landmark.self) }
        } catch {
            let appError = AppError.from(error)
            #if DEBUG
            print("LandmarkDataProvider: Error fetching all landmarks: \(appError.errorDescription ?? "Unknown")")
            #endif
            return []
        }
    }

    func fetchLandmark(by id: String) async -> Landmark? {
        do {
            // Use retry logic for network fetch
            let document = try await withRetry(maxAttempts: 3) {
                try await self.db.collection("landmarks").document(id).getDocument()
            }
            return try document.data(as: Landmark.self)
        } catch {
            let appError = AppError.from(error)
            #if DEBUG
            print("LandmarkDataProvider: Error fetching landmark: \(appError.errorDescription ?? "Unknown")")
            #endif
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
            let appError = AppError.from(error)
            #if DEBUG
            print("LandmarkDataProvider: Error marking landmark as visited: \(appError.errorDescription ?? "Unknown")")
            #endif
        }
    }

    func unmarkLandmarkVisited(userId: String, landmarkId: String) async {
        do {
            let userRef = db.collection("users").document(userId)
            try await userRef.updateData([
                "visitedLandmarkIds": FieldValue.arrayRemove([landmarkId])
            ])
        } catch {
            let appError = AppError.from(error)
            #if DEBUG
            print("LandmarkDataProvider: Error unmarking landmark as visited: \(appError.errorDescription ?? "Unknown")")
            #endif
        }
    }

    /// Fetch landmarks visited by a specific user
    func fetchVisitedLandmarks(for userId: String) async -> [String] {
        do {
            // Use retry logic for network fetch
            let document = try await withRetry(maxAttempts: 3) {
                try await self.db.collection("users").document(userId).getDocument()
            }
            return document.get("visitedLandmarkIds") as? [String] ?? []
        } catch {
            let appError = AppError.from(error)
            #if DEBUG
            print("LandmarkDataProvider: Error fetching visited landmarks: \(appError.errorDescription ?? "Unknown")")
            #endif
            return []
        }
    }
}
