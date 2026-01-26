import Foundation
import Firebase
import FirebaseStorage
import SwiftUI

/// Handles all image storage operations for Firebase Storage.
///
/// This provider manages profile image upload, download, and caching.
/// It automatically creates thumbnails for efficient display in lists.
///
/// ## Features
/// - Automatic thumbnail generation (150x150)
/// - In-memory caching with configurable limits
/// - Retry logic for failed downloads
/// - Old image cleanup before new uploads
///
/// ## Usage
/// ```swift
/// // Upload a profile image
/// let urls = try await ImageStorageProvider.shared.uploadProfileImage(image, for: userId)
///
/// // Download with automatic caching
/// let image = try await ImageStorageProvider.shared.downloadProfileImage(from: url)
/// ```
@MainActor
class ImageStorageProvider {
    // MARK: - Singleton
    static let shared = ImageStorageProvider()

    // MARK: - Dependencies
    private lazy var storage = Storage.storage()

    /// In-memory cache for downloaded images to reduce network requests
    private let imageCache = NSCache<NSString, UIImage>()

    private init() {
        // Configure cache limits to balance memory usage and performance
        imageCache.countLimit = 100 // Maximum 100 images
        imageCache.totalCostLimit = 50 * 1024 * 1024 // 50MB memory limit

        print("ImageStorageProvider initialized")
    }

    // MARK: - Profile Image Upload

    /// Uploads a profile image to Firebase Storage.
    ///
    /// This method:
    /// 1. Deletes any existing profile images for the user
    /// 2. Uploads the full-size image (80% JPEG quality)
    /// 3. Creates and uploads a 150x150 thumbnail
    ///
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - userId: The user's unique identifier
    /// - Returns: Tuple containing URLs for full-size and thumbnail images
    /// - Throws: `AppError.imageProcessingFailed` if image conversion fails
    func uploadProfileImage(_ image: UIImage, for userId: String) async throws -> (fullUrl: String, thumbnailUrl: String) {
        // Delete old images first to prevent orphaned files
        await deleteOldProfileImage(for: userId)

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw AppError.imageProcessingFailed("Failed to convert image to JPEG data")
        }

        let fullSizeRef = storage.reference(withPath: "profile_images/\(userId)/full.jpg")
        let thumbnailRef = storage.reference(withPath: "profile_images/\(userId)/thumbnail.jpg")

        // Create metadata for proper content type handling
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        // Upload full size image with retry logic
        _ = try await withRetry(maxAttempts: 2) {
            try await fullSizeRef.putDataAsync(imageData, metadata: metadata)
        }
        let fullUrl = try await fullSizeRef.downloadURL().absoluteString

        // Create thumbnail (150x150) for efficient list displays
        let thumbnailSize = CGSize(width: 150, height: 150)
        guard let thumbnailImage = image.preparingThumbnail(of: thumbnailSize),
              let thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.8) else {
            throw AppError.imageProcessingFailed("Failed to create thumbnail image")
        }

        // Upload thumbnail with retry logic
        _ = try await withRetry(maxAttempts: 2) {
            try await thumbnailRef.putDataAsync(thumbnailData, metadata: metadata)
        }
        let thumbnailUrl = try await thumbnailRef.downloadURL().absoluteString

        return (fullUrl: fullUrl, thumbnailUrl: thumbnailUrl)
    }

    // MARK: - Profile Image Delete

    /// Deletes all existing profile images for a user.
    ///
    /// This is called automatically before uploading a new profile image
    /// to prevent orphaned files in storage. Errors are logged but not thrown
    /// since this is a cleanup operation that shouldn't block new uploads.
    ///
    /// - Parameter userId: The user's unique identifier
    func deleteOldProfileImage(for userId: String) async {
        let profileImagesRef = storage.reference(withPath: "profile_images/\(userId)")

        do {
            let result = try await profileImagesRef.listAll()

            // Delete all existing profile images for this user
            for item in result.items {
                try? await item.delete()
            }
        } catch {
            // Log but don't throw - cleanup failures shouldn't block new uploads
            #if DEBUG
            print("ImageStorageProvider: Error deleting old profile images: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Profile Image Download

    /// Downloads a profile image from a URL with caching and retry support.
    ///
    /// Images are cached in memory after download to reduce network requests
    /// for frequently accessed images (e.g., in friend lists).
    ///
    /// - Parameter url: The image URL to download from
    /// - Returns: The downloaded UIImage
    /// - Throws: `AppError.invalidImageUrl` or `AppError.imageDownloadFailed`
    func downloadProfileImage(from url: String) async throws -> UIImage {
        // Check cache first to avoid unnecessary network requests
        if let cachedImage = imageCache.object(forKey: url as NSString) {
            return cachedImage
        }

        // Validate URL format
        guard let imageUrl = URL(string: url) else {
            throw AppError.invalidImageUrl("Invalid image URL format: \(url)")
        }

        // Download with retry logic for transient network failures
        let image: UIImage = try await withRetry(maxAttempts: 3, initialDelay: 0.5) {
            let (data, response) = try await URLSession.shared.data(from: imageUrl)

            // Verify we got a successful HTTP response
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                throw AppError.imageDownloadFailed("Server returned status \(httpResponse.statusCode)")
            }

            guard let downloadedImage = UIImage(data: data) else {
                throw AppError.imageDownloadFailed("Invalid image data received")
            }

            return downloadedImage
        }

        // Cache the downloaded image for future requests
        imageCache.setObject(image, forKey: url as NSString)
        return image
    }

    // MARK: - Prefetch

    /// Prefetches multiple profile images in parallel for smoother scrolling.
    ///
    /// Use this when loading a list of users to warm the cache before
    /// the images are needed for display.
    ///
    /// - Parameter urls: Array of image URLs to prefetch
    func prefetchProfileImages(urls: [String]) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask {
                    // Silently ignore failures during prefetch
                    _ = try? await self.downloadProfileImage(from: url)
                }
            }
        }
    }

    // MARK: - Cache Management

    /// Clears all cached images from memory.
    ///
    /// Call this in response to memory warnings or when the user logs out.
    func clearCache() {
        imageCache.removeAllObjects()
    }

    /// Removes a specific image from the cache.
    ///
    /// Use this when an image has been updated and the cached version is stale.
    ///
    /// - Parameter url: The URL of the image to remove from cache
    func removeFromCache(url: String) {
        imageCache.removeObject(forKey: url as NSString)
    }
}
