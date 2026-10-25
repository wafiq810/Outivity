import Foundation
import UIKit

/// Central place for demo-mode content.
///
/// We keep this lightweight and purely in-memory. Nothing is persisted.
enum DemoModePhotos {
    /// Asset catalog image names (image set names).
    /// Keep these stable so demo-mode IDs can be deterministic.
    static let assetNames: [String] = [
        "bennie-bates-V1-Hv3GKMMo-unsplash",
        "charles-black-F7HGqkkMYAU-unsplash",
        "dmitrii-shirnin-mqEKg5D6lnE-unsplash",
        "kate-kasiutich-xnWP566J7gI-unsplash",
        "kellen-riggin-XiDOrT2-Wys-unsplash",
        "michael-held-uRo6k_uw1KU-unsplash",
        "raelle-cameron-RTSq4EOBld8-unsplash"
    ]

    /// Returns only assets that actually exist in the current build.
    static func availableAssetNames() -> [String] {
        assetNames.filter { UIImage(named: $0) != nil }
    }

    /// Deterministic UUID for a given asset name.
    ///
    /// This keeps SwiftUI identity stable for hero animations and scrolling.
    static func uuid(forAssetName name: String) -> UUID {
        // Simple stable hash -> UUID bytes.
        // Not cryptographic; just deterministic.
        var hasher = Hasher()
        hasher.combine("Outivity.DemoModePhotos")
        hasher.combine(name)
        let value = hasher.finalize()

        // Expand Int -> 16 bytes by repeating.
        var bytes = [UInt8](repeating: 0, count: 16)
        for i in 0..<16 {
            bytes[i] = UInt8(truncatingIfNeeded: (value >> ((i % 8) * 8)))
        }
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    // MARK: - Thumbnails

    /// Small container for a precomputed demo thumbnail.
    struct Thumbnail: Identifiable, Hashable {
        let assetName: String
        let side: CGFloat
        let image: UIImage

        var id: String { "\(assetName)|\(Int(side))" }
    }

    /// In-memory store of square-cropped thumbnails.
    ///
    /// Requirement: keep an array of cropped versions of the original demo images as thumbnails.
    @MainActor private(set) static var thumbnails: [Thumbnail] = []

    /// Fast lookup into `thumbnails`.
    ///
    /// Key: "assetName|side" -> index in `thumbnails`.
    @MainActor private static var thumbnailIndexByKey: [String: Int] = [:]

    @MainActor private static func key(assetName: String, side: CGFloat) -> String {
        "\(assetName)|\(Int(side.rounded()))"
    }

    /// Returns a cached square thumbnail for a given asset, generating + caching if needed.
    @MainActor static func thumbnail(forAssetName name: String, side: CGFloat = 300) -> UIImage? {
        let key = key(assetName: name, side: side)
        if let idx = thumbnailIndexByKey[key], thumbnails.indices.contains(idx) {
            return thumbnails[idx].image
        }

        guard let original = UIImage(named: name) else { return nil }
        guard let square = original.demoSquareCroppedThumbnail(side: side) else { return nil }

        thumbnails.append(Thumbnail(assetName: name, side: side, image: square))
        thumbnailIndexByKey[key] = thumbnails.count - 1
        return square
    }

    /// Precomputes thumbnails for all available demo assets.
    ///
    /// Handy to call during demo-mode boot so the first gallery render doesn't do work.
    @MainActor static func warmThumbnailCache(side: CGFloat = 300) {
        for name in availableAssetNames() {
            _ = thumbnail(forAssetName: name, side: side)
        }
    }

    /// Clears the in-memory thumbnail cache.
    ///
    /// Useful in debug builds if you want to validate regeneration.
    @MainActor static func clearThumbnailCache() {
        thumbnails.removeAll(keepingCapacity: false)
        thumbnailIndexByKey.removeAll(keepingCapacity: false)
    }

    // MARK: - Captured Photos Storage

    /// In-memory store for judge-captured photos in demo mode.
    @MainActor private(set) static var capturedPhotos: [DemoActivityPhoto] = []

    /// Add a judge-captured photo to the demo mode collection.
    @MainActor static func addCapturedPhoto(
        imageData: Data,
        thumbnailData: Data,
        goalID: UUID?,
        goalTitle: String?,
        tracker: ActivityTracker?
    ) {
        let photo = DemoActivityPhoto(
            imageData: imageData,
            thumbnailData: thumbnailData,
            goalID: goalID,
            goalTitle: goalTitle,
            createdAt: Date(),
            tracker: tracker
        )
        capturedPhotos.append(photo)
    }

    /// Get all captured photos for demo mode (most recent first).
    @MainActor static func getAllCapturedPhotos() -> [DemoActivityPhoto] {
        return capturedPhotos.sorted { $0.createdAt > $1.createdAt }
    }

    /// Clear all captured photos (useful for demo reset).
    @MainActor static func clearCapturedPhotos() {
        capturedPhotos.removeAll()
    }
}

private extension UIImage {
    /// Creates an orientation-safe square, center-cropped thumbnail.
    func demoSquareCroppedThumbnail(side: CGFloat) -> UIImage? {
        // Normalize orientation first so cropping is predictable.
        let normalized = normalizedOrientation() ?? self

        let w = normalized.size.width
        let h = normalized.size.height
        guard w > 0, h > 0 else { return nil }

        let s = min(w, h)
        let origin = CGPoint(x: (w - s) / 2, y: (h - s) / 2)
        let cropRect = CGRect(origin: origin, size: CGSize(width: s, height: s))

        // If we can crop via CGImage, do that, then thumbnail.
        if let cg = normalized.cgImage?.cropping(to: cropRect) {
            let cropped = UIImage(cgImage: cg, scale: normalized.scale, orientation: .up)
            return cropped.preparingThumbnail(of: CGSize(width: side, height: side)) ?? cropped
        }

        // Fallback: draw into a square context (still center-cropped).
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = normalized.scale
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)

        return renderer.image { _ in
            let scale = side / s
            let drawW = w * scale
            let drawH = h * scale
            let x = (side - drawW) / 2
            let y = (side - drawH) / 2
            normalized.draw(in: CGRect(x: x, y: y, width: drawW, height: drawH))
        }
    }

    /// Returns a new image with `.up` orientation by rasterizing into a context.
    func normalizedOrientation() -> UIImage? {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
