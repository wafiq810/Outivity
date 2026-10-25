//
//  CustomEquipment.swift
//  Outivity
//
//  Created by Wafiq on 1/7/26.
//

import Foundation
import SwiftData

@Model
public final class CustomEquipment {
    @Attribute(.unique) public var id: UUID
    public var displayName: String
    public var symbolName: String
    public var createdAt: Date
    
    @Relationship(inverse: \CustomActivity.customEquipment)
    public var activities: [CustomActivity] = []
    
    @Relationship(inverse: \BackPack.customEquipment)
    var backpacks: [BackPack] = []

    public init(
        id: UUID = UUID(),
        displayName: String,
        symbolName: String = "ellipsis.circle",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.symbolName = symbolName
        self.createdAt = createdAt
    }
}
