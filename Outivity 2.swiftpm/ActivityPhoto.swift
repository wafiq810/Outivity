//
//  ActivityPhoto.swift
//  Outivity
//
//  Created by Wafiq on 12/28/25.
//

import Foundation
import SwiftData
import UIKit

@Model
class ActivityPhoto: Identifiable {
    var id: UUID = UUID()
    var createdAt: Date = Date()

    /// Optional reference to the frozen goal id this photo relates to.
    var goalID: UUID?

    /// Optional snapshot of the goal title at time of capture (helps if templates change later).
    var goalTitle: String?

    /// Small thumbnail data for fast list rendering (keep compressed and small).
    var previewImageData: Data?

    /// Backwards compatibility alias: some files reference `thumbnailData`.
    var thumbnailData: Data? {
        get { previewImageData }
        set { previewImageData = newValue }
    }

    /// Full (or medium-resolution) image data stored inline in SwiftData as requested.
    var fullImageData: Data?

    /// MIME-like content type (e.g. "image/jpeg") to help decoding.
    var contentType: String?

    /// Width/height of the stored (full) image, useful for UI sizing without decoding the blob.
    var width: Int?
    var height: Int?

    /// Whether the image was captured from camera (vs imported).
    var isFromCamera: Bool = true

    @Relationship
    var tracker: ActivityTracker?

    init(goalID: UUID? = nil, goalTitle: String? = nil, thumbnailData: Data? = nil, fullImageData: Data? = nil, contentType: String? = nil, width: Int? = nil, height: Int? = nil, isFromCamera: Bool = true, tracker: ActivityTracker? = nil) {
        self.goalID = goalID
        self.goalTitle = goalTitle
        self.previewImageData = thumbnailData
        self.fullImageData = fullImageData
        self.contentType = contentType
        self.width = width
        self.height = height
        self.isFromCamera = isFromCamera
        self.tracker = tracker
    }

    /// Returns a UIImage created from the stored full image data, if available.
    func getImage() -> UIImage? {
        guard let data = fullImageData else { return nil }
        return UIImage(data: data)
    }

    /// Returns a UIImage for the preview (thumbnail) if present, otherwise falls back to the full image.
    func getPreviewImage() -> UIImage? {
        if let preview = previewImageData, let image = UIImage(data: preview) {
            return image
        }
        return getImage()
    }
}
