
import Foundation
import SwiftData

@Model
final class CustomGoal {
    @Attribute(.unique) var id: UUID
    var title: String
    var difficulty: Int
    
    // Links to parent activity
    // Predicate rule: Use denormalized ID fields
    var customActivityID: UUID?
    
    // For builtin activities
    var builtInActivityID: String?
    
    init(
        id: UUID = UUID(),
        title: String,
        difficulty: Int = 1,
        customActivityID: UUID? = nil,
        builtInActivityID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.difficulty = difficulty
        self.customActivityID = customActivityID
        self.builtInActivityID = builtInActivityID
    }
}
