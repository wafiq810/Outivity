import Foundation
import SwiftData

@Model
public final class ScheduledActivity {
    var activity: Activity?
    var customActivityID: UUID?
    var startTime: Date
    var goals: [GoalTemplate]
    
    @Relationship
    var session: ActivityTracker?
    
    init(activity: Activity? = nil, customActivityID: UUID? = nil, startTime: Date, goals: [GoalTemplate] = []) {
        self.activity = activity
        self.customActivityID = customActivityID
        self.startTime = startTime
        self.goals = goals
    }
    
    var status: ScheduleStatus {
        if let session = session {
            return session.isActive ? .ongoing : .completed
        }

        if Date() > startTime {
            return .missed
        }
        return .upcoming
    }
}

public enum ScheduleStatus: String, Codable {
    case upcoming
    case ongoing
    case completed
    case missed
}
