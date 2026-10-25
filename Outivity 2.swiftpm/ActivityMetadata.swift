//
//  ActivityMetadate.swift
//  Outivity-pretest
//
//  Created by Wafiq on 12/25/25.
//

import Foundation
import CryptoKit

public struct ActivityMetadata: Codable, Sendable {
    public let description: String
    public let safetyWarnings: [String]
    public let estimatedMinutes: ClosedRange<Int>
    public let goalPool: [GoalTemplate]

    // NEW
    public let phoneAvailability: PhoneAvailability
    public let sources: [SourceTemplate]

    public init(
        description: String,
        safetyWarnings: [String] = [],
        estimatedMinutes: ClosedRange<Int> = 15...1440,
        goalPool: [GoalTemplate] = [],
        phoneAvailability: PhoneAvailability,
        sources: [SourceTemplate]
    ) {
        self.description = description
        self.safetyWarnings = safetyWarnings
        self.estimatedMinutes = estimatedMinutes
        self.goalPool = goalPool

        self.phoneAvailability = phoneAvailability
        self.sources = sources
    }
}

public struct GoalTemplate: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let difficulty: Int
    public var isCustom: Bool = false

    /// Create a goal template. If `id` is not provided, generate a stable UUID derived from the title
    /// so IDs remain consistent across app launches (important for persisting references).
    public init(id: UUID? = nil, title: String, difficulty: Int, isCustom: Bool = false) {
        self.title = title
        self.difficulty = difficulty
        self.isCustom = isCustom
        if let explicit = id {
            self.id = explicit
        } else {
            self.id = GoalTemplate.stableUUID(from: title)
        }
    }

    private static func stableUUID(from string: String) -> UUID {
        let data = Data(string.utf8)
        let hash = SHA256.hash(data: data)
        let bytes = Array(hash)
        let first16 = bytes.prefix(16)
        let hex = first16.map { String(format: "%02x", $0) }.joined()
        let part1 = String(hex.prefix(8))
        let part2 = String(hex.dropFirst(8).prefix(4))
        let part3 = String(hex.dropFirst(12).prefix(4))
        let part4 = String(hex.dropFirst(16).prefix(4))
        let part5 = String(hex.dropFirst(20).prefix(12))
        let uuidString = [part1, part2, part3, part4, part5].joined(separator: "-")
        return UUID(uuidString: uuidString) ?? UUID()
    }
}

public struct SourceTemplate: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let description: String?
    public let hyperLink: String

    public init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        hyperLink: String
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.hyperLink = hyperLink
    }
}

public enum PhoneAvailability: Codable, Hashable, Sendable {
    case notAllowed
    case allowedWithRisk
    case fullyAllowed
}

@MainActor public let activityMetadataTable: [Activity: ActivityMetadata] = [

    // Core outdoors
    .hiking: ActivityMetadata(
        description: "Hiking is a walking adventure on trails that can range from easy, flat paths to steep climbs. It’s a great way to explore nature, build endurance, and clear your mind. You can go solo for reflection or with friends for a shared challenge. Pick a route that matches your fitness and daylight time.",
        safetyWarnings: [
            "Know your fitness level and choose a trail you can finish without exhaustion or injury",
            "Hike with at least one other person so help is available if needed",
            "For high elevations, sleep well, hydrate often, and don’t rush to reduce altitude illness risk",
            "Carry your phone charged and protected, but never depend on reception or it as a survival tool",
            "Always pack essentials plus extra water and snacks in case your hike takes longer than planned",
            "Wear sturdy rubber-soled shoes and moisture-wicking socks to prevent slips and blisters",
            "Check weather and park alerts before starting, and carry rain gear with a backup plan",
            "Set and obey a turnaround time so you don’t get caught in the dark or unsafe conditions",
            "Keep your group together by letting the slowest hiker set the pace and yielding to uphill hikers",
            "Avoid crossing rivers or climbing near cliffs or waterfalls unless depth and footing are certain",
            "Use insect repellent and long clothing, and check yourself for ticks during and after hiking",
            "Store food securely and avoid strong scents so you don’t attract wildlife"
        ],
        estimatedMinutes: 45...240,
        goalPool: [
            GoalTemplate(title: "Complete a short loop trail", difficulty: 1),
            GoalTemplate(title: "Hike for 60 minutes without long stops", difficulty: 2),
            GoalTemplate(title: "Climb 300 ft of elevation gain", difficulty: 3),
            GoalTemplate(title: "Stay on marked trails the entire hike", difficulty: 1),
            GoalTemplate(title: "Take 5 nature photos you’re proud of", difficulty: 1),
            GoalTemplate(title: "Pack and use a simple trail snack", difficulty: 1),
            GoalTemplate(title: "Identify 3 plants or trees", difficulty: 2),
            GoalTemplate(title: "Finish a moderate trail (3–5 miles)", difficulty: 3),
            GoalTemplate(title: "Practice steady pacing on climbs", difficulty: 3),
            GoalTemplate(title: "Do a 10-minute cooldown stretch after", difficulty: 2)
        ],
        phoneAvailability: .fullyAllowed,
        
        sources: [
            SourceTemplate(title: "Hike Smart", description: "Must-know's about hiking from the official US National Park Service.", hyperLink: "https://www.nps.gov/articles/hiking-safety.htm")
        ]
    ),

    .biking: ActivityMetadata(
        description: "Biking is a versatile activity that can be relaxed cruising or a serious cardio workout. Ride on roads, trails, or bike paths depending on your comfort level. It builds leg strength, stamina, and balance while letting you cover more distance than walking. Choose a route with safe surfaces and manageable traffic.",
        safetyWarnings: [
            "Treat your bicycle as a vehicle and obey all road signs, signals, and lane rules",
            "Always wear a properly fitted helmet and adjust straps using a mirror or a helper for accuracy",
            "Ride a bike that fits you and confirm the brakes and tires work before every ride",
            "Keep both hands on the handlebars unless signaling, and never ride more than one person per seat",
            "Wear bright or reflective clothing and use a white front light and red rear light in low visibility or at night",
            "Tie shoelaces and secure loose pant legs to prevent them from catching in the chain",
            "Carry items in a backpack or strap them to the rear rack instead of holding them",
            "Ride in the same direction as traffic and stay out of blind spots whenever possible",
            "Assume drivers haven’t seen you and scan ahead for potholes, toys, pebbles, grates, or tracks that can cause falls",
            "Avoid texting, music, or anything that distracts your eyes, ears, or attention from traffic",
            "Minimize sidewalk riding because drivers don’t expect bike traffic there and may back out or turn without looking",
            "If riding on sidewalks is unavoidable, check local laws, slow at crossings, watch pedestrians, and pass them carefully with a bell or a verbal alert",
            "Practice in safe areas like parks or empty parking lots before riding in traffic to build control and confidence",
            "Take a bike safety or on-bike navigation class through school or community programs to improve defensive riding skills",
            "Drivers should yield to cyclists like other vehicles and never underestimate their speed",
            "In parking lots or at intersections, look left-right-left and behind before turning, backing up, or moving on red",
            "Pass cyclists only when it’s safe to change lanes, leaving full room like you would for any vehicle",
            "Turning right on red requires a full stop and a shoulder-and-rear check to avoid cyclists approaching from the right rear",
            "Slow down for weather, road conditions, or congestion and never pass cyclists too closely"
        ],
        estimatedMinutes: 30...180,
        goalPool: [
            GoalTemplate(title: "Ride 3 miles at an easy pace", difficulty: 1),
            GoalTemplate(title: "Practice smooth braking and cornering", difficulty: 2),
            GoalTemplate(title: "Ride continuously for 45 minutes", difficulty: 2),
            GoalTemplate(title: "Complete a 10-mile ride", difficulty: 3),
            GoalTemplate(title: "Climb one moderate hill without stopping", difficulty: 4),
            GoalTemplate(title: "Maintain a steady cadence for 10 minutes", difficulty: 3),
            GoalTemplate(title: "Drink water at least once mid-ride", difficulty: 1),
            GoalTemplate(title: "Try a new safe route or trail section", difficulty: 2),
            GoalTemplate(title: "Do a 5-minute cooldown easy spin", difficulty: 1),
            GoalTemplate(title: "Check and clean your bike after the ride", difficulty: 2)
        ],
        phoneAvailability: .fullyAllowed,
        
        sources: [
            SourceTemplate(title: "Biking Safety", description: "Cautions to take during and before biking. ", hyperLink: "https://www.nhtsa.gov/road-safety/bicycle-safety")
        ]
    ),

    .running: ActivityMetadata(
        description: "Running is a simple, powerful cardio workout that improves heart health, endurance, and mental resilience. You can run outdoors on sidewalks, trails, or tracks and adjust the pace to match your current fitness. Consistency matters more than speed at first. Warm up, start easy, and build distance gradually to avoid injury.",
        safetyWarnings: [
            "Share your route and timing with at least one trusted person before you run",
            "Carry identification to help first responders assist you quickly if needed",
            "Pick neighborhoods and paths that are wide, well-lit, and free of hidden blind spots like alleys or tight doorways",
            "Run facing oncoming traffic so you can clearly see approaching vehicles or hazards",
            "Keep headphone volume low enough to hear your surroundings and avoid clothing that blocks peripheral vision",
            "Wear reflective or high-visibility gear when running at night in populated, well-lit areas"
        ],
        estimatedMinutes: 20...120,
        goalPool: [
            GoalTemplate(title: "Run/walk for 20 minutes total", difficulty: 2),
            GoalTemplate(title: "Run continuously for 10 minutes", difficulty: 2),
            GoalTemplate(title: "Complete a 5K distance (run/walk allowed)", difficulty: 3),
            GoalTemplate(title: "Keep a steady pace for 15 minutes", difficulty: 3),
            GoalTemplate(title: "Do a 5-minute warmup and cooldown", difficulty: 1),
            GoalTemplate(title: "Run a route with one moderate hill", difficulty: 4),
            GoalTemplate(title: "Practice relaxed breathing for 10 minutes", difficulty: 2),
            GoalTemplate(title: "Run with good posture and light steps", difficulty: 3),
            GoalTemplate(title: "Try interval training (1 min fast/2 min easy)", difficulty: 4),
            GoalTemplate(title: "Stretch calves/hips after the run", difficulty: 2)
        ],
        phoneAvailability: .fullyAllowed,
        
        sources: [
            SourceTemplate(title: "Protect Yourself: Running Safety", hyperLink: "https://www.ncdps.gov/blog/2020/02/12/protect-yourself-running-safety")
        ]
    ),

    .climbing: ActivityMetadata(
        description: "Climbing is an outdoor or indoor challenge that builds strength, problem-solving, and confidence. Whether bouldering or rope climbing, it demands focus, balance, and careful movement. Beginners should learn safe technique and, for roped climbing, proper belay skills. Start with easier routes and prioritize safety over difficulty.",
        safetyWarnings: [
            "Climb only routes that match your training and physical ability level",
            "Check that your gear, harness, and ropes are undamaged before climbing",
            "Double-check anchors, knots, and attachments every time before you ascend",
            "Always wear a helmet to protect from rock impact or falling debris",
            "Know your route and track your location using reliable tools like a map or compass",
            "Set a turnaround time and ensure someone knows your full climbing plan",
            "Check weather forecasts beforehand and be ready to descend if conditions worsen",
            "Use clear verbal or non-verbal communication signals your group understands",
            "Prepare for self-rescue because rescue services may not reach you quickly or at all",
            "During emergencies, call for help loudly and provide exact details to 911 or rescuers if a phone is available"
        ],
        estimatedMinutes: 30...180,
        goalPool: [
            GoalTemplate(title: "Warm up shoulders and fingers for 10 minutes", difficulty: 2),
            GoalTemplate(title: "Complete 3 easy routes focusing on technique", difficulty: 2),
            GoalTemplate(title: "Practice controlled downclimbing (bouldering)", difficulty: 3),
            GoalTemplate(title: "Try one slightly harder route and rest appropriately", difficulty: 4),
            GoalTemplate(title: "Focus on foot placement for a full session", difficulty: 3),
            GoalTemplate(title: "Practice 5 minutes of balance drills on easy holds", difficulty: 3),
            GoalTemplate(title: "Learn or review safety checks and knots", difficulty: 2),
            GoalTemplate(title: "Do 10 minutes of technique drills (flagging, edging)", difficulty: 4),
            GoalTemplate(title: "Cool down forearms and stretch shoulders", difficulty: 2),
            GoalTemplate(title: "Stop before form breaks down from fatigue", difficulty: 3)
        ],
        phoneAvailability: .allowedWithRisk,
        
        sources: [
            SourceTemplate(title: "Staying Safe", description: "Safety tips during climbing.", hyperLink: "https://www.nps.gov/subjects/climbing/staying-safe.htm")
        ]
    ),

    .fishing: ActivityMetadata(
        description: "Fishing is a calm outdoor activity that rewards patience, observation, and a little technique. You can fish from shore, a dock, or a boat, and it’s a great way to slow down and enjoy nature. Even when the fish aren’t biting, you can practice casting and reading the water. Bring the basics and follow local regulations.",
        safetyWarnings: [
            "Always wear a U.S. Coast Guard–approved life jacket when fishing on, in, or near water",
            "Assign a dedicated Water Watcher to actively supervise children and weak swimmers at all times",
            "Apply broad-spectrum sunscreen regularly and wear hats, long sleeves, pants, and sunglasses to prevent sun damage",
            "Handle hooks carefully, check behind you before casting, and wear shoes to prevent hook and foot injuries",
            "Fish only in areas where fishing is permitted and never enter closed or restricted park zones",
            "Monitor water temperature and leave the water immediately if you feel cold to prevent hypothermia",
            "Check the weather forecast and seek shelter during thunderstorms or rising water levels",
            "Use caution when wading or walking in water due to unseen hazards like currents, drop-offs, or submerged debris",
            "Assess swift water carefully and prepare properly before attempting any river crossing",
            "Track tides closely in coastal areas and move to higher ground if incoming tides threaten your exit",
            "Stay alert for wildlife near fishing areas and know how to respond to animal encounters",
            "Use designated fish cleaning stations and dispose of remains properly to avoid attracting wildlife"
        ],
        estimatedMinutes: 30...240,
        goalPool: [
            GoalTemplate(title: "Practice 20 accurate casts", difficulty: 2),
            GoalTemplate(title: "Set up safely and keep gear organized", difficulty: 1),
            GoalTemplate(title: "Identify 2 likely fish-holding spots", difficulty: 2),
            GoalTemplate(title: "Learn one new knot (e.g., improved clinch)", difficulty: 2),
            GoalTemplate(title: "Try one new lure/bait setup", difficulty: 2),
            GoalTemplate(title: "Stay patient and focused for 45 minutes", difficulty: 2),
            GoalTemplate(title: "Handle a fish safely and release correctly", difficulty: 3),
            GoalTemplate(title: "Clean your area and leave no trash", difficulty: 1),
            GoalTemplate(title: "Check your line and retie if frayed", difficulty: 2),
            GoalTemplate(title: "Log what worked (time, lure, conditions)", difficulty: 1)
        ],
        phoneAvailability: .fullyAllowed,
        
        sources: [
            SourceTemplate(title: "Reel It In: Be Prepared for a Successful Fishing Day", hyperLink: "https://www.nps.gov/articles/fishing-safety.htm")
        ]
    ),

    .camping: ActivityMetadata(
        description: "Camping is spending time outdoors with a temporary shelter, usually a tent, to rest, cook, and explore nature. It can be relaxing, adventurous, or both depending on your setup. Camping builds self-reliance and helps you disconnect from daily routines. Preparation is key: plan food, shelter, weather gear, and safety basics.",
        safetyWarnings: [
            "Plan your trip: Think about the setting, time of year, difficulty level and duration, and pack accordingly.",
            "Before setting out on your trip, take a look at the “Planning” section on the park’s information site.",
            "Ask a friend or family member not going on the trip to be an emergency contact and leave your travel itinerary with him/her.",
            "Test your equipment. Consider testing your equipment prior to your trip for a smooth camping or backcountry adventure.",
            "Before you head out, check in with your family and friends to see how they feel. Any activities you may have planned will depend on your group's ability to do them.",
            "Depending on where you camp, you may be able to talk to a park ranger or a campsite host. They'll likely have current information about the park's outdoor conditions, regulations, and possible alerts.",
            "To ensure safety within your campground, follow appropriate guidelines for distances between food and sleeping spaces, food storage and disposal, and other factors that apply to a safe camping experience.",
            "Campfire safety is important to prevent injuries and wildfires. Learn how to properly make, maintain and extinguish campfires.",
            "While on site, focus on personal safery such as awareness of yourself, family and friends, environment, make sure equipment is working properly throughout the trip, and check the weather regularly.",
            "Respect wildlife: Do NOT feed wildlife under any circumstances, avoid contact with wildlife, keep safe viewing distances, and avoid attracting wildlife to your campsite.",
            "After the trip, Let your emergency contact know you ended your trip safe and sound.",
            "Clean up your campsite, ensure that your campfire is extinguished and be sure to reference the seven principles of Leave No Trace.",
            "Share your experience!"
            
        ],
        estimatedMinutes: 120...1440,
        goalPool: [
            GoalTemplate(title: "Set up camp efficiently and safely", difficulty: 2),
            GoalTemplate(title: "Cook one simple camp meal", difficulty: 2),
            GoalTemplate(title: "Keep a clean campsite (food storage)", difficulty: 2),
            GoalTemplate(title: "Learn to pitch your tent properly", difficulty: 2),
            GoalTemplate(title: "Take a short nature walk from camp", difficulty: 1),
            GoalTemplate(title: "Practice Leave No Trace cleanup", difficulty: 2),
            GoalTemplate(title: "Check gear and pack down properly", difficulty: 2),
            GoalTemplate(title: "Stay warm and dry overnight", difficulty: 3),
            GoalTemplate(title: "Try stargazing for 10 minutes", difficulty: 1),
            GoalTemplate(title: "Sleep a full night outdoors comfortably", difficulty: 3)
        ],
        phoneAvailability: .fullyAllowed,
        
        sources: [
            SourceTemplate(title: "Camping Safely Step 1 - Before the Trip", hyperLink: "https://www.nps.gov/articles/camp-safety-before-the-trip.htm"),
            SourceTemplate(title: "Camping Safely Step 2 - Upon Arrival", hyperLink: "https://www.nps.gov/articles/camp-safety-upon-arrival.htm"),
            SourceTemplate(title: "Camping Safely Step 3 - During Your Stay", hyperLink: "https://www.nps.gov/articles/camp-safety-during-your-stay.htm"),
            SourceTemplate(title: "Camping Safely Step 4 - After the Trip", hyperLink: "https://www.nps.gov/articles/camp-safety-after-the-trip.htm")
        ]
    ),

    .swimming: ActivityMetadata(
        description: "Swimming is a full-body workout that builds endurance, strength, and breath control with low impact on joints. You can swim laps for fitness or enjoy open-water swimming for adventure. Technique matters—small form improvements can make swimming easier and safer. Choose a setting that matches your skill level.",
        safetyWarnings: [
            "Never swim alone and always keep a buddy within sight to help during emergencies",
            "Actively supervise all swimmers, not just kids, because drowning can be silent and fast",
            "Learn to swim through formal lessons since it is a core lifesaving skill for everyone",
            "Stay away from drains or suction outlets and never enter water with broken or missing drain covers",
            "Make sure pools and spas have compliant, secure drain covers because suction can trap even adults",
            "Use safety gear like Coast Guard approved life jackets when swimming in lakes, rivers, or oceans",
            "Check for currents and, if caught in one, swim with the flow until you can exit safely",
            "Take hydration and sun-safety breaks, avoid alcohol, and stay alert near water",
            "Swim only in designated or marked areas to avoid unseen hazards under the surface",
            "Exit the water immediately if weather shifts, tides rise, or rivers turn muddy or faster",
            "Use protective barriers, fences, covers, or alarms around pools to prevent accidental falls-in",
            "Get CPR certified and keep certification current because bystanders are often first responders",
            "Avoid algae bloom zones and seek medical help if sickness follows exposure",
            "Take the Pool Safely Pledge as a personal reminder to practice responsible water safety"
        ],
        estimatedMinutes: 20...90,
        goalPool: [
            GoalTemplate(title: "Swim continuously for 10 minutes (easy)", difficulty: 2),
            GoalTemplate(title: "Complete 10 pool lengths with rests", difficulty: 2),
            GoalTemplate(title: "Practice breathing rhythm (e.g. every 3 strokes)", difficulty: 3),
            GoalTemplate(title: "Do 4 × 50m/yd steady intervals", difficulty: 3),
            GoalTemplate(title: "Practice streamline push-offs each length", difficulty: 2),
            GoalTemplate(title: "Tread water for 3 minutes", difficulty: 2),
            GoalTemplate(title: "Try one technique drill (kickboard, catch-up)", difficulty: 3),
            GoalTemplate(title: "Warm up shoulders gently before starting", difficulty: 1),
            GoalTemplate(title: "Cool down with easy swimming for 5 minutes", difficulty: 1),
            GoalTemplate(title: "Hydrate before and after the session", difficulty: 1)
        ],
        phoneAvailability: .notAllowed,
        
        sources: [
            SourceTemplate(title: "Safety Tips", description: "Swimming safety tips for all ages", hyperLink: "https://www.poolsafely.gov/parents/safety-tips/"),
            SourceTemplate(title: "Swimming Safety", hyperLink: "https://tpwd.texas.gov/state-parks/park-information/safety/swimming-safety")
        ]
    ),

    .beach: ActivityMetadata(
        description: "A beach day can be relaxing or active—walking the shoreline, playing games, or simply enjoying the water and sun. It’s a great setting for social time and mindful breaks. Plan around tides, weather, and how long you’ll be in the sun. A little preparation makes the day far more comfortable.",
        safetyWarnings: [
            "Swim near a lifeguard and choose guarded beaches whenever possible for the lowest drowning risk",
            "Check surf zone forecasts and beach closures before entering the water",
            "Never turn your back to the ocean and watch for unpredictable larger waves, including sneaker waves",
            "Assume waves are stronger than they look because even small ones can knock you down with extreme force",
            "Learn to swim since it is the most essential personal safety skill in coastal water",
            "Avoid texting, loud headphones, or anything that reduces awareness of approaching waves or hazards",
            "Stay on marked paths when walking near cliffs or rocks because they can be slippery or unstable from erosion",
            "Avoid walking or digging at the base of cliffs or bluffs due to the risk of sudden falling rocks",
            "Stay far from logs in the surf zone since the ocean can roll even multi-ton water-soaked logs without warning",
            "Track incoming tides, especially near tidepools or secluded shorelines, to avoid being stranded",
            "If caught in a rip current, stay calm and swim parallel to shore to exit, then return at an angle",
            "Use sunscreen, hats, and sunglasses, and take hydration breaks to prevent sun and heat illness",
            "Wear Coast Guard approved life jackets if swimming conditions are rough or visibility is poor",
            "Keep beach fires on open sand away from vegetation, and extinguish them with water, never sand",
            "Stay away from drains or suction outlets in pools or spas and avoid water with broken or missing drain covers",
        ],
        estimatedMinutes: 60...360,
        goalPool: [
            GoalTemplate(title: "Apply sunscreen before sun exposure", difficulty: 1),
            GoalTemplate(title: "Take a 20-minute shoreline walk", difficulty: 1),
            GoalTemplate(title: "Drink water at least twice during the visit", difficulty: 1),
            GoalTemplate(title: "Set up a tidy base (towel, shade, trash bag)", difficulty: 1),
            GoalTemplate(title: "Play one beach game (frisbee, paddle ball)", difficulty: 2),
            GoalTemplate(title: "Do 10 minutes of stretching on the sand", difficulty: 2),
            GoalTemplate(title: "Collect and dispose of litter you find", difficulty: 2),
            GoalTemplate(title: "Spend 10 minutes mindful listening to waves", difficulty: 1),
            GoalTemplate(title: "Swim only in designated safe areas", difficulty: 2),
            GoalTemplate(title: "Leave with everything you brought (no trace)", difficulty: 1)
        ],
        phoneAvailability: .fullyAllowed,
        
        sources: [
            SourceTemplate(title: "Be safe exploring the beach", hyperLink: "https://stateparks.oregon.gov/index.cfm?do=v.page&id=96"),
            SourceTemplate(title: "Beach Safety", hyperLink: "https://www.weather.gov/safety/beach")
        ]
    ),

    // Water activities
    .kayaking: ActivityMetadata(
        description: "Kayaking is a paddle sport that lets you explore lakes, rivers, or calm coastal water from a small boat. It’s both relaxing and athletic, working your core, shoulders, and coordination. Beginners do best on flat, sheltered water with minimal wind. With practice, you can build speed, control, and confidence.",
        safetyWarnings: [
            "Use only a sea kayak on open or windy Lake Superior, never a recreational kayak, canoe, or unfit boat",
            "Wear a Coast Guard approved life jacket, wetsuit, and whistle or whistle alternative like a whistle-ready PFD",
            "Carry a whistle and paddle with others who know how to perform water rescues",
            "Check the marine forecast and local weather buoys before launching because lake conditions change fast",
            "Have a float plan shared with someone who cares, including your route and expected return time",
            "Practice self-rescue skills, including re-entry into your kayak from cold or deep water",
            "Wear a wetsuit on cold open water since cold water can be deadly even in summer",
            "Avoid kayaking alone, pets included, especially on open or rough waters",
            "Expect long rescue times, so rely on preparation and self-rescue, not immediate external help",
            "If weather turns rough, get to shore or safe landing only when conditions allow safe movement",
            "Cold water kills quickly, so always stay geared, practiced, and aware to survive immersion"
        ],
        estimatedMinutes: 30...180,
        goalPool: [
            GoalTemplate(title: "Do a safety check (PFD, whistle, leash)", difficulty: 2),
            GoalTemplate(title: "Practice forward stroke technique for 10 minutes", difficulty: 3),
            GoalTemplate(title: "Paddle steadily for 20 minutes", difficulty: 2),
            GoalTemplate(title: "Practice turning strokes (sweep) both sides", difficulty: 3),
            GoalTemplate(title: "Keep a relaxed grip to reduce fatigue", difficulty: 2),
            GoalTemplate(title: "Try a short out-and-back route close to shore", difficulty: 2),
            GoalTemplate(title: "Practice stopping and bracing safely", difficulty: 4),
            GoalTemplate(title: "Navigate around a marker with control", difficulty: 3),
            GoalTemplate(title: "Return before wind increases (good judgment)", difficulty: 2),
            GoalTemplate(title: "Dry and store gear properly after", difficulty: 2)
        ],
        phoneAvailability: .allowedWithRisk,
        
        sources: [
            SourceTemplate(title: "Kayaking and Kayak Safety", hyperLink: "https://www.nps.gov/thingstodo/kayaking-and-kayak-safety.htm")
        ]
    ),

    .canoeing: ActivityMetadata(
        description: "Canoeing is a classic paddle activity that’s great for lakes and gentle rivers. It can be a relaxing glide or a steady workout depending on pace and conditions. Canoes often carry more gear than kayaks, making them popular for longer day trips. Learning coordinated strokes (especially with a partner) makes it far easier and more fun.",
        safetyWarnings: [
            "Carry a USCG-approved Type III–V personal flotation device for every person aboard",
            "Keep a sound-signaling device such as a whistle within immediate reach",
            "Use a 360-degree visible white light source when visibility is low or after sunset",
            "Never paddle alone, especially on open or fast-changing water",
            "File a float plan with a trusted person including your route and return time",
            "Check weather and marine or river forecasts before launching",
            "Bring a physical map plus a handheld GPS or VHF radio to share your exact location in emergencies",
            "Wear protective footgear and carry water, sunscreen, insect repellent, and a trash bag",
            "Plan routes that match your skill level and avoid high-traffic channels where motorized boats operate",
            "Stay in shallow or off-channel areas when possible to avoid powerboat collision zones",
            "Wear bright colors and make your presence known when paddling near hunting areas",
            "Keep alert for blinds, hunters, and private property zones during hunting season",
            "Proceed quietly and give wide space when passing anglers, paddlers, or other recreational users"
        ],
        estimatedMinutes: 30...180,
        goalPool: [
            GoalTemplate(title: "Do a safety check (PFD, whistle, dry bag)", difficulty: 2),
            GoalTemplate(title: "Practice forward stroke technique for 10 minutes", difficulty: 2),
            GoalTemplate(title: "Paddle steadily for 20 minutes", difficulty: 2),
            GoalTemplate(title: "Practice 10 J-strokes for tracking straight", difficulty: 4),
            GoalTemplate(title: "Coordinate strokes with a partner for 10 minutes", difficulty: 3),
            GoalTemplate(title: "Practice turning (sweep strokes) both sides", difficulty: 3),
            GoalTemplate(title: "Try a short out-and-back route near shore", difficulty: 2),
            GoalTemplate(title: "Keep gear organized and secure", difficulty: 2),
            GoalTemplate(title: "Return early if wind increases", difficulty: 2),
            GoalTemplate(title: "Dry and store equipment properly after", difficulty: 2)
        ],
        phoneAvailability: .allowedWithRisk,
        
        sources: [
            SourceTemplate(title: "Safe & Ethical Paddling", hyperLink: "https://tpwd.texas.gov/boating/paddling-trails/safety/")
        ]
    ),

    .riverCanoe: ActivityMetadata(
        description: "River canoeing adds moving water and current reading to the canoe experience. It can be peaceful on gentle rivers or technical on faster sections. The key is staying alert and choosing water appropriate for your skill level. Good planning (launch/exit points and conditions) keeps it safe and enjoyable.",
        safetyWarnings: [
            "Follow the normal canoeing procedures and safety cautions.",
            "Canoe operators should carry a map and a handheld GPS or VHF radio because rivers have changing paths and limited phone reception",
            "Never paddle alone and always file a float plan with return timing since river hazards can require self-rescue and delayed emergency response",
            "Wear bright colors and announce your presence near riverbanks during hunting season because hunters and blinds may be nearby"
        ],
        estimatedMinutes: 30...180,
        goalPool: [
            GoalTemplate(title: "Plan put-in and take-out points clearly", difficulty: 2),
            GoalTemplate(title: "Practice ferrying across current (gentle river)", difficulty: 4),
            GoalTemplate(title: "Paddle steadily for 20 minutes", difficulty: 2),
            GoalTemplate(title: "Practice controlled turns in current", difficulty: 4),
            GoalTemplate(title: "Identify 3 hazards and avoid them", difficulty: 3),
            GoalTemplate(title: "Keep canoe trimmed and stable", difficulty: 3),
            GoalTemplate(title: "Communicate clearly with your partner", difficulty: 2),
            GoalTemplate(title: "Take a break and reassess conditions", difficulty: 1),
            GoalTemplate(title: "Exit safely at the planned point", difficulty: 2),
            GoalTemplate(title: "Dry/secure gear and clean up after", difficulty: 2)
        ],
        phoneAvailability: .allowedWithRisk,
        
        sources: [
            SourceTemplate(title: "Safe & Ethical Paddling", hyperLink: "https://tpwd.texas.gov/boating/paddling-trails/safety/")
        ]
    ),

    .surfing: ActivityMetadata(
        description: "Surfing is riding ocean waves on a board, combining balance, timing, and paddling power. It can be challenging at first, but progress comes quickly with practice and good instruction. Conditions matter—smaller, cleaner waves are best for beginners. Respect the ocean, learn etiquette, and build skills safely.",
        safetyWarnings: [
            "Do not swim or surf at unguarded beaches, and only enter the water where official rescue personnel patrol or lifeguards are present",
            "Water entry at Ocean Beach should not exceed knee depth, and even shallow water can sweep you out in seconds, so stay extremely cautious",
            "If caught in a rip current while surfing, stay calm, don’t fight it, and move parallel to shore until you can angle back safely",
            "If you cannot exit a rip, float or tread water to conserve energy and signal for help by waving hands high and calling out loudly",
            "Never turn your back to the ocean because waves, including sneaker waves, can surge farther inland and knock you into the water",
            "Stay off rocks, jetties, and unstable cliffs since they are slippery, eroded, and high-risk impact zones for sudden waves",
            "Keep pets leashed and never surf or swim after them if they are swept out because handlers are more likely to need rescue than the animal",
            "Cold water can cause hypothermia even when the weather feels warm, so wear proper thermal gear like a wetsuit when surfing",
            "Before launching into surf, watch wave and water behavior closely because calm-looking water is often where rips form",
            "If you lose your board or kayak in the surf, immediately alert authorities instead of trying risky retrieval",
            "Communication devices like a charged phone or VHF radio are helpful, but self-rescue readiness and awareness matter more",
            "Sneaker waves are powerful, unpredictable, and can instantly sweep standing or surfing adults into the ocean without warning"
        ],
        estimatedMinutes: 30...180,
        goalPool: [
            GoalTemplate(title: "Practice paddling form for 10 minutes", difficulty: 3),
            GoalTemplate(title: "Practice pop-ups on the sand 10 times", difficulty: 3),
            GoalTemplate(title: "Catch 3 small waves safely", difficulty: 4),
            GoalTemplate(title: "Practice staying balanced while prone", difficulty: 2),
            GoalTemplate(title: "Learn one surf etiquette rule and apply it", difficulty: 2),
            GoalTemplate(title: "Ride one wave to completion (whitewater ok)", difficulty: 4),
            GoalTemplate(title: "Practice controlled wipeouts (fall safely)", difficulty: 3),
            GoalTemplate(title: "Take breaks and assess fatigue", difficulty: 1),
            GoalTemplate(title: "Exit the water before conditions worsen", difficulty: 2),
            GoalTemplate(title: "Rinse and store gear properly", difficulty: 2)
        ],
        phoneAvailability: .notAllowed,
        
        sources: [
            SourceTemplate(title: "Surf Warning and Beach Safety Practices", hyperLink: "https://www.nps.gov/goga/learn/news/surf-warnings-and-beach-safety-tips.htm")
        ]
    ),

    .paddleboarding: ActivityMetadata(
        description: "Paddleboarding (SUP) is standing or kneeling on a board while paddling across calm water. It builds core strength, balance, and steady endurance. Beginners do best on flat water with little wind. As you improve, you can explore longer routes and practice turns and speed control.",
        safetyWarnings: [
            "Inspect your board and gear at home and again before launching, inflating to the correct PSI if using an inflatable",
            "Always wear a leash, using quick-release waist leashes for rivers or rough, windy, or hazardous water",
            "Wear a USCG-approved life jacket for every person, regardless of age, especially in open or changing conditions",
            "Children 12 and under must wear a properly sized PFD at all times, but adults should too for real safety",
            "Check wind and weather forecasts before and throughout paddling because conditions shift fast and can turn dangerous",
            "Ask locals or park officials about hazards like currents, underwater obstacles, coves, or sudden drop-offs",
            "Tell someone your route and return time, ideally paddling with a friend and doing check-ins if solo",
            "Avoid distractions because paddleboards share water with faster boats and collisions are a real risk",
            "Wear non-slip shoes, hydrate often, use sunscreen, and stay alert for waves, currents, or rising water",
            "If caught in strong water movement, stay calm and move parallel to safety instead of fighting the force",
            "Make yourself highly visible to fast-moving boaters in congested areas to prevent crashes",
            "Always assume the water is stronger and less predictable than it looks so you paddle prepared and defensively"
        ],
        estimatedMinutes: 30...180,
        goalPool: [
            GoalTemplate(title: "Practice standing balance for 5 minutes", difficulty: 2),
            GoalTemplate(title: "Paddle steadily for 20 minutes", difficulty: 2),
            GoalTemplate(title: "Practice 10 controlled turns each direction", difficulty: 3),
            GoalTemplate(title: "Maintain good posture for 15 minutes", difficulty: 2),
            GoalTemplate(title: "Try kneeling paddling for 5 minutes", difficulty: 2),
            GoalTemplate(title: "Do a short out-and-back route near shore", difficulty: 2),
            GoalTemplate(title: "Practice stopping and backing up safely", difficulty: 3),
            GoalTemplate(title: "Take a break and hydrate", difficulty: 1),
            GoalTemplate(title: "Return early if wind increases", difficulty: 2),
            GoalTemplate(title: "Dry and store gear properly", difficulty: 2)
        ],
        phoneAvailability: .allowedWithRisk,
        
        sources: [
            SourceTemplate(title: "Enjoy paddleboarding adventures with these 7 safety tips", description: "Paddleboarding safety tips for a sound adventure.", hyperLink: "https://staging.outdoornebraska.gov/about/press-events/news/enjoy-paddleboarding-adventures-with-these-7-safety-tips/")
        ]
    ),

    .snorkeling: ActivityMetadata(
        description: "Snorkeling is floating on the water’s surface while breathing through a snorkel to observe underwater life. It’s an accessible way to explore reefs, rocks, and marine ecosystems with minimal training. Calm, clear water and proper fit gear make the experience far better. Always prioritize safety, especially around currents and waves.",
        safetyWarnings: [
            "Snorkel only if you are an experienced ocean swimmer comfortable in waves and strong currents",
            "Check surf, wind, and shorebreak conditions and confirm safety with rescue or lifeguard personnel before entering",
            "Always snorkel with a buddy who can seek help during emergencies",
            "Go snorkeling in the morning for better visibility and calmer water, avoiding dawn, dusk, or murky conditions",
            "Ensure your mask, fins, and snorkel tube fit snugly, don’t leak, and are obstruction-free before use",
            "Use anti-fog on your mask and take extra care when entering or exiting so waves don’t flip or disorient you",
            "Float to conserve energy, kicking only when necessary, and consider a snorkel-safe flotation vest or belt",
            "Never touch, feed, stand on, or damage corals or marine life",
            "Avoid rocky or shallow reef zones where standing or resting becomes unsafe",
            "Stop and remove your snorkel immediately if you feel dizzy, disoriented, or get a headache, then exit calmly and safely",
            "Full-face masks lack proven direct danger links but may cause CO₂ buildup, seal leaks, or removal difficulty, so use cautiously and practice self-removal",
            "If renting gear, choose licensed vendors, practice removing equipment yourself, and never enter water if it feels unsafe or uncomfortable"
        ],
        estimatedMinutes: 20...120,
        goalPool: [
            GoalTemplate(title: "Practice breathing calmly through snorkel for 5 minutes", difficulty: 2),
            GoalTemplate(title: "Clear your mask safely 3 times", difficulty: 3),
            GoalTemplate(title: "Swim along a safe shoreline route", difficulty: 2),
            GoalTemplate(title: "Observe 5 different sea creatures or plants", difficulty: 2),
            GoalTemplate(title: "Practice finning efficiently for 10 minutes", difficulty: 3),
            GoalTemplate(title: "Stay relaxed and avoid over-breathing", difficulty: 3),
            GoalTemplate(title: "Use the buddy system the entire session", difficulty: 2),
            GoalTemplate(title: "Take breaks and check energy level", difficulty: 1),
            GoalTemplate(title: "Exit the water before fatigue sets in", difficulty: 2),
            GoalTemplate(title: "Rinse and dry gear after use", difficulty: 1)
        ],
        phoneAvailability: .notAllowed,
        
        sources: [
            SourceTemplate(title: "Snorkeling Safety", hyperLink: "https://oceansafety.hawaii.gov/snorkeling-safety/")
        ]
    ),

    .scubaDiving: ActivityMetadata(
        description: "Scuba diving is exploring underwater using breathing equipment, offering a unique view of marine life and underwater landscapes. It requires proper training and certification for safe independent diving. Good buoyancy control and calm breathing make dives more enjoyable and safer. Plan carefully, follow procedures, and dive within your limits.",
        safetyWarnings: [
            "Be sure to dive with a certified instructor if not experinced!",
            "Research local ocean and river conditions, currents, hazards, and water rules before entering",
            "Never swim alone in unfamiliar or unguarded waters because dangers can appear suddenly",
            "If caught in a rip current, stay calm and swim parallel to shore until you can exit diagonally to safety",
            "Avoid alcohol before or during swimming or diving because it impairs balance, judgment, and survival ability in water",
            "Enter water feet-first and never dive into shallow or obstacle-filled areas",
            "Inspect and fit your mask, fins, and scuba gear carefully and ensure it is maintained and leak-free",
            "During scuba ascents, rise slowly and follow pressure-safety protocols to prevent decompression sickness",
            "After decompression diving, wait 24–48 hours before flying, 12 hours after a single no-stop dive, or 18 hours after repetitive dives",
            "Bioluminescent or algal-bloom water may contain toxins, so observe it, but avoid swimming or inhaling near blooms to prevent illness"
        ],
        estimatedMinutes: 30...180,
        goalPool: [
            GoalTemplate(title: "Complete pre-dive safety check (BWRAF)", difficulty: 3),
            GoalTemplate(title: "Practice buoyancy control for 5 minutes", difficulty: 4),
            GoalTemplate(title: "Maintain calm, steady breathing", difficulty: 3),
            GoalTemplate(title: "Practice controlled fin kicks (avoid silting)", difficulty: 3),
            GoalTemplate(title: "Stay within planned depth and time limits", difficulty: 3),
            GoalTemplate(title: "Perform a proper safety stop", difficulty: 4),
            GoalTemplate(title: "Communicate with buddy using hand signals", difficulty: 2),
            GoalTemplate(title: "Ascend slowly and safely", difficulty: 4),
            GoalTemplate(title: "Log the dive details after", difficulty: 2),
            GoalTemplate(title: "Rinse and store gear correctly", difficulty: 2)
        ],
        phoneAvailability: .notAllowed,
        
        sources: [
            SourceTemplate(title: "Swimming and Diving Safety", description: "", hyperLink: "https://wwwnc.cdc.gov/travel/page/safe-swimming-diving")
        ]
    ),

    // Winter / snow
    .skiing: ActivityMetadata(
        description: "Skiing is sliding on snow with skis, combining balance, technique, and endurance. It can be gentle cruising or fast downhill runs depending on terrain. Lessons accelerate learning and reduce injury risk. Warm up, start easy, and build confidence with controlled turns and stopping.",
        safetyWarnings: [
            "Train and condition your body before the season so you ski in shape, not into fatigue or injury",
            "Use properly adjusted bindings fitted by a certified ski shop to prevent dangerous release failures during a fall",
            "Dress in moisture-resistant, wind-protected layers including headgear and gloves because most heat loss happens through the head",
            "Wear sun, eye, and weather protection even on cloudy days since snow amplifies UV exposure and glare",
            "Take a warm-up run every day to mentally and physically prepare for slope conditions and speed changes",
            "Stay in full control, yield to uphill traffic when merging, and respect right-of-way for skiers ahead of you",
            "If terrain becomes too steep or difficult, keep your skis on and side-step down slowly instead of removing them",
            "Avoid alcohol or drugs while skiing because they severely reduce reaction time, balance, and judgment",
            "In backcountry zones, carry a map, compass, food, water, medication, shovel, beacon, and practice self-rescue drills because patrol response may be delayed or impossible",
            "Check avalanche conditions before skiing, wear a beacon, and practice locating and digging quickly because survival time is extremely short in snow burial",
            "Keep equipment secured and never stop or rest in unsafe narrow zones, closed trails, or high-traffic downhill channels"
        ],
        estimatedMinutes: 45...240,
        goalPool: [
            GoalTemplate(title: "Warm up with gentle runs for 10 minutes", difficulty: 2),
            GoalTemplate(title: "Practice controlled stopping 10 times", difficulty: 3),
            GoalTemplate(title: "Do 10 consistent turns (pizza or parallel)", difficulty: 3),
            GoalTemplate(title: "Ride the lift and unload smoothly 5 times", difficulty: 2),
            GoalTemplate(title: "Complete 3 green runs with control", difficulty: 3),
            GoalTemplate(title: "Practice edging on a gentle slope", difficulty: 4),
            GoalTemplate(title: "Keep speed under control the entire session", difficulty: 3),
            GoalTemplate(title: "Take a hydration/rest break mid-session", difficulty: 1),
            GoalTemplate(title: "Cool down with easy skiing", difficulty: 2),
            GoalTemplate(title: "Check gear fit and comfort after", difficulty: 2)
        ],
        phoneAvailability: .allowedWithRisk,
        
        sources: [
            SourceTemplate(title: "Skiing and Snowboarding Safety Precautions", description: "", hyperLink: "https://www.clallamcountywa.gov/DocumentCenter/View/3316/Skiing-and-Snowboarding-Safety-Precautions-PDF")
        ]
    ),

    .snowboarding: ActivityMetadata(
        description: "Snowboarding is riding down snow-covered slopes on a single board, using balance, edge control, and body positioning. Beginners often start with gentle slopes and practice heel/toe edge control. It’s demanding but very rewarding once turns click. Protective gear and patience make learning safer and smoother.",
        safetyWarnings: [
            "Condition your body before the season so you ride prepared, alert, and injury-resistant",
            "Have your snowboard bindings professionally adjusted before riding because poor binding fit increases crash severity",
            "Wear layered, water- and wind-resistant gear, plus gloves and head protection since weather and heat loss change rapidly on slopes",
            "Use sunscreen and eye protection like goggles or sunglasses because snow reflection intensifies UV and glare risk",
            "Start every ride with a slow warm-up run to build control, mental focus, and awareness of surface conditions",
            "Stay in control at all times, yield to uphill riders when merging, and give right-of-way to snowboarders ahead of you",
            "If the slope exceeds your skill level, keep your board on and step down sideways instead of removing it",
            "Avoid alcohol or drugs while snowboarding because they drastically impair terrain response and survival odds",
            "In backcountry areas, carry navigation tools, food, water, medications, beacon, probe, shovel, and practice self-rescue because immediate rescue is uncertain",
            "Check avalanche conditions before snowboarding and practice fast location and snow digging drills because survival time is extremely short under snow",
            "Never stop in narrow, closed, blind-spot, or high-traffic zones and always secure your board to prevent runaway equipment"
        ],
        estimatedMinutes: 45...240,
        goalPool: [
            GoalTemplate(title: "Practice falling safely (knees bent, arms in)", difficulty: 2),
            GoalTemplate(title: "Practice heel-edge sliding with control", difficulty: 3),
            GoalTemplate(title: "Practice toe-edge sliding with control", difficulty: 3),
            GoalTemplate(title: "Link 5 turns on a gentle slope", difficulty: 4),
            GoalTemplate(title: "Get on/off the lift safely 5 times", difficulty: 3),
            GoalTemplate(title: "Ride one green run without frequent stops", difficulty: 4),
            GoalTemplate(title: "Practice controlled stopping 10 times", difficulty: 3),
            GoalTemplate(title: "Take a rest/hydration break mid-session", difficulty: 1),
            GoalTemplate(title: "Cool down with easy runs", difficulty: 2),
            GoalTemplate(title: "Check bindings and stance after", difficulty: 2)
        ],
        phoneAvailability: .allowedWithRisk,
        
        sources: [
            SourceTemplate(title: "Skiing and Snowboarding Safety Precautions", description: "", hyperLink: "https://www.clallamcountywa.gov/DocumentCenter/View/3316/Skiing-and-Snowboarding-Safety-Precautions-PDF")
        ]
    ),

    .iceSkating: ActivityMetadata(
        description: "Ice skating is gliding on ice with skates, building balance, coordination, and leg strength. It can be casual laps or skill practice like stops and turns. Beginners improve quickly with relaxed posture and small, controlled strides. Wear warm layers and take your time getting comfortable.",
        safetyWarnings: [
            "Wear skates that fit comfortably and provide enough ankle support to keep you on your feet.",
            "Have the blades professionally sharpened at the beginning of each season.",
            "Skate only on specially prepared skating areas where you are sure the ice is strong enough to withstand your weight.",
            "Always check for cracks, holes and other debris.",
            "Before setting out on your skating expedition, learn basic skating skills, such as how to stop and fall safely.",
            "Wear warm clothing and rest when you become tired or cold.",
            "Never skate alone."
        ],
        estimatedMinutes: 20...90,
        goalPool: [
            GoalTemplate(title: "Skate 5 minutes focusing on balance", difficulty: 2),
            GoalTemplate(title: "Practice stopping safely 10 times", difficulty: 3),
            GoalTemplate(title: "Do 5 controlled turns each direction", difficulty: 3),
            GoalTemplate(title: "Skate continuously for 15 minutes", difficulty: 3),
            GoalTemplate(title: "Practice bending knees for stability", difficulty: 2),
            GoalTemplate(title: "Try backward skating for 2 minutes", difficulty: 4),
            GoalTemplate(title: "Avoid holding the wall for 5 minutes", difficulty: 3),
            GoalTemplate(title: "Take a rest break and hydrate", difficulty: 1),
            GoalTemplate(title: "Cool down with easy laps", difficulty: 2),
            GoalTemplate(title: "Stretch calves and ankles after", difficulty: 2)
        ],
        phoneAvailability: .allowedWithRisk,
        
        sources: [
            SourceTemplate(title: "Ice Skating Safety", description: "", hyperLink: "https://www.naugatuck-ct.gov/filestorage/119/364/409/Ice_Skating_Safety_NSC.pdf")
        ]
    ),

    .snowHiking: ActivityMetadata(
        description: "Snow hiking is hiking in snowy conditions, which adds challenge through cold, slippery footing, and heavier gear. It can be peaceful and scenic, but requires extra preparation for warmth and safety. Traction devices and layered clothing help a lot. Keep routes shorter and return before conditions change.",
        safetyWarnings: [
            "Stay dry at all times because wet clothing can lose up to 90% of its insulation value in winter conditions",
            "Wear layered, non-cotton clothing and a windbreaker to protect your core body heat from cold and wind penetration",
            "Watch companions for early hypothermia signs like uncontrollable shivering, slurred speech, or unusual behavior and act immediately if symptoms appear",
            "Turn back if you cannot stay warm and dry because survival matters more than reaching the destination",
            "Carry navigation tools like a detailed map and compass and trust them to track your exact location when snow causes disorientation",
            "Prepare for self-rescue by practicing re-entry and survival drills because emergency response can be delayed in rough or remote winter conditions",
            "Keep a winter survival kit in your vehicle including blankets, hats, gloves, high-calorie snacks, towels, a shovel, traction material like sand or litter, and properly sized tire chains for severe snow or ice roads",
            "Check battery efficiency, oil viscosity, antifreeze levels, tire tread (minimum 5/32”), and washer-fluid antifreeze before winter travel because cold drastically reduces vehicle reliability",
            "Respect shared winter routes by passing others slowly, yielding properly, and never accelerating near people on foot",
            "Notify someone of your exact route, departure, and return time, marking it on a map, and always check back in when finished to activate rescue quickly if overdue",
            "Avoid getting lost by reading maps and compass skills in safe conditions first, and never depending on assumption during whiteouts"
        ],
        estimatedMinutes: 45...240,
        goalPool: [
            GoalTemplate(title: "Plan a safe route with turnaround time", difficulty: 2),
            GoalTemplate(title: "Use traction devices when needed", difficulty: 2),
            GoalTemplate(title: "Hike steadily for 60 minutes", difficulty: 3),
            GoalTemplate(title: "Stay warm with proper layering", difficulty: 2),
            GoalTemplate(title: "Practice careful footing on icy patches", difficulty: 3),
            GoalTemplate(title: "Take 5 winter landscape photos", difficulty: 1),
            GoalTemplate(title: "Drink water even if not thirsty", difficulty: 2),
            GoalTemplate(title: "Return before fatigue or weather worsens", difficulty: 2),
            GoalTemplate(title: "Do a cooldown stretch after", difficulty: 2),
            GoalTemplate(title: "Leave no trace (pack out everything)", difficulty: 1)
        ],
        phoneAvailability: .fullyAllowed,
        
        sources: [
            SourceTemplate(title: "Winter Safety", description: "Important rules to follow during winter hiking.", hyperLink: "https://www.fs.usda.gov/r06/ochoco/safety-ethics/winter-safety")
        ]
    ),

    .snowPlay: ActivityMetadata(
        description: "Snow play is casual fun in the snow—sledding, making snowmen, tossing snowballs, or just exploring. It’s great for families and light movement with plenty of laughter. The main goal is safe enjoyment, especially around slippery surfaces and cold exposure. Dress warmly and pick safe areas away from roads and steep hazards.",
        safetyWarnings: [
            "Protect against frostbite by limiting time outdoors in extreme cold and checking wind chill risks before snow play",
            "Dress in warm, non-cotton layers and keep outer gear dry to maintain body heat in snow and icy conditions",
            "Keep scarves tucked safely inside coats and avoid loose or dangling clothing near snow play or equipment",
            "Use sunscreen and hydrate even in cold weather because dehydration still occurs during snow recreation",
            "Take navigation tools like a winter map or compass if snow play extends beyond open, visible areas",
            "Stay at least 3 feet away from fires or heaters and turn portable heaters off when leaving a room or area",
            "Create a 3-foot kid-free safety zone around open fires, campfires, or space heaters during winter outings",
            "Test smoke and CO alarms monthly and never leave vehicles or fuel-burning equipment running in enclosed spaces",
            "Remove a warming vehicle from garages immediately and check tailpipes for snow blockage to prevent CO poisoning",
            "For infants, avoid blankets or loose items in cribs and use wearable sleep sacks instead for safe warmth",
            "Wash hands often, model safe sneeze-and-cough behavior, and follow seasonal vaccination guidance for flu prevention",
            "Take CPR or safety training if snow play occurs near deep or open water or remote winter zones"
        ],
        estimatedMinutes: 20...120,
        goalPool: [
            GoalTemplate(title: "Dress in proper layers before starting", difficulty: 1),
            GoalTemplate(title: "Play actively for 20 minutes", difficulty: 2),
            GoalTemplate(title: "Build a snowman or snow structure", difficulty: 2),
            GoalTemplate(title: "Do 3 safe sled runs (if available)", difficulty: 3),
            GoalTemplate(title: "Take a warm-up break halfway through", difficulty: 1),
            GoalTemplate(title: "Stay aware of slippery spots", difficulty: 2),
            GoalTemplate(title: "Keep gloves/socks dry", difficulty: 2),
            GoalTemplate(title: "Clean up and leave the area tidy", difficulty: 1),
            GoalTemplate(title: "Drink water after playing", difficulty: 1),
            GoalTemplate(title: "End before you’re overly cold or tired", difficulty: 2)
        ],
        phoneAvailability: .allowedWithRisk,
        
        sources: [
            SourceTemplate(title: "", description: "", hyperLink: "")
        ]
    ),

    // Exploration / chill
    .trailWalking: ActivityMetadata(
        description: "Trail walking is an easy, approachable way to get outside and move your body without the intensity of hiking steep terrain. It’s great for daily activity, clearing your head, and building a foundation for longer adventures. Choose a safe path with good footing and enjoy a steady pace. Even short walks add up over time.",
        safetyWarnings: [
            "Choose a trail distance and difficulty that your body can handle without overexertion",
            "Carry water and sun protection even on short trail walks to avoid dehydration or heat illness",
            "Stay on marked paths and respect barriers because trails are intentionally designed to avoid hidden hazards"
        ],
        estimatedMinutes: 20...120,
        goalPool: [
            GoalTemplate(title: "Walk for 20 minutes continuously", difficulty: 1),
            GoalTemplate(title: "Maintain a steady pace for 30 minutes", difficulty: 2),
            GoalTemplate(title: "Try a new trail segment", difficulty: 2),
            GoalTemplate(title: "Practice good posture the whole walk", difficulty: 2),
            GoalTemplate(title: "Do a short uphill section", difficulty: 3),
            GoalTemplate(title: "Take 5 photos of nature", difficulty: 1),
            GoalTemplate(title: "Listen for 5 distinct bird sounds", difficulty: 2),
            GoalTemplate(title: "Do a 5-minute cooldown stretch", difficulty: 2),
            GoalTemplate(title: "Stay hydrated before and after", difficulty: 1),
            GoalTemplate(title: "Leave no trace (pack out trash)", difficulty: 1)
        ],
        phoneAvailability: .fullyAllowed,
        
        sources: [
            SourceTemplate(title: "Hike Smart", description: "Important insights that apply both for hiking and trail walking.", hyperLink: "https://www.nps.gov/articles/hiking-safety.htm")
        ]
    ),

    .forestExploring: ActivityMetadata(
        description: "Forest exploring is a relaxed outdoor adventure focused on discovery—walking among trees, finding interesting plants, and enjoying quiet natural spaces. It blends light exercise with curiosity and mindfulness. Stay on safe routes or established paths when possible. The aim is gentle movement and awareness, not risky wandering.",
        safetyWarnings: [
            "Stay aware of surroundings and learn which wildlife, terrain, and seasonal risks exist in the forest before exploring",
            "Never feed wild animals because it alters their behavior and can attract dangerous predators",
            "Make noise while walking dense or brushy trails to avoid surprising bears that may be nearby",
            "If you spot a bear that hasn’t noticed you, remain calm and slowly back away without running",
            "Never run from a bear because they can sprint up to 40 mph and will instinctively chase movement",
            "If a brown bear knocks you down defensively, roll onto your stomach and play dead until it leaves",
            "If the bear attack becomes prolonged or predatory, fight back with any object available",
            "If you see a black bear, do not play dead—escape to a vehicle or building if possible, or fight back if escape is not an option",
            "Avoid hiking, biking, or walking alone in forests because most wildlife attacks and drowning cases happen when no help is nearby",
            "Do not approach mountain lions, especially at dawn or dusk, and stay standing to avoid resembling prey",
            "Make yourself look larger if a mountain lion approaches by raising arms, waving gear slowly, and speaking firmly in a loud voice",
            "Keep distance from alligators near rivers or wetlands because they can lunge within a few feet of the shoreline",
            "Do not let children or pets play or swim in water bodies where alligators or similar reptiles may live",
            "If an alligator bites, fight back aggressively by striking, kicking, or targeting its eyes to force release",
            "Store food and trash securely in airtight containers or designated stations to avoid attracting wildlife and protect the environment",
            "Wear sunscreen and stay hydrated because cold or cloudy forest weather can still cause dehydration and UV harm",
            "Report any wildlife attacks to 911 so rescue teams can respond and document the hazard properly",
            "Watch for blinds or hunters during hunting season, wear bright colors, and announce your presence when passing through riverfront or brush zones",
            "Avoid traditional or recreational kayaks or canoes on large, unpredictable open water like Lake Superior and prefer inland lakes or calm rivers instead",
            "Practice self-rescue skills if you plan to explore deep or fast-moving forest rivers, since rescue response can be delayed or uncertain"
        ],
        estimatedMinutes: 30...180,
        goalPool: [
            GoalTemplate(title: "Explore for 30 minutes at a relaxed pace", difficulty: 1),
            GoalTemplate(title: "Identify 3 plants/trees", difficulty: 2),
            GoalTemplate(title: "Stay on safe paths the entire time", difficulty: 2),
            GoalTemplate(title: "Take 5 photos of forest details", difficulty: 1),
            GoalTemplate(title: "Walk quietly for 10 minutes (mindful)", difficulty: 2),
            GoalTemplate(title: "Find a scenic spot and rest 5 minutes", difficulty: 1),
            GoalTemplate(title: "Avoid stepping on fragile plants", difficulty: 2),
            GoalTemplate(title: "Drink water once during the session", difficulty: 1),
            GoalTemplate(title: "Leave no trace and pack out trash", difficulty: 1),
            GoalTemplate(title: "Return before it gets dark", difficulty: 2)
        ],
        phoneAvailability: .fullyAllowed,
        
        sources: [
            SourceTemplate(title: "Wildlife Safety Tips for Enjoying the Great Outdoors", description: "", hyperLink: "https://www.fws.gov/story/2016-07/wildlife-safety-tips-enjoying-great-outdoors")
        ]
    ),

    .wildlifeSpotting: ActivityMetadata(
        description: "Wildlife spotting is quietly observing animals in their natural environment—deer, rabbits, birds, or anything you’re lucky enough to see. The best approach is patience, slow movement, and keeping distance so animals stay calm. It’s a great activity for mindfulness and photography. Respecting wildlife and habitat is the core of doing it well.",
        safetyWarnings: [
            "Learn park rules before spotting wildlife because viewing distances and hazards differ by location",
            "Stay at least 25 yards from most animals and 100 yards from predators unless your specific park requires even more distance",
            "Use binoculars or a zoom lens, and move back immediately if an animal reacts or approaches too closely",
            "Never feed, touch, tease, or frighten wildlife because it is illegal and can make animals aggressive toward humans",
            "Drive slowly and pull fully into designated pull-outs when stopping to watch animals to prevent vehicle strikes",
            "Store food and trash in wildlife-resistant, securely closed containers to avoid attracting predators or creating unsafe encounters",
            "Report any physical contact, injury, or unusual animal behavior to a park ranger or 911 if you believe it is an emergency",
            "Stay on marked trails, keep pets leashed and vaccinated if allowed, and avoid calls or attractants that disturb wildlife",
            "Take sun protection and hydration seriously even in cold or cloudy weather because exposure risk remains real",
            "Announce your presence calmly in dense or loud areas to avoid surprising predators or hunters during seasonal overlap",
            "Assume wildlife is unpredictable and prioritize distance, awareness, and preparedness over photos or close interaction"
        ],
        estimatedMinutes: 20...180,
        goalPool: [
            GoalTemplate(title: "Spot 3 different animals (or signs like tracks)", difficulty: 2),
            GoalTemplate(title: "Stay quiet and move slowly for 15 minutes", difficulty: 2),
            GoalTemplate(title: "Use binoculars or zoom instead of approaching", difficulty: 2),
            GoalTemplate(title: "Take 3 wildlife photos (from distance)", difficulty: 3),
            GoalTemplate(title: "Learn 1 new animal call or behavior", difficulty: 2),
            GoalTemplate(title: "Stay on trails the whole time", difficulty: 2),
            GoalTemplate(title: "Write a short note of what you observed", difficulty: 1),
            GoalTemplate(title: "Avoid disturbing animals (no chasing)", difficulty: 1),
            GoalTemplate(title: "Leave the area clean and quiet", difficulty: 1),
            GoalTemplate(title: "End before dark if unfamiliar location", difficulty: 2)
        ],
        phoneAvailability: .fullyAllowed,
        
        sources: [
            SourceTemplate(title: "7 Ways to Safely Watch Wildlife", description: "", hyperLink: "https://www.nps.gov/subjects/watchingwildlife/7ways.htm")
        ]
    ),

    .birdWatching: ActivityMetadata(
        description: "Bird watching is observing birds in parks, forests, or near water, focusing on behavior, calls, and identification. It’s calm, accessible, and surprisingly engaging once you start noticing details. Binoculars help, but patience and quiet movement matter most. You can make it more active by walking between spots.",
        safetyWarnings: [
            "Plan wildlife and bird watching trips based on season, tides, and morning or early-evening activity patterns for safer conditions",
            "Keep noise low near water or forests because sound travels far and can startle wildlife unexpectedly",
            "Use binoculars or spotting scopes so you stay at a safe distance without disturbing animals, which is both safer and legally required",
            "Stay well back from shore buffers and never enter the water to approach or retrieve wildlife",
            "Never feed or touch wildlife because it is illegal and can trigger aggressive or unsafe behavior in normally wild animals",
            "Avoid casting, fishing, or paddling through bird flocks and secure or weigh lines to prevent accidental harm to seabirds",
            "Dispose of hooks and lines responsibly and pack out all trash to avoid attracting predators or creating environmental hazards",
            "Report unusual or dangerous wildlife encounters, attacks, or sick or stranded animals to rangers or emergency hotlines",
            "Keep flotation and communication gear accessible when spotting wildlife from boats or paddlecraft because conditions can change fast",
            "Prioritize observation from predictable, marked paths to avoid blind-spot zones where predators or hunters may be present",
            "Assume wildlife is unpredictable and maintain awareness instead of focusing on close photos or distractions"
        ],
        estimatedMinutes: 15...180,
        goalPool: [
            GoalTemplate(title: "Identify 3 different bird species", difficulty: 2),
            GoalTemplate(title: "Listen for 5 distinct bird calls", difficulty: 2),
            GoalTemplate(title: "Stay quiet for 10 minutes", difficulty: 2),
            GoalTemplate(title: "Take one clear bird photo (if possible)", difficulty: 3),
            GoalTemplate(title: "Walk to 2 different observation spots", difficulty: 2),
            GoalTemplate(title: "Use binoculars correctly for 10 minutes", difficulty: 2),
            GoalTemplate(title: "Write down one behavior you observed", difficulty: 1),
            GoalTemplate(title: "Avoid approaching birds too closely", difficulty: 1),
            GoalTemplate(title: "Leave no trace and pack out trash", difficulty: 1),
            GoalTemplate(title: "End with a calm 2-minute breathing reset", difficulty: 1)
        ],
        phoneAvailability: .fullyAllowed,
        
        sources: [
            SourceTemplate(title: "7 Ways to Safely Watch Wildlife", description: "Respect wildlife for a safe and sound experience.", hyperLink: "https://www.nps.gov/subjects/watchingwildlife/7ways.htm")
        ]
    ),

    .stargazing: ActivityMetadata(
        description: "Stargazing is a peaceful outdoor activity focused on observing the night sky—stars, constellations, planets, and meteor showers. It’s great for relaxation and perspective, and you can do it almost anywhere with a dark enough view. Dress warmly and give your eyes time to adjust to the dark. A simple plan (what to look for) makes it even better.",
        safetyWarnings: [
            "Use a red flashlight or headlamp at night to navigate safely without losing night vision",
            "Turn off white outdoor lights when stargazing because they reduce visibility and can mask hazards around you",
            "Never stargaze or hike alone at night—stay with friends and keep communication devices accessible in case conditions change",
            "Check local weather, tides, and terrain risks before nighttime viewing because wilderness conditions shift quickly after dark",
            "Let your eyes adjust naturally to darkness or moonlight, keeping your headlamp off but ready if you must move or stop for safety",
            "Choose open, marked, stable ground for stargazing to avoid unseen obstacles, slippery rocks, or wildlife blind-spot zones",
            "Observe wildlife quietly from a safe distance and respect park guidelines during nocturnal exploration",
            "Join community or astronomy club events like star parties when possible because group settings increase safety and preparedness",
            "Avoid amber or white downward lighting during viewing and prioritize red or night-friendly bulbs for visibility and safety without glare",
            "Keep infants warm using fitted sleep sacks or proper thermal layers if sleeping under stars in cold seasons",
            "Monitor fatigue, cold stress, or disorientation in companions during long night sessions to prevent hypothermia or poor decisions",
            "Do not depend on assumptions in low light—use maps or directional references like constellations to orient yourself safely"
        ],
        estimatedMinutes: 15...180,
        goalPool: [
            GoalTemplate(title: "Find 2 constellations", difficulty: 2),
            GoalTemplate(title: "Spend 10 minutes without looking at bright screens", difficulty: 2),
            GoalTemplate(title: "Use a sky app to identify 5 stars", difficulty: 2),
            GoalTemplate(title: "Spot a satellite or plane and track it", difficulty: 2),
            GoalTemplate(title: "Do 5 minutes of quiet breathing while watching sky", difficulty: 1),
            GoalTemplate(title: "Take one night-sky photo (if possible)", difficulty: 3),
            GoalTemplate(title: "Stay warm and comfortable for 30 minutes", difficulty: 2),
            GoalTemplate(title: "Learn one astronomy fact and share it", difficulty: 1),
            GoalTemplate(title: "Avoid disturbing the area (quiet/no litter)", difficulty: 1),
            GoalTemplate(title: "Pack up safely and leave the site tidy", difficulty: 1)
        ],
        phoneAvailability: .fullyAllowed,
        
        sources: [
            SourceTemplate(title: "", description: "", hyperLink: "")
        ]
    ),

    .photographyWalk: ActivityMetadata(
        description: "A photography walk is a casual walk where your goal is to notice details and capture interesting moments—landscapes, textures, light, and small scenes. It’s a great blend of light exercise and creative focus. You can do it in a neighborhood, park, or trail. Slowing down and looking intentionally is the whole point.",
        safetyWarnings: [
            "Respect wildlife distance rules and stay far enough that animals can move without feeling threatened",
            "Stay on the safe side of barriers and railings to prevent sudden slips, falls, or unsafe encounters",
            "Use a zoom lens instead of selfies because being too close to wildlife is dangerous and illegal",
            "Back up to a safe distance if a wild animal approaches because their behavior is unpredictable",
            "Stick to marked trails and boardwalks so you avoid hidden hazards and reduce fall injuries",
            "Wear sturdy rubber-soled hiking boots or shoes for traction on mixed and slippery terrain",
            "Avoid walking backward, leaning over edges, or stepping close to steep drop-offs for photos",
            "Pull fully into safe designated areas before taking roadside photos to prevent accidents",
            "Check park alerts and safety signs, and obey closures to avoid unexpected environmental hazards",
            "Leave early or avoid busy afternoons so crowded trails don’t push you into risky positions",
            "Look both ways before crossing roads or trails and never risk a photo over your safety"
        ],
        estimatedMinutes: 20...180,
        goalPool: [
            GoalTemplate(title: "Take 10 photos focusing on composition", difficulty: 2),
            GoalTemplate(title: "Find 3 interesting textures to photograph", difficulty: 2),
            GoalTemplate(title: "Capture 5 different lighting situations", difficulty: 3),
            GoalTemplate(title: "Walk for 30 minutes total", difficulty: 1),
            GoalTemplate(title: "Try one new angle (low/high) safely", difficulty: 2),
            GoalTemplate(title: "Take a 5-minute mindful pause to observe", difficulty: 2),
            GoalTemplate(title: "Avoid rushing—move slowly and safely", difficulty: 1),
            GoalTemplate(title: "Select 3 favorite photos afterward", difficulty: 1),
            GoalTemplate(title: "Keep gear secure the whole time", difficulty: 2),
            GoalTemplate(title: "Leave the area clean (no trash)", difficulty: 1)
        ],
        phoneAvailability: .fullyAllowed,
        
        sources: [
            SourceTemplate(title: "Keep Safety In The Picture", description: "", hyperLink: "https://www.nps.gov/articles/safepicture.htm")
        ]
    ),

    .picnic: ActivityMetadata(
        description: "A picnic is a relaxed outdoor break with food, conversation, and time in nature. It’s perfect for recovery days or social connection, and you can make it as simple as a snack on a blanket. Choose a comfortable spot, bring basic supplies, and enjoy slowing down. A little planning keeps it clean and stress-free.",
        safetyWarnings: [
            "Keep cold foods at 40°F or below and never let perishables sit in the 40–140°F danger zone for more than 2 hours, or 1 hour if it’s above 90°F outside",
            "Pack drinks and perishables in separate coolers to reduce heat exposure from frequent opening",
            "Wrap raw meat, poultry, and seafood tightly so their juices never leak onto produce or cooked foods",
            "Rinse firm fruits and vegetables with clean water and dry them before packing unless labeled ready-to-eat",
            "Wash hands and surfaces with soap for 20+ seconds before and after handling food, even outdoors using jugs or disposable wipes if needed",
            "Never place cooked food on plates or utensils that held raw meat unless washed in hot, soapy water first",
            "Use a food thermometer because color and texture alone cannot confirm food safety",
            "Marinate and thaw food only in the refrigerator, and never reuse raw-food marinade as a sauce",
            "Grill-ready food should be kept hot on the side rack away from direct coals to prevent burning or overcooking",
            "Check grilled food for brush bristles or foreign objects if a bristle grill brush was used for cleaning",
            "Refrigerate or freeze leftovers within 2 hours of cooking, or 1 hour if outdoor heat exceeds 90°F",
            "Divide large leftovers into shallow containers to cool faster and prevent bacterial growth",
            "Never thaw or marinate food at room temperature, always choose fridge-based defrosting methods",
            "Carry extra ice and replace melted ice water frequently to maintain safe serving temperatures for chilled dishes",
            "Turn off or move vehicles away from enclosed spaces if warming food or using portable fuel-based heat sources near picnic zones",
            "Be patient, grill prepared, store food responsibly, and prioritize safety over speed when eating outdoors"
        ],
        estimatedMinutes: 20...180,
        goalPool: [
            GoalTemplate(title: "Pack simple snacks and water", difficulty: 1),
            GoalTemplate(title: "Choose a clean spot and lay out safely", difficulty: 1),
            GoalTemplate(title: "Spend 15 minutes screen-free", difficulty: 2),
            GoalTemplate(title: "Do a 10-minute gentle walk after eating", difficulty: 1),
            GoalTemplate(title: "Try mindful eating for 5 minutes", difficulty: 2),
            GoalTemplate(title: "Bring a trash bag and leave no trace", difficulty: 1),
            GoalTemplate(title: "Hydrate at least once during the picnic", difficulty: 1),
            GoalTemplate(title: "Take 3 photos of the scenery/meal", difficulty: 1),
            GoalTemplate(title: "Relax for 20 minutes without rushing", difficulty: 1),
            GoalTemplate(title: "Pack up and leave the area tidy", difficulty: 1)
        ],
        phoneAvailability: .fullyAllowed,
        
        sources: [
            SourceTemplate(title: "Handling Food Safely While Eating Outdoors", description: "", hyperLink: "https://www.fda.gov/food/buy-store-serve-safe-food/handling-food-safely-while-eating-outdoors")
        ]
    ),

    .outdoorYoga: ActivityMetadata(
        description: "Outdoor yoga combines stretching, breathing, and body control with the calming feel of fresh air and nature. It can be gentle recovery or more challenging depending on the flow. A flat surface and steady breathing make it easier. The goal is mindful movement, not forcing deep poses.",
        safetyWarnings: [
            "Practice yoga outdoors only after checking weather and ground conditions to avoid slips, cold stress, or overheating",
            "Use moisture-wicking, non-cotton layers and hydrate often because outdoor wind, sun, or cold can change fast",
            "Do yoga with a trained instructor or qualified group, not alone, to reduce injury and disorientation risk",
            "Avoid advanced poses like headstands, lotus, or forceful breathing outdoors if you are new or conditions are hot or cold",
            "Use sunscreen and carry drinking water even in cool weather because UV reflection and dehydration still occur outdoors",
            "Modify poses if you are pregnant, older, or have health conditions like high blood pressure, balance issues, spine, or knee injuries",
            "Never use yoga to delay medical care if pain, dizziness, confusion, or breathing discomfort develops outdoors",
            "Ask about your instructor’s training and experience before outdoor yoga sessions to ensure safe guidance",
            "Stay aware of your body’s limits and stop immediately if fatigue, dizziness, numbness, or temperature stress appears",
            "Choose stable, flat, non-slippery outdoor surfaces for yoga to prevent sprains and strains",
            "Keep infants warm using fitted wearable sleep layers if outdoor yoga includes long exposure or rest periods",
            "Avoid alcohol or drugs before or during outdoor yoga because they impair balance and judgment",
            "Outdoor yoga should match your fitness level and environmental conditions, not exceed them"
        ],
        estimatedMinutes: 10...90,
        goalPool: [
            GoalTemplate(title: "Do 10 minutes of gentle flow", difficulty: 1),
            GoalTemplate(title: "Hold 3 poses for 30 seconds each", difficulty: 2),
            GoalTemplate(title: "Practice steady breathing for 5 minutes", difficulty: 1),
            GoalTemplate(title: "Do a balance pose on each leg", difficulty: 3),
            GoalTemplate(title: "Stretch hips and hamstrings gently", difficulty: 2),
            GoalTemplate(title: "Finish with 2 minutes of relaxation", difficulty: 1),
            GoalTemplate(title: "Maintain good alignment throughout", difficulty: 3),
            GoalTemplate(title: "Try a short sun-salutation sequence", difficulty: 2),
            GoalTemplate(title: "Avoid distractions and stay mindful", difficulty: 2),
            GoalTemplate(title: "Hydrate after the session", difficulty: 1)
        ],
        phoneAvailability: .fullyAllowed,
        
        sources: [
            SourceTemplate(title: "Yoga: Effectiveness and Safety", description: "", hyperLink: "https://www.nccih.nih.gov/health/yoga-effectiveness-and-safety")
        ]
    ),

    .outdoorMeditation: ActivityMetadata(
        description: "Outdoor meditation is practicing calm attention while surrounded by natural sounds and fresh air. You can focus on breathing, listening, or simply watching thoughts come and go. Even short sessions can reduce stress and improve focus. The goal is gentle awareness, not forcing your mind to be blank.",
        safetyWarnings: [
            "Stay aware of wildlife and environmental risks instead of closing your eyes in unsafe areas",
            "Practice on stable ground and avoid edges near cliffs, shorebreaks, or fast-moving water",
            "Keep water activities separate from mindfulness sessions unless the area is designated safe",
            "Bring a charged communication device but don’t rely on it for constant reception",
            "Stop mindfulness practice immediately if symptoms of cold stress, dizziness, or disorientation appear",
            "Keep food and waste sealed because scents can attract dangerous animals",
            "Never feed or approach wildlife during meditation or nature mindfulness sessions",
            "Practice with a buddy or group, not alone, to improve emergency response chances",
            "Match session length to weather conditions to avoid hypothermia, overheating, or fatigue"
        ],
        estimatedMinutes: 5...45,
        goalPool: [
            GoalTemplate(title: "Sit quietly for 5 minutes focusing on breath", difficulty: 1),
            GoalTemplate(title: "Do a 10-minute body scan", difficulty: 2),
            GoalTemplate(title: "Practice listening meditation for 10 minutes", difficulty: 2),
            GoalTemplate(title: "Notice 10 distinct sounds without judging them", difficulty: 2),
            GoalTemplate(title: "Label thoughts gently and return to breath", difficulty: 3),
            GoalTemplate(title: "Meditate for 20 minutes total", difficulty: 3),
            GoalTemplate(title: "Try walking meditation for 10 minutes", difficulty: 2),
            GoalTemplate(title: "End with one written reflection sentence", difficulty: 1),
            GoalTemplate(title: "Stay consistent even if distracted", difficulty: 3),
            GoalTemplate(title: "Choose a new peaceful spot this week", difficulty: 2)
        ],
        phoneAvailability: .fullyAllowed,
        
        sources: [
            SourceTemplate(title: "The Impact of Outdoor in Nature Mindfulness on the Mental Well-being of Children and Adolescents. A Mental Health and Cross-cultural Approach", description: "", hyperLink: "https://pmc.ncbi.nlm.nih.gov/articles/PMC10999151/")
        ]
    ),

    .hammockResting: ActivityMetadata(
        description: "Hammock resting is a simple outdoor reset—gentle swaying, fresh air, and a break from screens. It can be a quick recharge between activities or a longer calm session with reading or music. Set it up securely and enjoy the stillness. Comfort comes from good angles, safe anchors, and a relaxed mindset.",
        safetyWarnings: [
            "Sleep only in designated tent or camping sites to avoid vegetation damage",
            "Test trees carefully and avoid using weak or unstable trees as hammock anchors",
            "Use self-supporting or tree-free hammock systems if safe anchors are unavailable",
            "Keep all drinks as pure water carried in a clean, sealed container",
            "Store food, flavored drinks, and all scented items away from your hammock or sleep area",
            "Avoid bear attractants anywhere near your resting or hammock setup spot",
            "Carry extra water and avoid dehydration during long outdoor resting sessions",
            "Use a hammock stand or self-supporting ultralight hammock when trees are unsafe or too far apart",
            "Keep fishing lines and hooks secured when resting to prevent accidental injuries",
            "Check weather and avoid hammock use in storms, high winds, or whiteout conditions",
            "Pack a basic survival kit even for hammock-only trips in the backcountry"
        ],
        estimatedMinutes: 15...120,
        goalPool: [
            GoalTemplate(title: "Set up hammock safely with correct strap height", difficulty: 2),
            GoalTemplate(title: "Spend 15 minutes screen-free resting", difficulty: 1),
            GoalTemplate(title: "Read 10 pages (or 15 minutes) comfortably", difficulty: 1),
            GoalTemplate(title: "Practice 5 minutes of deep breathing", difficulty: 1),
            GoalTemplate(title: "Notice 5 things you can see/hear/feel", difficulty: 1),
            GoalTemplate(title: "Keep posture comfortable (no neck strain)", difficulty: 2),
            GoalTemplate(title: "Pack up and leave no trace", difficulty: 1),
            GoalTemplate(title: "Adjust hang angle to improve comfort", difficulty: 2),
            GoalTemplate(title: "Rest for 30 minutes without dozing (optional)", difficulty: 2),
            GoalTemplate(title: "Hydrate before and after resting", difficulty: 1)
        ],
        phoneAvailability: .fullyAllowed,
        
        sources: [
            SourceTemplate(title: "Backcountry Relaxing", description: "", hyperLink: "https://www.nps.gov/glac/blogs/backcountry-relaxing.htm")
        ]
    ),

    .rockHopping: ActivityMetadata(
        description: "Rock hopping is moving across rocks near streams, shorelines, or trails—part play, part balance challenge. It’s great for agility, coordination, and exploring interesting terrain. Keep it light and controlled rather than risky leaps. The fun comes from careful movement and staying steady.",
        safetyWarnings: [
            "Stay a safe distance from wildlife before stepping on rocks or ledges",
            "Stand still and stay calm if you spot a large animal while rock hopping",
            "Avoid running, sudden moves, or surprising animals near rock areas",
            "Never feed wildlife because it can attract predators into your space",
            "Stay off unstable, sloping, or eroding cliffs and bluffs",
            "Use binoculars or zoom lenses instead of stepping closer on rocks for photos",
            "Wear non-slip, sturdy shoes to avoid cuts or fatal falls on sharp or wet rocks",
            "Stay on marked trails and remain on the safe side of barriers or railings",
            "Always warm up, move slowly, and stay in control when navigating rocky terrain",
            "Don’t walk backwards or close to steep rock edges to capture a better view",
            "Clap, talk, or make light noise to avoid surprising wildlife in brushy rock areas",
            "Keep your phone charged for emergencies but don’t depend on constant signal",
            "Stop immediately if the ground, weather, or water near rocks begins to change rapidly",
            "Avoid the base of cliffs or overhangs where rocks may fall unexpectedly",
            "Wear a helmet if there is any risk of rock fall or head impact during hopping",
            "Don’t enter cold or swift water from rocks, even if it looks calm on the surface",
            "If swept by a wave or current from a rock ledge, float, stay calm, and signal for help",
            "Never dive or jump into unseen or shallow water from rocks",
            "Pack out trash and secure fishing lines or hooks so they don’t injure birds or people",
            "Take breaks and hydrate often to avoid fatigue, poor judgment, or slips on rocks"
        ],
        estimatedMinutes: 15...90,
        goalPool: [
            GoalTemplate(title: "Cross a short rock section without slipping", difficulty: 3),
            GoalTemplate(title: "Take slow, deliberate steps for 10 minutes", difficulty: 2),
            GoalTemplate(title: "Practice 10 balance holds (2–3 seconds each)", difficulty: 3),
            GoalTemplate(title: "Avoid risky jumps—only safe steps", difficulty: 2),
            GoalTemplate(title: "Choose a route with safe exit points", difficulty: 2),
            GoalTemplate(title: "Keep shoes with good traction for the whole session", difficulty: 2),
            GoalTemplate(title: "Hop across 15 rocks with control", difficulty: 3),
            GoalTemplate(title: "Do a short warmup before starting", difficulty: 1),
            GoalTemplate(title: "Stop if rocks are too slick and switch activity", difficulty: 2),
            GoalTemplate(title: "Finish with calf/ankle stretching", difficulty: 2)
        ],
        phoneAvailability: .allowedWithRisk,
        
        sources: [
            SourceTemplate(title: "Staying Safe", description: "Keep rock hopping an exciting experience by maintaining these safety rules.", hyperLink: "https://www.nps.gov/subjects/climbing/staying-safe.htm")
        ]
    ),

    .bonfireNight: ActivityMetadata(
        description: "A bonfire night is a cozy outdoor gathering around a controlled fire—great for conversation, warmth, and relaxation. It can include roasting snacks, telling stories, or simply enjoying the glow. Safety matters most: a responsible setup and full extinguishing are non-negotiable. Keep it calm, clean, and respectful of local rules.",
        safetyWarnings: [
            "Buy fireworks only from licensed or established retail outlets",
            "Always read and follow the label directions before ignition",
            "Have a responsible adult present to supervise fireworks use",
            "Ignite fireworks only outdoors in cleared areas away from buildings, homes, and flammables",
            "Light one firework at a time and maintain full control while doing so",
            "Never relight or reignite malfunctioning fireworks; soak them in water and dispose safely",
            "Wear eye protection and avoid using metal, glass, or unauthorized containers when launching",
            "Keep water and a fire extinguisher close for fire or burn emergencies",
            "Do not hold your phone near your face while lighting; maintain distance immediately after ignition",
            "Never throw fireworks at people or animals, or carry them in pockets",
            "Keep bonfires far from ignition sources, loose fireworks cartons, and dry leaves",
            "Let others know your celebration location in case emergency help is needed",
            "Soak used fireworks before trash disposal to prevent accidental fires",
            "Avoid smoking or open flames within 50 feet of fireworks or bonfire zones",
            "Store fireworks in a cool, dry place until use",
            "Never attempt homemade fireworks or unauthorized modifications",
            "Watch for sudden wind or weather shifts around bonfire and fireworks areas",
            "Do not use metal or glass containers in bonfire pits where fireworks might roll or ignite accidentally",
            "If a wildfire or flare-up starts, step back, alert others loudly, and contact emergency services immediately",
            "Keep children and pets at a safe viewing distance from both fireworks and open bonfires",
            "Ensure exit routes from celebration areas remain clear at all times"
        ],
        estimatedMinutes: 30...240,
        goalPool: [
            GoalTemplate(title: "Set up fire safely in an approved area", difficulty: 2),
            GoalTemplate(title: "Keep a water source nearby", difficulty: 1),
            GoalTemplate(title: "Maintain a tidy area (no litter)", difficulty: 1),
            GoalTemplate(title: "Roast a snack safely (if desired)", difficulty: 1),
            GoalTemplate(title: "Stay warm with layers and comfort", difficulty: 1),
            GoalTemplate(title: "Keep fire controlled and not oversized", difficulty: 2),
            GoalTemplate(title: "Avoid smoke exposure by adjusting position", difficulty: 1),
            GoalTemplate(title: "Put out the fire completely", difficulty: 3),
            GoalTemplate(title: "Pack out all trash and leftovers", difficulty: 2),
            GoalTemplate(title: "Leave the site better than you found it", difficulty: 2)
        ],
        phoneAvailability: .fullyAllowed,
        
        sources: [
            SourceTemplate(title: "Fireworks Safety Fact Sheet", description: "Involvement with fire should be taken very cautiously.", hyperLink: "https://www.tdi.texas.gov/pubs/videoresource/fsfireworks.pdf")
        ]
    ),

    // Team sports
    .soccer: ActivityMetadata(
        description: "Soccer is a fast-paced sport that builds cardio fitness, footwork, and teamwork. It involves constant movement, short sprints, and quick direction changes. You can play full matches or do drills like passing, shooting, and agility work. Warmups and good footwear help prevent common lower-body injuries.",
        safetyWarnings: [
            "Use a sport-specific, certified helmet for high-risk positions or drills involving heading practice",
            "Always wear snug-fitting shin guards to protect your lower legs from kicks and collisions",
            "Keep your head up while tracking the ball to avoid unexpected player collisions",
            "Apply sunscreen and wear eye protection like goggles if playing in bright or dusty outdoor fields",
            "Never perform or exit a heading motion with poor technique to avoid neck or head strain",
            "Do not wear metal cleats; use molded plastic cleats for safer traction on grass or dirt",
            "If you feel joint or muscle pain, stop and leave the field until evaluated and recovered",
            "Swim or recover only after escaping rip-current zones if playing near coastal beach fields",
            "Match your skills to the terrain and avoid tackling or heading in unsafe ground conditions",
            "Hydrate before, during, and after play to prevent heat exhaustion and dehydration",
            "Cast only in permitted play zones when practicing ball kicks near open water or cliffs",
            "Do not fight the current of play disputes; let referees handle conflicts calmly"
        ],
        estimatedMinutes: 30...120,
        goalPool: [
            GoalTemplate(title: "Warm up with light jogging and dynamic stretches", difficulty: 1),
            GoalTemplate(title: "Do 20 accurate passes with a partner", difficulty: 2),
            GoalTemplate(title: "Practice dribbling through cones for 10 minutes", difficulty: 3),
            GoalTemplate(title: "Take 20 controlled shots on goal", difficulty: 3),
            GoalTemplate(title: "Complete a 20-minute scrimmage", difficulty: 3),
            GoalTemplate(title: "Practice defensive footwork for 5 minutes", difficulty: 3),
            GoalTemplate(title: "Do 5 short sprint intervals safely", difficulty: 4),
            GoalTemplate(title: "Cool down with light jogging and stretching", difficulty: 2),
            GoalTemplate(title: "Maintain teamwork communication throughout", difficulty: 2),
            GoalTemplate(title: "Hydrate before and after", difficulty: 1)
        ],
        phoneAvailability: .allowedWithRisk,
        
        sources: [
            SourceTemplate(title: "SUMMER SPORTS SAFETY", description: "", hyperLink: "https://www.njconsumeraffairs.gov/News/Consumer%20Briefs/summer-sports-safety.pdf")
        ]
    ),

    .basketball: ActivityMetadata(
        description: "Basketball is a quick, skill-driven sport combining shooting, dribbling, defense, and teamwork. It delivers excellent cardio through repeated sprints and direction changes. You can play full games or do focused drills that build consistency. Good footwork and warmups help protect ankles and knees.",
        safetyWarnings: [
            "Choose sturdy, non-skid sole sneakers to prevent ankle and foot slips on the court",
            "Keep your head up and body in control while moving fast to avoid collisions and falls",
            "Wear a mouthguard if there’s any risk of contact near the face or elbows",
            "Use shatterproof protective eyewear if you wear glasses during play",
            "Inspect the court for debris, glass, or holes before starting a game or practice",
            "Never crouch or run blindly toward a loose ball near hazards like stairs or edges",
            "Warm up with light cardio like jogging or jumping jacks and stretch for 30 seconds per muscle group",
            "Drink water frequently in hot gyms or outdoor courts to prevent dehydration",
            "Never throw or pass a ball near someone’s face during disagreements or disputes",
            "Stop playing immediately if you feel pain and don’t return until it fully subsides",
            "Maintain a 3-foot safe zone from burning equipment or heaters when courts are near indoor facilities",
            "Avoid alcohol before or during games because it impairs balance and judgment"
        ],
        estimatedMinutes: 30...120,
        goalPool: [
            GoalTemplate(title: "Warm up with light jogging and mobility", difficulty: 1),
            GoalTemplate(title: "Make 20 close-range shots", difficulty: 2),
            GoalTemplate(title: "Practice dribbling with both hands for 10 minutes", difficulty: 3),
            GoalTemplate(title: "Make 10 free throws with consistent routine", difficulty: 3),
            GoalTemplate(title: "Do 10 layups with each hand", difficulty: 4),
            GoalTemplate(title: "Practice defensive slides for 5 minutes", difficulty: 3),
            GoalTemplate(title: "Play a half-court game with good spacing", difficulty: 3),
            GoalTemplate(title: "Do 5 minutes of passing drills (chest/bounce)", difficulty: 2),
            GoalTemplate(title: "Cool down and stretch calves/quads", difficulty: 2),
            GoalTemplate(title: "Focus on safe landings after rebounds/jumps", difficulty: 3)
        ],
        phoneAvailability: .allowedWithRisk,
        
        sources: [
            SourceTemplate(title: "SUMMER SPORTS SAFETY", description: "", hyperLink: "https://www.njconsumeraffairs.gov/News/Consumer%20Briefs/summer-sports-safety.pdf")
        ]
    ),

    .tennis: ActivityMetadata(
        description: "Tennis is a racket sport that blends agility, strategy, and precise hand-eye coordination. You’ll move in short bursts while controlling spin, placement, and timing. It’s fun for casual rallies or competitive matches, and it’s great for fitness. Starting with consistent rallying builds the foundation fast.",
        safetyWarnings: [
            "Tennis requires no direct physical contact, but you should still keep distance from others during play",
            "Wash your hands before and after playing, especially if you touched shared surfaces or equipment",
            "Never share personal gear like racquets, grips, towels, wristbands, or water bottles",
            "Use your racquet or foot to pick up and return balls instead of your hands",
            "Stay on your side of the court and avoid walking into other play zones or crossing hazards",
            "Inspect the court beforehand for debris, glass, or holes that can cause slips or sprains",
            "Warm up gradually and do conditioning before intense play or competition",
            "Do not play if you feel pain or fatigue that reduces your control or reaction ability",
            "Avoid switching court ends frequently when resting in shared or crowded areas",
            "Do not use metal or unsafe cleats—wear proper tennis shoes with non-slip soles",
            "Carry water and take breaks to avoid dehydration or overheating",
            "Leave the facility promptly after playing to avoid blocking paths or exits"
        ],
        estimatedMinutes: 30...120,
        goalPool: [
            GoalTemplate(title: "Warm up with mini-tennis for 5 minutes", difficulty: 2),
            GoalTemplate(title: "Rally 20 hits in a row with a partner", difficulty: 3),
            GoalTemplate(title: "Practice 20 forehands focusing on form", difficulty: 2),
            GoalTemplate(title: "Practice 20 backhands focusing on form", difficulty: 3),
            GoalTemplate(title: "Hit 15 serves with consistent toss", difficulty: 4),
            GoalTemplate(title: "Practice footwork split-step for 5 minutes", difficulty: 3),
            GoalTemplate(title: "Aim 10 shots to a target area", difficulty: 3),
            GoalTemplate(title: "Play a short game with correct scoring", difficulty: 3),
            GoalTemplate(title: "Cool down and stretch shoulders/hips", difficulty: 2),
            GoalTemplate(title: "Stop if you feel elbow/shoulder pain increasing", difficulty: 2)
        ],
        phoneAvailability: .allowedWithRisk,
        
        sources: [
            SourceTemplate(title: "PLAYING TENNIS SAFELY", description: "", hyperLink: "https://assets.nfhs.org/umbraco/media/3812224/usta_covid19_playingtennissafely-players-1.pdf")
        ]
    ),

    .volleyball: ActivityMetadata(
        description: "Volleyball is a dynamic sport focused on quick reactions, jumping, and teamwork. It can be played on sand or court, and it builds agility and shoulder endurance. You can play casual games or do drills like serving and passing. Warmups help protect shoulders and knees.",
        safetyWarnings: [
            "Prioritize preventing ankle sprains, patellar tendinopathy (jumper’s knee), and shoulder overuse, since they are the most common volleyball injuries.",
            "Be extra cautious if you have a previous ankle sprain, because repeat sprains are very common and risk is highest within 6–12 months after injury.",
            "Rehab ankle sprains fully before returning to play, with a focus on restoring neuromuscular control and proprioception.",
            "Add balance-board (wobble board) training into warm-ups, especially if you’ve had a prior ankle sprain.",
            "Practice safer spike approach, takeoff, and landing technique to reduce under-the-net contact and awkward landings.",
            "Train block movement and landing awareness to avoid landing on an opponent’s or teammate’s foot near the net.",
            "Consider ankle taping or bracing if you have a history of sprains, since external supports may reduce recurrent sprains in similar sports.",
            "Limit jump volume on hard, unforgiving indoor surfaces to reduce the cumulative load that triggers jumper’s knee.",
            "Increase jump training gradually rather than abruptly, especially when moving up to a higher level of play with heavier training loads.",
            "Refine spike approach and landing mechanics to reduce valgus knee strain and excessive knee flexion on landing.",
            "Use eccentric quadriceps training (such as decline squats) as part of prevention and rehab for patellar tendinopathy.",
            "Do not return to play with jumper’s knee until rehab is complete, not just until pain temporarily fades.",
            "Reduce shoulder overload by managing the total volume of serving and spiking to allow recovery time.",
            "Maintain year-round shoulder conditioning with emphasis on eccentric rotator cuff and scapular control work.",
            "Keep a consistent stretching routine to address shoulder tightness and internal-rotation deficits that may increase risk in overhead athletes.",
            "Strengthen core stability so the torso generates more power and the shoulder is not overworked during serving and spiking.",
            "Get early, accurate diagnosis and thorough rehab for shoulder pain, and delay return until symptoms are gone and mechanics are corrected.",
            "Do not rely on patellar straps or shoulder taping as proven prevention tools, because evidence for them is lacking."
        ],
        estimatedMinutes: 30...120,
        goalPool: [
            GoalTemplate(title: "Warm up shoulders and ankles for 5 minutes", difficulty: 1),
            GoalTemplate(title: "Practice 20 controlled passes", difficulty: 2),
            GoalTemplate(title: "Practice 15 serves focusing on consistency", difficulty: 3),
            GoalTemplate(title: "Do 10 controlled sets to a target", difficulty: 3),
            GoalTemplate(title: "Practice 10 spikes with safe landings", difficulty: 4),
            GoalTemplate(title: "Play a short game to 15 points", difficulty: 3),
            GoalTemplate(title: "Communicate clearly for every play", difficulty: 2),
            GoalTemplate(title: "Take a hydration break mid-session", difficulty: 1),
            GoalTemplate(title: "Cool down and stretch shoulders/legs", difficulty: 2),
            GoalTemplate(title: "Focus on safe movement and spacing", difficulty: 2)
        ],
        phoneAvailability: .allowedWithRisk,
        
        sources: [
            SourceTemplate(title: "Strategies for the prevention of volleyball related injuries", description: "", hyperLink: "https://pmc.ncbi.nlm.nih.gov/articles/PMC2564299/")
        ]
    ),

    .cricket: ActivityMetadata(
        description: "Cricket is a bat-and-ball sport combining bursts of sprinting, throwing, batting technique, and teamwork. It can be casual in a park or more structured in organized play. The sport builds coordination and stamina while rewarding strategy. Warmups and safe throwing mechanics reduce strain.",
        safetyWarnings: [
            "Treat cricket as high-risk for overuse and impact injuries even though it is a noncontact sport.",
            "Track and manage workload because more matches and less rest increase injury prevalence.",
            "Pay special attention to bowling, fielding, and wicketkeeping since they account for most injuries.",
            "Warm up thoroughly to reduce strain risk, especially for hamstrings.",
            "Monitor overs bowled week-to-week because heavy recent bowling workload is linked to hamstring strains.",
            "Address fatigue early during play because tiredness is a modifiable contributor to hamstring injury.",
            "Maintain flexibility and correct strength imbalance by keeping hamstring strength at least 60% of quadriceps strength.",
            "Take previous hamstring injury seriously because it increases reinjury risk.",
            "Use gradual workload progression because sudden increases can trigger overuse injuries and stress fractures.",
            "Teach and practice correct diving-and-recovery technique to reduce acute knee and ankle injuries during fielding.",
            "Train fast bowlers to avoid mixed bowling technique because education toward nonmixed technique reduced spine injury incidence.",
            "Screen fast bowlers with single-leg balance tests and the Star Excursion Balance Test to flag higher back/trunk injury risk.",
            "Act early on low back pain in fast bowlers because MRI can detect stress changes that predict future stress fracture risk.",
            "Build trunk and core control to better tolerate the repeated lateral flexion and rotation loads of fast bowling.",
            "Limit excessive passive stretching and avoid forceful activation at maximal stretch to reduce quadriceps strain risk.",
            "Use proper batting mechanics and appropriate bat weight to reduce lateral epicondylitis risk.",
            "Manage throwing volume and shoulder conditioning because overhead throwing load is a major driver of shoulder problems.",
            "Protect fingers and hands during batting and fielding, since finger injuries are common in these roles.",
            "Consider strapping the last two fingers to help prevent hand injuries.",
            "Use sport-specific eye protection for batsmen and wicketkeepers to reduce serious eye injury risk.",
            "Wear a well-fitted helmet for batting because helmets have been associated with major reductions in head/face injury frequency.",
            "Stay alert that facial and nasal injuries can still occur even with helmets, so equipment standards and updates matter.",
            "Treat posterior ankle pain in fast bowlers as a workload-and-boot-related risk, especially with low-cut boots and harder ground.",
            "Manage ground hardness and footwear choices because they can contribute to repetitive foot/ankle trauma.",
            "Prioritize injury surveillance, early detection, and prompt treatment to reduce time lost and speed safe return to play."
        ],
        estimatedMinutes: 30...180,
        goalPool: [
            GoalTemplate(title: "Warm up with light jogging and stretches", difficulty: 1),
            GoalTemplate(title: "Practice 20 accurate throws", difficulty: 2),
            GoalTemplate(title: "Practice batting form for 10 minutes", difficulty: 3),
            GoalTemplate(title: "Run between wickets for 10 minutes", difficulty: 3),
            GoalTemplate(title: "Play a short over-based game", difficulty: 3),
            GoalTemplate(title: "Practice 10 controlled catches", difficulty: 3),
            GoalTemplate(title: "Focus on communication and teamwork", difficulty: 2),
            GoalTemplate(title: "Take a hydration break mid-session", difficulty: 1),
            GoalTemplate(title: "Cool down and stretch shoulders/legs", difficulty: 2),
            GoalTemplate(title: "Use safe throwing mechanics throughout", difficulty: 2)
        ],
        phoneAvailability: .allowedWithRisk,
        
        sources: [
            SourceTemplate(title: "Injuries in Cricket", description: "", hyperLink: "https://pmc.ncbi.nlm.nih.gov/articles/PMC5958448/")
        ]
    ),

    .baseball: ActivityMetadata(
        description: "Baseball is a classic team sport combining throwing, hitting, running, and fielding skills. It involves short bursts of effort with plenty of coordination and timing. You can play full games or focus on drills like batting practice and catching. Warming up arms and shoulders helps prevent strain.",
        safetyWarnings: [
            "Always use a sport-specific, certified helmet, especially when batting or catching",
            "Use molded plastic cleats, not metal, for safer footing on the field",
            "Check that your bat, hooks, rods, and gear are undamaged before play begins",
            "Keep your head up while running bases to avoid collisions or sudden falls",
            "Never reignite or reuse malfunctioning fireworks near baseball fields or gear zones",
            "Check the area behind you before casting or throwing to avoid accidental injuries from the bat or ball",
            "Stop immediately if you feel pain in your knee, lower leg, or joints",
            "Do not dive or jump into shallow water when retrieving a ball near lakes or rivers",
            "Designate someone in the group who knows first aid for emergencies during practice or games",
            "Carry identification if playing in remote park fields for faster emergency response if needed",
            "Hydrate consistently and reapply sunscreen every 2 hours during long summer play sessions",
            "Never run from or feed wildlife when retrieving a ball in backcountry fields"
        ],
        estimatedMinutes: 30...180,
        goalPool: [
            GoalTemplate(title: "Warm up with light throwing progression", difficulty: 2),
            GoalTemplate(title: "Catch 20 clean throws", difficulty: 2),
            GoalTemplate(title: "Practice 15 swings focusing on form", difficulty: 3),
            GoalTemplate(title: "Run bases safely 5 times", difficulty: 3),
            GoalTemplate(title: "Practice ground balls for 10 minutes", difficulty: 3),
            GoalTemplate(title: "Practice 10 fly-ball catches", difficulty: 3),
            GoalTemplate(title: "Play a short scrimmage inning", difficulty: 3),
            GoalTemplate(title: "Keep good communication on pop-ups", difficulty: 2),
            GoalTemplate(title: "Cool down and stretch shoulders/legs", difficulty: 2),
            GoalTemplate(title: "Stop if shoulder pain increases", difficulty: 2)
        ],
        phoneAvailability: .allowedWithRisk,
        
        sources: [
            SourceTemplate(title: "SUMMER SPORTS SAFETY", description: "", hyperLink: "https://www.njconsumeraffairs.gov/News/Consumer%20Briefs/summer-sports-safety.pdf")
        ]
    ),

    .outdoorBadminton: ActivityMetadata(
        description: "Outdoor badminton is a light, fast racket game that works reflexes, footwork, and coordination. Wind adds a fun challenge, so rallies may be shorter and strategy changes. It’s great for casual play in a park or backyard. Focus on control and positioning more than power.",
        safetyWarnings: [
            "Treat badminton as a high-injury-risk sport even though it is non-contact, because speed, lunges, jumps, and overhead strokes create major loads.",
            "Reduce repetitive overload by adjusting training workload so the body can recover and overuse injuries don’t accumulate.",
            "Prioritize prevention of lower-limb injuries, especially knee and ankle problems, since these are the most commonly affected areas.",
            "Limit excessive lunge and jump volume because these movements create very high impact forces and joint torque in the knee and ankle.",
            "Coach safer cutting, acceleration, and deceleration mechanics to lower non-contact sprains, strains, and ligament injuries.",
            "Improve lunge technique to reduce fatigue and soreness, and avoid inefficient patterns that raise knee loading.",
            "Teach controlled landing mechanics after jump smashes because single-leg jump-and-land patterns can stress the ankle and knee.",
            "Strengthen and condition for eccentric lower-limb demands to better tolerate repeated braking forces during rallies.",
            "Protect the shoulder with good kinetic-chain coordination from legs and trunk to arm, since poor coordination increases stress injuries.",
            "Manage overhead stroke volume and shoulder conditioning to reduce overuse shoulder pain and rotator cuff tendinopathy risk.",
            "Build core stability because trunk dysfunction can increase shoulder and elbow injury risk in overhead athletes.",
            "Use proper grip and stroke mechanics to reduce lateral epicondylitis linked to repetitive short hitting actions.",
            "Rotate sports or vary training in adolescents to break the repetitive loading cycle that contributes to tendinopathy and stress injuries.",
            "Take persistent tendon pain seriously because tendinopathy reflects reduced load tolerance and can worsen with continued overload.",
            "Address signs of bone stress early because stress reactions can progress to stress fractures if ignored.",
            "Prevent doubles collision and contact injuries by maintaining spacing and awareness of partner and racquet position.",
            "Wear protective eyewear, especially in doubles, because high-speed shuttlecock impacts can cause severe ocular injuries.",
            "Teach younger players safe, low-risk play habits because junior elite players are more prone to acute traumatic injuries."
        ],
        estimatedMinutes: 20...90,
        goalPool: [
            GoalTemplate(title: "Warm up wrists and shoulders for 5 minutes", difficulty: 1),
            GoalTemplate(title: "Rally 10 hits in a row (wind-adjusted)", difficulty: 3),
            GoalTemplate(title: "Practice 20 controlled serves", difficulty: 2),
            GoalTemplate(title: "Practice 15 clears (high shots) with control", difficulty: 3),
            GoalTemplate(title: "Practice 10 drop shots (soft landing)", difficulty: 4),
            GoalTemplate(title: "Move your feet (split-step) every rally", difficulty: 3),
            GoalTemplate(title: "Play to 11 points with fair rules", difficulty: 2),
            GoalTemplate(title: "Adjust strategy for wind (aim, height)", difficulty: 3),
            GoalTemplate(title: "Cool down and stretch forearms", difficulty: 2),
            GoalTemplate(title: "Pack up and leave the area tidy", difficulty: 1)
        ],
        phoneAvailability: .allowedWithRisk,
        
        sources: [
            SourceTemplate(title: "Badminton Injuries in Elite Athletes: A Review of Epidemiology and Biomechanics", description: "", hyperLink: "https://pmc.ncbi.nlm.nih.gov/articles/PMC7205924/")
        ]
    ),

    // Fallback
    .other: ActivityMetadata(
        description: "This category is for activities that don’t fit the other options yet. Use it when you want to capture a general outdoor plan without being too specific. You can still set goals and safety reminders based on your situation. Keep it flexible and customize as you learn what you enjoy most.",
        safetyWarnings: [
            "Check conditions (weather, daylight, terrain) before starting.",
            "Bring water and basic essentials appropriate for the setting.",
            "Wear appropriate clothing/footwear for the environment.",
            "Tell someone your plan if you’ll be alone or in a remote area.",
            "Stop if you feel unsafe, unwell, or conditions change suddenly."
        ],
        estimatedMinutes: 15...180,
        goalPool: [
            GoalTemplate(title: "Plan your activity start and end time", difficulty: 1),
            GoalTemplate(title: "Bring water and drink at least once", difficulty: 1),
            GoalTemplate(title: "Warm up for 5 minutes before starting", difficulty: 1),
            GoalTemplate(title: "Do the activity continuously for 20 minutes", difficulty: 2),
            GoalTemplate(title: "Try one new skill or variation safely", difficulty: 3),
            GoalTemplate(title: "Take a short break and check how you feel", difficulty: 1),
            GoalTemplate(title: "Finish with a 5-minute cooldown", difficulty: 2),
            GoalTemplate(title: "Leave the area cleaner than you found it", difficulty: 2),
            GoalTemplate(title: "Reflect on what worked and what to change", difficulty: 1),
            GoalTemplate(title: "Set one simple next-step goal for next time", difficulty: 2)
        ],
        phoneAvailability: .fullyAllowed,
        
        sources: [
            SourceTemplate(title: "", description: "", hyperLink: "")
        ]
    )
]
