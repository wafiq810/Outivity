import Foundation
import SwiftData

/// Recommends activities using a weighted score.
final class ActivityPredictorAlgorithm {
    private let modelContext: ModelContext
    private(set) var cachedUserInfo: UserInfo?
    var randomization: Double

    init(modelContext: ModelContext, randomization: Double = 1.0) {
        self.modelContext = modelContext
        self.cachedUserInfo = UserInfoStore.fetch(in: modelContext)
        self.randomization = max(0.0, min(1.0, randomization))
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

    /// Bias controls that influence scoring and selection.
    var bias = BiasControls()

    struct BiasControls {
        var themeSimilarityWeight: Double = 1.0
        var historyBlendMax: Double = 0.95
        var historyHalfLifeDays: Double = 21.0
        var historyConfidenceScale: Double = 8.0
        var historyVectorBoostWeight: Double = 0.9
        var recentThemeBoostWeight: Double = 650.0
        var recentThemeWindowSessions: Int = 12
        var historyWindowDays: Int = 180

        var preferenceChangeInitialDampening: Double = 0.02
        var preferenceChangeRecoveryCurvePower: Double = 1.0
        var preferenceChangeSessionsToRecover: Double = 2.0
        var preferenceChangePreChangeSessionWeight: Double = 0.01

        var diversityPenaltyBase: Double = 900.0
        var diversityPenaltyExplorationRelief: Double = 0.9
        var jitterRange: Double = 120.0
        var jitterExplorationScale: Double = 1.0

        var intensityExactBonus: Double = 900.0
        var intensityOffBy1Bonus: Double = 450.0
        var intensityOffBy2Bonus: Double = 150.0
        var intensityWeight: Double = 1.0

        var environmentBonus: Double = 600.0
        var environmentWeight: Double = 1.0
        var environmentAnchorMin: Double = 8.0

        var noveltyBase: Double = 20.0
        var noveltyMaxGap: Double = 70.0
        var noveltyWeight: Double = 1.0

        var equipmentOwnedBonus: Double = 400.0
        var equipmentPerMissingPenalty: Double = 900.0
        var equipmentBigGearPenalty: Double = 3500.0
        var equipmentWeight: Double = 1.0

        var timePenaltyHard: Double = 1200.0
        var timePenaltyMedium: Double = 900.0
        var timePenaltyLight: Double = 400.0
        var timePenaltyWeight: Double = 1.0

        var excludeExistingActivities: Bool = false

        var ageWeight: Double = 0.0
        var ageTeenHighRiskPenalty: Double = 600.0
    }

    func buildUserThemeProfile(from user: UserInfo) -> [Theme: Double] {
        // Snapshot up-front. `UserInfo` is a SwiftData model and can update underneath us.
        let existing = Array(user.existingActivities)
        guard !existing.isEmpty else {
            var profile: [Theme: Double] = [:]
            for t in Theme.allCases { profile[t] = 0 }
            profile[user.environment] = 100
            return profile
        }

        var sums: [Theme: Double] = [:]
        for t in Theme.allCases { sums[t] = 0 }

        for activity in existing {
            for (theme, pts) in activity.themePoints {
                sums[theme, default: 0] += Double(pts)
            }
        }

        let n = Double(existing.count)
        for theme in sums.keys {
            sums[theme] = (sums[theme] ?? 0) / n
        }

        let total = sums.values.reduce(0, +)
        guard total > 0 else { return [user.environment: 100] }

        var normalized: [Theme: Double] = [:]
        for (theme, value) in sums {
            normalized[theme] = value * (100.0 / total)
        }
        return normalized
    }

    func existingSet(from user: UserInfo) -> Set<Activity> {
        Set(Array(user.existingActivities))
    }

    private func existingEquipmentSet(from user: UserInfo) -> Set<Equipment> {
        Set(Array(user.existingEquipment))
    }

    private func missingEquipment(for activity: Activity, owned: Set<Equipment>) -> Set<Equipment> {
        activity.requiredEquipment.subtracting(owned)
    }

    private let bigGear: Set<Equipment> = [
        .kayak, .canoe, .paddleboard, .surfboard,
        .skis, .snowboard
    ]

    struct HistorySignal {
        let profile: [Theme: Double]
        let confidence: Double
        let totalWeight: Double
        let recentPrimaryThemes: [Theme]
    }

    private func historyDampeningMultiplier(for user: UserInfo) -> Double {
        guard let changedAt = user.preferencesLastChangedAt else { return 1.0 }


        let predicate = #Predicate<ActivityTracker> { $0.startedAt >= changedAt }
        let descriptor = FetchDescriptor<ActivityTracker>(predicate: predicate)
        let recentSessions: [ActivityTracker] = (try? modelContext.fetch(descriptor)) ?? []

        let postChangeCount = Double(recentSessions.count)
        let sessionsToRecover = max(0.0001, bias.preferenceChangeSessionsToRecover)
        let t_activity = min(1.0, postChangeCount / sessionsToRecover)

        let dampened = bias.preferenceChangeInitialDampening + (1.0 - bias.preferenceChangeInitialDampening) * t_activity
        return dampened
    }

    private func buildHistorySignal(for user: UserInfo? = nil) -> HistorySignal {
        let now = Date()
        let threshold = Calendar.current.date(byAdding: .day, value: -bias.historyWindowDays, to: now)
            ?? now.addingTimeInterval(-Double(bias.historyWindowDays) * 86400)

        let predicate = #Predicate<ActivityTracker> { $0.startedAt >= threshold }
        let descriptor = FetchDescriptor<ActivityTracker>(predicate: predicate)
        let sessions: [ActivityTracker] = (try? modelContext.fetch(descriptor)) ?? []

        let halfLifeDays = max(1.0, bias.historyHalfLifeDays)
        let lambda = log(2.0) / halfLifeDays

        var sums: [Theme: Double] = [:]
        for t in Theme.allCases { sums[t] = 0 }

        let totalWeight: Double = 0
        var recent: [Theme] = []

        let sorted = sessions.sorted { $0.startedAt > $1.startedAt }

        for (_, session) in sorted.enumerated() {
            let daysSince = max(0, now.timeIntervalSince(session.startedAt) / 86400.0)
            let weight = exp(-lambda * daysSince)

            // Optionally downweight sessions that occurred before the user's last
            // preference change so prior activity history has much less influence.
            var sessionWeight = weight
            if let u = user, let changedAt = u.preferencesLastChangedAt {
                if session.startedAt < changedAt {
                    let clamp = max(0.0, min(1.0, bias.preferenceChangePreChangeSessionWeight))
                    sessionWeight *= clamp
                }
            }

            for (idx, session) in sorted.enumerated() {
                guard let activity = session.activity else { continue }

                for (theme, pts) in activity.themePoints {
                    sums[theme, default: 0] += Double(pts) * sessionWeight
                }

                if idx < max(0, bias.recentThemeWindowSessions), sessionWeight > 1e-6 {
                    recent.append(primaryTheme(of: activity))
                }
            }
        }

        let total = sums.values.reduce(0, +)
        var normalized: [Theme: Double] = [:]
        for t in Theme.allCases { normalized[t] = 0 }

        if total > 0 {
            for (theme, value) in sums {
                normalized[theme] = value * (100.0 / total)
            }
        }

        let confScale = max(0.5, bias.historyConfidenceScale)
        let confidence = 1.0 - exp(-totalWeight / confScale)

        return HistorySignal(
            profile: normalized,
            confidence: max(0.0, min(1.0, confidence)),
            totalWeight: totalWeight,
            recentPrimaryThemes: recent
        )
    }

    private func explorationFactor(for user: UserInfo) -> Double {
        switch user.tryNewPreference {
        case .onlyRelated: return 0.0
        case .oneNew: return 0.25
        case .moreNew: return 0.6
        case .surprise: return 1.0
        case .other: return 0.9
        }
    }

    private func conservatismFactor(for user: UserInfo) -> Double {
        switch user.tryNewPreference {
        case .onlyRelated: return 1.25
        case .oneNew: return 1.0
        case .moreNew: return 0.85
        case .surprise: return 0.7
        case .other: return 1.0
        }
    }

    private func blendUserAndHistoryProfile(
        user: UserInfo,
        userProfile: [Theme: Double],
        history: HistorySignal,
        historyConfidence: Double
    ) -> [Theme: Double] {
        // Use the already-dampened history confidence supplied by the caller.
        var w = historyConfidence

        let explorationGate: Double = {
            switch user.tryNewPreference {
            case .onlyRelated: return 3.20
            case .oneNew: return 2.00
            case .moreNew: return 1.85
            case .surprise: return 0.70
            case .other: return 2.65
            }
        }()

        w = w * explorationGate
        w = max(0.0, min(bias.historyBlendMax, w))

        let historyTotal = history.profile.values.reduce(0, +)
        if historyTotal <= 0 { return userProfile }

        var blended: [Theme: Double] = [:]
        for t in Theme.allCases {
            let u = userProfile[t] ?? 0
            let h = history.profile[t] ?? 0
            blended[t] = (1.0 - w) * u + w * h
        }

        blended = normalizeTo100(blended)

        blended[user.environment] = max((blended[user.environment] ?? 0), bias.environmentAnchorMin)
        blended = normalizeTo100(blended)

        return blended
    }

    private func normalizeTo100(_ dict: [Theme: Double]) -> [Theme: Double] {
        let total = dict.values.reduce(0, +)
        guard total > 0 else { return dict }
        var out = dict
        for t in Theme.allCases {
            out[t] = (out[t] ?? 0) * (100.0 / total)
        }
        return out
    }

    func recommendActivities(count: Int = 5) -> [Activity] {
        guard let user = fetchUserInfo() else { return [] }

        let userProfile = buildUserThemeProfile(from: user)
        let history = buildHistorySignal(for: user)
        
         let dampenedMultiplier = historyDampeningMultiplier(for: user)
         let dampenedHistoryConfidence = history.confidence * dampenedMultiplier
        let blendedProfile = blendUserAndHistoryProfile(user: user, userProfile: userProfile, history: history, historyConfidence: dampenedHistoryConfidence)

        let existing = existingSet(from: user)
        let ownedEq = existingEquipmentSet(from: user)


        let candidates = Activity.allCases
            .filter { $0 != .other }
            .filter { activity in
                if bias.excludeExistingActivities {
                    if user.tryNewPreference == .onlyRelated {
                        return true
                    }
                    return !existing.contains(activity)
                } else {
                    return true
                }
            }
            .filter { activity in
                // Filter out activities that conflict with user limitations
                return !hasConflictingLimitations(activity: activity, userLimitations: user.userLimitations)
            }

        let scored: [(Activity, Double)] = candidates.map { activity in
            (activity, score(activity: activity,
                            user: user,
                            blendedProfile: blendedProfile,
                            userProfile: userProfile,
                            ownedEq: ownedEq,
                            history: history,
                            existing: existing,
                            dampenedHistoryConfidence: dampenedHistoryConfidence))
        }

         if count >= scored.count {
             return scored.sorted { $0.1 > $1.1 }.map(\.0)
         }

         let exploration = explorationFactor(for: user) * randomization * bias.jitterExplorationScale
         let baseThemeDupPenalty = bias.diversityPenaltyBase * (1.0 - (exploration * bias.diversityPenaltyExplorationRelief))

         var remaining = scored
         var selected: [Activity] = []
         var themeCounts: [Theme: Int] = [:]

         while selected.count < count && !remaining.isEmpty {
             var adjustedList: [(Activity, Double, Double, Theme)] = []
             for (activity, baseScore) in remaining {
                 let primary = primaryTheme(of: activity)
                 let dupCount = themeCounts[primary] ?? 0
                 let dupPenalty = Double(dupCount) * baseThemeDupPenalty

                 let jitter = Double.random(in: -bias.jitterRange...bias.jitterRange) * exploration
                 let adjusted = baseScore - dupPenalty + jitter
                 adjustedList.append((activity, adjusted, baseScore, primary))
             }

             adjustedList.sort { a, b in
                 if a.1 == b.1 { return a.2 > b.2 }
                 return a.1 > b.1
             }

             guard let winner = adjustedList.first else { break }
             selected.append(winner.0)
             themeCounts[winner.3, default: 0] += 1

             if let idx = remaining.firstIndex(where: { $0.0 == winner.0 }) {
                 remaining.remove(at: idx)
             } else {
                 break
             }
         }

         return selected
     }

    private func score(
        activity: Activity,
        user: UserInfo,
        blendedProfile: [Theme: Double],
        userProfile: [Theme: Double],
        ownedEq: Set<Equipment>,
        history: HistorySignal,
        existing: Set<Activity>,
        dampenedHistoryConfidence: Double
    ) -> Double {
         var themeDot: Double = 0
         for (theme, w) in blendedProfile {
             let actW = Double(activity.themePoints[theme] ?? 0)
             themeDot += w * actW
         }
         let themeScore = themeDot * bias.themeSimilarityWeight

         let historyVectorBoost: Double = {
             guard dampenedHistoryConfidence > 0 else { return 0 }
             var dot: Double = 0
             for (theme, hW) in history.profile {
                 let actW = Double(activity.themePoints[theme] ?? 0)
                 dot += hW * actW
             }
             return dot * bias.historyVectorBoostWeight * dampenedHistoryConfidence * conservatismFactor(for: user)
         }()

         let recentThemeBoost: Double = {
             guard !history.recentPrimaryThemes.isEmpty else { return 0 }
             let primary = primaryTheme(of: activity)

             var s: Double = 0
             for (i, t) in history.recentPrimaryThemes.enumerated() where t == primary {
                 s += 1.0 / Double(i + 1)
             }
             return s * bias.recentThemeBoostWeight * dampenedHistoryConfidence
         }()

         let intensityBonus: Double = {
             let gap = abs(activity.difficulty - user.intensity)
             switch gap {
             case 0: return bias.intensityExactBonus
             case 1: return bias.intensityOffBy1Bonus
             case 2: return bias.intensityOffBy2Bonus
             default: return 0
             }
         }() * bias.intensityWeight

         let timePenalty: Double = {
             if user.minutesOutside < 30 && activity.difficulty >= 4 { return bias.timePenaltyHard }
             if user.minutesOutside < 45 && activity.difficulty == 5 { return bias.timePenaltyMedium }
             if user.minutesOutside < 60 && activity.difficulty >= 4 { return bias.timePenaltyLight }
             return 0
         }() * bias.timePenaltyWeight

         let envBonus: Double = (primaryTheme(of: activity) == user.environment ? bias.environmentBonus : 0) * bias.environmentWeight

         let noveltyBonus: Double = noveltyBoost(activity: activity, user: user, userProfile: userProfile) * bias.noveltyWeight

         let equipmentScore: Double = equipmentAdjustment(activity: activity, user: user, ownedEq: ownedEq) * bias.equipmentWeight

         let ageAdjustment: Double = ageAdjustmentIfAvailable(activity: activity, user: user) * bias.ageWeight

        var existingBonus: Double = 0
        if user.tryNewPreference == .onlyRelated {
            if existing.contains(activity) {
                existingBonus = 2000.0
            }
        }

         return themeScore
         + historyVectorBoost
         + recentThemeBoost
         + intensityBonus
         + envBonus
         + noveltyBonus
         + equipmentScore
         + ageAdjustment
        - timePenalty
        + existingBonus
     }

     private func noveltyBoost(activity: Activity, user: UserInfo, userProfile: [Theme: Double]) -> Double {
         let factor = explorationFactor(for: user)
         guard factor > 0 else { return 0 }

         let t = primaryTheme(of: activity)
         let userWeight = userProfile[t] ?? 0
         let novelty = max(0, bias.noveltyMaxGap - userWeight)
         return novelty * bias.noveltyBase * factor
     }

     private func equipmentAdjustment(activity: Activity, user: UserInfo, ownedEq: Set<Equipment>) -> Double {
         let required = activity.requiredEquipment
         if required.isEmpty { return 0 }

         let missing = missingEquipment(for: activity, owned: ownedEq)
         if missing.isEmpty { return bias.equipmentOwnedBonus }

         let factor: Double
         switch user.tryNewPreference {
         case .onlyRelated: factor = 1.0
         case .oneNew: factor = 0.9
         case .moreNew: factor = 0.7
         case .surprise: factor = 0.5
         case .other: factor = 1.0
         }

         var penalty = Double(missing.count) * bias.equipmentPerMissingPenalty * factor
         if !missing.intersection(bigGear).isEmpty {
             penalty += bias.equipmentBigGearPenalty * factor
         }

         return -penalty
     }

     /// Set `bias.ageWeight > 0` if your `UserInfo` actually contains `age`.
     private func ageAdjustmentIfAvailable(activity: Activity, user: UserInfo) -> Double {

         let age = user.age
         if age < 18 && activity.difficulty >= 5 {
             return -bias.ageTeenHighRiskPenalty
         }
         return 0
     }

     private func primaryTheme(of activity: Activity) -> Theme {
         activity.themePoints.max(by: { $0.value < $1.value })?.key ?? .other
     }
     
     /// Determines if an activity conflicts with the user's limitations
     private func hasConflictingLimitations(activity: Activity, userLimitations: [UserLimitation]) -> Bool {
         // If user has no limitations, no conflict
         guard !userLimitations.isEmpty else { return false }
         
         // Get the limitations associated with this activity
         let activityLimitations = Set(activity.associatedLimitations)
         let userLimitationSet = Set(userLimitations)
         
         // Check if there's any overlap between user limitations and activity limitations
         return !activityLimitations.intersection(userLimitationSet).isEmpty
     }
 }
