//
//  UserLimitation.swift
//  Outivity
//
//  Created by Assistant on 2/25/26.
//

import Foundation

/// Represents various physical, sensory, or other limitations that may affect activity participation.
/// Used to filter activity recommendations and ensure appropriate suggestions for users.
public enum UserLimitation: String, CaseIterable, Codable, Identifiable, Sendable {
    public var id: String { rawValue }
    
    // Visual limitations
    case lowVision = "Low Vision"
    case blindness = "Blindness"
    case colorBlindness = "Color Blindness"
    
    // Mobility limitations
    case wheelchairUser = "Wheelchair User"
    case walkingAid = "Uses Walking Aid"
    case limitedMobility = "Limited Mobility"
    case amputee = "Amputee"
    
    // Physical limitations
    case heartCondition = "Heart Condition"
    case breathingDifficulty = "Breathing Difficulty"
    case jointIssues = "Joint Issues"
    case backProblems = "Back Problems"
    case balanceIssues = "Balance Issues"
    
    // Sensory limitations
    case hearingImpairment = "Hearing Impairment"
    case deafness = "Deafness"
    
    // Cognitive/Neurological
    case cognitiveImpairment = "Cognitive Impairment"
    case epilepsy = "Epilepsy"
    case anxietyDisorder = "Anxiety Disorder"
    
    // Environmental/Safety
    case waterFear = "Fear of Water"
    case heightFear = "Fear of Heights"
    case allergySevere = "Severe Allergies"
    
    // Temporary limitations
    case recentInjury = "Recent Injury"
    case postSurgery = "Post-Surgery Recovery"
    
    /// User-facing display name
    public var displayName: String { rawValue }
    
    /// Short description of how this limitation might affect activities
    public var description: String {
        switch self {
        case .lowVision:
            return "Difficulty seeing details, may need well-lit or familiar environments"
        case .blindness:
            return "Cannot see, requires accessible paths and audio guidance"
        case .colorBlindness:
            return "Difficulty distinguishing certain colors, may affect navigation"
            
        case .wheelchairUser:
            return "Requires wheelchair-accessible paths and facilities"
        case .walkingAid:
            return "Uses crutches, walker, or cane for mobility assistance"
        case .limitedMobility:
            return "Reduced ability to move or walk long distances"
        case .amputee:
            return "Missing limb(s), may require adaptive equipment"
            
        case .heartCondition:
            return "Should avoid high-intensity or strenuous activities"
        case .breathingDifficulty:
            return "May have trouble with activities requiring sustained exertion"
        case .jointIssues:
            return "Arthritis or joint problems may limit certain movements"
        case .backProblems:
            return "Should avoid activities with heavy lifting or twisting"
        case .balanceIssues:
            return "Difficulty maintaining balance, avoid uneven terrain"
            
        case .hearingImpairment:
            return "Partial hearing loss, may need visual cues for safety"
        case .deafness:
            return "Cannot hear, requires visual safety alerts and communication"
            
        case .cognitiveImpairment:
            return "May need simplified instructions or supervision"
        case .epilepsy:
            return "Should avoid activities with flashing lights or extreme stress"
        case .anxietyDisorder:
            return "May prefer calm, familiar environments over crowded areas"
            
        case .waterFear:
            return "Uncomfortable or fearful around water activities"
        case .heightFear:
            return "Fearful of elevated places or climbing activities"
        case .allergySevere:
            return "May have severe reactions to environmental allergens"
            
        case .recentInjury:
            return "Currently recovering from an injury, activities may be limited"
        case .postSurgery:
            return "In recovery period following surgery, reduced activity level"
        }
    }
    
    /// SF Symbol name for UI representation
    public var symbolName: String {
        switch self {
        case .lowVision, .blindness:
            return "eye.slash"
        case .colorBlindness:
            return "eyedropper.halffull"
            
        case .wheelchairUser:
            return "figure.roll"
        case .walkingAid:
            return "figure.walk.motion"
        case .limitedMobility, .amputee:
            return "figure.walk.diamond"
            
        case .heartCondition:
            return "heart.text.square"
        case .breathingDifficulty:
            return "lungs"
        case .jointIssues:
            return "figure.flexibility"
        case .backProblems:
            return "figure.stand.line.dotted.figure.stand"
        case .balanceIssues:
            return "figure.mind.and.body"
            
        case .hearingImpairment, .deafness:
            return "ear.trianglebadge.exclamationmark"
            
        case .cognitiveImpairment:
            return "brain.head.profile"
        case .epilepsy:
            return "bolt.horizontal"
        case .anxietyDisorder:
            return "heart.circle"
            
        case .waterFear:
            return "drop.triangle"
        case .heightFear:
            return "mountain.2"
        case .allergySevere:
            return "allergens"
            
        case .recentInjury:
            return "bandage"
        case .postSurgery:
            return "cross.case"
        }
    }
    
    /// Category grouping for UI organization
    public var category: LimitationCategory {
        switch self {
        case .lowVision, .blindness, .colorBlindness:
            return .visual
        case .wheelchairUser, .walkingAid, .limitedMobility, .amputee:
            return .mobility
        case .heartCondition, .breathingDifficulty, .jointIssues, .backProblems, .balanceIssues:
            return .physical
        case .hearingImpairment, .deafness:
            return .auditory
        case .cognitiveImpairment, .epilepsy, .anxietyDisorder:
            return .cognitive
        case .waterFear, .heightFear, .allergySevere:
            return .environmental
        case .recentInjury, .postSurgery:
            return .temporary
        }
    }
}

/// Categories for organizing limitations in the UI
public enum LimitationCategory: String, CaseIterable, Codable {
    case visual = "Visual"
    case mobility = "Mobility"
    case physical = "Physical"
    case auditory = "Auditory"
    case cognitive = "Cognitive/Neurological"
    case environmental = "Environmental/Safety"
    case temporary = "Temporary"
    
    public var displayName: String { rawValue }
    
    public var symbolName: String {
        switch self {
        case .visual: return "eye"
        case .mobility: return "figure.walk"
        case .physical: return "heart"
        case .auditory: return "ear"
        case .cognitive: return "brain.head.profile"
        case .environmental: return "exclamationmark.triangle"
        case .temporary: return "clock"
        }
    }
    
    public var limitations: [UserLimitation] {
        UserLimitation.allCases.filter { $0.category == self }
    }
}