import Foundation
import SwiftData

@Model
public final class CustomActivity {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var symbolName: String
    public var difficulty: Int // 1-5
    
    // Tracking toggles
    public var needDistance: Bool
    public var needSteps: Bool
    
    // Calorie tracking
    // represented by optional MET. If nil, no calorie tracking.
    public var metValue: Double?
    
    // Metadata
    public var userDescription: String
    public var safetyWarnings: [String]

    // Default goals for sessions created from this custom activity
    public var defaultGoals: [GoalTemplate] = []
    
    public var minMinutes: Int
    public var maxMinutes: Int
    
    public var phoneAllowance: PhoneAvailability
    
    // Equipment
    // Relationship to custom equipment
    @Relationship(deleteRule: .nullify)
    public var customEquipment: [CustomEquipment] = []
    
    // Built-in equipment stored as raw Strings
    public var builtInEquipmentIDs: [String] = []
    
    public init(
        id: UUID = UUID(),
        name: String,
        symbolName: String,
        difficulty: Int = 1,
        needDistance: Bool = false,
        needSteps: Bool = false,
        metValue: Double? = nil,
        userDescription: String = "",
        safetyWarnings: [String] = [],
        defaultGoals: [GoalTemplate] = [],
        minMinutes: Int = 15,
        maxMinutes: Int = 60,
        phoneAllowance: PhoneAvailability = .fullyAllowed,
        customEquipment: [CustomEquipment] = [],
        builtInEquipmentIDs: [String] = []
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.difficulty = difficulty
        self.needDistance = needDistance
        self.needSteps = needSteps
        self.metValue = metValue
        self.userDescription = userDescription
        self.safetyWarnings = safetyWarnings
        self.defaultGoals = defaultGoals
        self.minMinutes = minMinutes
        self.maxMinutes = maxMinutes
        self.phoneAllowance = phoneAllowance
        self.customEquipment = customEquipment
        self.builtInEquipmentIDs = builtInEquipmentIDs
    }
}

extension CustomActivity {
    var asMetadata: ActivityMetadata {
        ActivityMetadata(
            description: self.userDescription,
            safetyWarnings: self.safetyWarnings,
            estimatedMinutes: self.minMinutes...self.maxMinutes,
            goalPool: [], // Custom goals fetched separately
            phoneAvailability: self.phoneAllowance,
            sources: []
        )
    }
}
