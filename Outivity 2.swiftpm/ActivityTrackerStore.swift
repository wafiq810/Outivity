import Foundation
import SwiftData

// BIG LOCAL API!!!
enum ActivityTrackerStore {
    /// Returns the currently active activity session if it exists.
    @MainActor
    static func fetchActive(in context: ModelContext) -> ActivityTracker? {
        let predicate = #Predicate<ActivityTracker> { $0.endedAt == nil }
        let descriptor = FetchDescriptor<ActivityTracker>(predicate: predicate)
        return (try? context.fetch(descriptor))?.first
    }

    @MainActor
    @discardableResult
    static func startNewActivity(
        _ activity: Activity,
        in context: ModelContext,
        at date: Date = Date(),
        presetGoals: [GoalTemplate]? = nil
    ) -> ActivityTracker {
        if let active = fetchActive(in: context) {
            active.end(at: date)
        }

        // Rule 3: Built-in sessions show predicted goals PLUS custom goals
        let predicted = GoalPredictorAlgorithm(modelContext: context, activity: activity).predictGoals()
        var frozenGoals = predicted
        
        if let presetGoals, !presetGoals.isEmpty {
            // Add custom goals to predicted goals, avoiding duplicates if any title matches
            for custom in presetGoals {
                if !frozenGoals.contains(where: { $0.title == custom.title }) {
                    frozenGoals.append(custom)
                }
            }
        }

        let tracker = ActivityTracker(activity: activity, startedAt: date)
        tracker.goalIDs = frozenGoals.map { $0.id }
        tracker.goalTitles = frozenGoals.map { $0.title }
        // Ensure we freeze the full template data so we can retrieve custom goals later
        tracker.frozenGoalsData = try? JSONEncoder().encode(frozenGoals)

        // Start distance/speed at a known baseline.
        tracker.resetDistanceTracking()

        context.insert(tracker)
        // Persist immediately so the active tracker and its frozen goal IDs/titles survive a force-quit.
        do {
            try context.save()
        } catch {
            // Log any save errors so they can be diagnosed in the console.
        }
        return tracker
    }

    @MainActor
    @discardableResult
    static func startCustomActivity(
        _ custom: CustomActivity,
        in context: ModelContext,
        at date: Date = Date(),
        presetGoals: [GoalTemplate] = []
    ) -> ActivityTracker {
        if let active = fetchActive(in: context) {
            active.end(at: date)
        }

        // Rule 2: Explicitly distinguish activity type, no .other fallback
        let tracker = ActivityTracker(customActivityID: custom.id, startedAt: date)
        tracker.customName = custom.name
        tracker.customSymbolName = custom.symbolName
        tracker.customDifficulty = custom.difficulty
        tracker.customNeedDistance = custom.needDistance
        tracker.customNeedSteps = custom.needSteps
        tracker.customMET = custom.metValue
        tracker.customSummary = custom.userDescription
        tracker.customSafetyWarnings = custom.safetyWarnings
        tracker.customPhoneAvailability = custom.phoneAllowance

        // Rule 3: ONLY custom goals for custom activities
        let frozen: [GoalTemplate] = presetGoals.isEmpty ? custom.defaultGoals : presetGoals
        tracker.goalIDs = frozen.map { $0.id }
        tracker.goalTitles = frozen.map { $0.title }
        tracker.frozenGoalsData = try? JSONEncoder().encode(frozen)

        tracker.resetDistanceTracking()

        context.insert(tracker)
        try? context.save()
        return tracker
    }


    @MainActor
    static func ensureSnapshotIfMissing(_ tracker: ActivityTracker, in context: ModelContext) {
        // If any of these are present, assume snapshot exists.
        if tracker.frozenGoalsData != nil || !tracker.goalTitles.isEmpty { return }

        // If there are already goalIDs that resolve, we don't need to regenerate.
        let available = tracker.selectedGoals
        if !available.isEmpty { return }

        // Rule 3: Custom activities should not have predicted goals.
        if tracker.isCustomActivity { return }

        // Regenerate a best-effort snapshot using the predictor and persist it.
        guard let activity = tracker.activity else { return }
        let predicted = GoalPredictorAlgorithm(modelContext: context, activity: activity).predictGoals()
        guard !predicted.isEmpty else { return }

        tracker.goalIDs = predicted.map { $0.id }
        tracker.goalTitles = predicted.map { $0.title }
        tracker.frozenGoalsData = try? JSONEncoder().encode(predicted)

        do {
            try context.save()
        } catch {
            print("[ActivityTrackerStore] Failed to save regenerated snapshot: \(error)")
        }
    }

    /// Deletes an activity session.
    @MainActor
    static func delete(_ tracker: ActivityTracker, in context: ModelContext) {
        context.delete(tracker)
        do {
            try context.save()
        } catch {
            print("[ActivityTrackerStore] Failed to save after delete: \(error)")
        }
    }
}

