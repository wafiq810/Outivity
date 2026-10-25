import SwiftData
import SwiftUI

struct ActivityHistoryView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\ActivityTracker.startedAt, order: .reverse)])
    private var trackers: [ActivityTracker]

    var body: some View {
        List {
            if trackers.isEmpty {
                Section{} footer: {
                    VStack(alignment: .center) {
                        
                        Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                            .font(.system(size: 44))
                            .padding(18)
                            .background(Circle().fill(Color.secondary))
                            .foregroundColor(.white)
                        
                        Text("No activities yet")
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.secondary)
                            .multilineTextAlignment(.center)

                        Text("Complete your first activity to see it in the history.")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            } else {
                ForEach(groupedtrackers, id: \.day) { group in
                    Section {
                        ForEach(group.trackers) { tracker in
                            NavigationLink {
                                ActivityHistoryDetailView(tracker: tracker)
                            } label: {
                                ActivityHistoryRowView(tracker: tracker)
                            }
                        }
                        .onDelete { offsets in
                            deleteActivityTracker(at: offsets, in: group.trackers)
                        }
                    } header: {
                        Text(dayHeaderText(for: group.day))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                }
            }
        }
        .navigationTitle("Activity history")
        .toolbar {
            if !trackers.isEmpty{
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditModeToggleButton(inactiveSystemImageName: "square.and.pencil", doneTitle: "Done")
                }
            }
        }
    }

    private var groupedtrackers: [(day: Date, trackers: [ActivityTracker])] {
        // trackers is already sorted by startedAt desc; preserve that ordering within each day
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: trackers) { tracker in
            calendar.startOfDay(for: tracker.startedAt)
        }

        return grouped
            .map { (day: $0.key, trackers: $0.value) }
            .sorted { $0.day > $1.day }
    }

    private func dayHeaderText(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(date: .abbreviated, time: .omitted)
    }

    private func subtitle(for tracker: ActivityTracker) -> String {
        let started = tracker.startedAt.formatted(date: .abbreviated, time: .shortened)
        if let ended = tracker.endedAt {
            let endedS = ended.formatted(date: .omitted, time: .shortened)
            return "Started \(started) • Ended \(endedS)"
        } else {
            return "Started \(started)"
        }
    }

    private func duration(for tracker: ActivityTracker) -> TimeInterval? {
        guard let endedAt = tracker.endedAt else { return nil }
        return max(0, endedAt.timeIntervalSince(tracker.startedAt))
    }

    private func formattedDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval.rounded(.down))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }

    private func deleteActivityTracker(at offsets: IndexSet, in items: [ActivityTracker]) {
        for idx in offsets {
            modelContext.delete(items[idx])
        }
    }
    
}

private struct ActivityHistoryRowView: View {
    let tracker: ActivityTracker

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: tracker.displaySymbolName)
                .font(.title2)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(tracker.displayActivityName)
                        .font(.headline)
                        .lineLimit(1)

                    if tracker.isCustomActivity {
                        Text("Custom")
                            .font(.caption2.weight(.semibold))
                            .padding(.vertical, 2)
                            .padding(.horizontal, 6)
                            .background(
                                Capsule().fill(Color.primary.opacity(0.08))
                            )
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Custom activity")
                    }
                }

                Text(tracker.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let ended = tracker.endedAt {
                Text(ended.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

public struct ActivityHistoryDetailView: View {
    let tracker: ActivityTracker
    @Environment(\.modelContext) private var modelContext
    @Environment(ActivityPhotoGalleryCoordinator.self) private var activityPhotoGalleryCoordinator

    // Fetch trackers so we can detect if there's an ongoing tracker for this activity
    @Query(sort: [SortDescriptor(\ActivityTracker.startedAt, order: .reverse)])
    private var allTrackers: [ActivityTracker]

    @State private var galleryConfig: GalleryConfig?
    // Expose the currently visible index to allow the view to delete the visible photo
    @State private var gallerySelection: Int = 0
    // Per-goal delete mode: when set to a goal ID, thumbnails for that goal show a delete overlay
    @State private var deleteModeGoalID: UUID? = nil
    // Photo selected for deletion from thumbnail (shows confirmation)
    @State private var photoToDelete: ActivityPhoto? = nil
    @State private var isShowingPhotoDeleteConfirm: Bool = false

    @State private var userInfo: UserInfo? = nil

    private struct GalleryConfig: Identifiable {
        let id = UUID()
        let photos: [ActivityPhoto]
        let initialIndex: Int
    }

    private var activityMetadata: ActivityMetadata? {
        tracker.activityMetadata
    }

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

    public var body: some View {
        ZStack{
            ScrollView{
                VStack(spacing: 16) {
                    Image(systemName: tracker.displaySymbolName)
                        .font(.system(size: 44, weight: .semibold))
                    
                    VStack {
                        Text(tracker.displayActivityName)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        
                        if tracker.isCustomActivity {
                            Text("Custom")
                                .font(.headline.bold())
                                .padding()
                                .glassEffect()
                        }
                    }
                    
                    VStack{
                        VStack(alignment: .leading, spacing: 10) {
                            row("Started", tracker.startedAt.formatted(date: .abbreviated, time: .shortened))
                            if let ended = tracker.endedAt {
                                row("Ended", ended.formatted(date: .abbreviated, time: .shortened))
                                row("Duration", durationText)
                            } else {
                                row("Status", "In progress")
                            }
                        }.padding()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .glassEffect(in: RoundedRectangle(cornerRadius: 38))
                    .padding()
                    // If there is an ongoing tracker for this activity, show a Resume button that navigates to it
                    if let active = allTrackers.first(where: { $0.endedAt == nil && $0.displayActivityName == tracker.displayActivityName }) {
                        NavigationLink {
                            ActivityTrackerView(tracker: active)
                        } label: {
                            HStack {
                                Text("Resume \(active.displayActivityName)")
                                Spacer()
                                Image(systemName: "play.fill")
                            }
                            .padding()
                        }
                        .padding(.horizontal)
                        .buttonStyle(.glassProminent)
                    }
                    
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
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Goals")
                            .font(.headline)
                        let customIDs = GoalPresentation.customGoalIDs(in: modelContext)
                        let sortedGoals = GoalPresentation.customFirst(tracker.selectedGoals, customIDs: customIDs)
                        if sortedGoals.isEmpty {
                            Text("No goals for this tracker")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(sortedGoals, id: \.id) { goal in
                                let isCustom = customIDs.contains(goal.id)
                                HStack {
                                    Image(systemName: tracker.isGoalCompleted(goal.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(tracker.isGoalCompleted(goal.id) ? .green : .secondary)
                                    HStack(spacing: 8) {
                                        Text(goal.title)
                                        if isCustom {
                                            Text("Custom")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(Capsule().fill(.thinMaterial))
                                        }
                                    }
                                    .foregroundStyle(tracker.isGoalCompleted(goal.id) ? .secondary : .primary)
                                    Spacer()
                                    if let completedAt = tracker.goalCompletedAt(goal.id) {
                                        Text(completedAt.formatted(date: .omitted, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 6)
                                
                                // Thumbnails for this goal in the tracker
                                let photosForGoal = photosForGoal(goalID: goal.id)
                                if !photosForGoal.isEmpty {
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
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // History stats (show only if the activity permits this kind of data)
                }
                .padding()
                
            }
            .onAppear {
                UserInfoStore.ensureSingleInstance(in: modelContext)
                userInfo = UserInfoStore.fetch(in: modelContext)
            }
            .allowsHitTesting(!activityPhotoGalleryCoordinator.animateView)
            Rectangle()
                .fill(.background)
                .ignoresSafeArea()
                .opacity(activityPhotoGalleryCoordinator.animateView ? 1 - activityPhotoGalleryCoordinator.dragProcess : 0)
                .allowsHitTesting(false)

            // detail view
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

        
    }

    private var durationText: String {
        guard let ended = tracker.endedAt else { return "In progress" }
        let interval = max(0, ended.timeIntervalSince(tracker.startedAt))
        let totalSeconds = Int(interval.rounded(.down))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.body)
    }

    private func deleteActivityPhoto(at idx: Int) {
        guard let config = galleryConfig else { return }
        guard idx >= 0 && idx < config.photos.count else { return }
        let photo = config.photos[idx]
        tracker.removePhoto(photo, in: modelContext)

        var newPhotos = config.photos
        newPhotos.remove(at: idx)
        if newPhotos.isEmpty {
            galleryConfig = nil
        } else {
            let newIndex = min(idx, newPhotos.count - 1)
            galleryConfig = GalleryConfig(photos: newPhotos, initialIndex: newIndex)
            gallerySelection = newIndex
        }
    }

    private func deleteActivityPhoto(_ photo: ActivityPhoto) {
        tracker.removePhoto(photo, in: modelContext)
    }

    private func deleteActivityPhotos(at offsets: IndexSet) {
        for index in offsets {
            let photo = tracker.photos[index]
            tracker.removePhoto(photo, in: modelContext)
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

#Preview {
    NavigationStack {
        ActivityHistoryView()
    }
}
