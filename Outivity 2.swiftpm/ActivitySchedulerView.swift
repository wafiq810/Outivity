import SwiftUI
import SwiftData

// MARK: - ScheduledActivityListView

public struct ScheduledActivityListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isPresentingAdd: Bool
    @Query(sort: [SortDescriptor(\ScheduledActivity.startTime, order: .reverse)])
    private var scheduledActivities: [ScheduledActivity]
    @Query private var allCustomActivities: [CustomActivity]

    public init(showAddSheet: Bool = false) {
        _isPresentingAdd = State(initialValue: showAddSheet)
    }

    public var body: some View {
        List {
            if scheduledActivities.isEmpty {
                Section{} footer: {
                    VStack(alignment: .center) {
                        
                        Image(systemName: "calendar")
                            .font(.system(size: 44))
                            .padding(18)
                            .background(Circle().fill(Color.secondary))
                            .foregroundColor(.white)
                        
                        Text("No scheduled activities yet")
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.secondary)
                            .multilineTextAlignment(.center)

                        Text("Tap \(Image(systemName: "plus")) to schedule your first activity.")
                            .foregroundStyle(Color.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            } else {
                ForEach(groupedScheduledActivities, id: \.day) { group in
                    Section {
                        ForEach(group.scheduled) { sched in
                            NavigationLink {
                                ScheduledActivityDetailedView(scheduled: sched)
                            } label: {
                                ScheduledActivityCardView(scheduled: sched)
                            }
                        }
                        .onDelete { offsets in
                            delete(at: offsets, in: group.scheduled)
                        }
                    } header: {
                        Text(dayHeaderText(for: group.day))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                }
            }
        }
        .navigationTitle("Scheduled Activities")
        .navigationBarHidden(false)
        .toolbar {
            if !scheduledActivities.isEmpty{
                ToolbarItem(placement: .topBarTrailing) {
                    EditModeToggleButton(inactiveSystemImageName: "square.and.pencil", doneTitle: "Done")
                }
            }
            // Plus button remains on the trailing side
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isPresentingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingAdd) {
            NavigationStack {
                AddNewScheduledActivity()
            }
        }
    }

    // Group scheduled activities by start-of-day, preserve recent-first ordering within each day
    private var groupedScheduledActivities: [(day: Date, scheduled: [ScheduledActivity])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: scheduledActivities) { sched in
            calendar.startOfDay(for: sched.startTime)
        }
        return grouped
            .map { (day: $0.key, scheduled: $0.value.sorted { $0.startTime > $1.startTime }) }
            .sorted { $0.day > $1.day }
    }

    private func delete(at offsets: IndexSet, in items: [ScheduledActivity]) {
        for index in offsets {
            let s = items[index]
            modelContext.delete(s)
        }
        try? modelContext.save()
    }

    private func dayHeaderText(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(date: .abbreviated, time: .omitted)
    }
}

// MARK: - ScheduledActivityCardView

public struct ScheduledActivityCardView: View {
    @Bindable var scheduled: ScheduledActivity
    @Environment(\.modelContext) private var modelContext
    @Query private var allCustomActivities: [CustomActivity]
    @State private var now: Date = .now
    @State private var activeTracker: ActivityTracker? = nil
    @State private var pushTracker: Bool = false

    public init(scheduled: ScheduledActivity) {
        self._scheduled = Bindable(wrappedValue: scheduled)
    }

    public var body: some View {
        HStack(spacing: 12) {
            let identity = schedIdentity
            Image(systemName: identity?.symbolName ?? "questionmark")
                .font(.title)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(identity?.displayName ?? "Unknown Activity")
                        .font(.headline)
                    if let identity {
                        typeBadge(for: identity)
                    }
                }
                Text(scheduled.startTime.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 6) {
                Text(scheduled.status.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(statusColor)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6).strokeBorder(statusColor.opacity(0.25)))

                if shouldShowQuickStart {
                        Text("Starts in 5m")
                            .font(.caption2)
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor))
                            .foregroundColor(.white)
                }
            }
        }
        .padding(.vertical, 8)
        // Programmatic navigation to ActivityTrackerView using navigationDestination (non-deprecated)
        .navigationDestination(isPresented: $pushTracker) {
            if let t = activeTracker {
                ActivityTrackerView(tracker: t)
            } else {
                EmptyView()
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { tick in
            now = tick
        }
    }

    private var schedIdentity: ActivityIdentity? {
        if let customID = scheduled.customActivityID, let custom = allCustomActivities.first(where: { $0.id == customID }) {
            return ActivityIdentity(custom: custom)
        } else if let activity = scheduled.activity {
            return ActivityIdentity(activity: activity)
        }
        return nil
    }

    private var statusColor: Color {
        switch scheduled.status {
        case .upcoming: return .blue
        case .ongoing: return .green
        case .completed: return .gray
        case .missed: return .red
        }
    }

    @ViewBuilder
    private func typeBadge(for identity: ActivityIdentity) -> some View {
        let isCustom: Bool = {
            if case .custom = identity.kind { return true } else { return false }
        }()
        Text(isCustom ? "Custom" : "Built-in")
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(
                    (isCustom ? Color.blue : Color.secondary).opacity(0.15)
                )
            )
            .foregroundStyle(isCustom ? Color.blue : Color.secondary)
    }

    private var shouldShowQuickStart: Bool {
        guard scheduled.status == .upcoming else { return false }
        let interval = scheduled.startTime.timeIntervalSince(now)
        return interval <= 5 * 60 && interval > 0
    }

    private func quickStart() {
        let tracker = ActivityTrackerStore.startNewActivity(scheduled.activity!, in: modelContext, at: Date(), presetGoals: scheduled.goals)
        tracker.attachToScheduled(scheduled, in: modelContext)
        activeTracker = tracker
        DispatchQueue.main.async {
            pushTracker = true
        }
    }
}

// MARK: - ScheduledActivityDetailedView

public struct ScheduledActivityDetailedView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var scheduled: ScheduledActivity

    @State private var sessionToShow: ActivityTracker? = nil
    @State private var showSessionDetail: Bool = false
    @State private var trackerToShow: ActivityTracker? = nil
    @State private var showTrackerDetail: Bool = false

    public init(scheduled: ScheduledActivity) {
        self._scheduled = Bindable(wrappedValue: scheduled)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack {
                    Image(systemName: scheduled.activity!.symbolName)
                        .font(.system(size: 56))
                    VStack {
                        Text(scheduled.activity!.displayName)
                            .font(.largeTitle).bold()
                        Text(scheduled.startTime.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding()
                // Show UI based on schedule status
                Group {
                    switch scheduled.status {
                    case .upcoming:
                        Button(action: startScheduledActivity) {
                            HStack {
                                Spacer()
                                Text("Start")
                                    .font(.headline)
                                Spacer()
                            }
                            .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.horizontal)

                    case .ongoing:
                        HStack {
                            Image(systemName: "timer")
                                .foregroundStyle(.green)
                            Text("Ongoing.")
                                .font(.headline)
                                .foregroundStyle(.green)
                        }
                        .padding(.horizontal)
                        if let session = scheduled.session {
                            Button("Open session") {
                                sessionToShow = session
                                showSessionDetail = true
                            }
                            .buttonStyle(.bordered)
                            .padding(.horizontal)
                        }

                    case .completed:
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.gray)
                            Text("Completed.")
                                .font(.headline)
                                .foregroundStyle(.gray)
                        }
                        .padding(.horizontal)
                        
                        if let session = scheduled.session {
                            Button {
                                sessionToShow = session
                                showSessionDetail = true
                            } label: {
                                Text("See activity data")
                                    .padding()

                            }
                            .buttonStyle(.glassProminent)
                        }

                    case .missed:
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text("Missed.")
                                .font(.headline)
                                .foregroundStyle(.red)
                        }
                        .padding(.horizontal)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Goals")
                        .font(.headline)
                    if scheduled.goals.isEmpty {
                        Text("No goals predicted yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(scheduled.goals, id: \.id) { goal in
                            HStack {
                                if goal.isCustom {
                                   Text("Custom")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.blue.opacity(0.15)))
                                        .foregroundStyle(.blue)
                                }
                                Text(goal.title)
                                Spacer()
                                Text("Difficulty \(goal.difficulty)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()

                
            }
            .navigationBarTitleDisplayMode(.inline)
            .padding()
            .padding(.horizontal)
        }
        // Programmatic navigation to ActivityHistoryDetailView
        .navigationDestination(isPresented: $showSessionDetail) {
            if let s = sessionToShow {
                ActivityHistoryDetailView(tracker: s)
            } else {
                // Fallback empty view if session is unexpectedly nil
                EmptyView()
            }
        }
        .navigationDestination(isPresented: $showTrackerDetail) {
            if let tracker = trackerToShow {
                ActivityTrackerView(tracker: tracker)
            } else {
                EmptyView()
            }
        }
    }

    private func startScheduledActivity() {
        guard let activity = scheduled.activity else {
            trackerToShow = nil
            showTrackerDetail = true
            return
        }

        let tracker = ActivityTrackerStore.startNewActivity(activity, in: modelContext, at: Date(), presetGoals: scheduled.goals)
        tracker.attachToScheduled(scheduled, in: modelContext)

        trackerToShow = tracker
        showTrackerDetail = true
    }
}

// MARK: - AddNewScheduledActivity

public struct AddNewScheduledActivity: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedIdentity: ActivityIdentity = ActivityIdentity(activity: .hiking)
    @State private var startTime: Date = Date()
    @State private var goals: [GoalTemplate] = []
    @State private var predictedGoals: [GoalTemplate] = []
    @State private var selectedCustomGoalIDs: Set<UUID> = []
    @State private var suppressedPredictedGoalIDs: Set<UUID> = []
    @State private var userAddedBuiltInGoalIDs: Set<UUID> = []
    @State private var showGoalSheet: Bool = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack{
                    ActivityCardPicker(selection: $selectedIdentity)
                    
                    DatePicker("Start time", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                        .padding()
                        .padding(.leading)
                        .glassEffect(in: RoundedRectangle(cornerRadius: 38))
                    
                    
                    
                    VStack {
                        HStack{
                            Text("Goals")
                                .font(.headline)
                            Spacer()
                            Button {
                                showGoalSheet = true
                            } label: {
                                HStack {
                                    Image(systemName: "target")
                                    Text("Edit goals")
                                    
                                    Image(systemName: "chevron.right")
                                    
                                }
                                .foregroundStyle(Color.secondary)

                            }
                        }
                        .padding(.vertical)
                        
                        if goals.isEmpty {
                            Text("No goals yet")
                                .foregroundStyle(.secondary)
                        } else {
                            let customIDs = GoalPresentation.customGoalIDs(in: modelContext)
                            ForEach(goals, id: \.id) { goal in
                                HStack(spacing: 8) {
                                    HStack(spacing: 8) {
                                        Text(goal.title)
                                        if customIDs.contains(goal.id) {
                                            Text("Custom")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(Capsule().fill(Color.primary.opacity(0.08)))
                                        }
                                    }
                                    Spacer()
                                    Text("Difficulty \(goal.difficulty)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Button {
                                        if let idx = goals.firstIndex(where: { $0.id == goal.id }) {
                                            goals.remove(at: idx)
                                        }
                                        // Keep custom selection set in sync when removing
                                        if selectedCustomGoalIDs.contains(goal.id) {
                                            selectedCustomGoalIDs.remove(goal.id)
                                        } else if !customIDs.contains(goal.id) {
                                            // Built-in: either user-added or predicted; update the right set
                                            if userAddedBuiltInGoalIDs.contains(goal.id) {
                                                userAddedBuiltInGoalIDs.remove(goal.id)
                                            } else {
                                                suppressedPredictedGoalIDs.insert(goal.id)
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(.vertical, 6)
                            }
                        }

                        Button {
                            // Reset suppression and re-predict from scratch.
                            suppressedPredictedGoalIDs.removeAll()
                            userAddedBuiltInGoalIDs.removeAll()
                            predictedGoals = computePredictedGoals(for: selectedIdentity)
                            goals = mergeGoals(predicted: predictedGoals, custom: fetchSelectedCustomTemplates())
                        } label: {
                            Text("Reset goals")
                                .padding()
                        }
                        .padding()
                        .buttonStyle(.glass)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .padding()
                    .glassEffect(in: RoundedRectangle(cornerRadius: 38))
                }
                .padding()
            }
            .navigationTitle("New scheduled activity")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Initialize predicted goals once on first appearance.
                if predictedGoals.isEmpty && goals.isEmpty {
                    predictedGoals = computePredictedGoals(for: selectedIdentity)
                    goals = mergeGoals(predicted: predictedGoals, custom: [])
                }
            }
            .onChange(of: selectedIdentity) { _, newIdentity in
                // Recompute predicted goals only when the activity identity changes.
                predictedGoals = computePredictedGoals(for: newIdentity)
                // Clear suppression since predictions are for a new identity.
                suppressedPredictedGoalIDs.removeAll()
                // Clear user-added built-ins for the old identity.
                userAddedBuiltInGoalIDs.removeAll()
                // Preserve custom selections that are valid for the new identity.
                selectedCustomGoalIDs = filterSelectedCustomGoalIDs(for: newIdentity)
                // Rebuild goals with predictions + currently valid custom selections.
                goals = mergeGoals(predicted: predictedGoals, custom: fetchSelectedCustomTemplates())
            }
            .onChange(of: selectedCustomGoalIDs) { _, _ in
                // Only re-merge with currently stored predicted goals; do not regenerate
                goals = mergeGoals(predicted: predictedGoals, custom: fetchSelectedCustomTemplates())
            }
            .sheet(isPresented: $showGoalSheet) {
                NavigationStack {
                    CombinedGoalPickerSheet(
                        identity: selectedIdentity,
                        goals: $goals,
                        selectedCustomGoalIDs: $selectedCustomGoalIDs,
                        suppressedPredictedGoalIDs: $suppressedPredictedGoalIDs,
                        predictedGoalIDs: Set(predictedGoals.map { $0.id }),
                        userAddedBuiltInGoalIDs: $userAddedBuiltInGoalIDs
                    )
                }
            }
            .toolbar{
                ToolbarItem(placement: .navigationBarLeading){
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing){
                    Button("Save") {
                        saveScheduledActivity()
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
    }

    private func computePredictedGoals(for identity: ActivityIdentity) -> [GoalTemplate] {
        switch identity.kind {
        case .builtIn(let activity):
            return GoalPredictorAlgorithm(modelContext: modelContext, activity: activity).predictGoals()
        case .custom:
            return []
        }
    }

    private func fetchSelectedCustomTemplates() -> [GoalTemplate] {
        guard !selectedCustomGoalIDs.isEmpty else { return [] }
        let ids = selectedCustomGoalIDs
        let descriptor = FetchDescriptor<CustomGoal>(predicate: #Predicate<CustomGoal> { ids.contains($0.id) })
        let rows = (try? modelContext.fetch(descriptor)) ?? []
        return rows.map { GoalTemplate(id: $0.id, title: $0.title, difficulty: $0.difficulty) }
    }

    private func filterSelectedCustomGoalIDs(for identity: ActivityIdentity) -> Set<UUID> {
        guard !selectedCustomGoalIDs.isEmpty else { return [] }
        let ids = selectedCustomGoalIDs
        switch identity.kind {
        case .builtIn(let activity):
            let raw = activity.rawValue
            let descriptor = FetchDescriptor<CustomGoal>(predicate: #Predicate<CustomGoal> { ids.contains($0.id) && $0.builtInActivityID == raw })
            let rows = (try? modelContext.fetch(descriptor)) ?? []
            return Set(rows.map { $0.id })
        case .custom(let uuid):
            let descriptor = FetchDescriptor<CustomGoal>(predicate: #Predicate<CustomGoal> { ids.contains($0.id) && $0.customActivityID == uuid })
            let rows = (try? modelContext.fetch(descriptor)) ?? []
            return Set(rows.map { $0.id })
        }
    }

    private func mergeGoals(predicted: [GoalTemplate], custom: [GoalTemplate]) -> [GoalTemplate] {
        // Exclude any predicted goals the user has explicitly removed (suppressed).
        let predicted = predicted.filter { !suppressedPredictedGoalIDs.contains($0.id) }
        // Preserve predicted order exactly as provided (no resorting).
        var seen = Set<UUID>()
        var predictedUnique: [GoalTemplate] = []
        predictedUnique.reserveCapacity(predicted.count)
        for g in predicted {
            if !seen.contains(g.id) {
                predictedUnique.append(g)
                seen.insert(g.id)
            }
        }

        // Add custom (exclude any duplicates), optionally sort custom for UX.
        var customUnique: [GoalTemplate] = []
        for g in custom {
            if !seen.contains(g.id) {
                customUnique.append(g)
                seen.insert(g.id)
            }
        }
        let customSorted = customUnique.sorted {
            if $0.difficulty != $1.difficulty { return $0.difficulty < $1.difficulty }
            return $0.title < $1.title
        }

        // Add user-added built-in goals (those not part of predictions), sourced from the current identity's built-in pool.
        var addedBuiltIns: [GoalTemplate] = []
        if case .builtIn(let activity) = selectedIdentity.kind {
            let pool = activityMetadataTable[activity]?.goalPool ?? []
            let poolMap = Dictionary(uniqueKeysWithValues: pool.map { ($0.id, $0) })
            for id in userAddedBuiltInGoalIDs {
                if let g = poolMap[id], !suppressedPredictedGoalIDs.contains(id), !seen.contains(id) {
                    addedBuiltIns.append(g)
                    seen.insert(id)
                }
            }
            // Keep a consistent order for added built-ins
            addedBuiltIns.sort {
                if $0.difficulty != $1.difficulty { return $0.difficulty < $1.difficulty }
                return $0.title < $1.title
            }
        }

        // Place custom first, followed by predicted, then user-added built-ins.
        return customSorted + predictedUnique + addedBuiltIns
    }

    private func saveScheduledActivity() {
        var act: Activity? = nil
        var customID: UUID? = nil
        
        switch selectedIdentity.kind {
        case .builtIn(let a): act = a
        case .custom(let uuid): customID = uuid
        }

        let scheduled = ScheduledActivity(activity: act, customActivityID: customID, startTime: startTime, goals: goals)
        modelContext.insert(scheduled)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to save ScheduledActivity: \(error)")
            dismiss()
        }
    }
}

private struct CombinedGoalPickerSheet: View {
    let identity: ActivityIdentity
    @Binding var goals: [GoalTemplate]
    @Binding var selectedCustomGoalIDs: Set<UUID>
    @Binding var suppressedPredictedGoalIDs: Set<UUID>
    @Binding var userAddedBuiltInGoalIDs: Set<UUID>
    let predictedGoalIDs: Set<UUID>

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showingGoalEditor: Bool = false

    @Query private var customGoals: [CustomGoal]

    init(identity: ActivityIdentity, goals: Binding<[GoalTemplate]>, selectedCustomGoalIDs: Binding<Set<UUID>>, suppressedPredictedGoalIDs: Binding<Set<UUID>>, predictedGoalIDs: Set<UUID>, userAddedBuiltInGoalIDs: Binding<Set<UUID>>) {
        self.identity = identity
        self._goals = goals
        self._selectedCustomGoalIDs = selectedCustomGoalIDs
        self._suppressedPredictedGoalIDs = suppressedPredictedGoalIDs
        self.predictedGoalIDs = predictedGoalIDs
        self._userAddedBuiltInGoalIDs = userAddedBuiltInGoalIDs

        switch identity.kind {
        case .builtIn(let activity):
            let raw: String = activity.rawValue
            let predicate: Predicate<CustomGoal> = #Predicate { $0.builtInActivityID == raw }
            let sortDescriptors: [SortDescriptor<CustomGoal>] = [
                SortDescriptor(\CustomGoal.customActivityID, order: .reverse),
                SortDescriptor(\CustomGoal.title)
            ]
            self._customGoals = Query(filter: predicate, sort: sortDescriptors)
        case .custom(let uuid):
            let predicate: Predicate<CustomGoal> = #Predicate { $0.customActivityID == uuid }
            let sortDescriptors: [SortDescriptor<CustomGoal>] = [
                SortDescriptor(\CustomGoal.customActivityID, order: .reverse),
                SortDescriptor(\CustomGoal.title)
            ]
            self._customGoals = Query(filter: predicate, sort: sortDescriptors)
        }
    }

    private var builtInPool: [GoalTemplate] {
        switch identity.kind {
        case .builtIn(let activity):
            return activityMetadataTable[activity]?.goalPool ?? []
        case .custom:
            return []
        }
    }

    var body: some View {
        List {
            Section {
                ForEach(customGoals) { g in
                    HStack {
                        Text(g.title)
                        Spacer()
                        Text("Difficulty \(g.difficulty)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            let tmpl = GoalTemplate(id: g.id, title: g.title, difficulty: g.difficulty)
                            toggleGoal(tmpl, isCustom: true)
                        } label: {
                            Image(systemName: selectedCustomGoalIDs.contains(g.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            } header: {
                HStack {
                    Text("Custom goals")
                    Spacer()
                    Button {
                        showingGoalEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.glass)
                }
            }

            Section("Built-in goals") {
                ForEach(builtInPool, id: \.id) { g in
                    HStack {
                        Text(g.title)
                        Spacer()
                        Text("Difficulty \(g.difficulty)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            toggleGoal(g, isCustom: false)
                        } label: {
                            Image(systemName: contains(g.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .navigationTitle("Add goals")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .buttonStyle(.glassProminent)
            }
        }
        .sheet(isPresented: $showingGoalEditor) {
            NavigationStack {
                CustomGoalEditView(identity: identity, goal: nil)
            }
        }
    }

    private func contains(_ id: UUID) -> Bool {
        goals.contains { $0.id == id }
    }

    private func toggleGoal(_ g: GoalTemplate, isCustom: Bool) {
        if let idx = goals.firstIndex(where: { $0.id == g.id }) {
            // Remove if already selected
            goals.remove(at: idx)
            if isCustom {
                selectedCustomGoalIDs.remove(g.id)
            } else {
                // Built-in: if it was user-added, remove from that set; otherwise suppress prediction
                if userAddedBuiltInGoalIDs.contains(g.id) {
                    userAddedBuiltInGoalIDs.remove(g.id)
                } else {
                    suppressedPredictedGoalIDs.insert(g.id)
                }
            }
        } else {
            // Add if not selected
            goals.append(g)
            if isCustom {
                selectedCustomGoalIDs.insert(g.id)
            } else {
                // Built-in: unsuppress if needed, and track as user-added if not part of predictions
                suppressedPredictedGoalIDs.remove(g.id)
                if !predictedGoalIDs.contains(g.id) {
                    userAddedBuiltInGoalIDs.insert(g.id)
                } else {
                    userAddedBuiltInGoalIDs.remove(g.id)
                }
            }
        }
        reorder()
    }

    private func reorder() {
        // Keep the relative order of items as-is, but ensure custom goals appear first.
        let customIDs = GoalPresentation.customGoalIDs(in: modelContext)
        let custom = goals.filter { customIDs.contains($0.id) }
        let nonCustom = goals.filter { !customIDs.contains($0.id) }
        goals = custom + nonCustom
    }
}

// MARK: - Previews

#Preview("Scheduled List (seeded)") {
    ScheduledActivityListView()
        .modelContainer(PreviewStore.containerSeeded)
}

#Preview("Scheduled List (empty)") {
    ScheduledActivityListView()
        .modelContainer(PreviewStore.containerEmpty)
}

#Preview("Card") {
    let container = PreviewStore.containerSeeded
    let ctx = container.mainContext
    let sched = (try? ctx.fetch(FetchDescriptor<ScheduledActivity>()))?.first

    return NavigationStack {
        if let sched {
            List {
                ScheduledActivityCardView(scheduled: sched)
            }
            .navigationTitle("Card Preview")
        } else {
            Text("No scheduled activity found")
        }
    }
    .modelContainer(container)
}

#Preview("Detail") {
    let container = PreviewStore.containerSeeded
    let ctx = container.mainContext
    let sched = (try? ctx.fetch(FetchDescriptor<ScheduledActivity>()))?.first

    return NavigationStack {
        if let sched {
            ScheduledActivityDetailedView(scheduled: sched)
        } else {
            Text("No scheduled activity found")
        }
    }
    .modelContainer(container)
}

#Preview("Add New (sheet)") {
    NavigationStack {
        AddNewScheduledActivity()
    }
    .modelContainer(PreviewStore.containerSeeded)
}

// MARK: - PreviewStore

private enum PreviewStore {
    @MainActor static var containerEmpty: ModelContainer = {
        let schema = Schema([
            ScheduledActivity.self,
            CustomActivity.self,
            CustomGoal.self,
            ActivityTracker.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    @MainActor static var containerSeeded: ModelContainer = {
        let container = containerEmpty
        let ctx = container.mainContext

        // ---- Seed Custom Activities ----
        let yoga = CustomActivity(
            name: "Morning Yoga",
            symbolName: "figure.yoga",
            difficulty: 2
        )
        let strength = CustomActivity(
            name: "Strength Circuit",
            symbolName: "dumbbell.fill",
            difficulty: 4
        )
        ctx.insert(yoga)
        ctx.insert(strength)

        // ---- Seed Custom Goals ----
        // Built-in goals can be created elsewhere; for preview we just create a few custom ones
        // and tie them to either a built-in activity id or a custom activity id depending on your model.
        //
        // NOTE: adjust these initializers/fields to match your CustomGoal model.
        let g1 = CustomGoal(
            title: "Hold plank 60s",
            difficulty: 3,
            customActivityID: nil, builtInActivityID: Activity.hiking.rawValue
        )
        let g2 = CustomGoal(
            title: "Stretch hips 10m",
            difficulty: 1,
            customActivityID: yoga.id, builtInActivityID: nil                       // example custom association
        )
        let g3 = CustomGoal(
            title: "10 push-ups x 3",
            difficulty: 3,
            customActivityID: strength.id, builtInActivityID: nil
        )
        ctx.insert(g1)
        ctx.insert(g2)
        ctx.insert(g3)

        // ---- Seed Scheduled Activities ----
        let now = Date()

        // A built-in scheduled activity
        let sched1 = ScheduledActivity(
            activity: .hiking,
            customActivityID: nil,
            startTime: Calendar.current.date(byAdding: .minute, value: 25, to: now)!,
            goals: [
                GoalTemplate(id: g1.id, title: g1.title, difficulty: g1.difficulty)
            ]
        )

        // A custom scheduled activity
        let sched2 = ScheduledActivity(
            activity: nil,
            customActivityID: yoga.id,
            startTime: Calendar.current.date(byAdding: .hour, value: 2, to: now)!,
            goals: [
                GoalTemplate(id: g2.id, title: g2.title, difficulty: g2.difficulty)
            ]
        )

        // Another one yesterday to test section headers + grouping
        let sched3 = ScheduledActivity(
            activity: nil,
            customActivityID: strength.id,
            startTime: Calendar.current.date(byAdding: .day, value: -1, to: now)!,
            goals: [
                GoalTemplate(id: g3.id, title: g3.title, difficulty: g3.difficulty)
            ]
        )

        ctx.insert(sched1)
        ctx.insert(sched2)
        ctx.insert(sched3)

        try? ctx.save()
        return container
    }()
}
