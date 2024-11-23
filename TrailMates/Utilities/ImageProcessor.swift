import UIKit

enum ImageProcessingError: Error {
    case invalidImage
    case compressionFailed
    case imageTooLarge(size: Int)
    case dimensionsTooLarge(width: Int, height: Int)
}

struct ImageProcessor {
    // Constants
    static let maxFileSizeBytes: Int = 2 * 1024 * 1024  // 2MB
    static let maxDimension: CGFloat = 1200  // Max width/height
    static let thumbnailDimension: CGFloat = 200  // Thumbnail size
    static let compressionQuality: CGFloat = 0.8
    
    static func processProfileImage(_ image: UIImage) throws -> (full: Data, thumbnail: Data) {
        // 1. Resize image while maintaining aspect ratio
        let resizedImage = resizeImage(image, maxDimension: maxDimension)
        let thumbnailImage = resizeImage(image, maxDimension: thumbnailDimension)
        
        // 2. Compress images
        guard let fullData = resizedImage.jpegData(compressionQuality: compressionQuality),
              let thumbnailData = thumbnailImage.jpegData(compressionQuality: compressionQuality) else {
            throw ImageProcessingError.compressionFailed
        }
        
        // 3. Check size constraints
        if fullData.count > maxFileSizeBytes {
            throw ImageProcessingError.imageTooLarge(size: fullData.count)
        }
        
        return (full: fullData, thumbnail: thumbnailData)
    }
    
    private static func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let originalSize = image.size
        var newSize = originalSize
        
        // Calculate new size while maintaining aspect ratio
        if originalSize.width > maxDimension || originalSize.height > maxDimension {
            let widthRatio = maxDimension / originalSize.width
            let heightRatio = maxDimension / originalSize.height
            let ratio = min(widthRatio, heightRatio)
            
            newSize = CGSize(width: originalSize.width * ratio,
                           height: originalSize.height * ratio)
        }
        
        // Create resized image
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    static func validateImage(_ image: UIImage) throws {
        // Check dimensions
        if image.size.width > maxDimension * 2 || image.size.height > maxDimension * 2 {
            throw ImageProcessingError.dimensionsTooLarge(
                width: Int(image.size.width),
                height: Int(image.size.height)
            )
        }
    }
}
