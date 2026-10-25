import Foundation
import SwiftData

/// Convenience accessors for the single persisted `UserInfo` record.
///
/// The app is designed to keep exactly one `UserInfo` row. `UserInfoView` enforces that by
/// updating the existing row rather than inserting new ones.
enum UserInfoStore {
    /// Returns the single `UserInfo` record if it exists.
    static func fetch(in context: ModelContext) -> UserInfo? {
        let descriptor = FetchDescriptor<UserInfo>()
        return (try? context.fetch(descriptor))?.first
    }

    /// Returns the single `UserInfo` record, or creates it using the provided defaults.
    @discardableResult
    static func fetchOrCreate(
        in context: ModelContext,
        defaultName: String = "",
        defaultAge: Int = 18,
        defaultWeight: Int = 170,
        defaultExistingActivities: [Activity] = [],
        
        defaultMinutesOutside: Int = 60,
        defaultEnvironment: Theme = .other,
        defaultIntensity: Int = 3,
        defaultTryNewPreference: TryNewLevel = .onlyRelated,
        defaultUserLimitations: [UserLimitation] = [],
        defaultAddedStatsWidgets: [StatsWidget] = [.allTimeActivities,.averageCaloriesPerSession,.averagePerWeek, .averageSessionLength, .currentStreak, .goalsMet],
        defaultPreferredUnits: PreferredUnits = .imperial
    ) -> UserInfo {
        if let existing = fetch(in: context) {
            return existing
        }

        let created = UserInfo(
            name: defaultName,
            age: defaultAge,
            weight: defaultWeight,
            existingActivities: defaultExistingActivities,
            minutesOutside: defaultMinutesOutside,
            environment: defaultEnvironment,
            intensity: defaultIntensity,
            tryNewPreference: defaultTryNewPreference,
            userLimitations: defaultUserLimitations,
            preferredUnits: defaultPreferredUnits,
            demoMode: false,
            demoSeededAt: nil,
            preferencesLastChangedAt: nil,
            addedStatsWidgets: defaultAddedStatsWidgets,
            statsWidgetOrderRaw: defaultAddedStatsWidgets.map { $0.rawValue }
        )
        context.insert(created)
        return created
    }

    static func ensureSingleInstance(in context: ModelContext) {
        let descriptor = FetchDescriptor<UserInfo>()
        guard let all = try? context.fetch(descriptor), all.count > 1 else { return }
        for extra in all.dropFirst() {
            context.delete(extra)
        }
    }
}
