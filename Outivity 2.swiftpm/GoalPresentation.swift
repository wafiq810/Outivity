import Foundation
import SwiftData

/// Small, view-layer helpers for presenting goals consistently across the app.
enum GoalPresentation {
    /// Returns the set of custom goal IDs.
    ///
    /// Note: This is intentionally "broad" (fetches all CustomGoal IDs) so we can
    /// cheaply label/sort goals without doing per-row fetches.
    @MainActor
    static func customGoalIDs(in context: ModelContext) -> Set<UUID> {
        let desc = FetchDescriptor<CustomGoal>()
        let all = (try? context.fetch(desc)) ?? []
        return Set(all.map { $0.id })
    }

    /// Stable-partitions goals so custom ones appear first while preserving the existing
    /// relative order inside the custom and non-custom groups.
    static func customFirst(_ goals: [GoalTemplate], customIDs: Set<UUID>) -> [GoalTemplate] {
        guard !goals.isEmpty, !customIDs.isEmpty else { return goals }
        var custom: [GoalTemplate] = []
        var builtIn: [GoalTemplate] = []
        custom.reserveCapacity(goals.count)
        builtIn.reserveCapacity(goals.count)

        for g in goals {
            if customIDs.contains(g.id) {
                custom.append(g)
            } else {
                builtIn.append(g)
            }
        }
        return custom + builtIn
    }
}
