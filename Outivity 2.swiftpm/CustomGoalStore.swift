
import Foundation
import SwiftData

enum CustomGoalStore {
    @MainActor
    static func fetchGoals(for identity: ActivityIdentity, in context: ModelContext) -> [CustomGoal] {
        switch identity.kind {
        case .builtIn(let activity):
             let name = activity.rawValue
             let predicate = #Predicate<CustomGoal> { $0.builtInActivityID == name }
             let descriptor = FetchDescriptor<CustomGoal>(predicate: predicate, sortBy: [SortDescriptor(\.title)])
             return (try? context.fetch(descriptor)) ?? []
             
        case .custom(let uuid):
             let predicate = #Predicate<CustomGoal> { $0.customActivityID == uuid }
             let descriptor = FetchDescriptor<CustomGoal>(predicate: predicate, sortBy: [SortDescriptor(\.title)])
             return (try? context.fetch(descriptor)) ?? [] 
        }
    }
    
    @MainActor
    static func fetchAll(in context: ModelContext) -> [CustomGoal] {
         let descriptor = FetchDescriptor<CustomGoal>()
         return (try? context.fetch(descriptor)) ?? []
    }
    
    @MainActor
    static func delete(_ goal: CustomGoal, in context: ModelContext) {
        context.delete(goal)
        try? context.save()
    }
    
    @MainActor
    static func create(title: String, difficulty: Int, for identity: ActivityIdentity, in context: ModelContext) -> CustomGoal {
        let goal: CustomGoal
        switch identity.kind {
        case .builtIn(let activity):
             goal = CustomGoal(title: title, difficulty: difficulty, builtInActivityID: activity.rawValue)
        case .custom(let uuid):
             goal = CustomGoal(title: title, difficulty: difficulty, customActivityID: uuid)
        }
        context.insert(goal)
        try? context.save()
        return goal
    }
}
