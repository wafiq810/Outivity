//
//  CustomEquipmentStore.swift
//  Outivity
//
//  Created by Wafiq on 1/7/26.
//

import Foundation
import SwiftData

/// Convenience accessors for managing custom equipment in SwiftData.
///
/// This store provides a simple API for fetching and creating custom equipment items.
enum CustomEquipmentStore {
    /// Fetches all custom equipment items.
    static func fetchAll(in context: ModelContext) -> [CustomEquipment] {
        let descriptor = FetchDescriptor<CustomEquipment>(
            sortBy: [SortDescriptor(\.displayName, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// Fetches a custom equipment item by ID.
    static func fetch(id: UUID, in context: ModelContext) -> CustomEquipment? {
        let predicate = #Predicate<CustomEquipment> { $0.id == id }
        let descriptor = FetchDescriptor<CustomEquipment>(predicate: predicate)
        return (try? context.fetch(descriptor))?.first
    }
    
    /// Searches custom equipment by name (case-insensitive partial match).
    static func search(query: String, in context: ModelContext) -> [CustomEquipment] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard !trimmedQuery.isEmpty else {
            return fetchAll(in: context)
        }
        
        let allEquipment = fetchAll(in: context)
        return allEquipment.filter { $0.displayName.lowercased().contains(trimmedQuery) }
    }
    
    /// Creates and inserts a new custom equipment item.
    /// Returns nil if name is empty or if equipment with same name and symbol already exists.
    @discardableResult
    static func create(
        displayName: String,
        symbolName: String = "ellipsis.circle",
        in context: ModelContext
    ) -> CustomEquipment? {
        let cleanName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate that the name is not empty
        guard !cleanName.isEmpty else {
            return nil
        }
        
        // Check if equipment with same name and symbol already exists
        let allEquipment = fetchAll(in: context)
        if allEquipment.contains(where: { $0.displayName == cleanName && $0.symbolName == symbolName }) {
            return nil
        }
        
        let equipment = CustomEquipment(
            displayName: cleanName,
            symbolName: symbolName
        )
        
        context.insert(equipment)
        
        // Attempt to save immediately
        do {
            try context.save()
        } catch {
            print("Failed to save custom equipment: \(error)")
            return nil
        }
        
        return equipment
    }
    
    /// Deletes a custom equipment item.
    static func delete(_ equipment: CustomEquipment, in context: ModelContext) {
        context.delete(equipment)
        
        do {
            try context.save()
        } catch {
            print("Failed to delete custom equipment: \(error)")
        }
    }
    
    /// Deletes multiple custom equipment items.
    static func delete(_ equipment: [CustomEquipment], in context: ModelContext) {
        equipment.forEach { context.delete($0) }
        
        do {
            try context.save()
        } catch {
            print("Failed to delete custom equipment: \(error)")
        }
    }
    
    /// Updates an existing custom equipment item.
    static func update(
        _ equipment: CustomEquipment,
        displayName: String? = nil,
        symbolName: String? = nil,
        in context: ModelContext
    ) {
        if let displayName {
            let cleanName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanName.isEmpty {
                equipment.displayName = cleanName
            }
        }
        
        if let symbolName {
            equipment.symbolName = symbolName
        }
        
        do {
            try context.save()
        } catch {
            print("Failed to update custom equipment: \(error)")
        }
    }
}
