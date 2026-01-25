import Foundation
import Firebase
import FirebaseStorage
import SwiftUI

/// Handles all image storage operations for Firebase
/// Extracted from FirebaseDataProvider as part of the provider refactoring
class ImageStorageProvider {
    // MARK: - Singleton
    static let shared = ImageStorageProvider()

    // MARK: - Dependencies
    private lazy var storage = Storage.storage()
    private let imageCache = NSCache<NSString, UIImage>()

    private init() {
        // Configure cache limits
        imageCache.countLimit = 100 // Maximum number of images
        imageCache.totalCostLimit = 50 * 1024 * 1024 // 50MB limit

        print("ImageStorageProvider initialized")
    }

    // MARK: - Profile Image Upload

    func uploadProfileImage(_ image: UIImage, for userId: String) async throws -> (fullUrl: String, thumbnailUrl: String) {
        // Delete old images first
        await deleteOldProfileImage(for: userId)

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw FirebaseDataProvider.ValidationError.invalidData("Failed to convert image to data")
        }

        let fullSizeRef = storage.reference(withPath: "profile_images/\(userId)/full.jpg")
        let thumbnailRef = storage.reference(withPath: "profile_images/\(userId)/thumbnail.jpg")

        // Create metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        // Upload full size image
        _ = try await fullSizeRef.putDataAsync(imageData, metadata: metadata)
        let fullUrl = try await fullSizeRef.downloadURL().absoluteString

        // Create and upload thumbnail
        let thumbnailSize = CGSize(width: 150, height: 150)
        guard let thumbnailImage = image.preparingThumbnail(of: thumbnailSize),
              let thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.8) else {
            throw FirebaseDataProvider.ValidationError.invalidData("Failed to create thumbnail")
        }

        _ = try await thumbnailRef.putDataAsync(thumbnailData, metadata: metadata)
        let thumbnailUrl = try await thumbnailRef.downloadURL().absoluteString

        return (fullUrl: fullUrl, thumbnailUrl: thumbnailUrl)
    }

    // MARK: - Profile Image Delete

    func deleteOldProfileImage(for userId: String) async {
        let profileImagesRef = storage.reference(withPath: "profile_images/\(userId)")

        do {
            let result = try await profileImagesRef.listAll()

            // Delete all existing profile images for this user
            for item in result.items {
                try? await item.delete()
            }
        } catch {
            print("ImageStorageProvider: Error deleting old profile images: \(error.localizedDescription)")
            // We don't throw here as this is a cleanup operation
            // and shouldn't prevent the new upload from proceeding
        }
    }

    // MARK: - Profile Image Download

    func downloadProfileImage(from url: String) async throws -> UIImage {
        // Check cache first
        if let cachedImage = imageCache.object(forKey: url as NSString) {
            return cachedImage
        }

        // Download if not in cache
        guard let imageUrl = URL(string: url) else {
            throw FirebaseDataProvider.ValidationError.invalidUrl("Invalid image URL")
        }

        let (data, _) = try await URLSession.shared.data(from: imageUrl)
        guard let image = UIImage(data: data) else {
            throw FirebaseDataProvider.ValidationError.failedToDownloadImage("Invalid image data")
        }

        // Cache the downloaded image
        imageCache.setObject(image, forKey: url as NSString)
        return image
    }

    // MARK: - Prefetch

    func prefetchProfileImages(urls: [String]) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask {
                    _ = try? await self.downloadProfileImage(from: url)
                }
            }
        }
    }

    // MARK: - Cache Management

    func clearCache() {
        imageCache.removeAllObjects()
    }

    func removeFromCache(url: String) {
        imageCache.removeObject(forKey: url as NSString)
    }
}
