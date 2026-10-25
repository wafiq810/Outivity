import Foundation
import SwiftData

@Model
class ActivityTracker: Identifiable {
    /// Built-in activity being tracked (nil for custom sessions).
    var activity: Activity?

    /// Custom activity identifier for custom sessions (nil for built-in sessions).
    var customActivityID: UUID?

    /// When the activity session started.
    var startedAt: Date

    /// When the activity session ended. `nil` means the activity is still in progress.
    var endedAt: Date?

    /// IDs of the goals that were frozen for this session (predicted at start time for built-in; selected custom goals for custom sessions).
    var goalIDs: [UUID] = []

    /// Legacy: human-readable titles of frozen goals (kept for compatibility).
    var goalTitles: [String] = []

    /// Legacy: raw JSON blob storing frozen goals (kept for compatibility).
    var frozenGoalsData: Data? = nil

    /// IDs of the goals the user has completed for this session.
    ///
    /// Legacy storage (pre goal-completion timestamps). Kept for lightweight migration.
    var completedGoalIDs: [UUID] = []

    /// When each goal was completed for this session.
    var completedGoalTimestamps: [UUID: Date] = [:]

    /// Calorie calculation
    /// Estimated calories burned for this session (kcal). `nil` means not computed/available.
    var estimatedCalories: Double? = nil

    /// Total steps counted for this session when the activity requires it.
    /// `nil` means steps were not tracked/available.
    var totalSteps: Int? = nil

    // MARK: - Custom Activity Snapshot
    var customName: String?
    var customSymbolName: String?
    var customDifficulty: Int?
    var customNeedDistance: Bool?
    var customNeedSteps: Bool?
    var customMET: Double?
    var customSummary: String?
    var customSafetyWarnings: [String]?
    var customPhoneAvailability: PhoneAvailability?

    /// Rule 2: Explicitly distinguish built-in vs custom.
    @Transient
    var isCustomActivity: Bool {
        customActivityID != nil
    }

    @Transient
    var displayActivityName: String {
        if isCustomActivity {
            return customName ?? "Custom activity"
        }
        return activity?.displayName ?? "Activity"
    }

    @Transient
    var displaySymbolName: String {
        if isCustomActivity {
            return customSymbolName ?? "star"
        }
        return activity?.symbolName ?? "figure.walk"
    }

    @Transient
    var displayDifficulty: Int {
        if isCustomActivity {
            return customDifficulty ?? 1
        }
        return activity?.difficulty ?? 1
    }

    @Transient
    var effectiveNeedDistance: Bool {
        if isCustomActivity {
            return customNeedDistance ?? false
        }
        return activity?.needDistance ?? false
    }

    @Transient
    var effectiveNeedStepCount: Bool {
        if isCustomActivity {
            return customNeedSteps ?? false
        }
        return activity?.needStepCount ?? false
    }

    @Transient
    var effectiveSummaryMET: Double? {
        if isCustomActivity {
            return customMET
        }
        return activity?.summaryMET
    }

    @Transient
    @MainActor
    var effectiveDescription: String {
        if isCustomActivity {
            return customSummary ?? ""
        }
        guard let activity else { return "" }
        return activityMetadataTable[activity]?.description ?? ""
    }

    @Transient
    @MainActor
    var effectivePhoneAvailability: PhoneAvailability {
        if isCustomActivity {
            return customPhoneAvailability ?? .fullyAllowed
        }
        guard let activity else { return .fullyAllowed }
        return activityMetadataTable[activity]?.phoneAvailability ?? .fullyAllowed
    }

    /// If this tracker was created from a `ScheduledActivity`, this points back to it.
    @Relationship
    var scheduledActivity: ScheduledActivity?

    /// Photos captured/attached during this tracker session.
    @Relationship
    var photos: [ActivityPhoto] = []

    /// Derived at runtime from `activity`.
    /// For custom sessions this returns nil (Rule 1).
    @Transient
    @MainActor
    var activityMetadata: ActivityMetadata? {
        guard let activity else { return nil }
        return activityMetadataTable[activity]
    }

    var isActive: Bool { endedAt == nil }

    init(activity: Activity, startedAt: Date = Date(), endedAt: Date? = nil) {
        self.activity = activity
        self.customActivityID = nil
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    init(customActivityID: UUID, startedAt: Date = Date(), endedAt: Date? = nil) {
        self.activity = nil
        self.customActivityID = customActivityID
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    func end(at date: Date = Date()) {
        self.endedAt = date
    }

    // MARK: - Goal helpers

    /// Returns the frozen goals for this session.
    /// - Built-in: from frozen JSON, else resolve from built-in pool.
    /// - Custom: from frozen JSON only; never resolve via built-in pool.
    @MainActor
    var selectedGoals: [GoalTemplate] {
        if let data = frozenGoalsData,
           let goals = try? JSONDecoder().decode([GoalTemplate].self, from: data) {
            return goals
        }

        // Rule 3: custom sessions must never inherit built-in goals.
        if isCustomActivity { return [] }
        guard let activity, let pool = activityMetadataTable[activity]?.goalPool else { return [] }
        return goalIDs.compactMap { id in pool.first(where: { $0.id == id }) }
    }

    /// Returns completed goals.
    /// Custom sessions: derives from `selectedGoals` (frozen JSON). Built-in: resolves from pool.
    @MainActor
    var completedGoals: [GoalTemplate] {
        let idsInOrder: [UUID]
        if !completedGoalIDs.isEmpty {
            idsInOrder = completedGoalIDs
        } else {
            idsInOrder = goalIDs.filter { completedGoalTimestamps[$0] != nil }
        }

        let selected = selectedGoals
        if !selected.isEmpty {
            return idsInOrder.compactMap { id in selected.first(where: { $0.id == id }) }
        }

        // If selected is empty (e.g. legacy built-in without frozen JSON), attempt built-in resolution.
        if isCustomActivity { return [] }
        guard let activity, let pool = activityMetadataTable[activity]?.goalPool else { return [] }
        return idsInOrder.compactMap { id in pool.first(where: { $0.id == id }) }
    }

    /// Returns a completion timestamp for a goal if that goal is completed.
    @MainActor
    func goalCompletedAt(_ id: UUID) -> Date? {
        if let date = completedGoalTimestamps[id] { return date }

        // Lightweight migration: if legacy storage says "completed" but no timestamp exists yet,
        // backfill with `endedAt` (if available) or `Date()`.
        if completedGoalIDs.contains(id) {
            let fallback = endedAt ?? Date()
            completedGoalTimestamps[id] = fallback
            return fallback
        }
        return nil
    }

    @MainActor
    func isGoalCompleted(_ id: UUID) -> Bool {
        if completedGoalTimestamps[id] != nil { return true }
        return completedGoalIDs.contains(id)
    }

    /// Marks a goal completed/uncompleted.
    @MainActor
    func toggleGoalCompleted(_ id: UUID, at date: Date = Date()) {
        if isGoalCompleted(id) {
            completedGoalTimestamps.removeValue(forKey: id)
            if let idx = completedGoalIDs.firstIndex(of: id) {
                completedGoalIDs.remove(at: idx)
            }
        } else {
            completedGoalTimestamps[id] = date
            if !completedGoalIDs.contains(id) {
                completedGoalIDs.append(id)
            }
        }
    }

    // MARK: - Prediction helpers

    /// Ensure this tracker has frozen goals.
    /// Rule 3: for custom sessions, this will never run prediction.
    @MainActor
    func ensureGoals(in context: ModelContext) -> [GoalTemplate] {
        if isCustomActivity {
            return selectedGoals
        }

        // If we already have frozen IDs that resolve, return them.
        if !goalIDs.isEmpty {
            let resolved = selectedGoals
            if !resolved.isEmpty { return resolved }
        }

        guard let activity else { return [] }

        // Generate new predictions.
        let predicted = GoalPredictorAlgorithm(modelContext: context, activity: activity).predictGoals()
        guard !predicted.isEmpty else { return [] }

        // Freeze the predictions on this model for robust persistence.
        goalIDs = predicted.map { $0.id }
        goalTitles = predicted.map { $0.title }
        frozenGoalsData = try? JSONEncoder().encode(predicted)

        do {
            try context.save()
        } catch {
            print("[ActivityTracker] Failed to save frozen goals: \(error)")
        }

        return predicted
    }

    /// Public helper that returns the goals for this tracker, ensuring predictions are generated and
    /// persisted if needed. This allows views to simply call `tracker.getGoals(in:)` instead of
    /// instantiating the predictor themselves.
    @MainActor
    func getGoals(in context: ModelContext) -> [GoalTemplate] {
        if !goalIDs.isEmpty {
            let resolved = selectedGoals
            if !resolved.isEmpty { return resolved }
        }
        return ensureGoals(in: context)
    }

    @MainActor
    func attachToScheduled(_ scheduled: ScheduledActivity, in context: ModelContext) {
        scheduledActivity = scheduled
        // Ensure the schedule points back to this session so both sides are linked.
        scheduled.session = self
        // If the tracker has no goals, adopt the schedule's predicted goals.
        if goalIDs.isEmpty && !scheduled.goals.isEmpty {
            goalIDs = scheduled.goals.map { $0.id }
            goalTitles = scheduled.goals.map { $0.title }
            frozenGoalsData = try? JSONEncoder().encode(scheduled.goals)
        }
        do {
            try context.save()
        } catch {
            print("[ActivityTracker] Failed to save attached scheduled goals/session link: \(error)")
        }
    }

    @MainActor
    func photos(forGoalID id: UUID?) -> [ActivityPhoto] {
        photos.filter { $0.goalID == id }
    }

    @MainActor
    func addPhoto(thumbnail: Data?, fullImage: Data?, contentType: String?, goalID: UUID?, goalTitle: String?, isFromCamera: Bool = true, in context: ModelContext) {
        let photo = ActivityPhoto(goalID: goalID, goalTitle: goalTitle, thumbnailData: thumbnail, fullImageData: fullImage, contentType: contentType, isFromCamera: isFromCamera)
        photo.tracker = self
        photos.append(photo)
        do {
            try context.save()
        } catch {
            print("[ActivityTracker] Failed to save photo: \(error)")
        }
    }

    @MainActor
    func removePhoto(_ photo: ActivityPhoto, in context: ModelContext) {
        if let idx = photos.firstIndex(where: { $0.id == photo.id }) {
            photos.remove(at: idx)
        }
        context.delete(photo)
        do {
            try context.save()
        } catch {
            print("[ActivityTracker] Failed to delete photo: \(error)")
        }
    }

    // MARK: - Distance / speed

    /// Total distance travelled for this session (meters).
    /// `nil` means distance tracking has not started/has no data yet.
    var totalDistance: Double? = nil

    /// Average speed for this session (m/s).
    /// `nil` means speed tracking has not started/has no data yet.
    var averageSpeed: Double? = nil

    // MARK: - Distance / speed helpers

    /// Resets distance/speed to a known baseline. Useful when a session starts.
    @MainActor
    func resetDistanceTracking() {
        totalDistance = 0
        averageSpeed = nil
    }

    /// Applies incoming distance/speed samples from a runtime tracker.
    /// - Parameters:
    ///   - distanceDelta: Distance since last sample in meters.
    ///   - speed: Instantaneous speed in m/s (optional). Used to update a running average.
    ///   - sampleCount: The number of speed samples already included in `averageSpeed`.
    ///     If you don't have this yet, pass `nil` and we'll treat the incoming speed as the average.
    @MainActor
    func applyDistanceSample(distanceDelta: Double, speed: Double?, sampleCount: Int? = nil) {
        if totalDistance == nil { totalDistance = 0 }
        if distanceDelta.isFinite {
            totalDistance = (totalDistance ?? 0) + max(0, distanceDelta)
        }

        guard let speed, speed.isFinite else { return }
        let clamped = max(0, speed)

        // Default behavior until we introduce a proper speed averaging strategy:
        // if there is no sampleCount provided, treat the latest speed as the session average.
        guard let sampleCount, sampleCount > 0, let existing = averageSpeed else {
            averageSpeed = clamped
            return
        }

        // Running mean: newAvg = (existing * n + x) / (n + 1)
        averageSpeed = ((existing * Double(sampleCount)) + clamped) / Double(sampleCount + 1)
    }
}
