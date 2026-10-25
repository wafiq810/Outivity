import Foundation
import UIKit
import SwiftData

/// A lightweight, in-memory stand-in for `ActivityPhoto` used for demo mode.
///
/// We implement the subset of API the gallery uses (`id`, `createdAt`, `tracker`, `getPreviewImage()`).
/// Supports both asset-based bundled demo photos and judge-captured photos.
final class DemoActivityPhoto: ActivityPhoto {
    private let assetName: String?
    private let capturedImageData: Data?
    private let capturedThumbnailData: Data?
    
    // Override the tracker property to avoid SwiftData relationship issues
    private var _tracker: ActivityTracker?
    override var tracker: ActivityTracker? {
        get { _tracker }
        set { _tracker = newValue }
    }

    /// Initializer for asset-based demo photos (bundled images).
    init(assetName: String, createdAt: Date) {
        self.assetName = assetName
        self.capturedImageData = nil
        self.capturedThumbnailData = nil
        
        super.init(
            goalID: nil,
            goalTitle: nil,
            thumbnailData: nil,
            fullImageData: nil,
            contentType: "image/asset",
            width: nil,
            height: nil,
            isFromCamera: false,
            tracker: nil
        )

        // Override identity + timestamp to be stable/deterministic.
        self.id = DemoModePhotos.uuid(forAssetName: assetName)
        self.createdAt = createdAt
    }

    /// Initializer for captured photos in demo mode.
    init(
        imageData: Data,
        thumbnailData: Data,
        goalID: UUID?,
        goalTitle: String?,
        createdAt: Date,
        tracker: ActivityTracker?
    ) {
        self.assetName = nil
        self.capturedImageData = imageData
        self.capturedThumbnailData = thumbnailData
        
        super.init(
            goalID: goalID,
            goalTitle: goalTitle,
            thumbnailData: thumbnailData,
            fullImageData: imageData,
            contentType: "image/jpeg",
            width: nil,
            height: nil,
            isFromCamera: true,
            tracker: nil // Don't pass tracker to super.init to avoid SwiftData issues
        )

        // Use a random UUID for captured photos
        self.id = UUID()
        self.createdAt = createdAt
        // Set tracker directly to our private property
        self._tracker = tracker
    }

    /// Required by SwiftData's `@Model` macro.
    ///
    /// This path shouldn't be hit because demo photos aren't loaded from SwiftData,
    /// but we must provide it to satisfy the compiler.
    required init(backingData: any BackingData<ActivityPhoto>) {
        // Give a placeholder name; callers should not rely on this initializer.
        self.assetName = ""
        self.capturedImageData = nil
        self.capturedThumbnailData = nil
        self._tracker = nil
        super.init(backingData: backingData)
    }

    override func getImage() -> UIImage? {
        if let assetName = assetName {
            return UIImage(named: assetName)
        } else if let capturedImageData = capturedImageData {
            return UIImage(data: capturedImageData)
        }
        return nil
    }

    override func getPreviewImage() -> UIImage? {
        if let assetName = assetName {
            // Asset-based photos use square thumbnails for consistency
            // Since we can't rely on the @MainActor cache from this context,
            // we'll create a simple square thumbnail directly
            guard let original = UIImage(named: assetName) else { return nil }
            
            // Create a simple square crop for preview
            let size = original.size
            let minDimension = min(size.width, size.height)
            let cropRect = CGRect(
                x: (size.width - minDimension) / 2,
                y: (size.height - minDimension) / 2,
                width: minDimension,
                height: minDimension
            )
            
            guard let cgImage = original.cgImage?.cropping(to: cropRect) else { return original }
            let croppedImage = UIImage(cgImage: cgImage, scale: original.scale, orientation: original.imageOrientation)
            
            // Scale down to preview size
            let targetSize = CGSize(width: 300, height: 300)
            return croppedImage.preparingThumbnail(of: targetSize) ?? croppedImage
        } else if let capturedThumbnailData = capturedThumbnailData {
            return UIImage(data: capturedThumbnailData)
        }
        return getImage()
    }

    /// Get the photo attribution text for demo photos from bundled assets.
    /// Returns nil for captured photos or if no asset name is available.
    func getAttribution() -> String? {
        guard let assetName = assetName else { return nil }
        
        // Map asset names to photographer attributions
        switch assetName {
        case "bennie-bates-V1-Hv3GKMMo-unsplash":
            return "Photo by Bennie Bates on Unsplash"
        case "charles-black-F7HGqkkMYAU-unsplash":
            return "Photo by Charles Black on Unsplash"
        case "dmitrii-shirnin-mqEKg5D6lnE-unsplash":
            return "Photo by Dmitrii Shirnin on Unsplash"
        case "kate-kasiutich-xnWP566J7gI-unsplash":
            return "Photo by Kate Kasiutich on Unsplash"
        case "kellen-riggin-XiDOrT2-Wys-unsplash":
            return "Photo by Kellen Riggin on Unsplash"
        case "michael-held-uRo6k_uw1KU-unsplash":
            return "Photo by Michael Held on Unsplash"
        case "raelle-cameron-RTSq4EOBld8-unsplash":
            return "Photo by Raelle Cameron on Unsplash"
        default:
            return nil
        }
    }
}
