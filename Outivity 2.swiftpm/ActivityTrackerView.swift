//
//  ActivityTrackerView.swift
//  Outivity-pretest
//
//  Created by Wafiq on 12/26/25.
//

import SwiftUI
import SwiftData
import UIKit

struct ActivityTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ActivityPhotoGalleryCoordinator.self) private var activityPhotoGalleryCoordinator

    private var activity: Activity? { tracker.activity }
    @Bindable var tracker: ActivityTracker
    private var activityMetadata: ActivityMetadata? {
        guard let a = activity else { return nil }
        return activityMetadataTable[a]
    }

    @State private var expandedGoalID: UUID? = nil
    @State private var goals: [GoalTemplate] = []
    @State private var customGoalIDs: Set<UUID> = []

    // User info
    @State private var userInfo: UserInfo? = nil

    // Timer
    @State private var now: Date = .now
    @State private var timerTask: Task<Void, Never>? = nil

    // Camera
    @State private var isPresentingCamera: Bool = false
    @State private var selectedGoalID: UUID? = nil
    @State private var selectedGoalTitle: String? = nil

    // Runtime tracker (and Calorie Calculator)
    @StateObject private var runtime = MovementRuntimeTracker()

    @State private var lastRuntimeSteps: Int = 0

    @State private var avgCalories: Int = 0

    // Gallery (item-driven sheet)
    @State private var galleryConfig: GalleryConfig?
    // current selection index for expanded photo gallery
    @State private var gallerySelection: Int = 0
    @State private var presentedPhotos: [ActivityPhoto] = []

    private struct GalleryConfig: Identifiable {
        let id = UUID()
        let photos: [ActivityPhoto]
        let initialIndex: Int
    }

    // Per-goal delete mode: when set to a goal ID, thumbnails for that goal show a delete overlay
    @State private var deleteModeGoalID: UUID? = nil
    // Photo selected for deletion from thumbnail (shows confirmation)
    @State private var photoToDelete: ActivityPhoto? = nil
    @State private var isShowingPhotoDeleteConfirm: Bool = false

    private var shouldShowTrackerStats: Bool {
        tracker.effectiveSummaryMET != nil
    }

    private var shouldShowDistance: Bool {
        tracker.effectiveSummaryMET != nil && tracker.effectiveNeedDistance
    }

    private var shouldShowSteps: Bool {
        tracker.effectiveSummaryMET != nil && tracker.effectiveNeedStepCount
    }

    private var preferredUnits: PreferredUnits {
        userInfo?.preferredUnits ?? .imperial
    }

    private var distanceText: String {
        UnitsFormatter.distanceString(meters: tracker.totalDistance, units: preferredUnits)
    }

    private var stepsText: String {
        guard let steps = tracker.totalSteps else { return "—" }
        return "\(steps)"
    }

    private var caloriesText: String {
        guard let cals = tracker.estimatedCalories else { return "—" }
        return String(format: "%.0f", cals)
    }

    private let idleCalorieScaleWhenNotMoving: Double = 0.03

    
    private struct RuntimeMetricCard: View {
        let title: String
        let value: String

        var body: some View {
            VStack(alignment: .leading) {
                Text(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(value)
                    .font(.title)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
            .contentShape(RoundedRectangle(cornerRadius: 38.0))
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 38.0))
        }
    }

    private struct RuntimeStatsView: View {
        let showDistance: Bool
        let showSteps: Bool
        let showCalories: Bool

        let distanceText: String
        let stepsText: String
        let caloriesText: String

        var body: some View {
            VStack(spacing: 12) {
                // Row 1: Distance (+ Steps)
                if showDistance || showSteps {
                    HStack {
                        if showDistance {
                            RuntimeMetricCard(title: "Distance", value: distanceText)
                        }
                        if showSteps {
                            RuntimeMetricCard(title: "Steps", value: stepsText)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .compositingGroup()
                    .zIndex(1)
                }

                // Row 2: Calories
                if showCalories {
                    HStack {
                        RuntimeMetricCard(title: "Calories", value: caloriesText)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .compositingGroup()
                    .zIndex(1)
                }
            }
        }
    }

    

    var body: some View {

        ZStack{
            ScrollView {
                VStack(spacing: 20) {
                    // Activity icons
                    VStack(spacing: 10) {
                        Image(systemName: tracker.displaySymbolName)
                            .font(.system(size: 52, weight: .semibold, design: .rounded))
                        
                        Text(tracker.displayActivityName)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                        
                        Text(formattedElapsed(max(0, now.timeIntervalSince(tracker.startedAt))))
                            .font(.system(.title2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    // Activity navigation buttons
                    GlassEffectContainer {
                        VStack(spacing: 12) {
                            Button {
                                tracker.end(at: .now)
                                dismiss()
                            } label: {
                                HStack {
                                    Text("Stop & save")
                                    Spacer()
                                    Image(systemName: "stop.fill")
                                }
                                .padding()
                            }
                            .buttonStyle(.glassProminent)
                            
                            Button(role: .destructive) {
                                modelContext.delete(tracker)
                                dismiss()
                            } label: {
                                HStack {
                                    Text("Cancel")
                                    Spacer()
                                    Image(systemName: "trash")
                                }
                                .padding()
                            }
                            .buttonStyle(.glass)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                    
                    if tracker.effectivePhoneAvailability != .notAllowed, shouldShowTrackerStats {
                        RuntimeStatsView(
                            showDistance: shouldShowDistance,
                            showSteps: shouldShowSteps,
                            showCalories: true,
                            distanceText: distanceText,
                            stepsText: stepsText,
                            caloriesText: caloriesText
                        )
                        .padding(.horizontal)
                    }
                    
                    goalsSection
                }
                .navigationTitle("In progress")
                .navigationBarTitleDisplayMode(.inline)
                .id(tracker.id)
                .onAppear {
                    customGoalIDs = GoalPresentation.customGoalIDs(in: modelContext)
                    goals = GoalPresentation.customFirst(tracker.getGoals(in: modelContext), customIDs: customGoalIDs)
                    UserInfoStore.ensureSingleInstance(in: modelContext)
                    userInfo = UserInfoStore.fetch(in: modelContext)
                    startTimer()
                    
                    // Configure runtime tracking based on activity.
                    runtime.trackSteps = tracker.effectiveNeedStepCount
                    
                    // Distance should only be persisted when the activity needs it.
                    if shouldShowDistance, tracker.totalDistance == nil {
                        tracker.totalDistance = 0
                    }
                    
                    if shouldShowSteps, tracker.totalSteps == nil {
                        tracker.totalSteps = 0
                    }
                    
                    // Seed step baseline so we only persist deltas.
                    lastRuntimeSteps = runtime.peakSteps
                    
                    // Stream GPS distance deltas into the model ONLY when distance is relevant.
                    runtime.onSample = { segmentMeters, speed in
                        Task { @MainActor in
                            guard shouldShowDistance else { return }
                            tracker.applyDistanceSample(distanceDelta: segmentMeters, speed: speed)
                            try? modelContext.save()
                        }
                    }
                    
                    // Restore calorie tracking baseline.
                    if shouldShowTrackerStats, tracker.estimatedCalories == nil {
                        tracker.estimatedCalories = 0
                    }
                    
                    runtime.start()
                }
                .onDisappear {
                    runtime.stop()
                    stopTimer()
                    try? modelContext.save()
                }
                .onChange(of: runtime.peakSteps) { _, newValue in
                    guard shouldShowSteps else { return }
                    let delta = max(0, newValue - lastRuntimeSteps)
                    guard delta > 0 else { return }
                    if tracker.totalSteps == nil { tracker.totalSteps = 0 }
                    tracker.totalSteps = (tracker.totalSteps ?? 0) + delta
                    lastRuntimeSteps = newValue
                    try? modelContext.save()
                }
                .onChange(of: runtime.totalSeconds) { _, newValue in
                    guard shouldShowTrackerStats else { return }
                    guard let calsPerMin = caloriesPerMinute() else { return }
                    
                    let isMovingNow = (runtime.currentSpeedMps ?? 0) > 0.7 || runtime.isMovingByAccel
                    let scale = isMovingNow ? 1.0 : idleCalorieScaleWhenNotMoving
                    
                    let kcalDelta = (calsPerMin / 60.0) * scale
                    if tracker.estimatedCalories == nil { tracker.estimatedCalories = 0 }
                    tracker.estimatedCalories = (tracker.estimatedCalories ?? 0) + kcalDelta
                    
                    if newValue % 15 == 0 {
                        try? modelContext.save()
                    }
                }
            }
            .allowsHitTesting(!activityPhotoGalleryCoordinator.animateView)
            Rectangle()
                    .fill(.background)
                    .ignoresSafeArea()
                    .opacity(activityPhotoGalleryCoordinator.animateView ? 1 - activityPhotoGalleryCoordinator.dragProcess : 0)
                    .allowsHitTesting(false)

            // Present the unified detail view (with indicator) for tracker as well
            if activityPhotoGalleryCoordinator.selectedImage != nil {
                ActivityPhotoDetailView()
                    .environment(activityPhotoGalleryCoordinator)
                    .allowsHitTesting(activityPhotoGalleryCoordinator.showDetailView)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zIndex(5)
            }


        }.overlayPreferenceValue(ActivityPhotoGalleryHeroKey.self) { value in
            if let selectedImage = activityPhotoGalleryCoordinator.selectedImage,
               let sAnchor = value[selectedImage.id.uuidString + "SOURCE"],
               let dAnchor = value[selectedImage.id.uuidString + "DEST"] {
                ActivityPhotoGalleryHeroLayer(
                    activityPhoto: selectedImage,
                    sAnchor: sAnchor,
                    dAnchor: dAnchor
                )
                .allowsHitTesting(false)
                .zIndex(10)
            }
        }
        // Present the camera full-screen so it works regardless of navigation context.
        .fullScreenCover(isPresented: $isPresentingCamera) {
            ActivityCameraView(onCapture: { displayData, stripThumbData in
                Task.detached(priority: .userInitiated) {
                    guard let uiImage = UIImage(data: displayData) else { return }
                    let fullData = displayData
                    let thumbData = stripThumbData
                    await MainActor.run {
                        // Check if we're in demo mode
                        if userInfo?.demoMode == true {
                            // Store in demo mode system
                            DemoModePhotos.addCapturedPhoto(
                                imageData: fullData,
                                thumbnailData: thumbData,
                                goalID: selectedGoalID,
                                goalTitle: selectedGoalTitle,
                                tracker: tracker
                            )
                        } else {
                            // Normal mode: store in SwiftData
                            let photo = ActivityPhoto(goalID: selectedGoalID,
                                                      goalTitle: selectedGoalTitle,
                                                      thumbnailData: thumbData,
                                                      fullImageData: fullData,
                                                      contentType: "image/jpeg",
                                                      width: Int(uiImage.size.width),
                                                      height: Int(uiImage.size.height),
                                                      isFromCamera: true,
                                                      tracker: tracker)
                            modelContext.insert(photo)
                            try? modelContext.save()
                        }
                    }
                }
                isPresentingCamera = false
            }, onCancel: {
                isPresentingCamera = false
            })
            .ignoresSafeArea()
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
            .ignoresSafeArea(edges: .top)
        }
        
    }

    // MARK: - Subviews

    private var goalsSection: some View {
        VStack {
            Text("Goals")
                .font(.headline)

            ForEach(goals, id: \.id) { goal in
                let isCustom = customGoalIDs.contains(goal.id)
                VStack(spacing: 0) {
                    Button {
                        withAnimation {
                            expandedGoalID = (expandedGoalID == goal.id) ? nil : goal.id
                        }
                    } label: {
                        HStack(spacing: 12) {
                            HStack(spacing: 8) {
                                Text(goal.title)
                                if isCustom {
                                    Text("Custom")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(
                                            Capsule().fill(.thinMaterial)
                                        )
                                }
                            }
                            .strikethrough(tracker.isGoalCompleted(goal.id), color: .secondary)
                            .foregroundStyle(tracker.isGoalCompleted(goal.id) ? .secondary : .primary)

                            Spacer()

                            Image(systemName: expandedGoalID == goal.id ? "chevron.up" : "chevron.down")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground).opacity(0.001)))
                    }
                    .buttonStyle(.plain)

                    if expandedGoalID == goal.id {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Spacer()
                                if let completedAt = tracker.goalCompletedAt(goal.id) {
                                    Text("Completed at \(completedAt.formatted(date: .omitted, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal)
                                }
                                Spacer()
                            }

                            HStack(spacing: 12) {
                                Button {
                                    withAnimation {
                                        tracker.toggleGoalCompleted(goal.id, at: .now)
                                    }
                                    DispatchQueue.main.async { try? modelContext.save() }
                                } label: {
                                    HStack {
                                        Image(systemName: tracker.isGoalCompleted(goal.id) ? "checkmark.circle.fill" : "circle")
                                            .font(.title2)
                                        Text("Check off")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                }
                                .buttonStyle(.glassProminent)

                                Button {
                                    selectedGoalID = goal.id
                                    selectedGoalTitle = goal.title
                                    isPresentingCamera = true
                                } label: {
                                    HStack {
                                        Image(systemName: "camera")
                                        Text("Capture")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                }
                                .buttonStyle(.glass)
                            }
                            .padding(.bottom, 8)

                            // thumbnails
                            let photosForGoal = photosForGoal(goalID: goal.id)
                            if !photosForGoal.isEmpty{
                                Text("Photos for this goal")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                                ActivityPhotoGallerySurface(
                                    photos: photosForGoal,
                                    mode: .strip(height: 72, itemWidth: 72, cornerRadius: 12, spacing: 8),
                                    selectedPhotoID: activityPhotoGalleryCoordinator.selectedImage?.id.uuidString,
                                    isHeroAnimating: activityPhotoGalleryCoordinator.animateView,
                                    onTap: { tapped in
                                        activityPhotoGalleryCoordinator.presentedPhotos = photosForGoal
                                        activityPhotoGalleryCoordinator.selectedImage = tapped
                                        activityPhotoGalleryCoordinator.detailScrollPosition = tapped.id.uuidString
                                        activityPhotoGalleryCoordinator.detailIndicatorPosition = tapped.id.uuidString

                                        DispatchQueue.main.async {
                                            activityPhotoGalleryCoordinator.toggleView(show: true)
                                        }
                                    },
                                    isDeleteMode: deleteModeGoalID == goal.id,
                                    onDeleteTapped: { photo in
                                        photoToDelete = photo
                                        isShowingPhotoDeleteConfirm = true
                                    }
                                )
                                .frame(height: 84)
                            }
                            


                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Helpers
    // Calorie helpers

    // MARK: - VERY IMPORTANT METHOD.
    // This calculates the calorie
    public func caloriesPerMinute() -> Double? {
        guard let baseMET = tracker.effectiveSummaryMET else { return nil }

        let intensityLevel = max(1, min(5, userInfo?.intensity ?? 3))
        let intensityScale: Double
        switch intensityLevel {
        case 1: intensityScale = 1.00
        case 2: intensityScale = 1.12
        case 3: intensityScale = 1.25
        case 4: intensityScale = 1.40
        case 5: intensityScale = 1.60
        default: intensityScale = 1.25
        }

        // Chosen MET
        let metChosen = max(1.0, baseMET * intensityScale)

        // Convert
        let userWeightLb = userInfo?.weight ?? 170
        let weightKg = Double(userWeightLb) * 0.45359237

        /// This formula is widely used by many calorie calculators. (MET x 3.5 x weight) / 200
        return (metChosen * 3.5 * weightKg) / 200.0
    }

    
    // Photo deleter
    private func deleteActivityPhotos(at offsets: IndexSet) {
        for index in offsets {
            let photo = tracker.photos[index]
            tracker.removePhoto(photo, in: modelContext)
        }
    }
    // MARK: - Timer helpers
    private func startTimer() {
        timerTask?.cancel()
        now = .now
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run { now = Date() }
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    private func formattedElapsed(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval.rounded(.down))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    private func deleteActivityPhoto(_ photo: ActivityPhoto) {
        modelContext.delete(photo)
    }

    private func deleteActivityPhoto(at index: Int, config: GalleryConfig) {
        guard index >= 0 && index < config.photos.count else { return }
        let photo = config.photos[index]
        tracker.removePhoto(photo, in: modelContext)

        // Build a new photos array and update/dismiss the gallery
        var newPhotos = config.photos
        newPhotos.remove(at: index)
        if newPhotos.isEmpty {
            galleryConfig = nil
        } else {
            let newIndex = min(index, newPhotos.count - 1)
            galleryConfig = GalleryConfig(photos: newPhotos, initialIndex: newIndex)
        }
    }
    
    // MARK: - Helper Functions
    
    /// Get photos for a specific goal, considering demo mode
    private func photosForGoal(goalID: UUID) -> [ActivityPhoto] {
        if userInfo?.demoMode == true {
            // In demo mode, include captured photos from DemoModePhotos
            let capturedPhotos = DemoModePhotos.getAllCapturedPhotos()
                .filter { $0.goalID == goalID && $0.tracker?.id == tracker.id }
            let regularPhotos = tracker.photos(forGoalID: goalID)
            return (capturedPhotos + regularPhotos).sorted { $0.createdAt > $1.createdAt }
        } else {
            // Normal mode: just use the tracker method
            return tracker.photos(forGoalID: goalID)
        }
    }
}

fileprivate func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
    let size = image.size
    let aspect = size.width / size.height
    var newSize: CGSize
    if size.width > size.height {
        newSize = CGSize(width: maxDimension, height: maxDimension / aspect)
    } else {
        newSize = CGSize(width: maxDimension * aspect, height: maxDimension)
    }
    let renderer = UIGraphicsImageRenderer(size: newSize)
    return renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: newSize))
    }
}


