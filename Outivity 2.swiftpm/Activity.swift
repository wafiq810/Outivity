// Activity.swift
// Shared activity names used across the app

import Foundation
import SwiftData
/// A shared, string-backed enum of activity names that can be used in UI and persisted where needed.
/// Conforms to `Codable` so it can be stored as a transformable value if desired.
public enum Activity: String, CaseIterable, Codable, Identifiable, Sendable {
    public var id: String { rawValue }
    
    // Core activities
        case hiking = "Hiking"
        case biking = "Biking"
        case running = "Running"
        case climbing = "Climbing"
        case fishing = "Fishing"
        case camping = "Camping"
        case swimming = "Swimming"
        case beach = "Beach"

        // Water activities
        case kayaking = "Kayaking"
        case canoeing = "Canoeing"
        case surfing = "Surfing"
        case paddleboarding = "Paddleboarding"
        case snorkeling = "Snorkeling"
        case scubaDiving = "Scuba Diving"
        case riverCanoe = "River Canoe"

        // Winter / snow sports
        case skiing = "Skiing"
        case snowboarding = "Snowboarding"
        case iceSkating = "Ice Skating"
        case snowHiking = "Snow Hiking"
        case snowPlay = "Snow Play"

        // Urban / nature exploration
        case trailWalking = "Trail Walking"
        case forestExploring = "Forest Exploring"
        case wildlifeSpotting = "Wildlife Spotting"
        case birdWatching = "Bird Watching"
        case stargazing = "Stargazing"
        case photographyWalk = "Photography Walk"
        case picnic = "Picnic"
        case outdoorYoga = "Outdoor Yoga"
        case outdoorMeditation = "Outdoor Meditation"
        case hammockResting = "Hammock Resting"
        case rockHopping = "Rock Hopping"
        case bonfireNight = "Bonfire Night"

        // Outdoor team sports
        case soccer = "Soccer"
        case basketball = "Basketball"
        case tennis = "Tennis"
        case volleyball = "Volleyball"
        case cricket = "Cricket"
        case baseball = "Baseball"
        case outdoorBadminton = "Outdoor Badminton"

        // Fallback
        case other = "Other"
    
    /// A user-facing display name (currently same as rawValue, kept here for future localization)
    public var displayName: String { rawValue }
    
    /// A simple SF Symbol name you can use with `Image(systemName:)` if you want icons for activities.
    public var symbolName: String {
            switch self {
            case .hiking: return "figure.walk"
            case .biking: return "bicycle"
            case .running: return "figure.run"
            case .climbing: return "figure.climbing"
            case .fishing: return "fish"
            case .camping: return "tent"
            case .swimming: return "figure.pool.swim"
            case .beach: return "water.waves"

            case .kayaking: return "drop"
            case .canoeing: return "sailboat"
            case .surfing: return "figure.surfing"
            case .paddleboarding: return "figure.stand"
            case .snorkeling: return "bubbles.and.sparkles"
            case .scubaDiving: return "lungs"
            case .riverCanoe: return "water.waves.and.arrow.down"

            case .skiing: return "figure.skiing.downhill"
            case .snowboarding: return "figure.snowboarding"
            case .iceSkating: return "figure.ice.skating"
            case .snowHiking: return "figure.walk.circle"
            case .snowPlay: return "snowflake"

            case .trailWalking: return "figure.walk.motion"
            case .forestExploring: return "tree"
            case .wildlifeSpotting: return "pawprint"
            case .birdWatching: return "bird"
            case .stargazing: return "moon.stars"
            case .photographyWalk: return "camera"
            case .picnic: return "basket"
            case .outdoorYoga: return "figure.cooldown"
            case .outdoorMeditation: return "figure.mind.and.body"
            case .hammockResting: return "leaf"
            case .rockHopping: return "mountain.2"
            case .bonfireNight: return "flame"

            case .soccer: return "soccerball"
            case .basketball: return "basketball"
            case .tennis: return "tennisball"
            case .volleyball: return "volleyball"
            case .cricket: return "figure.cricket"
            case .baseball: return "baseball"
            case .outdoorBadminton: return "figure.badminton"

            case .other: return "ellipsis"
            }
        }
    

    
    public var requiredEquipment: Set<Equipment> {
        switch self {
            // Core
            case .hiking:
            return [.comfyShoes, .waterBottle]
            case .biking:
                return [.comfyShoes, .waterBottle]
            case .running:
                return [.comfyShoes, .waterBottle]
            case .climbing:
                return [.comfyShoes, .firstAidKit]
            case .fishing:
                return [.hat, .sunscreen,.fishingRod]
            case .camping:
            return [.tent, .sleepingBag, .flashlight, .bugSpray, .firstAidKit]
            case .swimming:
                return [.swimsuit, .towel]
            case .beach:
                return [.sunscreen, .towel]

            // Water
            case .kayaking:
                return [.kayak, .lifeJacket]
            case .canoeing:
                return [.canoe, .lifeJacket]
            case .surfing:
                return [.surfboard]
            case .paddleboarding:
                return [.paddleboard]
            case .snorkeling:
                return [.snorkelMask]
            case .scubaDiving:
                return []
            case .riverCanoe:
                return [.canoe, .lifeJacket]

            // Winter
            case .skiing:
                return [.skis, .winterJacket, .gloves]
            case .snowboarding:
                return [.snowboard, .winterJacket, .gloves]
            case .iceSkating:
                return [.skates]
            case .snowHiking:
                return [.winterJacket, .gloves]
            case .snowPlay:
                return [.winterJacket, .gloves]

            // Chill / nature
            case .trailWalking:
                return [.comfyShoes]
            case .forestExploring:
                return [.comfyShoes]
            case .wildlifeSpotting:
                return [.comfyShoes]
            case .birdWatching:
                return [.comfyShoes]
            case .stargazing:
                return [] // none required
            case .photographyWalk:
                return [.camera]
            case .picnic:
                return [] // optional
            case .outdoorYoga:
                return [] // yoga mat optional
            case .outdoorMeditation:
                return [] // none
            case .hammockResting:
                return [] // hammock optional
            case .rockHopping:
                return [.comfyShoes]
            case .bonfireNight:
                return [] // none required

            // Team sports
            case .soccer:
                return [.soccerBall]
            case .basketball:
                return [.basketball]
            case .tennis:
                return [.tennisRacket]
            case .volleyball:
                return [.volleyball]
            case .cricket:
                return [.cricketBat]
            case .baseball:
                return [.baseballGlove]
            case .outdoorBadminton:
                return [.badmintonRacket]

            case .other:
                return []
            }
        }
    
    public var themePoints: [Theme: Int] {
        switch self {
            
            // Water aligned
        case .beach: return [.water: 60, .chillNature: 30, .adventure: 10]
        case .kayaking: return [.water: 70, .adventure: 20, .trails: 10]
        case .canoeing: return [.water: 50, .chillNature: 30, .adventure: 20]
        case .paddleboarding: return [.water: 65, .chillNature: 25, .adventure: 10]
        case .snorkeling: return [.water: 75, .adventure: 15, .chillNature: 10]
        case .scubaDiving: return [.water: 40, .adventure: 50, .chillNature: 10]
        case .riverCanoe: return [.water: 50, .adventure: 30, .chillNature: 20]
            
            // Trails / Nature aligned
        case .hiking: return [.trails: 70, .adventure: 20, .chillNature: 10]
        case .biking: return [.trails: 60, .teamSports: 20, .adventure: 20]
        case .running: return [.trails: 65, .adventure: 25, .chillNature: 10]
        case .trailWalking: return [.trails: 80, .chillNature: 15, .adventure: 5]
        case .forestExploring: return [.trails: 60, .chillNature: 30, .adventure: 10]
        case .wildlifeSpotting: return [.trails: 50, .chillNature: 40, .adventure: 10]
        case .birdWatching: return [.trails: 40, .chillNature: 55, .water: 5]
            
            // Team outdoor sports
        case .soccer: return [.teamSports: 85, .adventure: 10, .chillNature: 5]
        case .basketball: return [.teamSports: 80, .chillNature: 10, .adventure: 10]
        case .tennis: return [.teamSports: 75, .chillNature: 15, .adventure: 10]
        case .volleyball: return [.teamSports: 60, .water: 20, .adventure: 10, .chillNature: 10]
        case .cricket: return [.teamSports: 90, .chillNature: 10]
        case .baseball: return [.teamSports: 88, .adventure: 12]
        case .outdoorBadminton: return [.teamSports: 82, .chillNature: 15, .adventure: 3]
            
            // Winter aligned
        case .skiing: return [.winter: 90, .adventure: 10]
        case .snowboarding: return [.winter: 85, .adventure: 15]
        case .iceSkating: return [.winter: 70, .teamSports: 20, .chillNature: 10]
        case .snowHiking: return [.winter: 75, .trails: 20, .adventure: 5]
        case .snowPlay: return [.winter: 60, .chillNature: 40]
            
            // Chill outdoors
        case .picnic: return [.chillNature: 85, .trails: 10, .water: 5]
        case .stargazing: return [.chillNature: 60, .winter: 25, .trails: 15]
        case .photographyWalk: return [.chillNature: 65, .trails: 30, .adventure: 5]
        case .outdoorYoga: return [.chillNature: 55, .water: 20, .trails: 20, .adventure: 5]
        case .outdoorMeditation: return [.chillNature: 90, .winter: 10]
        case .hammockResting: return [.chillNature: 95, .trails: 5]
        case .rockHopping: return [.adventure: 50, .trails: 40, .water: 10]
        case .bonfireNight: return [.winter: 50, .chillNature: 40, .adventure: 10]
            
            // Pure adventure
        case .climbing: return [.adventure: 85, .trails: 15]
        case .surfing: return [.water: 55, .adventure: 45]
        case .fishing: return [.water: 70, .chillNature: 25, .adventure: 5]
            
            // Other fallback
        default: return [.other: 100]
        }
    }
    
    /// A difficulty score on a 1 (very easy) to 5 (very hard) scale.
    /// Use this for sorting, filtering, or showing a difficulty indicator in the UI.
    public var difficulty: Int {
        switch self {
            case .hiking: return 3
            case .biking: return 3
            case .running: return 4
            case .climbing: return 5
            case .fishing: return 1
            case .camping: return 2
            case .swimming: return 3
            case .beach: return 1

            case .kayaking: return 3
            case .canoeing: return 2
            case .surfing: return 4
            case .paddleboarding: return 2
            case .snorkeling: return 2
            case .scubaDiving: return 5
            case .riverCanoe: return 3

            case .skiing: return 4
            case .snowboarding: return 5
            case .iceSkating: return 2
            case .snowHiking: return 3
            case .snowPlay: return 1

            case .trailWalking: return 1
            case .forestExploring: return 2
            case .wildlifeSpotting: return 1
            case .birdWatching: return 1
            case .stargazing: return 1
            case .photographyWalk: return 1
            case .picnic: return 1
            case .outdoorYoga: return 2
            case .outdoorMeditation: return 1
            case .hammockResting: return 1
            case .rockHopping: return 3
            case .bonfireNight: return 1

            case .soccer: return 4
            case .basketball: return 4
            case .tennis: return 3
            case .volleyball: return 3
            case .cricket: return 2
            case .baseball: return 3
            case .outdoorBadminton: return 2

            case .other: return 0
            }
        }
    
    /// The summary Metabolic Equivalent of a Task (MET) used to calculate average calorie burned during an activity
    /// this information is compiled from the `United States National Cancer Institute Division of Cancer Control & Population Sciences` (Public Domain)
    /// The chart used can be found here: `https://epi.grants.cancer.gov/physical/met/atus-met.php?major%5B%5D=01&major%5B%5D=02&major%5B%5D=03&major%5B%5D=04&major%5B%5D=06&major%5B%5D=07&major%5B%5D=08&major%5B%5D=09&major%5B%5D=10&major%5B%5D=11&major%5B%5D=12&major%5B%5D=13&major%5B%5D=14&major%5B%5D=15&major%5B%5D=16&keywords=&metval_min=&metval_max=`
    ///
    /// The Specific Category of each activities are commented next it. A MET value for some activities may not be appropriete.
    public var summaryMET: Double? {
        switch self {
        case .hiking: return 6.00            // (16 Hiking)
        case .biking: return 8.00            // (04 Biking)
        case .running: return 7.50           // (24 Running)
        case .climbing: return 9.50          // (08 Climbing, spelunking, caving)
        case .fishing: return 4.50           // (12 Fishing)
        case .camping: return nil

        case .swimming: return 5.22          // (32 Participating in water sports)
        case .beach: return nil

        case .kayaking: return 5.22          // (32 Participating in water sports)
        case .canoeing: return 5.22          // (32 Participating in water sports)
        case .surfing: return 5.22           // (32 Participating in water sports)
        case .paddleboarding: return 5.22    // (32 Participating in water sports)
        case .snorkeling: return 5.22        // (32 Participating in water sports)
        case .scubaDiving: return 5.22       // (32 Participating in water sports)
        case .riverCanoe: return 5.22        // (32 Participating in water sports)

        case .skiing: return 7.00            // (25 Skiing, ice skating, snowboarding)
        case .snowboarding: return 7.00      // (25 Skiing, ice skating, snowboarding)
        case .iceSkating: return 7.00        // (25 Skiing, ice skating, snowboarding)
        case .snowHiking: return 6.00        // (16 Hiking)
        case .snowPlay: return 5.10          // (99 Playing sports, n.e.c.)

        case .trailWalking: return 3.80      // (31 Walking)
        case .forestExploring: return 3.80   // (31 Walking)
        case .wildlifeSpotting: return nil
        case .birdWatching: return nil
        case .stargazing: return nil
        case .photographyWalk: return nil
        case .picnic: return nil
        case .outdoorYoga: return 3.00       // (36 Doing yoga)
        case .outdoorMeditation: return 1.21 // (01 Relaxing, thinking)
        case .hammockResting: return 1.21    // (01 Relaxing, thinking)
        case .rockHopping: return 5.10       // (99 Playing sports, n.e.c.)
        case .bonfireNight: return nil

        case .soccer: return 7.00            // (26 Playing soccer)
        case .basketball: return 8.00        // (03 Playing basketball)
        case .tennis: return 8.50            // (20 Racquet Sport)
        case .volleyball: return 5.50        // (30 Playing volleyball)
        case .cricket: return 5.10           // (99 Playing sports, n.e.c.)
        case .baseball: return 5.00          // (02 Playing baseball)
        case .outdoorBadminton: return 5.10  // (99 Playing sports, n.e.c.)

        case .other: return nil
        }
    }

    public var needDistance: Bool {
        switch self {
        case .hiking, .biking, .running, .kayaking, .canoeing, .surfing,
             .paddleboarding, .trailWalking, .forestExploring, .snowHiking,
             .soccer, .basketball, .tennis, .volleyball, .cricket, .baseball,
             .outdoorBadminton, .climbing:
            return true

        case .fishing, .camping, .swimming, .beach, .snorkeling,
             .scubaDiving, .riverCanoe, .skiing, .snowboarding,
             .iceSkating, .snowPlay, .birdWatching, .stargazing,
             .photographyWalk, .picnic, .outdoorYoga, .outdoorMeditation,
             .hammockResting, .rockHopping, .bonfireNight, .wildlifeSpotting,
             .other:
            return false
        }
    }

    
    public var needStepCount: Bool {
        switch self {
        case .hiking, .running, .trailWalking, .forestExploring, .soccer, .basketball, .tennis, .volleyball, .cricket, .baseball,
                .outdoorBadminton:
            return true
        case .biking, .climbing, .fishing, .camping, .swimming, .beach,
             .kayaking, .canoeing, .surfing, .paddleboarding, .snorkeling,
             .scubaDiving, .riverCanoe, .skiing, .snowboarding, .iceSkating,
             .snowHiking, .snowPlay, .photographyWalk, .picnic, .outdoorYoga,
             .outdoorMeditation, .hammockResting, .rockHopping, .bonfireNight,
             .other, .wildlifeSpotting, .stargazing, .birdWatching:
            return false
        }
    }

    
    /// Difficulty name
    public var difficultyLevel: String {
        switch difficulty {
        case 1: return "Very Easy"
        case 2: return "Easy"
        case 3: return "Moderate"
        case 4: return "Hard"
        case 5: return "Very Hard"
        default: return "Unknown"
        }
    }
    
    /// Limitations that may make this activity challenging or unsafe
    public var associatedLimitations: [UserLimitation] {
        switch self {
        // Core activities
        case .hiking:
            return [.limitedMobility, .wheelchairUser, .walkingAid, .heartCondition, .breathingDifficulty, .balanceIssues, .recentInjury, .postSurgery]
        case .biking:
            return [.limitedMobility, .wheelchairUser, .walkingAid, .amputee, .balanceIssues, .heartCondition, .recentInjury, .postSurgery]
        case .running:
            return [.limitedMobility, .wheelchairUser, .walkingAid, .amputee, .heartCondition, .breathingDifficulty, .jointIssues, .recentInjury, .postSurgery]
        case .climbing:
            return [.limitedMobility, .wheelchairUser, .walkingAid, .amputee, .heartCondition, .breathingDifficulty, .balanceIssues, .heightFear, .recentInjury, .postSurgery]
        case .fishing:
            return [.allergySevere] // minimal limitations for this calm activity
        case .camping:
            return [.wheelchairUser, .allergySevere, .cognitiveImpairment] // needs accessible facilities
        case .swimming:
            return [.waterFear, .heartCondition, .breathingDifficulty, .recentInjury, .postSurgery]
        case .beach:
            return [.wheelchairUser, .allergySevere] // sand can be challenging for wheelchairs
            
        // Water activities
        case .kayaking, .canoeing, .riverCanoe:
            return [.waterFear, .limitedMobility, .wheelchairUser, .walkingAid, .amputee, .heartCondition, .breathingDifficulty, .balanceIssues, .recentInjury, .postSurgery]
        case .surfing:
            return [.waterFear, .limitedMobility, .wheelchairUser, .walkingAid, .amputee, .heartCondition, .breathingDifficulty, .balanceIssues, .recentInjury, .postSurgery]
        case .paddleboarding:
            return [.waterFear, .limitedMobility, .wheelchairUser, .walkingAid, .amputee, .balanceIssues, .heartCondition, .recentInjury, .postSurgery]
        case .snorkeling:
            return [.waterFear, .breathingDifficulty, .heartCondition, .anxietyDisorder, .recentInjury, .postSurgery]
        case .scubaDiving:
            return [.waterFear, .breathingDifficulty, .heartCondition, .anxietyDisorder, .epilepsy, .recentInjury, .postSurgery] // requires certification and medical clearance
            
        // Winter sports
        case .skiing, .snowboarding:
            return [.limitedMobility, .wheelchairUser, .walkingAid, .amputee, .balanceIssues, .heartCondition, .breathingDifficulty, .lowVision, .blindness, .recentInjury, .postSurgery]
        case .iceSkating:
            return [.limitedMobility, .wheelchairUser, .walkingAid, .amputee, .balanceIssues, .recentInjury, .postSurgery]
        case .snowHiking:
            return [.limitedMobility, .wheelchairUser, .walkingAid, .heartCondition, .breathingDifficulty, .balanceIssues, .lowVision, .blindness, .recentInjury, .postSurgery]
        case .snowPlay:
            return [.allergySevere] // generally accessible for most people
            
        // Urban / nature exploration
        case .trailWalking:
            return [.limitedMobility, .wheelchairUser, .walkingAid, .balanceIssues, .recentInjury, .postSurgery]
        case .forestExploring:
            return [.limitedMobility, .wheelchairUser, .walkingAid, .balanceIssues, .allergySevere, .recentInjury, .postSurgery]
        case .wildlifeSpotting, .birdWatching:
            return [.wheelchairUser, .allergySevere] // may need accessible paths
        case .stargazing:
            return [.wheelchairUser] // needs accessible viewing areas
        case .photographyWalk:
            return [.limitedMobility, .wheelchairUser, .walkingAid, .lowVision, .blindness, .recentInjury, .postSurgery]
        case .picnic:
            return [.wheelchairUser, .allergySevere] // needs accessible picnic areas
        case .outdoorYoga:
            return [.limitedMobility, .balanceIssues, .backProblems, .jointIssues, .recentInjury, .postSurgery]
        case .outdoorMeditation:
            return [.wheelchairUser, .allergySevere] // needs accessible seating
        case .hammockResting:
            return [.limitedMobility, .wheelchairUser, .walkingAid, .balanceIssues, .backProblems, .recentInjury, .postSurgery]
        case .rockHopping:
            return [.limitedMobility, .wheelchairUser, .walkingAid, .amputee, .balanceIssues, .heartCondition, .recentInjury, .postSurgery]
        case .bonfireNight:
            return [.wheelchairUser, .allergySevere, .breathingDifficulty] // smoke and accessibility concerns
            
        // Team sports
        case .soccer:
            return [.limitedMobility, .wheelchairUser, .walkingAid, .amputee, .heartCondition, .breathingDifficulty, .balanceIssues, .recentInjury, .postSurgery]
        case .basketball:
            return [.limitedMobility, .wheelchairUser, .walkingAid, .amputee, .heartCondition, .breathingDifficulty, .balanceIssues, .recentInjury, .postSurgery]
        case .tennis, .outdoorBadminton:
            return [.limitedMobility, .wheelchairUser, .walkingAid, .amputee, .heartCondition, .breathingDifficulty, .balanceIssues, .recentInjury, .postSurgery]
        case .volleyball:
            return [.limitedMobility, .wheelchairUser, .walkingAid, .amputee, .heartCondition, .breathingDifficulty, .balanceIssues, .recentInjury, .postSurgery]
        case .cricket, .baseball:
            return [.limitedMobility, .wheelchairUser, .walkingAid, .amputee, .heartCondition, .breathingDifficulty, .lowVision, .blindness, .recentInjury, .postSurgery]
            
        case .other:
            return [] // user-defined activity, can't predict limitations
        }
    }
}


