import Foundation
import SwiftData

enum CustomActivityStore {

    @MainActor
    static func fetchAll(in context: ModelContext) -> [CustomActivity] {
        let descriptor = FetchDescriptor<CustomActivity>(sortBy: [SortDescriptor(\.name)])
        return (try? context.fetch(descriptor)) ?? []
    }

    @MainActor
    static func delete(_ activity: CustomActivity, in context: ModelContext) throws {
        context.delete(activity)
        try context.save()
    }

    /// Creates a NEW activity with ALL fields you support.
    @MainActor
    static func create(
        name: String,
        symbolName: String,
        difficulty: Int,
        needDistance: Bool,
        needSteps: Bool,
        metValue: Double?,
        userDescription: String,
        safetyWarnings: [String],
        defaultGoals: [GoalTemplate],
        minMinutes: Int,
        maxMinutes: Int,
        phoneAllowance: PhoneAvailability,
        customEquipment: [CustomEquipment],
        builtInEquipmentIDs: [String],
        in context: ModelContext
    ) throws -> CustomActivity {
        let activity = CustomActivity(
            name: name,
            symbolName: symbolName,
            difficulty: difficulty,
            needDistance: needDistance,
            needSteps: needSteps,
            metValue: metValue,
            userDescription: userDescription,
            safetyWarnings: safetyWarnings,
            defaultGoals: defaultGoals,
            minMinutes: minMinutes,
            maxMinutes: maxMinutes,
            phoneAllowance: phoneAllowance,
            customEquipment: customEquipment,
            builtInEquipmentIDs: builtInEquipmentIDs
        )

        context.insert(activity)
        try context.save()
        return activity
    }

    /// Updates an EXISTING activity.
    @MainActor
    static func update(
        _ activity: CustomActivity,
        name: String,
        symbolName: String,
        difficulty: Int,
        needDistance: Bool,
        needSteps: Bool,
        metValue: Double?,
        userDescription: String,
        safetyWarnings: [String],
        defaultGoals: [GoalTemplate],
        minMinutes: Int,
        maxMinutes: Int,
        phoneAllowance: PhoneAvailability,
        customEquipment: [CustomEquipment],
        builtInEquipmentIDs: [String],
        in context: ModelContext
    ) throws {
        activity.name = name
        activity.symbolName = symbolName
        activity.difficulty = difficulty
        activity.needDistance = needDistance
        activity.needSteps = needSteps
        activity.metValue = metValue
        activity.userDescription = userDescription
        activity.safetyWarnings = safetyWarnings
        activity.defaultGoals = defaultGoals
        activity.minMinutes = minMinutes
        activity.maxMinutes = maxMinutes
        activity.phoneAllowance = phoneAllowance
        activity.customEquipment = customEquipment
        activity.builtInEquipmentIDs = builtInEquipmentIDs

        try context.save()
    }

    /// Convenience: if activity is nil -> create; else -> update.
    @MainActor
    static func upsert(
        activity: CustomActivity?,
        name: String,
        symbolName: String,
        difficulty: Int,
        needDistance: Bool,
        needSteps: Bool,
        metValue: Double?,
        userDescription: String,
        safetyWarnings: [String],
        defaultGoals: [GoalTemplate],
        minMinutes: Int,
        maxMinutes: Int,
        phoneAllowance: PhoneAvailability,
        customEquipment: [CustomEquipment],
        builtInEquipmentIDs: [String],
        in context: ModelContext
    ) throws -> CustomActivity {
        if let activity {
            try update(
                activity,
                name: name,
                symbolName: symbolName,
                difficulty: difficulty,
                needDistance: needDistance,
                needSteps: needSteps,
                metValue: metValue,
                userDescription: userDescription,
                safetyWarnings: safetyWarnings,
                defaultGoals: defaultGoals,
                minMinutes: minMinutes,
                maxMinutes: maxMinutes,
                phoneAllowance: phoneAllowance,
                customEquipment: customEquipment,
                builtInEquipmentIDs: builtInEquipmentIDs,
                in: context
            )
            return activity
        } else {
            return try create(
                name: name,
                symbolName: symbolName,
                difficulty: difficulty,
                needDistance: needDistance,
                needSteps: needSteps,
                metValue: metValue,
                userDescription: userDescription,
                safetyWarnings: safetyWarnings,
                defaultGoals: defaultGoals,
                minMinutes: minMinutes,
                maxMinutes: maxMinutes,
                phoneAllowance: phoneAllowance,
                customEquipment: customEquipment,
                builtInEquipmentIDs: builtInEquipmentIDs,
                in: context
            )
        }
    }
}
