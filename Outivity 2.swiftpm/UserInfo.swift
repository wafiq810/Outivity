import Foundation
import SwiftData

@Model
class UserInfo {
    var name: String?
    var age: Int
    var weight: Int
    var existingActivities: [Activity]  // always an array, no nil
    var existingEquipment: [Equipment]
    var minutesOutside: Int

    // New high-signal preference fields
    var environment: Theme
    var intensity: Int
    var tryNewPreference: TryNewLevel
    
    // Accessibility limitations
    var userLimitations: [UserLimitation]

    // MARK: - Demo mode

    /// Backing store for demo mode.
    /// Optional for backward compatibility with existing persisted stores.
    var demoModeRaw: Bool? = nil

    /// When enabled, the app shows bundled demo content (e.g. gallery images) instead of user data.
    var demoMode: Bool {
        get { demoModeRaw ?? false }
        set { demoModeRaw = newValue }
    }

    /// Backing store for when demo content was seeded.
    /// Optional for backward compatibility.
    var demoSeededAtRaw: Date? = nil

    /// When demo content was seeded into SwiftData (if ever).
    var demoSeededAt: Date? {
        get { demoSeededAtRaw }
        set { demoSeededAtRaw = newValue }
    }

    var isDemoSeeded: Bool {
        demoSeededAt != nil
    }

    /// Preferred unit system for displaying measurements in the UI.
    ///
    /// This is optional to stay backward-compatible with existing persisted `UserInfo` rows
    /// created before this property existed.
    var preferredUnitsRaw: PreferredUnits? = nil

    /// Non-optional convenience accessor with a stable default.
    var preferredUnits: PreferredUnits {
        get { preferredUnitsRaw ?? .imperial }
        set { preferredUnitsRaw = newValue }
    }

    // MARK: - Stats widgets persistence

    /// Backing store for the user's chosen stats widgets (and their order).
    ///
    /// Stored as raw string IDs because this is stable and SwiftData-friendly.
    /// Optional for backwards compatibility with existing stores.
    var statsWidgetOrderRaw: [String]? = nil

    /// Legacy storage used previously.
    /// Kept to allow seamless migration.
    var addedStatsWidgets: [StatsWidget] = []

    /// Normalized list of widgets to render (no duplicates), preserving the user's order.
    ///
    /// - If `statsWidgetOrderRaw` exists, use it.
    /// - Else migrate from `addedStatsWidgets` if available.
    /// - Else default to current `StatsWidget.defaultOrder`.
    ///
    /// Note: we DO NOT automatically re-add "all widgets" if the user removes them. We only
    /// fall back to default order when there is no saved order at all.
    var statsWidgets: [StatsWidget] {
        get {
            if let raw = statsWidgetOrderRaw {
                return Self.normalize(rawIds: raw)
            }

            if !addedStatsWidgets.isEmpty {
                let normalized = Self.normalize(widgets: addedStatsWidgets)
                statsWidgetOrderRaw = normalized.map { $0.rawValue }
                return normalized
            }

            return StatsWidget.defaultOrder
        }
        set {
            let normalized = Self.normalize(widgets: newValue)
            statsWidgetOrderRaw = normalized.map { $0.rawValue }
            addedStatsWidgets = normalized
        }
    }

    /// Timestamp for when the user last changed preference
    var preferencesLastChangedAt: Date?

    init(
        name: String,
        age: Int,
        weight: Int,
        existingActivities: [Activity]? = nil,
        existingEquipment: [Equipment]? = nil,
        minutesOutside: Int,
        environment: Theme,
        intensity: Int = 3,
        tryNewPreference: TryNewLevel = .onlyRelated,
        userLimitations: [UserLimitation] = [],
        preferredUnits: PreferredUnits = .imperial,
        demoMode: Bool = false,
        demoSeededAt: Date? = nil,
        preferencesLastChangedAt: Date? = nil,
        addedStatsWidgets: [StatsWidget] = [],
        statsWidgetOrderRaw: [String]? = nil
    ) {
        self.name = name
        self.age = age
        self.weight = weight
        self.existingActivities = existingActivities ?? []  // no nil
        self.existingEquipment = existingEquipment ?? []  // no nil
        self.minutesOutside = minutesOutside
        self.environment = environment
        self.intensity = intensity
        self.tryNewPreference = tryNewPreference
        self.userLimitations = userLimitations
        self.preferredUnitsRaw = preferredUnits
        self.demoModeRaw = demoMode
        self.demoSeededAtRaw = demoSeededAt
        self.preferencesLastChangedAt = preferencesLastChangedAt
        self.addedStatsWidgets = addedStatsWidgets
        self.statsWidgetOrderRaw = statsWidgetOrderRaw

        // Seed new field from legacy if needed.
        if self.statsWidgetOrderRaw == nil, !addedStatsWidgets.isEmpty {
            self.statsWidgetOrderRaw = addedStatsWidgets.map { $0.rawValue }
        }
    }

    // MARK: - Normalization helpers

    /// Converts raw IDs into widgets, drops unknown IDs, removes duplicates while preserving order.
    private static func normalize(rawIds: [String]) -> [StatsWidget] {
        let decoded = rawIds.compactMap { StatsWidget(rawValue: $0) }
        return normalize(widgets: decoded)
    }

    private static func normalize(widgets: [StatsWidget]) -> [StatsWidget] {
        var seen = Set<String>()
        var result: [StatsWidget] = []
        for w in widgets {
            guard seen.insert(w.rawValue).inserted else { continue }
            result.append(w)
        }
        return result
    }
}

enum TryNewLevel: String, CaseIterable, Codable {
    case onlyRelated = "Only related"
    case oneNew = "1 new suggestion"
    case moreNew = "More new suggestions"
    case surprise = "Surprise me"
    case other = "Other"
}

public enum Theme: String, CaseIterable, Codable, Identifiable {
    public var id: String { rawValue }

    case water = "Water"
    case trails = "Trails"
    case teamSports = "Team Sports"
    case chillNature = "Chill Nature"
    case adventure = "Adventure"
    case winter = "Winter"
    case other = "Other"
}
