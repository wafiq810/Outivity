import SwiftData
import SwiftUI


@main
struct Outivity: App {
//    @Environment(\.modelContext) var modelContext
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [UserInfo.self, ActivityTracker.self, ActivityPhoto.self, BackPack.self, CustomEquipment.self, CustomGoal.self, CustomActivity.self])
    }
}
