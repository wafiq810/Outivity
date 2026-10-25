import Foundation
import SwiftUI
import UniformTypeIdentifiers
/// Stable identifiers for the tiles in `ActivityStatisticsView`.
/// Store these raw values for persistence
public enum StatsWidget: String, CaseIterable, Codable, Identifiable {
    public var id: String { rawValue }

    case allTimeActivities
    case currentStreak
    case averagePerDay
    case averagePerWeek
    case averagePerMonth
    case averageSessionLength
    case goalsMet

    // Health/movement-derived
    case totalStepsAllTime
    case totalCaloriesAllTime
    case averageStepsPerSession
    case averageCaloriesPerSession
}

extension StatsWidget {
    static var defaultOrder: [StatsWidget] {
        [
            .allTimeActivities,
            .currentStreak,
            .averagePerDay,
            .averagePerWeek,
            .averagePerMonth,
            .averageSessionLength,
            .goalsMet,
            .totalStepsAllTime,
            .totalCaloriesAllTime,
            .averageStepsPerSession,
            .averageCaloriesPerSession,
        ]
    }
}

extension UTType {
    static let statsWidget = UTType(exportedAs: "com.outivity.statswidget")
}


extension StatsWidget: @unchecked Sendable {}

extension StatsWidget: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .statsWidget)
    }
}
