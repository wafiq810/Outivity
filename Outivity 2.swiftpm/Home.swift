import SwiftData
import SwiftUI
import CoreML

struct Home: View {
    var menuRouteHandler: ((MenuRoute) -> Void)? = nil
    @State private var isAlactivitiesShowing: Bool = false
    @Environment(\.modelContext) private var modelContext

    @State private var navigationPath = NavigationPath()
    @State private var activityPhotoGalleryCoordinator = ActivityPhotoGalleryCoordinator()

    @Query(filter: #Predicate<ActivityTracker> { $0.endedAt == nil })
    private var activeTrackers: [ActivityTracker]

    @Query(sort: [SortDescriptor(\ScheduledActivity.startTime, order: .forward)])
    private var scheduledActivities: [ScheduledActivity]

    // Activity sheet -> navigation state
    @State private var activityToShow: ActivityIdentity? = nil
    @State private var showActivityDetail: Bool = false

    // Quick-start tracker navigation state
    @State private var trackerToShow: ActivityTracker? = nil
    @State private var showTrackerDetail: Bool = false

    @State private var now: Date = .now

    @State private var showingMenu: Bool = false
    @State private var pendingMenuRoute: MenuRoute? = nil
    @StateObject private var recommendationReloader = RecommendationReloader()

    init(menuRouteHandler: ((MenuRoute) -> Void)? = nil) {
        self.menuRouteHandler = menuRouteHandler
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            HStack(alignment: .center) {
                VStack(alignment: .leading) {
                    HStack(spacing: 12){
                        Image(systemName: "figure.outdoor.soccer")
                            .font(.system(size: 14))
                            .padding(8)
                            .background(Circle().fill(Color.accentColor))
                            .foregroundColor(.white)
                        Text("Outivity")
                            .font(.system(size: 37, weight: .bold, design: .rounded))
                    }
                }

                Spacer()

                Button {
                    showingMenu = true
                    activityToShow = nil
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 24))
                        .padding()
                        .accessibilityLabel("Menu")
                }
                .glassEffect(.regular.interactive(), in: Circle())
                .buttonStyle(.plain)
            }
            .navigationTitle("Home")
            .padding()
            .padding(.horizontal)

            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .center) {
                        
                        // MARK: Start and schedule buttons
                        HStack(spacing: 16){
                            Button {
                                activityToShow = nil
                                isAlactivitiesShowing = true
                            } label: {
                                VStack(alignment: .leading) {
                                    Text("Start new activity").frame(maxWidth: .infinity, alignment: .leading)
                                    Spacer()
                                    Image(systemName: "plus")
                                        .font(.title3)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(24)
                                .contentShape(RoundedRectangle(cornerRadius: 38.0))
                                .glassEffect(.regular.interactive().tint(.blue), in: .rect(cornerRadius: 38.0))
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.white)
                            .buttonStyle(.plain)
                            .sheet(isPresented: $isAlactivitiesShowing) {
                                NavigationStack {
                                    ActivityCardList(title: "Activities", showsCloseButton: true) { identity in
                                        activityToShow = identity
                                        showActivityDetail = true
                                        isAlactivitiesShowing = false
                                    }
                                }
                            }
                            NavigationLink {
                                ScheduledActivityListView()
                            } label: {
                                
                                VStack(alignment: .leading){
                                    Text("Schedule activities").frame(maxWidth: .infinity, alignment: .leading)
                                    Spacer()
                                    Image(systemName: "calendar")
                                }
                                .padding(24)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(RoundedRectangle(cornerRadius: 38.0))
                                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 38.0))
                            }
                            .frame(maxWidth: .infinity)
                            .buttonStyle(.plain)
                            
                        }.frame(maxWidth: .infinity)
                            .frame(height: 160)
                            .compositingGroup()
                            .zIndex(1)
                        
                            .padding()
                        
                        //MARK: Resume button
                        if let active = activeTrackers.first {
                            NavigationLink {
                                ActivityTrackerView(tracker: active)
                            } label: {
                                HStack {
                                    Text("Resume \(active.displayActivityName)")
                                    Spacer()
                                    Image(systemName: "play.fill")
                                }
                                .padding()
                            }
                            .padding(.horizontal)
                            .buttonStyle(.glassProminent)
                        }
                        
                        //MARK: Scheduled activity quick start
                        if let soon = upcomingWithin5Minutes {
                            Button {
                                quickStartScheduled(soon)
                            } label: {
                                HStack {
                                    Text("Start \(soon.activity?.displayName ?? "Scheduled Activity")")
                                    Spacer()
                                    Text(timeRemainingString(until: soon.startTime))
                                        .foregroundStyle(.secondary)
                                        .font(.callout)
                                }
                                .padding()
                            }
                            .buttonStyle(.glassProminent)
                            .padding(.horizontal)
                        }
                        
                        //MARK: History button
                        NavigationLink {
                            ActivityHistoryView()
                        } label: {
                            HStack {
                                Text("Your activity history")
                                Spacer()
                                Image(systemName: "clock.arrow.circlepath")
                            }
                            .padding()
                        }
                        .buttonStyle(.glass)
                        .padding(.horizontal)
                        
                        
                    }
                }
                .padding(.horizontal)
                
                // MARK: Predicted activity
                PredictedActivityView { activity in
                    activityToShow = ActivityIdentity(activity: activity)
                    showActivityDetail = true
                }
                .environmentObject(recommendationReloader)
                .padding(.horizontal)
                .padding(.top)
                
                // MARK: Quick statistics
                VStack{
                    ActivityChartsQuickLook()
                        .padding(.top)
                    
                    Button {
                        menuRouteHandler?(.progress)
                    } label: {
                        HStack {
                            Text("See your progress")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                    }
                    .buttonStyle(.glassProminent)
                    .padding(.bottom)
                }.padding(.horizontal)
                    .padding(.horizontal)
            }
            .toolbar(.hidden, for: .navigationBar)                // push ActivityDetailedView when an activity was selected from the sheet
            .navigationDestination(isPresented: $showActivityDetail) {
                if let identity = activityToShow {
                    ActivityDetailedView(identity: identity)
                }
            }
            // push tracker view when quick-starting a schedule
            .navigationDestination(isPresented: $showTrackerDetail) {
                if let t = trackerToShow {
                    ActivityTrackerView(tracker: t)
                }
            }
            .navigationDestination(for: MenuRoute.self) { route in
                switch route {
                case .activityHistory:
                    ActivityHistoryView()
                case .scheduledActivities:
                    ScheduledActivityListView()
                case .scheduledActivitiesAdd:
                    ScheduledActivityListView(showAddSheet: true)
                case .gallery, .backpack, .backpackAdd, .progress:
                    EmptyView()
                }
            }
            // keep 'now' updated
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { tick in
                now = tick
            }
            // when the activities sheet dismisses, trigger navigation to selected activity (use two-arg onChange to avoid deprecation)
            .onChange(of: isAlactivitiesShowing) { _old, isPresented in
                if !isPresented, activityToShow != nil {
                    showActivityDetail = true
                }
            }
            .onChange(of: showingMenu) { _, isPresented in
                if !isPresented {
                    openPendingMenuRoute()
                    // If an activity was selected while the menu was open, navigate now that the menu is closed.
                    if self.activityToShow != nil && !self.isAlactivitiesShowing && !self.showActivityDetail {
                        DispatchQueue.main.async {
                            self.showActivityDetail = true
                        }
                    }
                }
            }
        }
        .allowsHitTesting(activityPhotoGalleryCoordinator.selectedImage == nil)
        .refreshable {
            guard activityPhotoGalleryCoordinator.selectedImage == nil else { return }

            recommendationReloader.reload()
            NotificationCenter.default.post(name: .predictedActivityReload, object: nil)
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        .onReceive(NotificationCenter.default.publisher(for: .activityIdentityPicked)) { note in
            guard let identity = note.object as? ActivityIdentity else { return }
            // Store selection
            self.activityToShow = identity
            // Navigate immediately so it appears while sheets are dismissing
            if !self.showActivityDetail {
                self.showActivityDetail = true
            }
            if self.isAlactivitiesShowing { self.isAlactivitiesShowing = false }
            if self.showingMenu { self.showingMenu = false }
        }
        .sheet(isPresented: $showingMenu) {
            Menu(sections: menuSections, actionHandler: handleMenuRoute(_:))
        }
    }

    private var menuSections: [MenuSection] {
        [
            MenuSection(
                id: "general",
                title: "General",
                actions: [
                    MenuAction.internalAction(id: "settings", title: "Settings", systemImage: "gear", destination: UserSettingsView())
                ]
            ),
            MenuSection(
                id: "activity",
                title: "Activity",
                actions: [
                    MenuAction.routedAction(id: "activityHistory", title: "Activity history", systemImage: "clock.arrow.circlepath", route: .activityHistory),
                    MenuAction.internalAction(id: "customActivities", title: "Custom activities", systemImage: "list.bullet", destination: CustomActivityView())
                ]
            ),
            MenuSection(
                id: "equipment",
                title: "Equipment",
                actions: [
                    MenuAction.internalAction(id: "customEquipment", title: "Your custom equipment", systemImage: "plus.rectangle.fill", destination: CustomEquipmentView())

                ]
            ),
            MenuSection(
                id: "reference",
                title: "Reference",
                actions: [
                    MenuAction.internalAction(id: "metValues", title: "MET Values", systemImage: "flame", destination: METValuesView())
                ]
            ),
            MenuSection(
                id: "activitySchedule",
                title: "Activity Schedule",
                actions: [
                    MenuAction.routedAction(id: "scheduledActivities", title: "Scheduled activities", systemImage: "calendar", route: .scheduledActivities),
                    MenuAction.routedAction(id: "scheduleNewActivity", title: "Schedule new activity", systemImage: "calendar.badge.plus", route: .scheduledActivitiesAdd)
                ]
            ),
            MenuSection(
                id: "backpack",
                title: "Backpack",
                actions: [
                    MenuAction.routedAction(id: "backpackTab", title: "BackPack", systemImage: "backpack", route: .backpack),
                    MenuAction.routedAction(id: "backpackAdd", title: "Add new backpack", systemImage: "plus.circle.fill", route: .backpackAdd)
                ]
            ),
            MenuSection(
                id: "progress",
                title: "Your progress",
                actions: [
                    MenuAction.routedAction(id: "progressTab", title: "Your progress", systemImage: "figure.run", route: .progress)
                ]
            ),
            MenuSection(
                id: "gallery",
                title: "Gallery",
                actions: [
                    MenuAction.routedAction(id: "gallery", title: "Gallery", systemImage: "photo.fill.on.rectangle.fill", route: .gallery)
                ]
            )
        ]
    }

    private func handleMenuRoute(_ route: MenuRoute) {
        pendingMenuRoute = route
    }

    private func openPendingMenuRoute() {
        guard let route = pendingMenuRoute else { return }
        pendingMenuRoute = nil

        switch route {
        case .activityHistory, .scheduledActivities, .scheduledActivitiesAdd:
            navigationPath.append(route)
        case .gallery, .backpack, .backpackAdd, .progress:
            menuRouteHandler?(route)
        }
    }

    // MARK: - Quick-start helpers
    private var upcomingWithin5Minutes: ScheduledActivity? {
        let nowDate = now
        return scheduledActivities.first { sched in
            guard sched.status == .upcoming else { return false }
            let interval = sched.startTime.timeIntervalSince(nowDate)
            return interval > 0 && interval <= 5 * 60
        }
    }

    private func timeRemainingString(until date: Date) -> String {
        let interval = max(0, Int(date.timeIntervalSince(now)))
        let minutes = interval / 60
        let seconds = interval % 60
        if minutes > 0 {
            return String(format: "%dm %02ds", minutes, seconds)
        } else {
            return String(format: "%02ds", seconds)
        }
    }

    private func quickStartScheduled(_ scheduled: ScheduledActivity) {
        let tracker = ActivityTrackerStore.startNewActivity(scheduled.activity!, in: modelContext, at: Date(), presetGoals: scheduled.goals)
        tracker.attachToScheduled(scheduled, in: modelContext)
        trackerToShow = tracker
        DispatchQueue.main.async {
            showTrackerDetail = true
        }
    }
}

#Preview{
    Home()
}

