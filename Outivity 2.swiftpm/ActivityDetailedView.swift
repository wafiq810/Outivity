import SwiftData
import SwiftUI

struct ActivityDetailedView: View {
    let identity: ActivityIdentity

    // Compatibility for existing code
    init(activity: Activity) {
        self.identity = ActivityIdentity(activity: activity)
    }
    
    init(identity: ActivityIdentity) {
        self.identity = identity
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var activeTracker: ActivityTracker?
    @State private var trackerToShow: ActivityTracker? = nil
    @State private var showTrackerDetail: Bool = false

    @State private var showSourcesSheet: Bool = false
    
    // Custom Goals
    @State private var showCustomGoals: Bool = false
    @State private var selectedGoalIDs: Set<UUID> = []
    
    // Delete custom
    @State private var showDeleteAlert: Bool = false
    @State private var deleteErrorMessage: String? = nil
    @State private var showDeleteErrorAlert: Bool = false
    
    // Custom Activity Lookup
    @Query private var allCustomActivities: [CustomActivity]
    
    // Editing state for custom activities
    @State private var isEditingCustom: Bool = false
    @State private var editedName: String = ""
    @State private var editedSymbolName: String = "figure.run"
    @State private var editedDifficulty: Int = 1
    @State private var editedNeedDistance: Bool = false
    @State private var editedNeedSteps: Bool = false
    @State private var editedNeedMET: Bool = false
    @State private var editedMETValueStr: String = ""
    @State private var editedDescription: String = ""
    @State private var editedSafetyWarnings: [String] = []
    @State private var editedGoals: [EditableGoal] = []
    @State private var editedMinMinutes: Int = 15
    @State private var editedMaxMinutes: Int = 60
    @State private var editedPhoneAllowance: PhoneAvailability = .fullyAllowed
    @State private var editedBuiltInEquipmentIDs: [String] = []
    @State private var editedCustomEquipment: [CustomEquipment] = []
    @State private var showEquipmentSheet: Bool = false
    @State private var showingSymbolPicker: Bool = false
    @Namespace private var editNamespace
    
    // Helper to resolve custom object
    private var customActivity: CustomActivity? {
        if case .custom(let uuid) = identity.kind {
            return allCustomActivities.first(where: { $0.id == uuid })
        }
        return nil
    }

    // Resolve unified metadata
    private var metadata: ActivityMetadata? {
        switch identity.kind {
        case .builtIn(let activity):
            return activityMetadataTable[activity]
        case .custom:
            return customActivity?.asMetadata
        }
    }
    
    // Resolve equipment
    struct DisplayEquipment: Hashable {
        let id: String
        let displayName: String
        let symbolName: String
    }
    
    // Editable goal wrapper for default goals
    struct EditableGoal: Identifiable, Hashable {
        let id = UUID()
        var title: String
        var difficulty: Int
    }
    
    private var currentDisplayName: String {
        if isEditingCustom { return editedName }
        return customActivity?.name ?? identity.displayName
    }
    
    private var currentSymbolName: String {
        if isEditingCustom { return editedSymbolName }
        return customActivity?.symbolName ?? identity.symbolName
    }
    
    private var itemsNeeded: [DisplayEquipment] {
        switch identity.kind {
        case .builtIn(let activity):
            return activity.requiredEquipment.map {
                DisplayEquipment(id: $0.id, displayName: $0.displayName, symbolName: $0.symbolName)
            }
        case .custom:
            if isEditingCustom {
                var list: [DisplayEquipment] = []
                for item in editedCustomEquipment {
                    list.append(DisplayEquipment(id: item.id.uuidString, displayName: item.displayName, symbolName: item.symbolName))
                }
                for id in editedBuiltInEquipmentIDs {
                    if let eq = Equipment(rawValue: id) {
                        list.append(DisplayEquipment(id: eq.id, displayName: eq.displayName, symbolName: eq.symbolName))
                    }
                }
                return list
            }
            guard let custom = customActivity else { return [] }
            var list: [DisplayEquipment] = []
            for item in custom.customEquipment {
                list.append(DisplayEquipment(id: item.id.uuidString, displayName: item.displayName, symbolName: item.symbolName))
            }
            for id in custom.builtInEquipmentIDs {
                if let eq = Equipment(rawValue: id) {
                    list.append(DisplayEquipment(id: eq.id, displayName: eq.displayName, symbolName: eq.symbolName))
                }
            }
            return list
        }
    }

    var body: some View {
        ScrollView {
            Group {
                if isEditingCustom, customActivity != nil {
                    editContent
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if let metadata {
                    detailContent(metadata)
                        .transition(.opacity.combined(with: .scale))
                } else {
                    ContentUnavailableView(
                        "Activity Not Found",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Could not load activity details.")
                    )
                }
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: isEditingCustom)
        .sheet(isPresented: $showCustomGoals) {
            NavigationStack {
                CustomGoalView(identity: identity, selectedGoalIDs: $selectedGoalIDs, isSelectionMode: true)
            }
        }
        .sheet(isPresented: $showSourcesSheet) {
            if case .builtIn = identity.kind, let metadata {
                ActivitySourcesSheetView(activityName: currentDisplayName, sources: metadata.sources)
            }
        }
        .sheet(isPresented: $showingSymbolPicker) {
            SymbolPickerView(selectedSymbol: $editedSymbolName)
        }
        .sheet(isPresented: $showEquipmentSheet) {
            EquipmentPickerSheet(
                isPresented: $showEquipmentSheet,
                selectedEquipment: $editedBuiltInEquipmentIDs.asEquipmentSelection(),
                selectedCustomEquipment: $editedCustomEquipment,
                title: "Equipment",
                showsAddCustomEquipmentButton: true
            )
        }
        .toolbar {
            if customActivity != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if isEditingCustom {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                saveEdits()
                            }
                        } else {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                beginEditingCustom()
                            }
                        }
                    } label: {
                        if isEditingCustom {
                            Text("Done")
                        } else {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                    .disabled(isEditingCustom && editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            
        }
        .alert("Delete this activity?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteCustomActivity()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This activity will be deleted, but the history will remain.")
        }
        .alert("Couldn’t delete activity", isPresented: $showDeleteErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteErrorMessage ?? "Please try again.")
        }
    }

    private func detailContent(_ metadata: ActivityMetadata) -> some View {
        VStack(spacing: 30){
            VStack{
                icon
                    .frame(width: 75, height: 75)
                    .background(circleBackground)
                    .clipShape(.circle)
                Text(currentDisplayName)
                    .font(.system(size: 37, weight: .bold, design: .rounded))
                Text("\(metadata.estimatedMinutes.lowerBound) - \(metadata.estimatedMinutes.upperBound) minutes")
                    .foregroundStyle(.secondary)

            }
            
            Button {
                startSession()
            } label: {
                HStack { Text("Start activity") }
                    .padding()
            }
            .navigationDestination(item: $trackerToShow) { tracker in
                ActivityTrackerView(tracker: tracker)
            }
            .buttonStyle(.glassProminent)
            .padding(.horizontal)
            
            Button {
                showCustomGoals = true
            } label: {
                HStack {
                    Image(systemName: "target")
                    Text("Custom goals")
                    Spacer()
                    if !selectedGoalIDs.isEmpty {
                        Text("\(selectedGoalIDs.count)")
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(Color.blue)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                
            }
            .padding(.horizontal)
            .buttonStyle(.glass)
            
            Text("\(metadata.description)")
                .padding()
                
            VStack{
                switch metadata.phoneAvailability {
                case .notAllowed:
                    VStack(){
                        VStack(spacing: 7){
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title)
                                .foregroundStyle(.red)
                            Text("Do not bring your phone")
                                .font(.headline)
                        }.padding(.top)
                        
                        Text("For your safety, leaving your phone behind for \(currentDisplayName) is strongly recommended. Bringing it along may result in damage. So please consider leaving it in a safe position before starting \(currentDisplayName).")
                            .padding()
                        
                        Text("Calories won't be tracked")
                            .font(.headline)
                        Text("Your calories will not be tracked due to the phone's movement restriction.")
                            .padding()
                    }
                    .padding()
                    .background(.red.opacity(0.1))
                    .cornerRadius(40)
                case .allowedWithRisk:
                    VStack{
                        VStack(spacing: 7){
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(.yellow)
                            Text("Careful bringing your phone")
                                .font(.headline)
                        }.padding(.top)
                        
                        Text("If you decide to bring your phone during \(currentDisplayName), please make sure to take extra care to protect it.")
                            .padding()
                    }.padding()
                        .background(.yellow.opacity(0.1))
                        .cornerRadius(40)
                default:
                    VStack{
                        VStack(spacing: 7){
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(.blue)
                            Text("Bring your phone")
                                .font(.headline)
                        }.padding(.top)
                        Text("Bringing your phone along for \(currentDisplayName) is generally safe, but it's important to handle it with care to avoid potential damage during \(currentDisplayName).")
                            .padding()
                    }.padding()
                        .background(.blue.opacity(0.1))
                        .cornerRadius(40)
                }
            }.padding(.horizontal)
            
            if !itemsNeeded.isEmpty{
                Text("What do I need?")
                    .font(.title2)
                    .fontWeight(.bold)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(itemsNeeded.sorted { $0.displayName < $1.displayName }, id: \.self) { equipment in
                        HStack(alignment: .center) {
                            Image(systemName: equipment.symbolName)
                                .font(.title)
                                .frame(width: 50, height: 100)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(equipment.displayName)
                                    .font(.body)
                            }
                            Spacer()
                            
                        }
                        .foregroundColor(.primary)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.2))
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)))
                        )
                        
                    }
                }.padding()
            }
            
            if !metadata.safetyWarnings.isEmpty {
                VStack{
                    Text("Safety tips")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    ForEach(metadata.safetyWarnings, id: \.self){ safetyWarning in
                        HStack{
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                                .padding(.trailing, 10)
                                .font(.title2)
                            Text(safetyWarning)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding()
                    }
                }
                .padding()
                .background(.red.opacity(0.1))
                .cornerRadius(40)
                .padding()
            }
            if case .builtIn = identity.kind {
                VStack{
                    Button {
                        showSourcesSheet = true
                    } label: {
                        Text("Where are the safety tips from?")
                        Image(systemName: "book")
                        
                    }
                    .accessibilityLabel("Sources")
                }
            }
        }
        .padding(.horizontal)
        .padding(.top)
       
    }

    // Editable form for custom activities
    private var editContent: some View {
        VStack(spacing: 20) {
            sectionCard {
                VStack(spacing: 12) {
                    Image(systemName: editedSymbolName)
                        .font(.system(size: 100))
                        .foregroundColor(.blue)
                        .matchedGeometryEffect(id: "icon", in: editNamespace)
                    Button("Change Icon") { showingSymbolPicker = true }
                        .buttonStyle(.glass)
                    TextField("Activity Name", text: $editedName)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .padding()
                        .glassEffect()
                }
            }
            
            sectionCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Difficulty")
                        .font(.title3).fontWeight(.semibold)
                    DifficultySelector(difficulty: $editedDifficulty)
                }
            }
            
            sectionCard {
                HStack {
                    Text("Estimated Minutes")
                        .font(.title3).fontWeight(.semibold)
                    Spacer()
                    TextField("Min", value: $editedMinMinutes, format: .number)
                        .multilineTextAlignment(.center)
                        .frame(width: 40)
                    Text("to")
                    TextField("Max", value: $editedMaxMinutes, format: .number)
                        .multilineTextAlignment(.center)
                        .frame(width: 40)
                }
            }
            
            sectionCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.title3).fontWeight(.semibold)
                    TextField("Describe your activity (Optional)", text: $editedDescription, axis: .vertical)
                        .padding()
                        .glassEffect(in: RoundedRectangle(cornerRadius: 24))
                }
            }
            
            sectionCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Phone Availability")
                            .font(.title3).fontWeight(.semibold)
                        Spacer()
                        Picker("Phone Allowance", selection: $editedPhoneAllowance) {
                            Text("Fully Allowed").tag(PhoneAvailability.fullyAllowed)
                            Text("Allowed with Risk").tag(PhoneAvailability.allowedWithRisk)
                            Text("Not Allowed").tag(PhoneAvailability.notAllowed)
                        }
                        .pickerStyle(.menu)
                    }
                    if editedPhoneAllowance != .notAllowed {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tracking")
                                .font(.title3).fontWeight(.semibold)
                            Toggle("Track Distance", isOn: $editedNeedDistance)
                            Toggle("Track Steps", isOn: $editedNeedSteps)
                            Toggle("Track Calories", isOn: $editedNeedMET)
                                .tint(.orange)
                            if editedNeedMET {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Metabolic Equivalent of Task (MET)")
                                        .fontWeight(.semibold)
                                    TextField("MET Value", text: $editedMETValueStr)
                                        .padding()
                                        .keyboardType(.decimalPad)
                                        .glassEffect(in: RoundedRectangle(cornerRadius: 18))
                                    Text("MET captures activity intensity to estimate calories burned.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .transition(.opacity)
                            }
                        }
                    }
                }
            }
            
            sectionCard { SafetyWarningsEditor(safetyWarnings: $editedSafetyWarnings) }
            sectionCard { GoalsEditor(editableGoals: $editedGoals) }
            
            sectionCard {
                VStack(spacing: 12) {
                    VStack{
                        HStack {
                            Text("Equipment")
                                .font(.title3).fontWeight(.semibold)
                            Spacer()
                            Button { showEquipmentSheet = true } label: {
                                Image(systemName: "plus")
                            }
                            .buttonStyle(.glassProminent)
                        }
                        if editedBuiltInEquipmentIDs.isEmpty && editedCustomEquipment.isEmpty {
                            Text("No equipment selected yet.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        if !editedBuiltInEquipmentIDs.compactMap(Equipment.init(rawValue:)).isEmpty {
                            Text("Selected Built-in Equipment")
                                .font(.subheadline)
                        }
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(editedBuiltInEquipmentIDs.compactMap(Equipment.init(rawValue:))) { equipment in
                                EquipmentCardView(symbolName: equipment.symbolName, title: equipment.displayName)
                                    .transition(.opacity)
                            }
                        }
                        if !editedCustomEquipment.isEmpty {
                            Text("Selected Custom Equipment")
                                .font(.subheadline)
                        }
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(editedCustomEquipment) { equipment in
                                EquipmentCardView(symbolName: equipment.symbolName, title: equipment.displayName)
                                    .transition(.opacity)
                            }
                        }
                    }
                }
            }
            
            sectionCard {
                VStack(alignment: .center, spacing: 10) {
                    Text("Danger zone")
                        .font(.headline)

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Spacer()
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete activity")
                        }
                        .padding(.vertical, 6)
                        .foregroundStyle(.red)
                        Spacer()
                    }
                    .tint(.red)
                    .buttonStyle(.glass)
                }
                
            }
            
        }
        .padding(.horizontal)
        .padding(.top)
        .padding(.bottom, 24)
        
    }

    private func beginEditingCustom() {
        guard let custom = customActivity else { return }
        editedName = custom.name
        editedSymbolName = custom.symbolName
        editedDifficulty = custom.difficulty
        editedNeedDistance = custom.needDistance
        editedNeedSteps = custom.needSteps
        editedNeedMET = custom.metValue != nil
        editedMETValueStr = custom.metValue.map { "\($0)" } ?? ""
        editedDescription = custom.userDescription
        editedSafetyWarnings = custom.safetyWarnings.isEmpty ? [""] : custom.safetyWarnings
        editedGoals = custom.defaultGoals.map { EditableGoal(title: $0.title, difficulty: max(1, min(5, $0.difficulty))) }
        editedMinMinutes = custom.minMinutes
        editedMaxMinutes = custom.maxMinutes
        editedPhoneAllowance = custom.phoneAllowance
        editedBuiltInEquipmentIDs = custom.builtInEquipmentIDs
        editedCustomEquipment = custom.customEquipment
        isEditingCustom = true
    }
    
    private func saveEdits() {
        guard let custom = customActivity else { return }
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let warnings = editedSafetyWarnings
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let cleanGoals: [GoalTemplate] = editedGoals
            .map { EditableGoal(title: $0.title.trimmingCharacters(in: .whitespacesAndNewlines), difficulty: max(1, min(5, $0.difficulty))) }
            .filter { !$0.title.isEmpty }
            .map { GoalTemplate(id: UUID(), title: $0.title, difficulty: $0.difficulty) }
        let met: Double?
        if editedNeedMET {
            met = Double(editedMETValueStr.trimmingCharacters(in: .whitespacesAndNewlines))
        } else {
            met = nil
        }
        let minMinutes = max(1, editedMinMinutes)
        let maxMinutes = max(minMinutes, editedMaxMinutes)
        do {
            try CustomActivityStore.update(
                custom,
                name: trimmedName,
                symbolName: editedSymbolName,
                difficulty: editedDifficulty,
                needDistance: editedNeedDistance,
                needSteps: editedNeedSteps,
                metValue: met,
                userDescription: editedDescription,
                safetyWarnings: warnings,
                defaultGoals: cleanGoals,
                minMinutes: minMinutes,
                maxMinutes: maxMinutes,
                phoneAllowance: editedPhoneAllowance,
                customEquipment: editedCustomEquipment,
                builtInEquipmentIDs: editedBuiltInEquipmentIDs,
                in: modelContext
            )
            isEditingCustom = false
        } catch {
            // Keep behavior simple for now (no new UI): just don't exit edit mode on failure.
            // If you want, we can add a save error banner/alert later.
        }
    }

    private func deleteCustomActivity() {
        guard let custom = customActivity else { return }
        do {
            try CustomActivityStore.delete(custom, in: modelContext)
            isEditingCustom = false
            dismiss()
        } catch {
            deleteErrorMessage = error.localizedDescription
            showDeleteErrorAlert = true
        }
    }

    private struct DifficultySelector: View {
        @Binding var difficulty: Int
        var body: some View {
            HStack {
                ForEach(1...5, id: \.self) { level in
                    Spacer()
                    Button {
                        withAnimation(.spring()) { difficulty = level }
                    } label: {
                        Image(systemName: level <= difficulty ? "flame.fill" : "flame")
                            .font(.system(size: level == difficulty ? 22 : 18))
                            .foregroundStyle(level <= difficulty ? Color.white : Color.primary)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(level <= difficulty ? Color.blue : Color(.systemBackground))
                                    .overlay(Circle().stroke(level == difficulty ? Color.blue : Color.gray.opacity(0.2), lineWidth: level == difficulty ? 0 : 1))
                            )
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
        }
    }
    
    private struct SafetyWarningsEditor: View {
        @Binding var safetyWarnings: [String]
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Safety Warnings")
                        .font(.title3).fontWeight(.semibold)
                    Spacer()
                    Button { safetyWarnings.append("") } label: { Image(systemName: "plus.circle.fill") }
                        .buttonStyle(.plain)
                }
                if safetyWarnings.isEmpty {
                    Text("No warnings added")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(safetyWarnings.indices), id: \.self) { idx in
                        HStack(spacing: 8) {
                            TextField("Warning \(idx + 1)", text: Binding(get: { safetyWarnings[idx] }, set: { safetyWarnings[idx] = $0 }))
                                .textInputAutocapitalization(.sentences)
                            Button(role: .destructive) { safetyWarnings.remove(at: idx) } label: { Image(systemName: "minus.circle.fill").foregroundStyle(.red) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
    
    private struct GoalsEditor: View {
        @Binding var editableGoals: [EditableGoal]
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Default Goals")
                        .font(.title3).fontWeight(.semibold)
                    Spacer()
                    Button { editableGoals.append(EditableGoal(title: "", difficulty: 1)) } label: { Image(systemName: "plus.circle.fill") }
                        .buttonStyle(.plain)
                }
                if editableGoals.isEmpty {
                    Text("No default goals added")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(editableGoals.indices), id: \.self) { idx in
                        HStack(spacing: 8) {
                            TextField("Title", text: Binding(get: { editableGoals[idx].title }, set: { editableGoals[idx].title = $0 }))
                                .textInputAutocapitalization(.words)
                            Stepper(value: Binding(get: { editableGoals[idx].difficulty }, set: { editableGoals[idx].difficulty = max(1, min(5, $0)) }), in: 1...5) {
                                Text("Diff \(editableGoals[idx].difficulty)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Button(role: .destructive) { editableGoals.remove(at: idx) } label: { Image(systemName: "minus.circle.fill").foregroundStyle(.red) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var icon: some View {
        Image(systemName: currentSymbolName)
            .font(.system(size: 24))
            .foregroundStyle(.white)
    }
    
    private var circleBackground: some View {
        let hue = identity.colorHue
        return LinearGradient(colors: [Color(hue: hue, saturation: 0.6, brightness: 0.9), Color(hue: hue, saturation: 0.8, brightness: 0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    private func sectionCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding()
        .glassEffect(in: RoundedRectangle(cornerRadius: 32))
    }
    
    func startSession() {
       let selectedCustomGoals: [CustomGoal]
        if !selectedGoalIDs.isEmpty {
            let ids = selectedGoalIDs
            let desc = FetchDescriptor<CustomGoal>(predicate: #Predicate<CustomGoal> { ids.contains($0.id) })
            selectedCustomGoals = (try? modelContext.fetch(desc)) ?? []
        } else {
            selectedCustomGoals = []
        }
        
        let templates = selectedCustomGoals.map { GoalTemplate(id: $0.id, title: $0.title, difficulty: $0.difficulty) }
        
        switch identity.kind {
        case .builtIn(let activity):
            trackerToShow = ActivityTrackerStore.startNewActivity(activity, in: modelContext, presetGoals: templates)
            
        case .custom:
            if let custom = customActivity {
                trackerToShow = ActivityTrackerStore.startCustomActivity(custom, in: modelContext, presetGoals: templates)
            }
        }
    }
}

struct ActivitySourcesSheetView: View {
    let activityName: String
    let sources: [SourceTemplate]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if sources.isEmpty {
                        ContentUnavailableView(
                            "No sources",
                            systemImage: "book",
                            description: Text("No sources are available for \(activityName) yet.")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(sources) { source in
                            SourceRow(source: source)
                        }
                    }
                } header: {
                    VStack(spacing: 10) {
                        Text("Information you can trust")
                            .font(.title3)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                        Text("All activity information, including safety recommendations and calorie-calculation constants, is compiled exclusively from official U.S. Government sources to ensure accuracy, reliability, and public-domain legitimacy.")
                            .font(.callout)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Sources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
        }
    }
}

private struct SourceRow: View {
    let source: SourceTemplate

    private var url: URL? {
        let trimmed = source.hyperLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let u = URL(string: trimmed), u.scheme != nil {
            return u
        }
        // If the link is missing a scheme, default to https.
        return URL(string: "https://\(trimmed)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(source.title.isEmpty ? "Source" : source.title)
                .font(.headline)

            if let description = source.description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let url {
                Link(url.absoluteString, destination: url)
                    .font(.subheadline)
            } else if !source.hyperLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(source.hyperLink)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        ActivityDetailedView(activity: Activity.camping)
    }
}

