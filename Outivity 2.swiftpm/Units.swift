import Foundation

enum PreferredUnits: String, CaseIterable, Codable, Identifiable {
    var id: String { rawValue }

    case imperial
    case metric

    var displayName: String {
        switch self {
        case .imperial: return "Imperial"
        case .metric: return "Metric"
        }
    }
}

enum UnitsFormatter {
    /// Distance
    static func distanceString(meters: Double?, units: PreferredUnits, fallback: String = "—") -> String {
        guard let meters, meters.isFinite else { return fallback }

        let clamped = max(0, meters)
        switch units {
        case .imperial:
            let miles = clamped / 1609.344
            return String(format: "%.2f mi", miles)
        case .metric:
            let km = clamped / 1000.0
            return String(format: "%.2f km", km)
        }
    }

///Weight
    static func weightString(pounds: Int, units: PreferredUnits) -> String {
        let lb = max(0, pounds)
        switch units {
        case .imperial:
            return "\(lb) lb"
        case .metric:
            let kg = Double(lb) * 0.45359237
            return "\(Int(kg.rounded())) kg"
        }
    }
}
