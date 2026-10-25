//
//  SwiftUIView.swift
//  Outivity
//
//  Created by Wafiq on 12/31/25.
//

import SwiftUI
import SwiftData
import Charts

struct ActivityStatisticsView: View {
    // Import model context for SwiftDataxr
    @Environment(\.modelContext) private var modelContext

    // Observe ActivityTracker and ActivityPhoto
    @Query(sort: [SortDescriptor(\ActivityTracker.startedAt, order: .reverse)])
    private var activityTrackers: [ActivityTracker]
    @Query(sort: [SortDescriptor(\ActivityPhoto.createdAt, order: .reverse)])
    private var activityPhotos: [ActivityPhoto]

    // UI state: selected timespan and day selection
    private enum Timespan: String, CaseIterable, Identifiable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
        var id: String { rawValue }
    }
    @State private var selectedTimespan: Timespan = .week
    @State private var selectedDay: Date = Date()
    @State private var isShowingAllActivities: Bool = false
    @State private var isShowingTopByTime: Bool = false
    @State private var isShowingAllGoalCompletions: Bool = false

    // Fetch user info on appear (single persisted row)
    @State private var userInfo: UserInfo? = nil

    // Card editingstate variables
    @State private var liveWidgets: [StatsWidget] = []
    @State private var draggingWidget: StatsWidget? = nil
    @State private var dragArmedWidget: StatsWidget? = nil
    @State private var dragArmTask: Task<Void, Never>? = nil
    @State private var isEditingStats: Bool = false
    @State private var isShowingWidgetSheet: Bool = false


    // Unified activity wrapper to handle both built-in and custom activities uniformly
    private struct UnifiedActivity: Identifiable, Hashable {
        let id: String
        let displayName: String
        let colorSeed: Int

        // Ensure hashing/equality is stable across sessions by using the stable id only.
        static func == (lhs: UnifiedActivity, rhs: UnifiedActivity) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
        
        static func from(_ tracker: ActivityTracker) -> UnifiedActivity? {
            // Built-in session
            if let act = tracker.activity {
                return UnifiedActivity(
                    id: "builtin-\(act.id)",
                    displayName: act.displayName,
                    colorSeed: act.id.hashValue
                )
            }
            // Custom session: prefer a stable UUID if present; fall back to a reasonable name.
            if let customID = tracker.customActivityID {
                let name = (tracker.customName ?? tracker.displayActivityName)
                let uuid = customID.uuidString
                return UnifiedActivity(
                    id: "custom-\(uuid)",
                    displayName: name,
                    colorSeed: uuid.hashValue
                )
            }
            // Legacy/fallback: if we only have a name, synthesize an id from it.
            if let name = tracker.customName {
                return UnifiedActivity(
                    id: "custom-\(name)",
                    displayName: name,
                    colorSeed: name.hashValue
                )
            }
            return nil
        }
    }

    // Highlighted activity selected from the custom legend in the week chart (nil = no highlight)
    @State private var highlightedActivity: UnifiedActivity? = nil
    // Bubble info displayed when a user taps a specific day for a highlighted activity
    private struct BubbleInfo {
        let date: Date
        let count: Int
        let seconds: TimeInterval
        let location: CGPoint
    }
    @State private var bubbleInfo: BubbleInfo? = nil

    // Stats (count + total duration seconds) for a given activity on a given day.
    // Uses completed trackers when available; if endedAt is nil, counts duration up to now.
    private func statsFor(activity: UnifiedActivity, on day: Date, calendar: Calendar = .current) -> (count: Int, seconds: TimeInterval) {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return (0, 0)
        }

        var count = 0
        var seconds: TimeInterval = 0

        for tracker in activityTrackers {
            guard let ua = UnifiedActivity.from(tracker), ua == activity else { continue }
            // Count a session if it overlaps with the day at all.
            let start = tracker.startedAt
            let end = tracker.endedAt ?? Date()
            let clampedStart = max(start, dayStart)
            let clampedEnd = min(end, dayEnd)
            let delta = max(0, clampedEnd.timeIntervalSince(clampedStart))
            if delta > 0 {
                count += 1
                seconds += delta
            }
        }

        return (count, seconds)
    }

    // Helper: color generator matching ActivityCard's circleBackground
    private func color(for activity: UnifiedActivity) -> Color {
        let hue = Double(abs(activity.colorSeed) % 256) / 255.0
        return Color(hue: hue, saturation: 0.7, brightness: 0.8)
    }

    // Build day starts for N days (oldest -> newest)
    private func dayStarts(days: Int, calendar: Calendar = .current) -> [Date] {
        let today = calendar.startOfDay(for: Date())
        var starts: [Date] = []
        starts.reserveCapacity(days)
        for i in 0..<days {
            let offset = -(days - 1) + i
            if let d = calendar.date(byAdding: .day, value: offset, to: today) {
                starts.append(d)
            }
        }
        return starts
    }

    // MARK: - Month mode: total counts per day (LineMark)
    private struct SimpleDayCount: Identifiable {
        let id: Date
        let date: Date
        let count: Int
    }
    private func monthDayCounts(days: Int = 30) -> [SimpleDayCount] {
        let starts = dayStarts(days: days)
        var counts: [Date: Int] = [:]
        for s in starts { counts[s] = 0 }
        let calendar = Calendar.current
        for tracker in activityTrackers {
            let day = calendar.startOfDay(for: tracker.startedAt)
            if counts[day] != nil { counts[day]! += 1 }
        }
        return starts.map { SimpleDayCount(id: $0, date: $0, count: counts[$0] ?? 0) }
    }

    // MARK: - Week mode: stacked counts per day by activity
    private struct StackedDayCount: Identifiable {
        let id: String
        let date: Date
        let activity: UnifiedActivity
        let count: Int
    }
    private func weekStackedCounts(days: Int = 7) -> [StackedDayCount] {
        let starts = dayStarts(days: days)
        var counts: [Date: [UnifiedActivity: Int]] = [:]
        for s in starts { counts[s] = [:] }
        let calendar = Calendar.current
        for tracker in activityTrackers {
            let day = calendar.startOfDay(for: tracker.startedAt)
            guard counts[day] != nil else { continue }
            if let ua = UnifiedActivity.from(tracker) {
                counts[day]![ua, default: 0] += 1
            }
        }
        
        let activities = presentActivities
        var rows: [StackedDayCount] = []
        for s in starts {
            for act in activities {
                let c = counts[s]?[act] ?? 0
                let id = "\(s.timeIntervalSince1970)-\(act.id)"
                rows.append(StackedDayCount(id: id, date: s, activity: act, count: c))
            }
        }
        return rows
    }

    // Activities present in trackers (deterministic order)
    private var presentActivities: [UnifiedActivity] {
        let set = Set(activityTrackers.compactMap { UnifiedActivity.from($0) })
        return Array(set).sorted { $0.displayName < $1.displayName }
    }

    // MARK: - Stats helpers
    // Return a dictionary mapping the start-of-day for the last `days` days (inclusive) to the count
    private func countsForLast(days: Int, calendar: Calendar = .current) -> [Date: Int] {
        let starts = dayStarts(days: days, calendar: calendar)
        var counts: [Date: Int] = [:]
        for s in starts { counts[s] = 0 }
        for tracker in activityTrackers {
            let day = calendar.startOfDay(for: tracker.startedAt)
            if counts[day] != nil { counts[day]! += 1 }
        }
        return counts
    }

    // Average number of activities per day over the last `days` days; returns nil if there
    // were zero activities in that period so UI can show "None".
    private func averageOverLast(days: Int) -> Double? {
        let counts = countsForLast(days: days)
        let total = counts.values.reduce(0, +)
        if total == 0 { return nil }
        return Double(total) / Double(days)
    }

    // All-time counts for activities the user actually performed, sorted by descending count
    private var allTimeActivityCounts: [(activity: UnifiedActivity, count: Int)] {
        var counts: [UnifiedActivity: Int] = [:]
        for t in activityTrackers {
            if let ua = UnifiedActivity.from(t) {
                counts[ua, default: 0] += 1
            }
        }
        return counts.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }
    }

    // Total activities all-time (convenience)
    private var allTimeTotalCount: Int { allTimeActivityCounts.reduce(0) { $0 + $1.count } }

    // MARK: - Calories & Steps helpers
    private var totalStepsAllTime: Int? {
        let values = activityTrackers.compactMap { $0.totalSteps }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }

    private var totalCaloriesAllTime: Double? {
        let values = activityTrackers
            .compactMap { $0.estimatedCalories }
            .filter { $0.isFinite && $0 >= 0 }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }

    private var averageStepsPerSession: Double? {
        let values = activityTrackers.compactMap { $0.totalSteps }.map(Double.init)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private var averageCaloriesPerSession: Double? {
        let values = activityTrackers
            .compactMap { $0.estimatedCalories }
            .filter { $0.isFinite && $0 >= 0 }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    // MARK: - Day mode: durations per activity for selectedDay
    private struct ActivityDuration: Identifiable {
        let id: UnifiedActivity
        let activity: UnifiedActivity
        let seconds: TimeInterval
    }
    private func durationsPerActivity(on day: Date, calendar: Calendar = .current) -> [ActivityDuration] {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        var sums: [UnifiedActivity: TimeInterval] = [:]
        for tracker in activityTrackers {
            // Determine overlap of tracker with the selected day
            let start = tracker.startedAt
            let end = tracker.endedAt ?? Date()
            let clampedStart = max(start, dayStart)
            let clampedEnd = min(end, dayEnd)
            let delta = max(0, clampedEnd.timeIntervalSince(clampedStart))
            if delta > 0, let ua = UnifiedActivity.from(tracker) {
                sums[ua, default: 0] += delta
            }
        }
        return sums.map { ActivityDuration(id: $0.key, activity: $0.key, seconds: $0.value) }
            .sorted { $0.activity.displayName < $1.activity.displayName }
    }

    // Type-erased current chart to avoid control-flow inside ViewBuilder closures
    private var currentChartView: AnyView {
        switch selectedTimespan {
        case .month:
            return AnyView(monthChart(for: selectedDay))
        case .week:
            return AnyView(weekChart())
        case .day:
            return AnyView(dayChart())
        }
    }

    // MARK: - Session & goals statistics helpers
    // Completed trackers (ended)
    private var completedTrackers: [ActivityTracker] {
        activityTrackers.filter { $0.endedAt != nil }
    }

    // Average session length in seconds (nil if no completed sessions)
    private func averageSessionLengthSeconds() -> Double? {
        let durations = completedTrackers.map { max(0, ($0.endedAt ?? Date()).timeIntervalSince($0.startedAt)) }
        guard !durations.isEmpty else { return nil }
        return durations.reduce(0, +) / Double(durations.count)
    }

    // Top activities by total time spent (seconds)
    private var topActivitiesByTime: [(activity: UnifiedActivity, seconds: TimeInterval)] {
        var sums: [UnifiedActivity: TimeInterval] = [:]
        for t in completedTrackers {
            let duration = max(0, (t.endedAt ?? Date()).timeIntervalSince(t.startedAt))
            if let ua = UnifiedActivity.from(t) {
                sums[ua, default: 0] += duration
            }
        }
        return sums.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }
    }

    // Current streak in days (consecutive days up to today with at least one activity)
    private func currentStreak() -> Int {
        let calendar = Calendar.current
        let daySet: Set<Date> = Set(activityTrackers.map { calendar.startOfDay(for: $0.startedAt) })
        var streak = 0
        var day = calendar.startOfDay(for: Date())
        while daySet.contains(day) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    // Number of goals met across all trackers and recent goal completions (activity + date + title)
    private var goalsMetSummary: (count: Int, recent: [(tracker: ActivityTracker, title: String, date: Date)]) {
        var completions: [(tracker: ActivityTracker, title: String, date: Date)] = []
        for tracker in activityTrackers {
            // Collect all completed goal IDs for this tracker (timestamps preferred)
            let ids: [UUID]
            if !tracker.completedGoalTimestamps.isEmpty {
                ids = Array(tracker.completedGoalTimestamps.keys)
            } else {
                ids = tracker.completedGoalIDs
            }
            for id in ids {
                // Try to resolve a title from the tracker's metadata; fall back to unknown
                let title = (tracker.activityMetadata?.goalPool.first(where: { $0.id == id })?.title) ?? "Goal"
                let date = tracker.goalCompletedAt(id) ?? tracker.endedAt ?? tracker.startedAt
                completions.append((tracker: tracker, title: title, date: date))
            }
        }
        // Sort by date descending
        completions.sort { $0.date > $1.date }
        return (completions.count, Array(completions.prefix(5)))
    }

    // All goal completions (not limited) sorted by date descending. Used by the "Show all" sheet.
    private var allGoalCompletions: [(tracker: ActivityTracker, title: String, date: Date)] {
        var completions: [(tracker: ActivityTracker, title: String, date: Date)] = []
        for tracker in activityTrackers {
            let ids: [UUID]
            if !tracker.completedGoalTimestamps.isEmpty {
                ids = Array(tracker.completedGoalTimestamps.keys)
            } else {
                ids = tracker.completedGoalIDs
            }
            for id in ids {
                let title = (tracker.activityMetadata?.goalPool.first(where: { $0.id == id })?.title) ?? "Goal"
                let date = tracker.goalCompletedAt(id) ?? tracker.endedAt ?? tracker.startedAt
                completions.append((tracker: tracker, title: title, date: date))
            }
        }
        completions.sort { $0.date > $1.date }
        return completions
    }

    // Helper: format seconds into human-friendly string
    private func formatSeconds(_ seconds: TimeInterval) -> String {
        if seconds <= 0 { return "0m" }
        let totalMinutes = Int((seconds / 60).rounded())
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
        } else {
            return "\(totalMinutes)m"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView{
                VStack(spacing: 12) {
                    // Picker to choose timespan
                    Picker("Timespan", selection: $selectedTimespan) {
                        ForEach(Timespan.allCases) { t in Text(t.rawValue).tag(t) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedTimespan) { oldValue, newValue in
                        if newValue != .week { highlightedActivity = nil }
                    }
                    .padding(.horizontal)
                    
                    HStack {
                        Text(selectedTimespan == .day ? "Activities today" : (selectedTimespan == .week ? "Last 7 days" : "Last 30 days"))
                            .font(.title2).bold()
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Optional date picker for Day mode
                    if selectedTimespan == .day {
                        HStack(spacing: 12) {
                            Button {
                                let cal = Calendar.current
                                selectedDay = cal.date(byAdding: .day, value: -1, to: selectedDay) ?? selectedDay
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.title2)
                                    .padding(8)
                            }
                            .accessibilityLabel("Previous day")
                            
                            Spacer()
                            
                            Text(selectedDay.formatted(date: .abbreviated, time: .omitted))
                                .font(.headline)
                            
                            Spacer()
                            
                            Button {
                                let cal = Calendar.current
                                let today = cal.startOfDay(for: Date())
                                if let newDate = cal.date(byAdding: .day, value: 1, to: selectedDay) {
                                    selectedDay = min(newDate, today)
                                }
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.title2)
                                    .padding(8)
                            }
                            .accessibilityLabel("Next day")
                            .disabled(Calendar.current.startOfDay(for: selectedDay) >= Calendar.current.startOfDay(for: Date()))
                        }
                        .padding(.horizontal)
                    }
                    
                    // Chart area
                    Group {
                        if activityTrackers.isEmpty {
                            ContentUnavailableView("No activity data yet", systemImage: "chart.bar.xaxis")
                                .padding()
                        } else {
                            currentChartView
                                .frame(height: 320)
                                .padding()
                        }
                    }
                    
                    VStack(spacing: 7) {
                        // Replace the big VStack(spacing: 7) { ... your HStacks ... } with:

                        let columns = [
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)
                        ]

                        
                        HStack {
                            Text("Quick Data")
                                .font(.headline)
                            Spacer()

                            Button {
                                isEditingStats ? exitEditMode() : enterEditMode()
                            } label: {
                                Text(isEditingStats ? "Done" : "Edit")
                                    .fontWeight(.semibold)
                            }
                            .buttonStyle(.glass)
                        }
                        .padding()

                        if isEditingStats {
                            withAnimation{
                                Text("Add and remove your Quick Datas. Hold and drag on \(Image(systemName: "line.3.horizontal")) to re order.")
                                    .multilineTextAlignment(.center)
                                    .font(.caption)
                                    .padding()
                                    .padding(.horizontal)
                            }
                        }
                        
                        
                        // MARK: - Quick datas (widgets)
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(liveWidgets, id: \.self) { widget in
                                GeometryReader { geo in
                                    let size = geo.size
                                    let t = tile(for: widget)

                                    statCard(t.title, value: t.value, unit: t.unit)
                                        .frame(width: size.width, height: size.height)
                                        .onDrop(
                                            of: [.text],
                                            delegate: StatsWidgetDropDelegate(
                                                item: widget,
                                                items: $liveWidgets,
                                                dragging: $draggingWidget,
                                                onCommit: { persistWidgets() }
                                            )
                                        )
                                        .overlay(alignment: .trailing) {
                                            if isEditingStats {
                                                VStack {
                                                    Spacer()
                                                    Image(systemName: "line.3.horizontal")
                                                        .font(.subheadline.weight(.semibold))
                                                        .foregroundStyle(.secondary)
                                                        .padding(10)
                                                        .contentShape(Rectangle())
                                                        .onDrag {
                                                            Task { @MainActor in
                                                                hapticWidgetPickedUp()
                                                            }
                                                            draggingWidget = widget
                                                            return NSItemProvider(object: widget.rawValue as NSString)
                                                        } preview: {
                                                            Color.clear.frame(width: 1, height: 1)
                                                        }
                                                        .padding(.trailing, 4)
                                                        .transition(.opacity.combined(with: .scale))
                                                    Spacer()
                                                }
                                                .frame(maxHeight: .infinity)
                                            }
                                        }
                                        .overlay(alignment: .topLeading) {
                                            if isEditingStats {
                                                Button {
                                                    withAnimation(.bouncy) {
                                                        liveWidgets.removeAll { $0 == widget }
                                                    }
                                                    persistWidgets()
                                                } label: {
                                                    Image(systemName: "xmark")
                                                        .font(.title3)
                                                        .padding(10)
                                                        .foregroundStyle(.foreground)
                                                }
                                                .buttonStyle(.plain)
                                                .glassEffect(.regular.interactive(), in: Circle())
                                                .offset(x: -12, y: -12)
                                            }
                                        }
                                }
                                .frame(height: 160)
                            }

                            if isEditingStats {
                                GeometryReader { geo in
                                    let size = geo.size

                                    Button {
                                        isShowingWidgetSheet = true
                                    } label: {
                                        VStack {
                                            Spacer()
                                            Image(systemName: "plus")
                                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                        }
                                        .frame(width: size.width, height: size.height)
                                        .contentShape(RoundedRectangle(cornerRadius: 38.0))
                                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 38.0))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .frame(height: 160)
                            }
                        }
                        .padding(.horizontal)
                        .onLongPressGesture(minimumDuration: 0.35) {
                            enterEditMode()
                        }
                        .compositingGroup()
                        .zIndex(1)


                        



                        
                        

                        
                        
                        
                        
                        
                        
                        // Recent goal completions caption (if any)
                        if !goalsMetSummary.recent.isEmpty {
                            VStack{
                                VStack{
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(alignment: .firstTextBaseline) {
                                            Text("Recent goal completions")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            
                                        }
                                        VStack{
                                            ForEach(Array(goalsMetSummary.recent.enumerated()), id: \.offset) { idx, item in
                                                NavigationLink {
                                                    ActivityHistoryDetailView(tracker: item.tracker)
                                                } label: {
                                                    HStack(alignment: .firstTextBaseline){
                                                        VStack(alignment: .listRowSeparatorLeading){
                                                            Text("\(item.title)")
                                                                .multilineTextAlignment(.leading)
                                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                                .foregroundColor(.primary)
                                                            Text(item.tracker.displayActivityName)
                                                                .foregroundStyle(.secondary)
                                                        }
                                                        Spacer()
                                                        Text(item.date.formatted(date: .abbreviated, time: .shortened))
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                }.padding(.vertical)
                                            }
                                        }.padding(.vertical)
                                    }
                                    Button {
                                        isShowingAllGoalCompletions = true
                                        
                                    } label: {
                                        Spacer()
                                        Text("Show all")
                                            .padding()
                                        Spacer()
                                    }
                                    .buttonStyle(.glass)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(24)
                                .contentShape(RoundedRectangle(cornerRadius: 38.0))
                                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 38.0))
                            }.padding(.horizontal)
                        }
                        
                        // Top activities by time
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Top activities by time")
                                .font(.subheadline).bold()
                            
                            if topActivitiesByTime.isEmpty {
                                Text("None yet")
                                    .foregroundColor(.secondary)
                            } else {
                                // Top 3 inline
                                ForEach(Array(topActivitiesByTime.prefix(3).enumerated()), id: \.offset) { idx, item in
                                    HStack {
                                        Text("\(idx + 1).")
                                            .frame(width: 24, alignment: .leading)
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(color(for: item.activity))
                                            .frame(width: 20, height: 14)
                                        Text(item.activity.displayName)
                                        Spacer()
                                        Text(formatSeconds(item.seconds))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                // Disclosure shows remaining items after top 3
                                let remaining = Array(topActivitiesByTime.dropFirst(3))
                                if !remaining.isEmpty {
                                    DisclosureGroup(isExpanded: $isShowingTopByTime) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            ForEach(remaining.indices, id: \.self) { i in
                                                let item = remaining[i]
                                                HStack {
                                                    Text("\(i + 4).")
                                                        .frame(width: 24, alignment: .leading)
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .fill(color(for: item.activity))
                                                        .frame(width: 20, height: 14)
                                                    Text(item.activity.displayName)
                                                    Spacer()
                                                    Text(formatSeconds(item.seconds))
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                        .padding(.top, 6)
                                    } label: {
                                        Text(isShowingTopByTime ? "Hide full ranking" : "Show more")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                    .animation(.easeInOut, value: isShowingTopByTime)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(24)
                        .contentShape(RoundedRectangle(cornerRadius: 38.0))
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 38.0))
                        .padding(.horizontal)
                        
                        // Top activities: show top 3 inline, with a disclosure to show the full ranking
                        VStack(alignment: .leading, spacing: 8) {
                            Text("All-time top activities")
                                .font(.subheadline).bold()
                            
                            if allTimeActivityCounts.isEmpty {
                                Text("None yet")
                                    .foregroundColor(.secondary)
                            } else {
                                // Top 3 inline
                                ForEach(Array(allTimeActivityCounts.prefix(3).enumerated()), id: \.offset) { idx, item in
                                    HStack {
                                        Text("\(idx + 1).")
                                            .frame(width: 24, alignment: .leading)
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(color(for: item.activity))
                                            .frame(width: 20, height: 14)
                                        Text(item.activity.displayName)
                                        Spacer()
                                        Text("\(item.count)")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                // Disclosure shows everything after the top 3
                                let rest = Array(allTimeActivityCounts.dropFirst(3))
                                if !rest.isEmpty {
                                    DisclosureGroup(isExpanded: $isShowingAllActivities) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            ForEach(rest.indices, id: \.self) { i in
                                                let item = rest[i]
                                                HStack {
                                                    Text("\(i + 4).")
                                                        .frame(width: 24, alignment: .leading)
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .fill(color(for: item.activity))
                                                        .frame(width: 20, height: 14)
                                                    Text(item.activity.displayName)
                                                    Spacer()
                                                    Text("\(item.count)")
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                        .padding(.top, 6)
                                    } label: {
                                        Text(isShowingAllActivities ? "Hide full ranking" : "Show full ranking")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                    // Smooth expand/retract animation
                                    .animation(.easeInOut, value: isShowingAllActivities)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(24)
                        .contentShape(RoundedRectangle(cornerRadius: 38.0))
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 38.0))
                        .padding(.horizontal)
                        
                    }
                    
                    Spacer()
                }
                
                .navigationTitle("Your progress")
                .sheet(isPresented: $isShowingAllGoalCompletions) {
                    AllGoalCompletionsSheet(completions: allGoalCompletions)
                }
                .sheet(isPresented: $isShowingWidgetSheet) {
                    StatsWidgetPickerSheet(
                        added: $liveWidgets,
                        all: StatsWidget.defaultOrder,
                        onDone: {
                            exitEditMode()
                        }
                    )
                    .presentationDetents([.height(280)])
                    .presentationDragIndicator(.visible)
                }

            }
        }
        .onAppear {
            UserInfoStore.ensureSingleInstance(in: modelContext)
            userInfo = UserInfoStore.fetchOrCreate(in: modelContext)

            // Load persisted selection + order (or defaults if nothing has ever been saved).
            liveWidgets = userInfo?.statsWidgets ?? StatsWidget.defaultOrder
        }
        .onChange(of: draggingWidget) { _, new in
            if new == nil {
                persistWidgets()
            }
        }


    }

    
    // MARK: - Stat card thing
    private func enterEditMode() {
        guard !isEditingStats else { return }
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        withAnimation(.easeInOut) {
            isEditingStats = true
            isShowingWidgetSheet = true
        }
    }

    private func hapticWidgetPickedUp() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    private func exitEditMode() {
        withAnimation(.easeInOut) {
            isEditingStats = false
            isShowingWidgetSheet = false
            draggingWidget = nil
        }
        persistWidgets()
    }

    // Widgets user does NOT currently have added (for the sheet)
    private var unaddedWidgets: [StatsWidget] {
        let added = Set(liveWidgets)
        return StatsWidget.defaultOrder.filter { !added.contains($0) }
    }

    private struct StatsWidgetDropDelegate: DropDelegate {
        let item: StatsWidget
        @Binding var items: [StatsWidget]
        @Binding var dragging: StatsWidget?
        let onCommit: () -> Void

        func dropEntered(info: DropInfo) {
            guard let dragging, dragging != item else { return }
            guard
                let fromIndex = items.firstIndex(of: dragging),
                let toIndex = items.firstIndex(of: item)
            else { return }

            // This is the “make space while hovering” behavior
            withAnimation(.bouncy) {
                items.move(fromOffsets: IndexSet(integer: fromIndex),
                           toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
            }
        }

        func performDrop(info: DropInfo) -> Bool {
            dragging = nil
            onCommit()
            return true
        }

        func dropUpdated(info: DropInfo) -> DropProposal? {
            DropProposal(operation: .move)
        }

        func dropExited(info: DropInfo) {
            // optional: no-op
        }
    }

    private struct StatTile {
        let title: String
        let value: String
        let unit: String?
    }

    
    


    private struct StatsWidgetPickerSheet: View {
        @Binding var added: [StatsWidget]
        let all: [StatsWidget]
        let onDone: () -> Void

        private var unadded: [StatsWidget] {
            let set = Set(added)
            return all.filter { !set.contains($0) }
        }

        var body: some View {
            VStack(spacing: 12) {
                HStack {
                    Text("Add Quick Datas")
                        .font(.headline)
                    Spacer()
                    Button("Done") { onDone() }
                        .fontWeight(.semibold)
                        .buttonStyle(.glassProminent)
                }
                .padding()
                .padding()

                if unadded.isEmpty {
                    ContentUnavailableView("All Quick Datas added", systemImage: "checkmark.circle")
                        .padding(.top, 12)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(unadded, id: \.self) { w in
                                Button {
                                    withAnimation(.bouncy) {
                                        // Avoid duplicates just in case
                                        if !added.contains(w) {
                                            added.append(w)
                                        }
                                    }
                                } label: {
                                    ZStack(alignment: .topLeading) {
                                        // The actual card (unchanged)
                                        VStack(alignment: .leading) {
                                            Text(w.displayTitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .frame(maxWidth: .infinity, alignment: .leading)

                                            Spacer()

                                            Text("Add")
                                                .font(.title.weight(.semibold))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .frame(width: 180, alignment: .leading)
                                        .frame(maxHeight: 160, alignment: .leading)
                                        .padding(24)
                                        .contentShape(RoundedRectangle(cornerRadius: 38.0))
                                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 38.0))

                                        // Floating badge: now it sits *within the ZStack's larger bounds*, so it won't clip
                                        Image(systemName: "plus")
                                            .font(.title3)
                                            .symbolRenderingMode(.hierarchical)
                                            .foregroundStyle(.foreground)
                                            .padding(10)
                                            .glassEffect(.regular.interactive(), in: Circle())
                                            .offset(x: -12, y: -12)
                                            .allowsHitTesting(false)
                                    }
                                    .padding(.top, 12)
                                    .padding(.leading, 12)

                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical, 12)
        }
    

    }

    
    @ViewBuilder
    private func statCard(_ title: String, value: String, unit: String? = nil) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(unit.map { "\(value) \(value != "None" ? $0 : "")" } ?? value)
                .font(.title)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .contentShape(RoundedRectangle(cornerRadius: 38.0))
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 38.0))
    }

    private func tile(for widget: StatsWidget) -> StatTile {
        switch widget {
        case .allTimeActivities:
            return StatTile(title: "All-time activities", value: "\(allTimeTotalCount)", unit: nil)

        case .currentStreak:
            return StatTile(title: "Current streak", value: "\(currentStreak())", unit: "days")

        case .averagePerDay:
            let v = averageOverLast(days: 1).map { String(format: "%.1f", $0) } ?? "None"
            return StatTile(title: "Average per day", value: v, unit: nil)

        case .averagePerWeek:
            let v = averageOverLast(days: 7).map { String(format: "%.1f", $0) } ?? "None"
            return StatTile(title: "Average per week", value: v, unit: nil)

        case .averagePerMonth:
            let v = averageOverLast(days: 30).map { String(format: "%.1f", $0) } ?? "None"
            return StatTile(title: "Average per month", value: v, unit: nil)

        case .averageSessionLength:
            let v = averageSessionLengthSeconds().map { formatSeconds($0) } ?? "None"
            return StatTile(title: "Average session length", value: v, unit: nil)

        case .goalsMet:
            return StatTile(title: "Goals met", value: "\(goalsMetSummary.count)", unit: nil)

        case .totalStepsAllTime:
            return StatTile(title: "Total steps", value: totalStepsAllTime.map(String.init) ?? "None", unit: nil)

        case .totalCaloriesAllTime:
            let v = totalCaloriesAllTime.map { String(format: "%.0f", $0) } ?? "None"
            return StatTile(title: "Total calories", value: v, unit: "kcal")

        case .averageStepsPerSession:
            let v = averageStepsPerSession.map { String(format: "%.0f", $0) } ?? "None"
            return StatTile(title: "Avg steps/session", value: v, unit: nil)

        case .averageCaloriesPerSession:
            let v = averageCaloriesPerSession.map { String(format: "%.0f", $0) } ?? "None"
            return StatTile(title: "Avg calories/session", value: v, unit: "kcal")
        }
    }
    private func persistWidgets() {
        userInfo?.statsWidgets = liveWidgets
        try? modelContext.save()
    }


    // MARK: - Charts
    private func monthChart(for monthStart: Date) -> AnyView {
        let rows = monthDayCounts(days: 31)
        let chart = Chart {
            ForEach(rows) { r in
                LineMark(x: .value("Day", r.date), y: .value("Count", r.count))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.blue)
            }
        }
        .chartXAxis { AxisMarks(values: rows.map { $0.date }.removingDuplicates()) { _ in AxisGridLine(); AxisTick(); AxisValueLabel(format: .dateTime.month(.abbreviated).day()) } }
        .chartYAxisLabel("Count")

        return AnyView(chart)
    }

    @ViewBuilder
    private func weekChart() -> some View {
        let daysCount = 8
        let starts = dayStarts(days: daysCount)
        let rows = weekStackedCounts(days: daysCount)

        VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(rows) { r in
                    if r.count > 0 {
                        let isHighlighted = (highlightedActivity == nil || highlightedActivity == r.activity)
                        let barColor: Color = isHighlighted ? color(for: r.activity) : Color.primary.opacity(0.18)
                        let barOpacity: Double = isHighlighted ? 1.0 : 0.45

                        BarMark(x: .value("Day", r.date), y: .value("Count", r.count), stacking: .standard)
                            // Emphasize the selected activity; dim others.
                            .foregroundStyle(barColor)
                            .opacity(barOpacity)
                    }
                }
            }
            .chartXAxis { AxisMarks(values: starts.removingDuplicates()) { _ in AxisGridLine(); AxisTick(); AxisValueLabel(format: .dateTime.month(.abbreviated).day()) } }
            .chartXScale(domain: (starts.first ?? Date())...(Calendar.current.date(byAdding: .day, value: 1, to: (starts.last ?? Date())) ?? Date()))
            .chartYAxisLabel("Count")
            // Hide the built-in compact legend and render our own below so it can scroll horizontally
            .chartLegend(.hidden)
            // Attach interactive overlay to the Chart so taps map to chart coordinate
            

            // Custom horizontally-scrollable legend. Tap to choose one activity (enables bubble).
            if !presentActivities.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(presentActivities, id: \.self) { act in
                            Button {
                                bubbleInfo = nil
                                if highlightedActivity == act {
                                    highlightedActivity = nil
                                } else {
                                    highlightedActivity = act
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(color(for: act))
                                        .frame(width: 20, height: 14)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(highlightedActivity == act ? Color.primary.opacity(0.6) : Color.clear, lineWidth: 2)
                                        )
                                    Text(act.displayName)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .foregroundColor(.primary)
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(highlightedActivity == act ? Color.primary.opacity(0.06) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
    }

    @ViewBuilder
    private func dayChart() -> some View {
        let rows = durationsPerActivity(on: selectedDay)
        if rows.isEmpty {
            ContentUnavailableView("No activity for this day", systemImage: "clock")
                .padding()
        } else {
            // Legend activities are those present in today's rows (no unused activities)
            let legendActivities = rows.map { $0.activity }.removingDuplicates()

            VStack(alignment: .leading, spacing: 8) {
                Chart {
                    ForEach(rows) { r in
                        BarMark(x: .value("Activity", r.activity.displayName), y: .value("Minutes", r.seconds / 60.0))
                            .foregroundStyle(color(for: r.activity))
                    }
                }
                .chartYAxisLabel("Minutes")
                // hide any automatic chart legend and render our own below
                .chartLegend(.hidden)

                if !legendActivities.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(legendActivities, id: \.self) { act in
                                HStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(color(for: act))
                                        .frame(width: 20, height: 14)
                                    Text(act.displayName)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .foregroundColor(.primary)
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 4)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                }
            }
        }
    }
}

// Sheet showing all goal completions in the same row format as the recent list
private struct AllGoalCompletionsSheet: View {
    let completions: [(tracker: ActivityTracker, title: String, date: Date)]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(completions.enumerated()), id: \.offset) { _, item in
                    NavigationLink {
                        ActivityHistoryDetailView(tracker: item.tracker)
                    } label: {
                        HStack(alignment: .firstTextBaseline){
                            VStack(alignment: .listRowSeparatorLeading){
                                Text("\(item.title)")
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundColor(.primary)
                                Text(item.tracker.displayActivityName)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(item.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .navigationTitle("All goal completions")
            .toolbar { ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label:{
                    Image(systemName: "chevron.left")
                }
            }
            }
        }
    }
}

private extension Array where Element: Equatable {
    func removingDuplicates() -> [Element] {
        var seen: [Element] = []
        for v in self { if !seen.contains(v) { seen.append(v) } }
        return seen
    }
}
private extension StatsWidget {
    var displayTitle: String {
        switch self {
        case .allTimeActivities: return "All-time activities"
        case .currentStreak: return "Current streak"
        case .averagePerDay: return "Average per day"
        case .averagePerWeek: return "Average per week"
        case .averagePerMonth: return "Average per month"
        case .averageSessionLength: return "Avg session length"
        case .goalsMet: return "Goals met"
        case .totalStepsAllTime: return "Total steps"
        case .totalCaloriesAllTime: return "Total calories"
        case .averageStepsPerSession: return "Avg steps/session"
        case .averageCaloriesPerSession: return "Avg calories/session"
        }
    }
}

struct ActivityChartsQuickLook: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\ActivityTracker.startedAt, order: .reverse)])
    private var activityTrackers: [ActivityTracker]

    private enum Timespan: String, CaseIterable, Identifiable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
        var id: String { rawValue }
    }

    @State private var selectedTimespan: Timespan = .week
    @State private var selectedDay: Date = Date()
    @State private var highlightedActivity: UnifiedActivity? = nil

    var body: some View {
        VStack(spacing: 12) {
            // Timespan picker
            Picker("Timespan", selection: $selectedTimespan) {
                ForEach(Timespan.allCases) { t in Text(t.rawValue).tag(t) }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedTimespan) { _, newValue in
                if newValue != .week { highlightedActivity = nil }
            }

            HStack {
                Text(selectedTimespan == .day ? "Activities today" : (selectedTimespan == .week ? "Last 7 days" : "Last 30 days"))
                    .font(.title3).bold()
                Spacer()
            }

            // Optional date navigation in Day mode
            if selectedTimespan == .day {
                HStack(spacing: 12) {
                    Button {
                        let cal = Calendar.current
                        selectedDay = cal.date(byAdding: .day, value: -1, to: selectedDay) ?? selectedDay
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .padding(8)
                    }
                    .accessibilityLabel("Previous day")

                    Spacer()

                    Text(selectedDay.formatted(date: .abbreviated, time: .omitted))
                        .font(.headline)

                    Spacer()

                    Button {
                        let cal = Calendar.current
                        let today = cal.startOfDay(for: Date())
                        if let newDate = cal.date(byAdding: .day, value: 1, to: selectedDay) {
                            selectedDay = min(newDate, today)
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                            .padding(8)
                    }
                    .accessibilityLabel("Next day")
                    .disabled(Calendar.current.startOfDay(for: selectedDay) >= Calendar.current.startOfDay(for: Date()))
                }
            }

            Group {
                if activityTrackers.isEmpty {
                    ContentUnavailableView("No activity data yet", systemImage: "chart.bar.xaxis")
                        .padding()
                } else {
                    currentChartView
                        .frame(height: 320)
                }
            }
        }
    }

    // MARK: - Type-erased chart
    private var currentChartView: AnyView {
        switch selectedTimespan {
        case .month:
            return AnyView(monthChart(for: selectedDay))
        case .week:
            return AnyView(weekChart())
        case .day:
            return AnyView(dayChart())
        }
    }

    // MARK: - Unified Activity model (shared helper)
    private struct UnifiedActivity: Identifiable, Hashable {
        let id: String
        let displayName: String
        let colorSeed: Int

        static func == (lhs: UnifiedActivity, rhs: UnifiedActivity) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }

        static func from(_ tracker: ActivityTracker) -> UnifiedActivity? {
            if let act = tracker.activity {
                return UnifiedActivity(
                    id: "builtin-\(act.id)",
                    displayName: act.displayName,
                    colorSeed: act.id.hashValue
                )
            }
            if let customID = tracker.customActivityID {
                let name = (tracker.customName ?? tracker.displayActivityName)
                let uuid = customID.uuidString
                return UnifiedActivity(
                    id: "custom-\(uuid)",
                    displayName: name,
                    colorSeed: uuid.hashValue
                )
            }
            if let name = tracker.customName {
                return UnifiedActivity(
                    id: "custom-\(name)",
                    displayName: name,
                    colorSeed: name.hashValue
                )
            }
            return nil
        }
    }

    // Activities present in trackers (deterministic order)
    private var presentActivities: [UnifiedActivity] {
        let set = Set(activityTrackers.compactMap { UnifiedActivity.from($0) })
        return Array(set).sorted { $0.displayName < $1.displayName }
    }

    // MARK: - Colors & helpers
    private func color(for activity: UnifiedActivity) -> Color {
        let hue = Double(abs(activity.colorSeed) % 256) / 255.0
        return Color(hue: hue, saturation: 0.7, brightness: 0.8)
    }

    private func dayStarts(days: Int, calendar: Calendar = .current) -> [Date] {
        let today = calendar.startOfDay(for: Date())
        var starts: [Date] = []
        starts.reserveCapacity(days)
        for i in 0..<days {
            let offset = -(days - 1) + i
            if let d = calendar.date(byAdding: .day, value: offset, to: today) {
                starts.append(d)
            }
        }
        return starts
    }

    // MARK: - Month mode
    private struct SimpleDayCount: Identifiable {
        let id: Date
        let date: Date
        let count: Int
    }

    private func monthDayCounts(days: Int = 30) -> [SimpleDayCount] {
        let starts = dayStarts(days: days)
        var counts: [Date: Int] = [:]
        for s in starts { counts[s] = 0 }
        let calendar = Calendar.current
        for tracker in activityTrackers {
            let day = calendar.startOfDay(for: tracker.startedAt)
            if counts[day] != nil { counts[day]! += 1 }
        }
        return starts.map { SimpleDayCount(id: $0, date: $0, count: counts[$0] ?? 0) }
    }

    private func monthChart(for monthStart: Date) -> some View {
        let rows = monthDayCounts(days: 31)
        return Chart {
            ForEach(rows) { r in
                LineMark(x: .value("Day", r.date), y: .value("Count", r.count))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.blue)
            }
        }
        .chartXAxis {
            AxisMarks(values: rows.map { $0.date }.removingDuplicates()) { _ in
                AxisGridLine(); AxisTick(); AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartYAxisLabel("Count")
    }

    // MARK: - Week mode (stacked counts by activity)
    private struct StackedDayCount: Identifiable {
        let id: String
        let date: Date
        let activity: UnifiedActivity
        let count: Int
    }

    private func weekStackedCounts(days: Int = 7) -> [StackedDayCount] {
        let starts = dayStarts(days: days)
        var counts: [Date: [UnifiedActivity: Int]] = [:]
        for s in starts { counts[s] = [:] }
        let calendar = Calendar.current
        for tracker in activityTrackers {
            let day = calendar.startOfDay(for: tracker.startedAt)
            guard counts[day] != nil else { continue }
            if let ua = UnifiedActivity.from(tracker) {
                counts[day]![ua, default: 0] += 1
            }
        }

        let activities = presentActivities
        var rows: [StackedDayCount] = []
        for s in starts {
            for act in activities {
                let c = counts[s]?[act] ?? 0
                let id = "\(s.timeIntervalSince1970)-\(act.id)"
                rows.append(StackedDayCount(id: id, date: s, activity: act, count: c))
            }
        }
        return rows
    }

    @ViewBuilder
    private func weekChart() -> some View {
        let daysCount = 8
        let starts = dayStarts(days: daysCount)
        let rows = weekStackedCounts(days: daysCount)

        VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(rows) { r in
                    if r.count > 0 {
                        let isHighlighted = (highlightedActivity == nil || highlightedActivity == r.activity)
                        let barColor: Color = isHighlighted ? color(for: r.activity) : Color.primary.opacity(0.18)
                        let barOpacity: Double = isHighlighted ? 1.0 : 0.45

                        BarMark(x: .value("Day", r.date), y: .value("Count", r.count), stacking: .standard)
                            .foregroundStyle(barColor)
                            .opacity(barOpacity)
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: starts.removingDuplicates()) { _ in
                    AxisGridLine(); AxisTick(); AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartXScale(domain: (starts.first ?? Date())...(Calendar.current.date(byAdding: .day, value: 1, to: (starts.last ?? Date())) ?? Date()))
            .chartYAxisLabel("Count")
            .chartLegend(.hidden)

            if !presentActivities.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(presentActivities, id: \.self) { act in
                            Button {
                                if highlightedActivity == act {
                                    highlightedActivity = nil
                                } else {
                                    highlightedActivity = act
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(color(for: act))
                                        .frame(width: 20, height: 14)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(highlightedActivity == act ? Color.primary.opacity(0.6) : Color.clear, lineWidth: 2)
                                        )
                                    Text(act.displayName)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .foregroundColor(.primary)
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(highlightedActivity == act ? Color.primary.opacity(0.06) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Day mode (durations per activity)
    private struct ActivityDuration: Identifiable {
        let id: UnifiedActivity
        let activity: UnifiedActivity
        let seconds: TimeInterval
    }

    private func durationsPerActivity(on day: Date, calendar: Calendar = .current) -> [ActivityDuration] {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        var sums: [UnifiedActivity: TimeInterval] = [:]
        for tracker in activityTrackers {
            let start = tracker.startedAt
            let end = tracker.endedAt ?? Date()
            let clampedStart = max(start, dayStart)
            let clampedEnd = min(end, dayEnd)
            let delta = max(0, clampedEnd.timeIntervalSince(clampedStart))
            if delta > 0, let ua = UnifiedActivity.from(tracker) {
                sums[ua, default: 0] += delta
            }
        }
        return sums.map { ActivityDuration(id: $0.key, activity: $0.key, seconds: $0.value) }
            .sorted { $0.activity.displayName < $1.activity.displayName }
    }

    @ViewBuilder
    private func dayChart() -> some View {
        let rows = durationsPerActivity(on: selectedDay)
        if rows.isEmpty {
            ContentUnavailableView("No activity for this day", systemImage: "clock")
                .padding()
        } else {
            let legendActivities = rows.map { $0.activity }.removingDuplicates()

            VStack(alignment: .leading, spacing: 8) {
                Chart {
                    ForEach(rows) { r in
                        BarMark(x: .value("Activity", r.activity.displayName), y: .value("Minutes", r.seconds / 60.0))
                            .foregroundStyle(color(for: r.activity))
                    }
                }
                .chartYAxisLabel("Minutes")
                .chartLegend(.hidden)

                if !legendActivities.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(legendActivities, id: \.self) { act in
                                HStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(color(for: act))
                                        .frame(width: 20, height: 14)
                                    Text(act.displayName)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .foregroundColor(.primary)
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 4)
                            }
                        }
                    }
                }
            }
        }
    }
}
