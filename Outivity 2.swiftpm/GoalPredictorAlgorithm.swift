import Foundation
import SwiftData

@MainActor
final class GoalPredictorAlgorithm {
    private let modelContext: ModelContext
    let activity: Activity
    let activityMetadata: ActivityMetadata
    var cachedUserInfo: UserInfo? = nil

    init(modelContext: ModelContext, activity: Activity) {
        self.modelContext = modelContext
        self.cachedUserInfo = UserInfoStore.fetch(in: modelContext)
        self.activity = activity
        self.activityMetadata = activityMetadataTable[activity]!
    }

    func fetchUserInfo() -> UserInfo? {
        if let cached = cachedUserInfo { return cached }
        let fetched = UserInfoStore.fetch(in: modelContext)
        cachedUserInfo = fetched
        return fetched
    }

    func refreshCache() {
        cachedUserInfo = UserInfoStore.fetch(in: modelContext)
    }

    // MARK: - Public

    /// Predicts a set of goals for `activity` using:
    /// - user.intensity (1...5) -> difficulty bias + more goals at higher intensity
    /// - user.minutesOutside -> fewer goals + easier bias when time is low
    /// - activity.metadata.goalPool -> the candidates
    ///
    /// Returns goals sorted easiest -> hardest for a nice "mission" progression.
    func predictGoals() -> [GoalTemplate] {
        guard let user = fetchUserInfo() else { return [] }

        let pool = activityMetadata.goalPool
        guard !pool.isEmpty else { return [] }

        // Normalize inputs
        let intensity = clamp(user.intensity, min: 1, max: 5)
        let minutes = clamp(user.minutesOutside, min: 0, max: 1440)

        // 1) Decide how many goals user should get, scaled by time and intensity.
        let goalCount = recommendedGoalCount(intensity: intensity, minutesOutside: minutes)

        // 2) Choose preferred difficulty window based on intensity + time.
        let range = preferredDifficultyRange(intensity: intensity, minutesOutside: minutes)

        // 3) Assign weights to each goal.
        var weighted: [(goal: GoalTemplate, weight: Double)] = pool.map { goal in
            let d = clamp(goal.difficulty, min: 1, max: 5)
            let w = weightForDifficulty(
                goalDifficulty: d,
                preferredMin: range.min,
                preferredMax: range.max,
                intensity: intensity,
                minutesOutside: minutes
            )
            return (goal, w)
        }

        // Fallback: if all weights are ~0 (bad data), use uniform weights
        if weighted.allSatisfy({ $0.weight <= 0.0001 }) {
            weighted = pool.map { ($0, 1.0) }
        }

        // 4) Build final selection with a nice progression:
        //    - always try to include 1 "starter" (easy)
        //    - include 1 "core" (within preferred range)
        //    - include 1 "challenge" when intensity+time allow it
        var selected: [GoalTemplate] = []
        var used = Set<UUID>()

        if let starter = pickStarterGoal(from: pool, minutesOutside: minutes) {
            selected.append(starter); used.insert(starter.id)
        }

        if let core = pickCoreGoal(from: weighted, preferredRange: range, excluding: used) {
            selected.append(core); used.insert(core.id)
        }

        if shouldIncludeChallenge(intensity: intensity, minutesOutside: minutes),
           let challenge = pickChallengeGoal(from: pool, excluding: used) {
            selected.append(challenge); used.insert(challenge.id)
        }

        // 5) Fill the remaining slots with weighted sampling (no replacement)
        let remaining = max(0, goalCount - selected.count)
        let more = weightedSampleWithoutReplacement(candidates: weighted, count: remaining, excludingIDs: used)
        selected.append(contentsOf: more)

        // 6) Sort for UX: easiest -> hardest, tie-break by title
        selected.sort {
            if $0.difficulty != $1.difficulty { return $0.difficulty < $1.difficulty }
            return $0.title < $1.title
        }

        return selected
    }

    // MARK: - Count logic (Intensity + Minutes)

    private func recommendedGoalCount(intensity: Int, minutesOutside: Int) -> Int {
        // Base count by intensity
        let base: Int = {
            switch intensity {
            case 1: return 3
            case 2: return 4
            case 3: return 6
            case 4: return 8
            default: return 10
            }
        }()

        // Time scaling:
        // - short time => fewer goals
        // - longer time => closer to base (or slightly above at very high intensity)
        let timeFactor: Double = {
            switch minutesOutside {
            case 0..<15:   return 0.35
            case 15..<30:  return 0.55
            case 30..<45:  return 0.70
            case 45..<60:  return 0.85
            case 60..<90:  return 1.00
            case 90..<120: return 1.10
            default:       return 1.20
            }
        }()

        var count = Int(round(Double(base) * timeFactor))

        // Clamp to a sensible range
        count = clamp(count, min: 2, max: 12)

        // Extra guard: if you have extremely low time, avoid giving too many goals.
        if minutesOutside < 20 { count = min(count, 3) }
        if minutesOutside < 10 { count = min(count, 2) }

        return count
    }

    // MARK: - Difficulty preference (Intensity + Minutes)

    private typealias DifficultyRange = (min: Int, max: Int)

    private func preferredDifficultyRange(intensity: Int, minutesOutside: Int) -> DifficultyRange {
        // Start with intensity-based preference
        var range: DifficultyRange = {
            switch intensity {
            case 1: return (1, 2)
            case 2: return (1, 3)
            case 3: return (2, 4)
            case 4: return (3, 5)
            default: return (4, 5)
            }
        }()

        // If time is short, bias down (hard goals take longer + more fatigue risk)
        if minutesOutside < 30 {
            range.min = max(1, range.min - 1)
            range.max = max(range.min, range.max - 1)
        } else if minutesOutside < 45 {
            range.max = max(range.min, range.max - 1)
        }

        // If time is very long and intensity is high, allow top-end difficulty
        if minutesOutside >= 120 && intensity >= 4 {
            range.min = min(5, max(range.min, 3))
            range.max = 5
        }

        range.min = clamp(range.min, min: 1, max: 5)
        range.max = clamp(range.max, min: range.min, max: 5)
        return range
    }

    // MARK: - Weights

    private func weightForDifficulty(
        goalDifficulty d: Int,
        preferredMin: Int,
        preferredMax: Int,
        intensity: Int,
        minutesOutside: Int
    ) -> Double {
        // In preferred window => highest weight
        if d >= preferredMin && d <= preferredMax {
            // High intensity + more time => slight bias toward the top end
            let highBias = (intensity >= 4 && minutesOutside >= 60) ? 0.25 : 0.0
            let topEndBonus = (d == preferredMax) ? 0.15 : 0.0
            return 1.0 + highBias + topEndBonus
        }

        // 1 step away => medium
        if d == preferredMin - 1 || d == preferredMax + 1 {
            // If time is low, discourage too-hard (+1 above max) more strongly
            if minutesOutside < 30, d == preferredMax + 1 { return 0.20 }
            return 0.45
        }

        // Far away => low
        // If time is low, strongly discourage high difficulty outliers
        if minutesOutside < 30 && d >= 4 { return 0.05 }
        return 0.15
    }

    // MARK: - Structured picks (starter/core/challenge)

    private func pickStarterGoal(from pool: [GoalTemplate], minutesOutside: Int) -> GoalTemplate? {
        // When time is short, starter should be very easy (1).
        // Otherwise starter can be easy (1-2).
        let starterMax = (minutesOutside < 30) ? 1 : 2

        let candidates = pool
            .filter { clamp($0.difficulty, min: 1, max: 5) <= starterMax }
            .sorted {
                if $0.difficulty != $1.difficulty { return $0.difficulty < $1.difficulty }
                return $0.title < $1.title
            }

        return candidates.first
    }

    private func pickCoreGoal(
        from weighted: [(goal: GoalTemplate, weight: Double)],
        preferredRange: DifficultyRange,
        excluding used: Set<UUID>
    ) -> GoalTemplate? {
        // Prefer a goal inside the range (highest weights),
        // but try to avoid choosing the same one every time by using weighted random.
        let candidates = weighted
            .filter { !used.contains($0.goal.id) }
            .filter { g in
                let d = clamp(g.goal.difficulty, min: 1, max: 5)
                return d >= preferredRange.min && d <= preferredRange.max
            }

        guard !candidates.isEmpty else { return nil }
        let idx = pickWeightedIndex(from: candidates)
        return candidates[idx].goal
    }

    private func shouldIncludeChallenge(intensity: Int, minutesOutside: Int) -> Bool {
        // Only include a "challenge" when the user can realistically handle it.
        // High intensity and enough minutes => yes.
        if intensity >= 5 { return minutesOutside >= 30 }
        if intensity == 4 { return minutesOutside >= 45 }
        return false
    }

    private func pickChallengeGoal(from pool: [GoalTemplate], excluding used: Set<UUID>) -> GoalTemplate? {
        // Prefer difficulty 5, else 4, else highest available.
        let sorted = pool
            .filter { !used.contains($0.id) }
            .sorted {
                if $0.difficulty != $1.difficulty { return $0.difficulty > $1.difficulty }
                return $0.title < $1.title
            }
        return sorted.first
    }

    // MARK: - Weighted sampling (no replacement)

    private func weightedSampleWithoutReplacement(
        candidates: [(goal: GoalTemplate, weight: Double)],
        count: Int,
        excludingIDs: Set<UUID>
    ) -> [GoalTemplate] {
        guard count > 0 else { return [] }

        var available = candidates
            .filter { !excludingIDs.contains($0.goal.id) }
            .filter { $0.weight > 0 }

        var result: [GoalTemplate] = []
        result.reserveCapacity(min(count, available.count))

        for _ in 0..<count {
            guard !available.isEmpty else { break }
            let pickedIndex = pickWeightedIndex(from: available)
            result.append(available[pickedIndex].goal)
            available.remove(at: pickedIndex) // no replacement
        }

        return result
    }

    private func pickWeightedIndex(from items: [(goal: GoalTemplate, weight: Double)]) -> Int {
        let total = items.reduce(0.0) { $0 + max(0.0, $1.weight) }
        if total <= 0.0001 { return Int.random(in: 0..<items.count) }

        var r = Double.random(in: 0..<total)
        for (idx, item) in items.enumerated() {
            r -= max(0.0, item.weight)
            if r <= 0 { return idx }
        }
        return max(0, items.count - 1)
    }

    // MARK: - Helpers

    private func clamp(_ x: Int, min: Int, max: Int) -> Int {
        Swift.max(min, Swift.min(max, x))
    }

    // Example helper: safe fetch that compares an ActivityTracker's `activity` to this algorithm's `activity`.
    // IMPORTANT: capture `self.activity` into a local constant before using it inside `#Predicate`.
    // This prevents the macro from interpreting `self.activity` as a key-path (which leads to the
    // key-path vs key-path equality error you saw).
    @MainActor
    private func fetchTrackersForCurrentActivity() -> [ActivityTracker] {
        let activityToMatch = self.activity
        let predicate = #Predicate<ActivityTracker> { $0.activity == activityToMatch }
        let descriptor = FetchDescriptor<ActivityTracker>(predicate: predicate)
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
