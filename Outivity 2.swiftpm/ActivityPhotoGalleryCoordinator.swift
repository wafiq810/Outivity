import SwiftUI
import SwiftData
import UIKit

@Observable
class ActivityPhotoGalleryCoordinator {
    // Stored ActivityPhoto models fetched from SwiftData.
    var activityPhotos: [ActivityPhoto] = []

    var selectedImage: ActivityPhoto?
    var animateView: Bool = false
    var showDetailView: Bool = false
    
    var detailScrollPosition: String?
    var detailIndicatorPosition: String?
    
    // To handle navigation initiated from the detail view (e.g. "Show info" -> "Detailed History")
    // When set, the hosting view (e.g. Gallery) should trigger a navigation push.
    var pendingHistoryNavigation: ActivityTracker?

    var offset: CGSize = .zero
    var dragProcess: CGFloat = 0
    
    // The photo set currently being shown in the detail view (goal-scoped for tracker).
    // If empty, fallback to activityPhotos (global gallery).
    var presentedPhotos: [ActivityPhoto] = []
    
    // Flag to trigger info sheet on detail view appearance
    var showInfoSheetOnPresentation: Bool = false

    var currentPhotos: [ActivityPhoto] {
        presentedPhotos.isEmpty ? activityPhotos : presentedPhotos
    }

    /// Load ActivityPhoto objects. In demo mode, this provides in-memory photos backed by assets.
    /// This method must be called from the main actor.
    @MainActor func loadPhotos(from context: ModelContext, userInfo: UserInfo? = nil) {
        if userInfo?.demoMode == true {
            // Precompute demo thumbnails up front so the first gallery render is smooth.
            DemoModePhotos.warmThumbnailCache(side: 300)

            let names = DemoModePhotos.availableAssetNames()
            // Make a stable descending timeline for display.
            let now = Date()
            let bundledPhotos = names.enumerated().map { idx, name in
                DemoActivityPhoto(assetName: name, createdAt: now.addingTimeInterval(TimeInterval(-idx * 60)))
            }
            
            // Get judge-captured photos from demo storage
            let capturedPhotos = DemoModePhotos.getAllCapturedPhotos()
            
            // Combine both types of photos, with captured photos first (most recent)
            let allPhotos: [ActivityPhoto] = capturedPhotos + bundledPhotos
            self.activityPhotos = allPhotos.sorted { $0.createdAt > $1.createdAt }
            return
        }

        do {
            let desc = FetchDescriptor<ActivityPhoto>(sortBy: [SortDescriptor(\ActivityPhoto.createdAt, order: .reverse)])
            let fetched = try context.fetch(desc)
            self.activityPhotos = fetched
        } catch {
            print("[ActivityGalleryCoordinator] Failed to fetch photos: \(error)")
            self.activityPhotos = []
        }
    }
    
    func didDetailPageChange() {
        guard let id = detailScrollPosition,
              let updatedPhoto = currentPhotos.first(where: { $0.id.uuidString == id }) else { return }

        selectedImage = updatedPhoto
        detailIndicatorPosition = updatedPhoto.id.uuidString // no animation here
    }


    func didDetailIndicatorPageChange() {
        if let id = detailIndicatorPosition,
           let updatedPhoto = currentPhotos.first(where: { $0.id.uuidString == id }) {
            selectedImage = updatedPhoto
            detailScrollPosition = updatedPhoto.id.uuidString
        }
    }


    /// Convenience helper to reload; also must be called on the main actor.
    @MainActor
    func reload(in context: ModelContext, userInfo: UserInfo? = nil) {
        loadPhotos(from: context, userInfo: userInfo)
    }
 
    @MainActor
    func toggleView(show: Bool) {
        let openDuration: TimeInterval = 0.2
        let closeDuration: TimeInterval = 0.2

        if show {
            // Prep positions for detail UI
            detailScrollPosition = selectedImage?.id.uuidString
            detailIndicatorPosition = selectedImage?.id.uuidString

            // IMPORTANT: keep chrome hidden until hero finishes
            showDetailView = false

            withAnimation(.easeInOut(duration: openDuration)) {
                animateView = true
            }

            // Deterministic "completion"
            DispatchQueue.main.asyncAfter(deadline: .now() + openDuration) { [weak self] in
                guard let self else { return }
                // Only show if we're still in the open state
                if self.animateView, self.selectedImage != nil {
                    self.showDetailView = true
                }
            }

        } else {
            // Hide chrome immediately
            showDetailView = false

            withAnimation(.easeInOut(duration: closeDuration)) {
                animateView = false
                offset = .zero
                dragProcess = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + closeDuration) { [weak self] in
                guard let self else { return }
                // Only reset if we're still closed
                if !self.animateView {
                    self.resetAnimationProperties()
                }
            }
        }
    }

    @MainActor
    func resetForGalleryEntry() {
        presentedPhotos = []
        animateView = false
        showDetailView = false
        resetAnimationProperties()
    }

    func resetAnimationProperties(){
        selectedImage = nil
        detailScrollPosition = nil
        offset = .zero
        dragProcess = 0
        detailIndicatorPosition = nil
        presentedPhotos = []
    }
}
