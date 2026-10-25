//
//  BackPack.swift
//  Outivity
//
//  Created by Wafiq on 1/7/26.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class BackPack {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date

    /// Persist selected color as the enum raw value
    var colorRaw: String?

    /// Optional activity associated with this backpack
    var activity: Activity?

    var customActivityID: UUID?
    
    /// Persist built-in enum equipment selections
    var equipment: [Equipment]

    
    ///Description about backpack
    var backPackDescription: String?
    /// Relationship to reusable custom equipment models
    @Relationship(deleteRule: .nullify) var customEquipment: [CustomEquipment]

    init(
        id: UUID = UUID(),
        name: String,
        colorRaw: String? = nil,
        createdAt: Date = .now,
        activity: Activity? = nil,
        customActivityID: UUID? = nil,
        equipment: [Equipment] = [],
        customEquipment: [CustomEquipment] = [],
        backPackDescription: String? = ""
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.colorRaw = colorRaw
        self.createdAt = createdAt
        self.activity = activity
        self.customActivityID = customActivityID
        self.equipment = equipment
        self.customEquipment = customEquipment
        self.backPackDescription = backPackDescription
    }

    /// Convert stored color raw value to a Color for UI
    var color: Color {
        if let raw = colorRaw, let c = BackPackColor(rawValue: raw) {
            return c.color
        }
        return .white
    }

    var colorEnum: BackPackColor? {
        guard let raw = colorRaw else { return nil }
        return BackPackColor(rawValue: raw)
    }
    
    
}


enum BackPackColor: String, CaseIterable, Identifiable, Codable {
    case primary
    case red
    case blue
    case green
    case orange
    case yellow
    case purple
    case pink
    case teal
    case indigo
    case mint
    case cyan
    case brown
    case gray

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .primary: return .primary
        case .red: return .red
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .yellow: return .yellow
        case .purple: return .purple
        case .pink: return .pink
        case .teal: return .teal
        case .indigo: return .indigo
        case .mint: return .mint
        case .cyan: return .cyan
        case .brown: return .brown
        case .gray: return .gray
        }
    }
}
