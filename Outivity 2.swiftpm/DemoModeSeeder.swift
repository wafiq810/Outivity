import Foundation
import SwiftData
import UIKit

/// Seeds demo content into SwiftData so views like "Your progress" and "History" have data.
///
/// This is intended for judging/demo only and runs once per install when demo mode is enabled.
@MainActor
enum DemoModeSeeder {
    static func ensureSeededIfNeeded(in context: ModelContext) {
        UserInfoStore.ensureSingleInstance(in: context)
        let userInfo = UserInfoStore.fetchOrCreate(in: context)

        guard userInfo.demoMode else { return }
        guard userInfo.demoSeededAt == nil else { return }

        seed(in: context, userInfo: userInfo)
    }

    private static func seed(in context: ModelContext, userInfo: UserInfo) {
        let base = Calendar.current.startOfDay(for: Date())

        // Seed some custom objects too so demo mode isn't empty in Custom/BackPack screens.
        let seededCustomEquipment = seedCustomEquipment(in: context, base: base)
        let seededCustomActivities = seedCustomActivities(in: context, base: base, equipment: seededCustomEquipment)
        seedBackPacks(in: context, base: base, customActivities: seededCustomActivities, customEquipment: seededCustomEquipment)

        // A small, varied set of demo sessions over the last month.
        // Keep this deterministic so demos look consistent.
        let demo: [(activity: Activity, daysAgo: Int, minutes: Int, steps: Int?, distanceMeters: Double?, calories: Double?)] = [
            (.hiking, 2, 55, nil, 4200, 360),
            (.running, 4, 32, 5200, 5100, 410),
            (.biking, 7, 48, nil, 11900, 520),
            (.soccer, 10, 70, 6400, nil, 680),
            (.basketball, 14, 45, 4300, nil, 520),
            (.trailWalking, 18, 35, 3800, 2900, 170),
            (.kayaking, 23, 40, nil, 2600, 300)
        ]

        for item in demo {
            guard let start = Calendar.current.date(byAdding: .day, value: -item.daysAgo, to: base) else { continue }
            let end = start.addingTimeInterval(TimeInterval(max(5, item.minutes) * 60))

            let tracker = ActivityTracker(activity: item.activity, startedAt: start, endedAt: end)
            tracker.totalSteps = item.steps
            tracker.totalDistance = item.distanceMeters
            tracker.estimatedCalories = item.calories

            context.insert(tracker)

            // Freeze goals so goal completion widgets have something to show.
            let goals = tracker.ensureGoals(in: context)

            // Mark the first goal as completed.
            if let first = goals.first {
                tracker.toggleGoalCompleted(first.id, at: end)
            }

            // Add a photo to a couple of sessions so Progress/Gallery feels alive.
            if item.daysAgo <= 10 {
                attachDemoPhotoIfPossible(to: tracker, in: context)
            }
        }

        userInfo.demoSeededAt = Date()

        do {
            try context.save()
        } catch {
            print("[DemoModeSeeder] Failed to save demo seed: \(error)")
        }
    }

    private static func seedCustomEquipment(in context: ModelContext, base: Date) -> [CustomEquipment] {
        // Small set of realistic items (SF Symbols).
        let items: [(name: String, symbol: String, daysAgo: Int)] = [
            ("Yoga Mat", "figure.yoga", 4),
            ("Resistance Bands", "line.3.horizontal.decrease.circle", 12),
            ("Climbing Shoes", "shoe.2", 20)
        ]

        var results: [CustomEquipment] = []
        results.reserveCapacity(items.count)

        for item in items {
            let createdAt = Calendar.current.date(byAdding: .day, value: -item.daysAgo, to: base) ?? base
            let equipment = CustomEquipment(displayName: item.name, symbolName: item.symbol, createdAt: createdAt)
            context.insert(equipment)
            results.append(equipment)
        }

        return results
    }

    private static func seedCustomActivities(
        in context: ModelContext,
        base: Date,
        equipment: [CustomEquipment]
    ) -> [CustomActivity] {
        // Link to a subset of the custom equipment.
        let yogaMat = equipment.first(where: { $0.displayName == "Yoga Mat" })
        let bands = equipment.first(where: { $0.displayName == "Resistance Bands" })

        let mobility = CustomActivity(
            name: "Mobility Flow",
            symbolName: "figure.cooldown",
            difficulty: 2,
            needDistance: false,
            needSteps: false,
            metValue: 3.0,
            userDescription: "A 20–30 minute full-body mobility routine to feel looser and recover faster.",
            safetyWarnings: ["Move slowly through end ranges.", "Stop if you feel sharp pain."],
            minMinutes: 20,
            maxMinutes: 35,
            phoneAllowance: .fullyAllowed,
            customEquipment: [yogaMat, bands].compactMap { $0 },
            builtInEquipmentIDs: []
        )

        let hillSprints = CustomActivity(
            name: "Urban Hill Sprints",
            symbolName: "figure.run",
            difficulty: 4,
            needDistance: true,
            needSteps: true,
            metValue: 9.0,
            userDescription: "Short, uphill sprint intervals. Great for conditioning when you don't have much time.",
            safetyWarnings: ["Warm up first.", "Choose a safe route away from traffic."],
            minMinutes: 12,
            maxMinutes: 25,
            phoneAllowance: .allowedWithRisk,
            customEquipment: [],
            builtInEquipmentIDs: []
        )

        // Make demo content look older than 'now' a bit.
        _ = base // kept for possible future customization

        context.insert(mobility)
        context.insert(hillSprints)
        return [mobility, hillSprints]
    }

    private static func seedBackPacks(
        in context: ModelContext,
        base: Date,
        customActivities: [CustomActivity],
        customEquipment: [CustomEquipment]
    ) {
        // 1) A backpack for a built-in activity
        let hikePack = BackPack(
            name: "Weekend Hike",
            colorRaw: BackPackColor.teal.rawValue,
            createdAt: Calendar.current.date(byAdding: .day, value: -6, to: base) ?? base,
            activity: .hiking,
            customActivityID: nil,
            equipment: [.waterBottle, .sunscreen, .hat],
            customEquipment: Array(customEquipment.prefix(1)),
            backPackDescription: "My default pack for short trails."
        )
        context.insert(hikePack)

        // 2) A backpack for a custom activity (by ID)
        if let mobility = customActivities.first(where: { $0.name == "Mobility Flow" }) {
            let mobilityPack = BackPack(
                name: "Mobility Kit",
                colorRaw: BackPackColor.purple.rawValue,
                createdAt: Calendar.current.date(byAdding: .day, value: -15, to: base) ?? base,
                activity: nil,
                customActivityID: mobility.id,
                equipment: [],
                customEquipment: customEquipment.filter { $0.displayName == "Yoga Mat" || $0.displayName == "Resistance Bands" },
                backPackDescription: "Everything I need for a quick mobility session."
            )
            context.insert(mobilityPack)
        }
    }

    private static func attachDemoPhotoIfPossible(to tracker: ActivityTracker, in context: ModelContext) {
        let assets = DemoModePhotos.availableAssetNames()
        guard !assets.isEmpty else { return }

        // Pick an asset deterministically per tracker so demo is stable.
        let seed = Int(tracker.startedAt.timeIntervalSinceReferenceDate)
        let name = assets[abs(seed) % assets.count]

        guard let image = UIImage(named: name) else { return }

        let jpeg = image.jpegData(compressionQuality: 0.85)
        let thumb = image
            .preparingThumbnail(of: CGSize(width: 300, height: 300))?
            .jpegData(compressionQuality: 0.7)

        tracker.addPhoto(
            thumbnail: thumb,
            fullImage: jpeg,
            contentType: "image/jpeg",
            goalID: nil,
            goalTitle: nil,
            isFromCamera: false,
            in: context
        )
    }
}
